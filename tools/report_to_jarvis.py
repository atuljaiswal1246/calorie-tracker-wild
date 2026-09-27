#!/usr/bin/env python3
"""Send a report to my CEO's session - with the time MACHINE-READ, not typed.

The bug this closes, 2026-09-28: seven reports in a row carried a hand-typed
"Time: ~HH:MM IST". The machine said 05:13:38 when the seventh landed, and
`git log` said that commit was made at 05:12:31 - so my reports and my commits
gave two different answers to "when", two hours apart, and a session in three
weeks deciding "what did he believe at the time of that commit" would get a
different answer from each.

The cause was not a timezone bug, not an offset applied twice, and not
utcnow() mislabelled. grep proved it: NOTHING produced that number, because it
was typed into a chat message. There was no producer, so no producer could be
checked. That is standing order 6 arriving through the most ordinary door there
is, and it is why the fix is a CODE PATH and not a habit.

Therefore the report path itself now passes through a check:

  * the header is built from tools/now.py, which reads the clock;
  * there is NO way to pass a time in. `--time` does not exist, and a body
    containing its own "Time:" line has it stripped and replaced;
  * --dry-run prints the exact payload, so the check can run without sending;
  * before sending, the stamp is re-checked against a fresh read of the clock
    and the report is REFUSED if it is more than CLOCK_DRIFT_LIMIT out.

WHAT verify() CANNOT DO, stated here so this file does not overclaim: it compares
the stamp against the SAME source that wrote it, so it catches a STALE stamp and
nothing else. When I proved the guard by injecting a +2:07 offset into
tools/now.py, this script still sent happily - both readings were wrong together.
The only thing that catches a WRONG CLOCK is test/report_clock_test.dart, which
compares tools/now.py against the shell's own `date`. That test is the guard; this
check is a second opinion.

    python3 tools/report_to_jarvis.py --body notes/_body.md --dry-run
    python3 tools/report_to_jarvis.py --body notes/_body.md

It posts to my own CEO's session only. It never touches the owner's session, and
it has no code path to the Asha repo: this company reports to its own CEO, and a
report carrying another company's wishes is how that line gets crossed without
anyone deciding to cross it.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import now as clock                                        # noqa: E402

CEO_SESSION = "ses_f5746c0ccffeqoaMylao16h3Ox"
ENDPOINT = f"http://127.0.0.1:49374/api/session/{CEO_SESSION}/prompt"
SERVICE = os.path.expanduser("~/.config/opencode/service.json")

# If the stamped time is further than this from the clock at send time, something
# is wrong with the stamp or the machine, and the report is not sent.
CLOCK_DRIFT_LIMIT_S = 120

OPENING = ("I am the CEO of Cal Matters, reporting to Jarvis as per the owner "
           "instructions.")


def body_text(path: str | None, inline: str | None) -> str:
    if path:
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    if inline:
        return inline.strip()
    raise SystemExit("give me --body <file> or --body-text <string>")


def build(text: str) -> str:
    """Prefix the opening line and the machine-read time. Always."""
    stamp = clock.header()
    if re.search(r"(?im)^\s*time:\s", text):
        print("! this body already contains a 'Time:' line. It is being "
              "replaced with the machine's clock, because a typed time is a "
              "guess. If you meant to keep yours, do not.", file=sys.stderr)
        text = re.sub(r"(?im)^\s*time:.*$", "", text)
    return f"{OPENING}\n\n{text.rstrip()}\n\nTime: {stamp}"


def drift_minutes(said_min: int, real_min: int) -> int:
    """Minutes between two clock readings, across midnight.

    Modulo BEFORE wrapping. The first version of this assumed the raw difference
    was under 24h, so a stamp of 99:99 produced 1440 - 5725 = -4285 "minutes of
    drift" and sailed through every check: the guard passed the most obviously
    wrong stamp possible, and the only reason I know is that a test made it try
    one. A negative drift satisfies "<= 2" forever.
    """
    raw = (said_min - real_min) % (24 * 60)
    return min(raw, 24 * 60 - raw)


def verify(stamped: str) -> None:
    """Re-read the clock and refuse a stamp that has drifted."""
    m = re.search(r"~(\d{1,2}):(\d{2})", stamped)
    if not m:
        raise SystemExit(f"no time in the stamp {stamped!r}")
    said = int(m.group(1)) * 60 + int(m.group(2))
    n = clock.now()
    real = n.hour * 60 + n.minute
    drift = drift_minutes(said, real)
    if drift * 60 > CLOCK_DRIFT_LIMIT_S:
        raise SystemExit(
            f"REFUSING TO SEND: the header says {int(m.group(1)):02d}:{m.group(2)} "
            f"and the machine says {n:%H:%M} - {drift} minutes apart, past the "
            f"{CLOCK_DRIFT_LIMIT_S // 60}-minute limit. A report whose time is "
            f"wrong is worse than a late report, because a later session will "
            f"believe it.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--body", help="file holding the report body")
    ap.add_argument("--body-text", help="the report body, inline")
    ap.add_argument("--dry-run", action="store_true",
                    help="print the exact payload; send nothing")
    args = ap.parse_args()

    text = build(body_text(args.body, args.body_text))
    verify(text)

    if args.dry_run:
        print(text)
        print(f"\n[dry-run] nothing sent. {len(text)} chars, time machine-read "
              f"via tools/now.py")
        return 0

    with open(SERVICE, encoding="utf-8") as fh:
        password = json.load(fh)["password"]
    auth = base64.b64encode(f"opencode:{password}".encode()).decode()
    req = urllib.request.Request(
        ENDPOINT, data=json.dumps({"text": text}).encode(), method="POST",
        headers={"Content-Type": "application/json",
                 "Authorization": "Basic " + auth})
    with urllib.request.urlopen(req, timeout=90) as resp:
        print("HTTP", resp.status,
              json.loads(resp.read().decode())["data"]["id"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
