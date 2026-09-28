#!/usr/bin/env python3
"""Find commit messages that CLAIM a verification and do not say how it was done.

WHY THIS FILE EXISTS
--------------------
Learned from outside on 2026-09-29 (QA Lead, commit 0f5cda68, and it is a lesson
they learned by breaking it): a commit message stated that a perturbation had been
proven BEFORE it was run. The claim turned out to be true when it landed, and the
ORDER was wrong - which is the only kind of wrong nobody downstream can detect,
because a commit that performed a check and a commit that claims one read
identically.

And in the other company a commit subject read "a typed turn is written where it
can be read back" while a marker typed into the same product, in the same minute,
was found in zero rows of the store. A COMMIT SUBJECT IS A CLAIM NOBODY VERIFIES,
and it is the easiest place in a repo to write something true that later becomes
false, because the message is written first and the evidence may never arrive.

WHAT THIS CHECKS, and it is deliberately narrow
-----------------------------------------------
Only commits whose message ASSERTS a verification - verified, proven, bites,
confirmed, measured - and only whether the message names HOW. It does not judge
whether the verification was real, and it cannot: from the text alone, "verified
by sabotage" is indistinguishable from "verified" said after doing nothing. What
this catches is the narrower and much more common failure - an assertion with no
method, which is a claim the next reader cannot check at all.

TWO CALIBRATION PASSES, and they are the most useful thing in this file
-----------------------------------------------------------------------
The first version flagged "Device-verified bug list is in AGENTS.md" - a message
that names both a method and a file. The second flagged "Verified: flutter
analyze 160 / 0 errors; flutter test 213/213", which names the tool AND the
counts. Both were false positives produced by MY OWN MATCHER being too narrow.

That is recorded here rather than quietly fixed, because it is the finding: a
checker that fires on correct messages trains people to ignore it, and then it
protects nothing. THE FIRST THING TO DO WITH A FINDING FROM THIS TOOL IS SUSPECT
THE TOOL. Two passes of widening is the minimum; if it needs a third, the tool is
the wrong shape and should say so instead of printing a list.

USAGE
-----
    python3 tools/check_commit_claims.py                # last 40 commits
    python3 tools/check_commit_claims.py --since 200
    python3 tools/check_commit_claims.py --json

EXIT CODES
----------
    0  every commit claiming a verification also says how
    1  at least one asserts a verification with no method named
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Words that ASSERT something was checked.
CLAIMS = re.compile(
    r"\b(verified|proven|proves|bites|bite|confirmed|measured|re-?measured)\b",
    re.IGNORECASE,
)

# How a check says it did it. Only has to name the KIND of evidence.
METHODS = re.compile(
    r"(\b[0-9a-f]{7,40}\b"                                  # a commit hash
    r"|\b[\w./-]+\.(py|dart|js|sh|md|json|yaml|yml|plist|html|kts):\d+"  # file:line
    r"|\bon disk\b|\bexit\s*code\b|\bexit=\d"
    r"|\bsabotage|\bprobe[ds]?\b|\bgrep\b|\bnc -z\b|\bcurl\b"
    r"|\bmeasured\b|\bre-?measured\b"
    r"|\b\d+\s+tests?\b|\bRan \d+ tests\b|\bpass(?:ed|es)?\b|\bfails?\b"
    r"|\bread the (?:log|output|payload)\b|\bstdout\b|\bstderr\b"
    r"|\bgit (?:status|diff|rev-parse|check-ignore|log)\b"
    r"|\bdevice[- ]verified\b|\bon a real device\b|\bon device\b|\bhardware\b"
    r"|\bAGENTS\.md\b|\bCHANGELOG\.md\b|\bnotes/|\bHANDOFF\.md\b"
    r"|\bflutter (?:analyze|test)\b|\b\d+\s*/\s*\d+\b|\bgolden(?:s)?\b"
    r"|\bpixel[- ]identical\b|\bbyte[- ]for[- ]byte\b)",
    re.IGNORECASE,
)

# Not a claim about a verification: the negated and subjunctive uses.
NOT_A_CLAIM = re.compile(
    r"(unverified|unproven|is not (?:verified|proven)"
    r"|not (?:yet )?(?:verified|proven)|never (?:verified|proven)"
    r"|cannot be verified|cannot verify)",
    re.IGNORECASE,
)


def commits(limit: int) -> list[tuple[str, str]]:
    """(short sha, subject + body) for the last `limit` commits."""
    out = subprocess.run(
        ["git", "log", f"-{limit}", "--pretty=format:%H%x1f%s%x1f%b%x1e"],
        cwd=str(ROOT), capture_output=True, text=True)
    if out.returncode != 0:
        raise RuntimeError((out.stderr or "git log failed").strip())
    rows = []
    for chunk in out.stdout.split("\x1e"):
        chunk = chunk.strip()
        if not chunk:
            continue
        parts = chunk.split("\x1f")
        if len(parts) >= 2:
            body = parts[2] if len(parts) > 2 else ""
            rows.append((parts[0][:8], parts[1] + "\n" + body))
    return rows


def offenders(rows: list[tuple[str, str]]) -> list[tuple[str, str]]:
    out = []
    for sha, msg in rows:
        if NOT_A_CLAIM.search(msg):
            continue
        if not CLAIMS.search(msg):
            continue
        if METHODS.search(msg):
            continue
        first = msg.strip().splitlines()[0] if msg.strip() else ""
        out.append((sha, first[:70]))
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--since", type=int, default=40,
                    help="how many commits back to read")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    try:
        rows = commits(args.since)
    except (RuntimeError, OSError) as exc:
        # A checker that read nothing must not report success.
        if args.json:
            print(json.dumps({"tool": "check_commit_claims", "error": str(exc),
                              "ok": False}))
        else:
            print(f"ERROR: {exc} - nothing was checked, and that is not a pass.")
        return 1

    bad = offenders(rows)
    if args.json:
        print(json.dumps({
            "tool": "check_commit_claims",
            "checked": len(rows),
            "offenders": [{"sha": s, "subject": m} for s, m in bad],
            "ok": not bad,
        }, indent=2))
        return 1 if bad else 0

    print(f"check_commit_claims: last {len(rows)} commit(s)")
    if not bad:
        print("  every message that claims a verification also says how.")
        return 0
    print(f"  {len(bad)} assert a verification and name NO method:")
    for sha, subj in bad:
        print(f"    {sha}  {subj}")
    print("")
    print("A commit that says 'verified' without saying how is indistinguishable")
    print("from one that did nothing. Read the message yourself before trusting")
    print("either reading - this tool was wrong twice about correct messages.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
