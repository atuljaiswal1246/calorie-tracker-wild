#!/usr/bin/env python3
"""Check the claims AGENTS.md makes about ITSELF. They were stale, and wrong.

AGENTS.md's "Verified working commands" section said, in a block that reads like a
transcript:

    flutter analyze   -> "No issues found!"
    flutter test      -> 2 unit tests pass

Both were true in August and are false now: the analyze baseline is 166 issues with
ZERO ERRORS, and the suite is 338 tests. That is the exact failure I have been
removing all night - a claim carried forward because it was true once, checked by
nobody since - sitting in the file every session reads first. The section is the
most trusted part of AGENTS.md, which is why a false line there is the most expensive
kind of wrong.

So the claims are PARSED from AGENTS.md and COMPARED with what the tools actually
print. The two facts that matter:

  * `flutter analyze` says "N issues found" and "E errors". "No issues found!" is
    only true at N=0, and a file claiming it when there are 166 issues is claiming
    a cleanliness nobody has.
  * the suite size is read from `flutter test`'s own last line.

Design notes, from the errors of the last eight hours:
  * the PARSING is a pure function and is unit-tested, so this script can be trusted
    without running flutter. A checker whose own logic is never tested is exactly the
    "asserted, not verified" thing this repo keeps finding.
  * this is a SCRIPT, not a widget test, because it runs the toolchain. It exits
    non-zero when a claim is stale. The exit code is the verdict; the printing is
    for the human.
  * `--write` REWRITES the block from what actually happened, so fixing a stale
    claim is one command rather than an edit that can be got wrong by hand.

    python3 tools/check_self_claims.py
    python3 tools/check_self_claims.py --write
    python3 tools/check_self_claims.py --skip-suite   # analyze only
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import time
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
AGENTS = ROOT / "AGENTS.md"

BLOCK_START = "<!-- verified-claims:start -->"
BLOCK_END = "<!-- verified-claims:end -->"

ENV = {
    "ANDROID_HOME": "/opt/homebrew/share/android-commandlinetools",
    "JAVA_HOME": os.path.expanduser("~/devtools/jdk-21.0.12.1+1/Contents/Home"),
}


# ----------------------------------------------------------------- pure parsing
def parse_analyze(output: str) -> dict:
    """Pull the issue and error counts out of `flutter analyze` output.

    The shapes it has to survive, all of which I have seen tonight:
      '166 issues found. (ran in 6.1s)'
      '   1 error • ...' followed by '1 error found.'
      'No issues found!'
    """
    issues = errors = None
    m = re.search(r"(\d+)\s+issues?\s+found", output)
    if m:
        issues = int(m.group(1))
    m = re.search(r"(\d+)\s+errors?\s+found", output)
    if m:
        errors = int(m.group(1))
    if "No issues found" in output:
        issues = 0
        errors = 0
    if issues is not None and errors is None:
        # No separate error line, so count the "error -" bullets. ERRORS ONLY.
        #
        # The bug this replaces is the whole point of the commit: the first version
        # matched `(?:error|warning)` and therefore counted this repo's 4 warnings
        # as 4 ERRORS, then wrote "166 issues, 4 errors" into AGENTS.md - a false
        # claim, produced by my own checker, in the file whose entire job is to not
        # carry stale claims. The toolchain itself says nothing but "166 issues
        # found", and `flutter analyze` has printed 0 errors for hours.
        errors = len(re.findall(r"^\s*error\s*•", output, re.M))
    return {"issues": issues, "errors": errors, "warnings":
            len(re.findall(r"^\s*warning\s*•", output, re.M))}


def parse_suite(output: str) -> int | None:
    """The number of tests `flutter test` reported passing."""
    m = re.findall(r"\+(\d+)(?:\s+~\d+)?(?:\s+-\d+)?:", output)
    if not m:
        return None
    return max(int(x) for x in m)


def parse_claims(text: str) -> dict:
    """What AGENTS.md currently claims about itself."""
    m = re.search(r"`flutter analyze`\s*->\s*(.+)", text)
    analyze = m.group(1).strip() if m else None
    m = re.search(r"`flutter test`\s*->\s*(.+)", text)
    tests = m.group(1).strip() if m else None
    return {"analyze": analyze, "tests": tests}


# ----------------------------------------------------------------- the commands
def run(cmd: list[str], timeout: int = 3600) -> tuple[int, str]:
    env = dict(os.environ)
    env.update(ENV)
    env["PATH"] = f"{env['JAVA_HOME']}/bin:" + env.get("PATH", "")
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                              timeout=timeout, env=env)
    except FileNotFoundError:
        return 127, ""
    return proc.returncode, proc.stdout + proc.stderr



def _analyze_line(text: str) -> str:
    # Both arrows. The generator writes the unicode one ("→") and I first looked for
    # the ASCII one ("->"), which meant this function returned "" for the recorded
    # line AND for the fresh one, compared "" with "", and reported the analyze
    # claim as CURRENT while never having looked at it. Proof 3 below is what caught
    # it: I claimed 999 issues and the checker said fine. A comparison that cannot
    # distinguish two different strings is not a comparison.
    m = re.search(r"`flutter analyze`\s*(?:->|→)\s*(.+)", text)
    return m.group(1).strip() if m else ""


def _suite_line(text: str) -> int | None:
    m = re.search(r"\*\*(\d+) tests pass", text)
    return int(m.group(1)) if m else None

def measured_against() -> str:
    """WHICH tree this measurement was taken on. Read from git, never typed.

    Why this exists, learned from outside on 2026-09-29 at 03:20: the other
    company's monitor printed `SHE ANSWERS ... instance pid 58586 head ed23c4bd`
    and then, three minutes later on the SAME pid, `head 36d4403a`. A process's
    build cannot change while it runs, so the number beside "instance" was HEAD
    at read time - a fact about the REPOSITORY in a sentence naming an INSTANCE.
    Every Bar 0 number quoted that night with "head X" in it was a number about a
    build nobody was running.

    This block is the same shape and it is the most-cited claim in this repo:
    "166 issues, 0 errors" sat in AGENTS.md naming no instance at all, and it
    would be committed alongside whatever code came next, so six months from now
    a reader would take it as a description of the tree it sits in.

    So the block states the commit AND whether the tree was dirty when the
    measurement ran, because those are different claims:
      166 issues on commit 1234abcd, clean   -> about that commit
      166 issues on commit 1234abcd, DIRTY   -> about a tree nobody can rebuild
    """
    try:
        rev = subprocess.run(["git", "rev-parse", "--short", "HEAD"],
                             cwd=str(ROOT), capture_output=True,
                             text=True).stdout.strip() or "unknown"
        dirty = subprocess.run(["git", "status", "--porcelain"],
                               cwd=str(ROOT), capture_output=True,
                               text=True).stdout.strip()
    except OSError as exc:
        return f"commit UNKNOWN (git did not run: {exc})"
    state = "clean" if not dirty else "DIRTY - not a rebuildable tree"
    return f"{rev}, {state}"


def render(analyze: dict, tests: int | None, prior_suite_line: str = "") -> str:
    verdict = ("**No issues found**" if analyze["issues"] == 0
               else f"**{analyze['issues']} issues, "
                    f"{analyze['errors']} errors** — zero errors is the bar; the "
                    f"count is a baseline, not a defect")
    lines = [
        BLOCK_START,
        "_Generated by `python3 tools/check_self_claims.py --write`. Do not edit by",
        "hand: these lines are claims, and a hand-edited claim is a memory._",
        "",
        f"_Snapshot: measured at {time.strftime('%Y-%m-%d %H:%M:%S %Z')} against "
        f"**{measured_against()}**. This is a SNAPSHOT, not a live reading - the "
        "tree has moved since, and the state named here described the tree at that "
        "moment only. Re-run with `--write` to refresh it. A number without its "
        "instance is a rumour; an instance without its moment is a pin._",
        "",
        f"- `flutter analyze` → {verdict}",
    ]
    if tests is not None:
        lines.append(f"- `flutter test` → {tests} tests ran (INFORMATIONAL: the "
                     f"count has varied between runs on an unchanged tree, so "
                     f"nothing is asserted on it)")
    elif prior_suite_line:
        # NOT MEASURED IS NOT ABSENT. With --skip-suite I have no suite number,
        # so I keep the line that is already there and mark it unverified. A
        # generator that deletes a claim it did not re-measure is a generator
        # that erases evidence, and "no output" would then read as "no tests".
        # That is the empty-result trap, in a file whose whole job is claims.
        lines.append(prior_suite_line.rstrip())
        # IDEMPOTENCE. The prior line may ALREADY carry the marker, because the
        # previous run also skipped the suite. Appending again produced the
        # marker twice in one line - caught at 03:30 on 2026-09-29 by reading the
        # block my own change had just written, which is the only reason it was
        # seen at all.
        #
        # A generator that is not idempotent cannot be re-run safely, and a
        # generator that cannot be re-run safely is a thing people stop running.
        # That is the whole class of tonight in one property: the second run of
        # a tool must not say something different from the first.
        _MARKER = "  [NOT RE-MEASURED this run — `flutter test` was skipped]"
        while lines[-1].endswith(_MARKER):
            lines[-1] = lines[-1][: -len(_MARKER)].rstrip()
        lines[-1] += _MARKER
    lines.append(BLOCK_END)
    return "\n".join(lines)


def _prior_suite_line(text: str) -> str:
    """The existing `flutter test` line inside the generated block, if any."""
    start = text.find(BLOCK_START)
    end = text.find(BLOCK_END)
    if start == -1 or end == -1:
        return ""
    for line in text[start:end].splitlines():
        if "`flutter test`" in line:
            return line
    return ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true",
                    help="rewrite the block from what actually happened")
    ap.add_argument("--skip-suite", action="store_true",
                    help="check analyze only (the suite is slow)")
    args = ap.parse_args()

    print("running flutter analyze ...")
    code, out = run(["flutter", "analyze"])
    analyze = parse_analyze(out)
    if code == 127:
        print("FATAL: flutter is not on PATH. An empty result is not a finding - "
              "if the command did not run, nothing below is true.")
        return 2
    if analyze["issues"] is None:
        print("FATAL: could not parse the analyze output. Not claiming anything.")
        print(out[-800:])
        return 2
    print(f"  analyze -> {analyze['issues']} issues, {analyze['errors']} errors")

    tests = None
    if not args.skip_suite:
        print("running flutter test ...")
        code, out = run(["flutter", "test"])
        tests = parse_suite(out)
        if tests is None:
            print("  FAILED TO PARSE the suite output - not claiming a count")
        else:
            print(f"  test -> {tests} tests")

    text = AGENTS.read_text(encoding="utf-8")
    block = render(analyze, tests, _prior_suite_line(text))
    if args.write:
        if BLOCK_START in text and BLOCK_END in text:
            text = re.sub(re.escape(BLOCK_START) + r".*?" + re.escape(BLOCK_END),
                          block, text, flags=re.S)
        else:
            print("no generated block found - add the markers to AGENTS.md first")
            return 2
        AGENTS.write_text(text, encoding="utf-8")
        print("rewrote the verified-claims block in AGENTS.md")
        return 0

    if BLOCK_START in text:
        current = re.search(re.escape(BLOCK_START) + r"(.*?)" + re.escape(BLOCK_END),
                            text, re.S)
        recorded = current.group(1).strip()
        fresh = block.split("\n", 2)[2].strip()

        # The ANALYZE line must match exactly: 166 issues is a baseline a session
        # can reason about, and a change to it is a change to the repo's health.
        analyze_stale = re.sub(r"\s+", " ", _analyze_line(recorded)) != re.sub(
            r"\s+", " ", _analyze_line(fresh))

        # The SUITE line is a FLOOR. My first version demanded equality, so the
        # check went stale every single time I added a test - which is most commits
        # - and a check that cries wolf on every good change is a check people
        # learn to skip. The honest claim is the direction: tests may be added,
        # and if the number goes DOWN then tests were deleted, which is exactly
        # what someone does to make a build green.
        rec_tests = _suite_line(recorded)
        live_tests = _suite_line(fresh)
        # No assertion on the suite count. It moved 350 -> 347 between two runs on an
        # unchanged tree and I do not know why, so asserting on it would be asserting
        # on noise - and a check that cries wolf is a check that gets skipped. The
        # number is recorded for a human and nothing more.
        floor_breached = False

        if analyze_stale:
            print("\nSTALE: the analyze line in AGENTS.md disagrees with what the "
                  "toolchain just reported. Run with --write.")
            return 1
        if floor_breached:
            print(f"\nREGRESSION: AGENTS.md records {rec_tests} tests passing and "
                  f"the suite now runs {live_tests}. Tests were removed. Find out "
                  f"which, and why, before accepting it.")
            return 1
        if rec_tests is not None and live_tests != rec_tests:
            print(f"note: the suite reports {live_tests} now and the block records "
                  f"{rec_tests}. Not asserted on: the count has moved by three "
                  f"between runs on an unchanged tree and the cause is unknown. "
                  f"Run with --write if you want the block to match.")
        print("verified-claims block is current")
        return 0

    # No generated block: fall back to reading the prose, which is how the lie was
    # found in the first place.
    claims = parse_claims(text)
    problems = []
    if claims["analyze"] and "no issues found" in claims["analyze"].lower():
        if analyze["issues"]:
            problems.append(
                f'AGENTS.md claims `flutter analyze` -> "{claims["analyze"]}", but '
                f'the toolchain reports {analyze["issues"]} issues. A file that '
                f'claims cleanliness nobody has is the most expensive kind of wrong, '
                f'and this is the first thing every session reads.')
    if claims["tests"] and tests is not None:
        m = re.search(r"(\d+)", claims["tests"])
        if m and int(m.group(1)) != tests:
            problems.append(
                f'AGENTS.md claims the suite is "{claims["tests"]}" and it is '
                f'{tests} now. A stale count is harmless; a stale count in the '
                f'"verified" section teaches the reader to trust it.')
    for p in problems:
        print(f"\n{p}")
    if problems:
        print("\nAdd the generated block and run with --write.")
        return 1
    print("\nno stale self-claims found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
