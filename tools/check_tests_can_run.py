#!/usr/bin/env python3
"""Report any test file in this repo that CANNOT RUN. Exit 1 if there is one.

WHY THIS FILE EXISTS
--------------------
Learned from outside on 2026-09-29: the other company found 34 test files whose
runner discovers ZERO tests in them, 14 of them written that night, and the
count grew silently because a file with no test cases is INERT - it cannot fail,
so it passes forever. Their own tool printed the sentence on every run:

    a test file with no unittest.TestCase is a check that cannot run,
    and a check that cannot run is a check that passes.

I MEASURED THIS REPO AND IT IS CLEAN RIGHT NOW - 68 test files under test/, zero
of them without a test() or testWidgets() declaration, checked at 03:05 on
2026-09-29. That is a measurement, and it is worth nothing tomorrow, because I
measured it with a shell loop I typed into a terminal and then discarded.

WHICH IS THE ACTUAL POINT. Tonight's largest finding in either company was not a
missing check. It was that NOTHING IN EITHER COMPANY COULD TELL YOU WHAT IT DID
NOT KNOW. Four of my own wrong answers were confident zeros returned by an
instrument that could not see the thing being asked about, and a shell loop I
typed once is exactly that class of instrument: correct today, gone at 03:05.

So the rule this file encodes:

    A REPO THAT HAS NO INSTRUMENT FOR WHAT IT DOES NOT KNOW WILL BE TOLD BY A
    HUMAN, ONCE, IN A CHAT, AND THEN FORGET IT.

WHY THIS IS NOT THE SAME AS THEIR 34, and the difference matters
---------------------------------------------------------------
`flutter test` on a single file with no tests exits 79 ("No tests were found") -
measured here at 00:13 on 2026-09-29, on a probe file written and deleted in the
same command. So the Dart runner is NOT the same failure as a unittest runner
scoring an empty module as exit 0. What Dart cannot do is notice that one inert
file exists among sixty-eight while it is busy running the other sixty-seven.
That is this file's whole job, and it is a smaller job than theirs.

WHAT COUNTS AS A TEST, and the honesty of that list
--------------------------------------------------
  test(...)          a case
  testWidgets(...)   a case
  group(...)         not a case on its own - a group of nothing is still nothing

A file containing only imports, helpers and fixtures declares no case and is
reported. That is the definition, not a judgement, and the exit code carries it.

USAGE
-----
    python3 tools/check_tests_can_run.py            # scan test/
    python3 tools/check_tests_can_run.py --dir DIR  # scan elsewhere
    python3 tools/check_tests_can_run.py --json     # machine-readable

EXIT CODES
----------
    0  every test file declares at least one case
    1  at least one file declares none, or the directory could not be read
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# A call to test(...) or testWidgets(...), NOT at the start of a line. The first
# version of this matcher anchored to line-start and it was wrong in the
# expensive direction: a real file whose cases are declared inline
# (`void main() { test('x', () {}); }`) was reported INERT, so the instrument
# disagreed with a file that demonstrably runs. A false positive here is the same
# class of fault as the false negatives it was built to catch - the instrument
# contradicting reality - so it is fixed rather than tolerated.
#
# The lookbehind is what keeps it honest in the other direction: a bare `test(`
# preceded by a word character or a dot is NOT a declaration, so `expect(`,
# `subtest(` and `suite.test(` do not match. Matching the word "test" anywhere
# would count a comment that says "this is a test" as a case, which is the exact
# defect this file exists to report.
CASE = re.compile(r"(?<![\w.])(?:test|testWidgets)\s*\(")


def scan(directory: Path) -> tuple[list[str], int]:
    """Return (files declaring no case, total files scanned)."""
    if not directory.is_dir():
        raise RuntimeError(f"not a directory: {directory}")
    files = sorted(directory.glob("*.dart"))
    inert = [f.name for f in files if not CASE.search(f.read_text(encoding="utf-8"))]
    return inert, len(files)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dir", default="test", help="directory of .dart test files")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    directory = Path(args.dir)
    if not directory.is_absolute():
        directory = ROOT / directory

    try:
        inert, total = scan(directory)
    except (RuntimeError, OSError) as exc:
        # A runner that cannot read its own input has checked NOTHING, and must
        # not report success for it. This is the tool's own rule 1.
        if args.json:
            print(json.dumps({"tool": "check_tests_can_run", "error": str(exc),
                              "ok": False}))
        else:
            print(f"ERROR: {exc} - nothing was checked, and that is not a pass.")
        return 1

    if args.json:
        print(json.dumps({
            "tool": "check_tests_can_run",
            "dir": str(directory),
            "files": total,
            "inert": inert,
            "ok": not inert,
        }, indent=2))
        return 1 if inert else 0

    if not inert:
        print(f"check_tests_can_run: {directory}")
        print(f"  {total} test file(s), 0 of them declare no case. "
              "Every one can run.")
        return 0

    print(f"check_tests_can_run: {directory}")
    print(f"  {total} test file(s); {len(inert)} DECLARE NO TEST CASE:")
    for name in inert:
        print(f"    INERT: {name}")
    print("")
    print("A test file that declares no case cannot fail, so it passes forever.")
    print("It is not a weak check, it is an absent one that reports success.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
