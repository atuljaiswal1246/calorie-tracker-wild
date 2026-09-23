#!/usr/bin/env python3
"""Telegram <-> OpenCode bridge for the Cal Matters session.

Relays messages between the @Calmatters_bot Telegram bot and a running
OpenCode session, over the local OpenCode HTTP API. Stdlib only.

Config (kept OUT of the repo):  ~/.config/calmatters/telegram.json
  {
    "bot_token": "123:ABC...",
    "session_id": "ses_...",
    "allowed_chat_ids": [ 123456789 ]   # auto-bound on the first message
  }

Run:  python3 tools/telegram_bridge.py
Stop: Ctrl-C (or kill the background process)
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CONFIG_PATH = os.path.expanduser("~/.config/calmatters/telegram.json")
SERVICE_PATH = os.path.expanduser("~/.config/opencode/service.json")
OPENCODE_BASE = "http://127.0.0.1:49374"
TELEGRAM_POLL = 50          # long-poll seconds
TURN_TIMEOUT = 1800         # max wait for one agent turn (30 min)
TELEGRAM_MAX = 4000         # chars per Telegram message


def log(*parts):
    print(time.strftime("%H:%M:%S"), *parts, flush=True)


def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)


def save_config(cfg):
    tmp = CONFIG_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CONFIG_PATH)


# ----------------------------- Telegram -------------------------------------

def tg(token, method, params=None):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = json.dumps(params or {}).encode()
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=TELEGRAM_POLL + 20) as r:
        return json.loads(r.read().decode())


def tg_send(token, chat_id, text):
    text = text if (text and text.strip()) else "(no text reply)"
    # Split into Telegram-sized chunks on line boundaries where possible.
    while text:
        chunk, text = text[:TELEGRAM_MAX], text[TELEGRAM_MAX:]
        try:
            tg(token, "sendMessage", {
                "chat_id": chat_id,
                "text": chunk,
                "disable_web_page_preview": True,
            })
        except Exception as e:  # noqa: BLE001
            log("sendMessage failed:", e)


# ----------------------------- OpenCode -------------------------------------

def _password():
    with open(SERVICE_PATH) as f:
        return json.load(f)["password"]


class OpenCode:
    def __init__(self):
        self._auth = "Basic " + base64.b64encode(
            f"opencode:{_password()}".encode()
        ).decode()

    def _req(self, method, path, body=None):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(OPENCODE_BASE + path, data=data, method=method)
        req.add_header("Authorization", self._auth)
        if data is not None:
            req.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
        return json.loads(raw) if raw.strip() else {}

    def info(self):
        return self._req("GET", "/api/info")

    def messages(self, sid, limit=30):
        q = urllib.parse.urlencode({"order": "desc", "limit": str(limit)})
        return self._req("GET", f"/api/session/{sid}/message?{q}").get("data", [])

    def prompt(self, sid, text):
        return self._req("POST", f"/api/session/{sid}/prompt", {"text": text})

    def interrupt(self, sid):
        return self._req("POST", f"/api/session/{sid}/interrupt")


def _assistant_text(msg):
    parts = [
        p.get("text", "")
        for p in (msg.get("content") or [])
        if p.get("type") == "text"
    ]
    return "\n".join(t for t in parts if t).strip()


def wait_for_reply(oc, sid, baseline_id):
    """Poll the session until the turn finishes; return the final answer text.

    Completion = an `idle` message newer than baseline, or the newest assistant
    message carrying a completed timestamp.
    """
    deadline = time.time() + TURN_TIMEOUT
    while time.time() < deadline:
        msgs = oc.messages(sid, limit=40)  # newest first
        new = []
        for m in msgs:
            if baseline_id and m.get("id") == baseline_id:
                break
            new.append(m)
        new.reverse()  # chronological

        idle = any(m.get("type") == "idle" for m in new)
        texts = [
            _assistant_text(m) for m in new if m.get("type") == "assistant"
        ]
        texts = [t for t in texts if t]
        answer = texts[-1] if texts else ""

        if idle:
            return answer
        if texts:
            newest_assistant = [m for m in new if m.get("type") == "assistant"][-1]
            if (newest_assistant.get("time") or {}).get("completed"):
                return answer
        time.sleep(1.5)
    return "(timed out waiting for the agent to finish)"


# ----------------------------- Main loop ------------------------------------

def main():
    cfg = load_config()
    token = cfg["bot_token"]
    sid = cfg["session_id"]
    allowed = set(cfg.get("allowed_chat_ids") or [])
    oc = OpenCode()

    try:
        info = oc.info()
        log(f"OpenCode {info.get('version')} at {info.get('urls')}")
    except Exception as e:  # noqa: BLE001
        log("WARNING: OpenCode not reachable:", e)
    log(f"bridge up — session {sid}; allowed chats: {allowed or '(none yet)'}")

    # Drop any backlog so we don't replay old messages.
    offset = 0
    try:
        r = tg(token, "getUpdates", {"offset": -1, "timeout": 0})
        for u in r.get("result", []):
            offset = u["update_id"] + 1
    except Exception as e:  # noqa: BLE001
        log("backlog drain failed:", e)

    while True:
        try:
            r = tg(token, "getUpdates", {"offset": offset, "timeout": TELEGRAM_POLL})
        except Exception as e:  # noqa: BLE001
            log("getUpdates error:", e)
            time.sleep(3)
            continue

        for u in r.get("result", []):
            offset = u["update_id"] + 1
            msg = u.get("message") or u.get("edited_message")
            if not msg:
                continue
            chat_id = (msg.get("chat") or {}).get("id")
            text = (msg.get("text") or "").strip()
            frm = msg.get("from") or {}
            who = frm.get("first_name") or frm.get("username") or "someone"
            if not text or chat_id is None:
                continue

            # Hot-reload the allowlist so approvals apply without a restart.
            try:
                fresh = load_config()
                allowed = set(fresh.get("allowed_chat_ids") or [])
                cfg = fresh
            except Exception:  # noqa: BLE001
                pass

            # First ever message binds this chat as the owner.
            if not allowed:
                allowed.add(chat_id)
                cfg["allowed_chat_ids"] = sorted(allowed)
                save_config(cfg)
                log(f"bound owner chat {chat_id} ({who})")
                tg_send(token, chat_id,
                        "✅ Cal Matters bridge connected (you are the owner).\n"
                        "Send any message and I'll relay it to the agent.\n"
                        "Commands: /status, /who, /allow <id>, /deny <id>")

            # ---- Unknown chat: log + notify the owner, do not relay ----
            if chat_id not in allowed:
                log(f"access request from {who} (chat {chat_id})")
                tg_send(token, chat_id,
                        "⏳ Not approved yet — the owner has been notified.")
                for owner in allowed:
                    tg_send(token, owner,
                            f"🔔 Access request: {who} (id {chat_id}).\n"
                            f"Reply /allow {chat_id} to approve.")
                continue

            # ---- Owner-only admin commands ----
            if text.startswith("/allow "):
                try:
                    new_id = int(text.split(None, 1)[1].strip())
                except ValueError:
                    tg_send(token, chat_id, "Usage: /allow <chat_id>")
                    continue
                allowed.add(new_id)
                cfg["allowed_chat_ids"] = sorted(allowed)
                save_config(cfg)
                tg_send(token, chat_id, f"✅ Approved {new_id}.")
                tg_send(token, new_id, "✅ You now have access to Cal Matters.")
                continue

            if text.startswith("/deny "):
                try:
                    rm_id = int(text.split(None, 1)[1].strip())
                except ValueError:
                    tg_send(token, chat_id, "Usage: /deny <chat_id>")
                    continue
                if rm_id == chat_id:
                    tg_send(token, chat_id, "You can't remove yourself.")
                    continue
                allowed.discard(rm_id)
                cfg["allowed_chat_ids"] = sorted(allowed)
                save_config(cfg)
                tg_send(token, chat_id, f"✅ Removed {rm_id}.")
                continue

            if text == "/who":
                tg_send(token, chat_id,
                        "Allowed chats: " + ", ".join(str(i) for i in sorted(allowed)))
                continue

            if text in ("/start", "/help"):
                tg_send(token, chat_id,
                        "Cal Matters bridge is running. Send a message and I'll "
                        "pass it to the agent and reply here.\n"
                        "/status — server check\n/who — allowed chats")
                continue
            if text == "/status":
                try:
                    info = oc.info()
                    tg_send(token, chat_id,
                            f"OpenCode {info.get('version')} up.\nSession: {sid}")
                except Exception as e:  # noqa: BLE001
                    tg_send(token, chat_id, f"OpenCode unreachable: {e}")
                continue

            try:
                tg(token, "sendChatAction", {"chat_id": chat_id, "action": "typing"})
            except Exception:  # noqa: BLE001
                pass

            try:
                before = oc.messages(sid, limit=1)
                baseline = before[0]["id"] if before else None
                log(f"relay <- {who} ({chat_id}): {text[:70]!r}")
                oc.prompt(sid, text)
                reply = wait_for_reply(oc, sid, baseline)
                log(f"reply {len(reply)} chars -> {chat_id}")
                tg_send(token, chat_id, reply)
            except Exception as e:  # noqa: BLE001
                log("relay error:", e)
                tg_send(token, chat_id, f"⚠️ Bridge error: {e}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
