#!/usr/bin/env python3
"""Did a role's hash LAND, or did the role only say a hash?

THE DEFECT (2026-09-28 13:47). I ordered two drifting roles to end their reply
with a commit hash. Both did:

    Research Lead      replied 13:46:53, hash 581620f
    Engineering Lead   replied 13:47:36, hash 37d4f3c

Then I ran `git log -1 581620f` in the repo they work in, and:

    fatal: ambiguous argument '581620f': unknown revision or path not in the
    working tree.
    $ git cat-file -t 581620f
    fatal: Not a valid object name

So one of the two hashes is not a commit. Not a commit that is unpushed, not a
commit on another branch - not an object in that repository at all. A role said a
hash that does not exist, and the doorbell would have counted it as a landing,
because a doorbell that reads the MESSAGE cannot tell a hash from a string that
looks like one.

That is the whole class this repo keeps meeting, wearing a new hat: a claim
nothing can disagree with. The order said "end your reply with the short hash",
and the reply ended with a short hash, and the instruction was satisfied while
the work was not done. Satisfying the SHAPE of a done-condition is not
satisfying it.

WHAT THIS DOES. Reads the roles' own last assistant message, extracts hex tokens
that look like hashes, and asks GIT whether each one is an object in the repo.
Reports LANDED / NOT A COMMIT / NO HASH. Exits 1 when a role that answered has
no real commit behind its claim.

BOUNDARY. Read-only on the other company's repo: `git log`/`git cat-file` only,
never a write. It reads their sessions and their history; it changes nothing.

Exit codes
  0  every answering role's hash resolves to a real commit
  1  a role answered with a hash that is not a commit, or with none at all
  2  a role's session could not be read. NOT VERIFIED, which is not a pass.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

API = "http://127.0.0.1:49374"
OTHER_REPO = Path.home() / "Desktop" / "Jarvis"
STATE = Path(__file__).resolve().parent.parent / ".agent-logs" / "drift_orders.json"
# A git short hash is 7-40 hex. Anchored on a word boundary so a word that merely
# starts with hex letters ("facade", "decade") is not read as a hash.
HASH = re.compile(r"(?<![0-9a-zA-Z])([0-9a-f]{7,40})(?![0-9a-zA-Z])")


def _pw() -> str:
    return json.loads(
        (Path.home() / ".config" / "opencode" / "service.json")
        .read_text(encoding="utf-8"))["password"]


def last_reply(sid: str, timeout: float = 20.0) -> tuple[str | None, int | None, str]:
    """The role's most recent assistant text, its created time, and the model.

    The field names are `type` and `content` on this service. My first reader
    looked for `info.role` / `parts`, found nothing, and would have reported "no
    reply" for a role that had replied three minutes earlier - which is the same
    false negative as an empty instrument, wearing a new hat.
    """
    auth = "Basic " + base64.b64encode(
        ("opencode:" + _pw()).encode()).decode()
    req = urllib.request.Request(f"{API}/api/session/{sid}/message",
                                 headers={"authorization": auth})
    d = json.loads(urllib.request.urlopen(req, timeout=timeout).read())
    msgs = d.get("data", []) if isinstance(d, dict) else []
    asst = [m for m in msgs if isinstance(m, dict) and m.get("type") == "assistant"]
    if not asst:
        return None, None, ""
    last = asst[0]
    txt = " ".join(c.get("text", "") for c in last.get("content", [])
                   if isinstance(c, dict) and c.get("type") == "text")
    ms = last.get("time", {}).get("created")
    return txt, ms, (last.get("model") or {}).get("id", "?")


def is_commit(repo: Path, h: str) -> bool:
    p = subprocess.run(["git", "cat-file", "-t", h], cwd=str(repo),
                       capture_output=True, text=True)
    return p.returncode == 0 and p.stdout.strip() == "commit"


def subject_of(repo: Path, h: str) -> str:
    p = subprocess.run(["git", "log", "-1", "--format=%ad %s", "--date=format:%H:%M", h],
                       cwd=str(repo), capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--role", help="check one role by name")
    args = ap.parse_args()

    if not STATE.exists():
        print("NOT VERIFIED: no drift_orders.json - nobody has been ordered yet, "
              "so there is nothing to hold to a commit.")
        return 2
    orders = json.loads(STATE.read_text(encoding="utf-8"))

    rows, unreadable, bad = [], 0, []
    for role, rec in orders.items():
        if args.role and role != args.role:
            continue
        sid = rec.get("session")
        if not sid:
            unreadable += 1
            continue
        try:
            txt, ms, model = last_reply(sid)
        except Exception as e:  # noqa: BLE001
            print(f"  {role:<20} SESSION UNREADABLE ({type(e).__name__}) - "
                  f"NOT VERIFIED, not a pass")
            unreadable += 1
            continue
        if txt is None:
            print(f"  {role:<20} ordered, no reply yet - waiting, not failing")
            continue
        at = time.strftime("%H:%M:%S",
                           time.localtime(ms / 1000)) if ms else "?"
        cands = [h for h in HASH.findall(txt) if is_commit(OTHER_REPO, h)]
        claimed = HASH.findall(txt)
        if cands:
            h = cands[0]
            print(f"  {role:<20} LANDED  {at} {h}  {subject_of(OTHER_REPO, h)[:60]}")
            rows.append((role, "LANDED", h))
        elif claimed:
            print(f"  {role:<20} NOT A COMMIT  {at}  it said {claimed[0]}, which "
                  f"is not an object in that repo")
            rows.append((role, "NOT A COMMIT", claimed[0]))
            bad.append(role)
        else:
            print(f"  {role:<20} NO HASH  {at}  the order asked for a hash; there "
                  f"is not one in the reply")
            rows.append((role, "NO HASH", "-"))
            bad.append(role)

    print("")
    if bad:
        print(f"FAIL: {len(bad)} role(s) answered without a real commit behind "
              f"it: {', '.join(bad)}.")
        print("A doorbell that reads the MESSAGE counts a string shaped like a")
        print("hash as a landing. A shape is not a landing.")
        return 1
    if unreadable:
        print(f"PARTIAL: {unreadable} role(s) unreadable. Not verified, not failed.")
        return 2
    print(f"PASS: every answered role's hash resolves to a commit in {OTHER_REPO}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
