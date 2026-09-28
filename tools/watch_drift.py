#!/usr/bin/env python3
"""Read the drift number, and make stopping a drift role MY job, not the owner's.

THE ORDER THIS ENFORCES (owner, 2026-09-28 13:30): "har drift role ko TUM
personally ek order do ... apni report me likho 'maine X ko diya, uska jawaab
<hash>'", and "aaj ka pattern: role chup hote hain kyunki koi unhe rokta nahi, aur
main ye baat guard se nahi, har baar khud ke haath se karta hoon - jo scale nahi
hota."

The last clause is the whole point. The owner was doing this by hand, at 10:55
and again at 13:30, in chat. A thing done by hand in chat is a thing that does
not happen on the day it is also needed. So: read the other company's drift
instrument, and FAIL if a role is drifting and has not been given an order by me
since the last check.

WHAT THIS DOES NOT DO. It does not edit, create or commit anything in the other
company's repo. It runs their read-only instrument and posts a prompt to their
session - the same thing the owner asked me to do by hand. The line is: read and
post, never write. If this script ever grows a write into ~/Desktop/Jarvis, it
has crossed a line no instruction gave it.

Exit codes
  0  nobody is drifting, or every drifting role has been ordered recently
  1  a role is drifting and has NOT been ordered — the thing to act on
  2  the other instrument could not be read. NOT VERIFIED, which is not a pass
     (standing order 4: an empty result is not a negative finding)
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

OTHER_REPO = Path.home() / "Desktop" / "Jarvis"
DRIFT_TOOL = OTHER_REPO / "prototype" / "who_is_drifting.py"
API = "http://127.0.0.1:49374"
STATE = Path(__file__).resolve().parent.parent / ".agent-logs" / "drift_orders.json"
MAX_800 = 800


def _pw() -> str:
    cfg = Path.home() / ".config" / "opencode" / "service.json"
    return json.loads(cfg.read_text(encoding="utf-8"))["password"]


def post(session_id: str, text: str, timeout: float = 20.0) -> tuple[int, str]:
    body = json.dumps({"text": text}).encode()
    req = urllib.request.Request(
        f"{API}/api/session/{session_id}/prompt", data=body, method="POST",
        headers={"content-type": "application/json",
                 "authorization": "Basic " + base64.b64encode(
                     ("opencode:" + _pw()).encode()).decode()})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read().decode("utf-8", "replace")[:120]


def read_drift(timeout: int = 60) -> tuple[list[dict] | None, str]:
    """Run the other company's instrument READ-ONLY. Never writes to their repo."""
    if not DRIFT_TOOL.exists():
        return None, f"{DRIFT_TOOL} not found"
    p = subprocess.run([sys.executable, str(DRIFT_TOOL), "--json"],
                       cwd=str(OTHER_REPO), capture_output=True, text=True,
                       timeout=timeout)
    if p.returncode not in (0, 1):
        return None, f"instrument exited {p.returncode}: {p.stderr.strip()[:160]}"
    try:
        d = json.loads(p.stdout)
    except json.JSONDecodeError as e:
        return None, f"could not parse instrument output: {e}"
    rows = d if isinstance(d, list) else d.get("drifting")
    if not isinstance(rows, list):
        return None, "instrument output has no 'drifting' list"
    # The instrument lists every role it CHECKED, each with a `drifting` flag.
    # Taking the list as-is reports quiet roles as drift; taking only the flagged
    # ones and trusting the flag is right, but I still print the count I used so
    # a reader can see the two numbers and disagree with my filter.
    checked = [r for r in rows if isinstance(r, dict)]
    flagged = [r for r in checked if r.get("drifting") is True]
    # An EMPTY drifting list is a real answer - nobody is drifting - but only if
    # I can show the instrument actually ran. `checked_at` is its own stamp, and
    # requiring it is how I tell "0 drifting" from "I read nothing". Without this
    # the empty case is a guess, and a guess that reports calm is the most
    # expensive kind.
    stamp = (d.get("checked_at") if isinstance(d, dict) else None)
    if not stamp:
        return None, "instrument output carries no checked_at stamp, so an "\
                     "empty drifting list is not evidence of calm"
    print(f"  (instrument stamp {stamp}, {len(checked)} rows, "
          f"{len(flagged)} flagged drifting)")
    return flagged, "ok"


def load_state() -> dict:
    if STATE.exists():
        try:
            return json.loads(STATE.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def save_state(state: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def order_for(role: str, row: dict) -> str:
    queued = row.get("queued") or 0
    # Field names come from the instrument itself: `queued`, `quiet_min`,
    # `reasons` (a list), `last_landing_min`. My first version guessed
    # `queued_cards` and `reason`, so every role took the silence branch and a
    # six-open-card role got told it had been quiet. A wrapper that misreads its
    # instrument is worse than no wrapper, because it looks like a reading.
    if queued and int(queued) > 1:
        head = (f"You have {queued} cards open and not one of your own messages "
                f"carries a commit hash. That is the shape of a role that looks "
                f"busy and has landed nothing.\n\nSTOP OPENING WORK. Close ONE "
                f"card, by commit, in the next 20 minutes.")
    else:
        why = "; ".join(row.get("reasons", [])) or "past the drift limit"
        head = (f"You are past the drift limit: {why}. Land ONE thing now, "
                f"small — a commit, not effort.")
    return f"""ORDER from the Cal Matters CEO, {time.strftime('%H:%M')} IST. {head}

DONE-CONDITION, all four, no exceptions:
  1. ONE commit on the default branch, under {MAX_800} lines changed. The
     800-line rule is in every doorbell now: a commit nobody can review is not
     a landing.
  2. Your reply ENDS with the short hash on its own line, e.g. `a1b2c3d`.
     who_is_drifting.py reads a HASH, not effort.
  3. The commit message says WHAT changed and WHY in three lines.
  4. You run the scoped test that proves it and paste the exit code and its
     last line. Scoped only - never the full suite.

On any other open card, one line each: KEEP or DROP, and why. An honest DROP is
a better answer than another open card.

If you cannot land it in 20 minutes, say so in one line WITH the reason and the
hash of the last thing you did land. A truthful "blocked, here is why" is a real
answer. Silence is not, and silence is why this order exists.
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--order", action="store_true",
                    help="actually post the orders (default: report only)")
    ap.add_argument("--dry-run", action="store_true", help="print, do not post")
    args = ap.parse_args()

    rows, why = read_drift()
    if rows is None:
        print(f"NOT VERIFIED: {why}")
        print("A tool that could not be read tells me nothing. It does not tell "
              "me nobody is drifting.")
        return 2
    if not rows:
        print("drift: 0 - nobody is drifting right now.")
        return 0

    state = load_state()
    now = time.time()
    unhandled, handled = [], []

    for r in rows:
        role = r.get("role") or r.get("name") or "?"
        sid = r.get("session") or r.get("session_id")
        last = state.get(role, {})
        mins_since = (now - last.get("at", 0)) / 60.0
        if mins_since < 20:
            handled.append((role, last.get("order_id", "?"), round(mins_since)))
            print(f"  {role:<20} ordered {round(mins_since)}m ago "
                  f"(id {last.get('order_id', '?')}) - not re-ordered")
            continue
        unhandled.append((role, sid, r))

    if not unhandled:
        print(f"\ndrift: {len(rows)}, all already ordered within the 20m window.")
        return 0

    print(f"\ndrift: {len(rows)}, unhandled: {len(unhandled)}")
    for role, sid, r in unhandled:
        print(f"  {role:<20} quiet={r.get('quiet_min')}m queued={r.get('queued')}"
              f" session={sid} reasons={r.get('reasons')}")

    if not args.order:
        print("\n(dry run. pass --order to post. An unhandled drift is a FAILURE "
              "of this script, not a report to admire.)")
        return 1

    for role, sid, r in unhandled:
        if not sid:
            print(f"  {role}: NO SESSION ID - cannot order it. A role with no "
                  f"session is the worst state, not an absent one.")
            continue
        if args.dry_run:
            print(f"\n--- would post to {role} ({sid}) ---\n{order_for(role, r)}")
            continue
        try:
            status, body = post(sid, order_for(role, r))
            oid = ""
            try:
                oid = json.loads(body).get("data", {}).get("id", "")
            except json.JSONDecodeError:
                pass
            state[role] = {"at": now, "session": sid, "order_id": oid,
                           "reasons": r.get("reasons", [])}
            print(f"  {role}: ordered, HTTP {status}, id {oid}")
        except Exception as e:  # noqa: BLE001 - a failed post must be visible
            print(f"  {role}: ORDER FAILED ({type(e).__name__}: {e})")
    save_state(state)
    return 1 if unhandled else 0


if __name__ == "__main__":
    sys.exit(main())
