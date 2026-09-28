#!/usr/bin/env python3
"""Prove a Flutter test is reading the source you just edited, not a cached build.

WHY THIS EXISTS. A skill landed in this company on 2026-09-28 with the finding:
a stale `.pyc` can outlive the file it was compiled from, so git, grep and
`inspect.getsource` all report the file as clean while the code EXECUTING is the
old one. The only instrument that sees it recompiles the source and compares what
runs.

The Dart build cache is the same hazard wearing a different hat. `flutter test`
compiles to a kernel snapshot under `.dart_tool/`, and every claim I made tonight -
166 analyzer issues, the scoped suites, the goldens - is a claim about code. If
those results can come from a stale snapshot, then the whole night's evidence is
a rumour dressed as a green tick.

So this answers the question directly, by BREAKING something on purpose:

  1. copy a lib file to a patch first (order 11 - never lose uncommitted work)
  2. insert a marker string that a named test MUST be able to see, chosen so that
     the test cannot pass anyway
  3. run that test. It MUST fail.
  4. restore from HEAD and confirm the test is green again.

Step 2 is where I got it wrong the first time, and the mistake is the useful part.
I first flipped a message to "FRESHNESS PROBE 58271" and the suite PASSED - and
for a moment it looked like the build was stale and every result tonight was
worthless. It was not. The probe was invalid: that test asserts that no rendered
string contains "api key", and "freshness probe 58271" contains none of the banned
words, so passing was the CORRECT outcome. A probe that cannot fail proves
nothing, in either direction - and reading a correct pass as a broken build is the
same error as reading an empty result as a finding.

Usage:
    python3 tools/probe_test_sees_live_source.py \
        --file lib/services/scan_failure.dart \
        --test test/scan_failure_message_test.dart \
        --from "Something went wrong. Please try again." \
        --to   "Invalid API key. Go to Settings and check your key."

Exit codes
  0  the test FAILED on the sabotage and is GREEN again — the suite is live
  1  the test still passed on the sabotage — your probe is invalid, or the build
     is stale. Distinguish those two before believing either.
  2  the tool could not run (no patch, no git, no such file) — NOT VERIFIED
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def sh(*args: str, cwd: Path = ROOT) -> subprocess.CompletedProcess:
    return subprocess.run(list(args), cwd=str(cwd), capture_output=True, text=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--file", required=True, help="a file under lib/ to sabotage")
    ap.add_argument("--test", required=True, help="a scoped test file to run")
    ap.add_argument("--from", dest="src", required=True,
                    help="exact text currently in the file")
    ap.add_argument("--to", dest="dst", required=True,
                    help="replacement text the test CANNOT accept")
    a = ap.parse_args()

    target = ROOT / a.file
    testf = ROOT / a.test
    for p in (target, testf):
        if not p.exists():
            print(f"NOT VERIFIED: {p.relative_to(ROOT)} does not exist")
            return 2

    text = target.read_text(encoding="utf-8")
    if a.src not in text:
        print(f"NOT VERIFIED: {a.src!r} is not in {a.file}. Nothing was changed. "
              f"A probe whose 'from' text is absent cannot prove anything - and "
              f"reaching that state is a caption, not a finding.")
        return 2

    if sh("git", "ls-files", "--error-unmatch", a.file).returncode != 0:
        print(f"REFUSED: {a.file} is not tracked, so it cannot be restored from "
              f"HEAD. Take a patch first (tools/guard_uncommitted.py allow) or "
              f"point this at a tracked file.")
        return 2

    # Order 11: a patch BEFORE the sabotage, always.
    backup = ROOT / ".agent-logs" / "freshness-probe.patch"
    backup.parent.mkdir(parents=True, exist_ok=True)
    backup.write_text(sh("git", "diff", "HEAD", "--", a.file).stdout,
                      encoding="utf-8")

    # THE FIRST OCCURRENCE IS USUALLY IN A COMMENT. My first version of this tool
    # did `text.replace(a.src, a.dst, 1)` and the suite PASSED, which for about a
    # minute I read as a stale build — the expensive claim. It was not a stale
    # build. scan_failure.dart's docstring quotes the old string ("Something went
    # wrong. Please try again.") as part of describing the bug it documents, so
    # the first occurrence is line 21 of a COMMENT and the sabotage never reached
    # the code on line 167. `sed` replaced the code line and the suite failed, which
    # is what gave it away.
    #
    # So: sabotage the LAST occurrence, and then PROVE the code changed by
    # counting occurrences of the destination afterwards. A probe that cannot
    # demonstrate it altered the code is not a probe.
    target_text = text.rsplit(a.src, 1)
    if len(target_text) != 2:
        print("NOT VERIFIED: could not split on the 'from' text")
        return 2
    sabotaged = target_text[0] + a.dst + target_text[1]

    print(f"sabotaging {a.file}: replacing the LAST {a.src!r} with {a.dst!r}")
    if sabotaged.count(a.dst) == text.count(a.dst):
        print("NOT VERIFIED: the replacement did not add the destination text. "
              "Nothing was changed and nothing was proved.")
        return 2
    print(f"patch saved to {backup.relative_to(ROOT)} (order 11)")
    try:
        target.write_text(sabotaged, encoding="utf-8")
        check = target.read_text(encoding="utf-8")
        if check.count(a.dst) <= text.count(a.dst):
            print("NOT VERIFIED: the file on disk does not contain the sabotage. "
                  "Stopping - a probe that did not alter the code proves "
                  "nothing.")
            return 2
        r = sh("flutter", "test", a.test)
        out = f"{r.stdout}{r.stderr}"
        if r.returncode == 0:
            print("\nTHE TEST STILL PASSED. Two explanations and they mean very "
                  "different things:\n"
                  "  (a) your replacement text is ACCEPTABLE to that test, so "
                  "the probe cannot fail. Pick a change the test forbids.\n"
                  "  (b) the suite is reading a stale build and every result "
                  "from it is a rumour.\n"
                  "Read which one before believing either. 'The build is stale' "
                  "is the expensive claim and it is the less likely one.")
            return 1
        print("\nThe suite FAILED on the sabotage, which is what a live suite "
              "must do.")
        failing = [l for l in out.splitlines() if "[E]" in l or " -1:" in l]
        for l in failing[:4]:
            print(f"  {l.strip()[:110]}")
    finally:
        target.write_text(text, encoding="utf-8")
        print(f"\nrestored {a.file} from the in-memory copy")

    g = sh("flutter", "test", a.test)
    if g.returncode != 0:
        print("STILL RED after restore - do not trust anything until this is "
              "explained. The patch is at "
              f"{backup.relative_to(ROOT)}")
        return 1
    print(f"green again after restore: {a.test}")
    print("\nVERDICT: the suite reads the source you edit. Every scoped result "
          "from it is a result about current code.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
