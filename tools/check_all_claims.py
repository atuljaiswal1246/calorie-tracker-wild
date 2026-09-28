#!/usr/bin/env python3
"""Run every "is this still true?" checker in this repo, print ONE table, exit ONCE.

WHY THIS FILE EXISTS
--------------------
Every check in this repo was run by hand, one at a time, and the results lived
only in a chat report. A report is not a check: nothing re-reads it, nothing
fails when it stops being true, and the next session starts from whatever the
last session remembered. This is the whole failure §0 order 9 (a claim about my
own work is not evidence) is about, in one command.

THE TWO RULES THAT SHAPE EVERY LINE BELOW
------------------------------------------
1. NO ABSENCE IS A PASS. A checker that exited 0 but printed nothing has told
   nobody anything, and it is reported as a FAILURE, not a pass. This is order 4
   applied to the runners: silence from a broken command and silence from a real
   absence are different facts, and the exit code alone cannot tell them apart.
2. SOMETHING THAT DID NOT RUN IS NOT A PASS. A missing file, an OSError and a
   timeout are all reported as `ERROR <exception>` and all make the whole run
   exit 1. There is no code path here that prints "ok" for a checker it did not
   successfully start and read.

WHAT IT IS NOT
--------------
It is a RUNNER, not an inventor. It starts no processes of its own beyond the
four checkers plus `git rev-parse`, adds no retries, adds no network call of its
own, and invents no new check. If a checker is wrong, that is the checker's
business to report and a human's business to fix.

SAFE AT ANY HOUR
----------------
It never scans, never calls a model, and never writes to disk. Every checker it
starts is started in one of its two no-spend modes (`--self-test` stubs the
provider call with a counter; `--corpus` reads cases.json), and the two that
could touch a file are started WITHOUT their writing flag (`--write`,
`--record`), so a run cannot edit AGENTS.md or notes/. Subprocess output is
captured through pipes, so not even a temporary file is created.

USAGE
-----
    python3 tools/check_all_claims.py                # all four, needs network
    python3 tools/check_all_claims.py --skip-network # offline machine
    python3 tools/check_all_claims.py --json         # machine-readable

EXIT CODES
----------
    0  every checker ran, exited 0, and printed something
    1  at least one checker failed, printed nothing, or could not be run at all
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

# Resolved from __file__, not from os.getcwd(), so the tool finds the same repo
# no matter which directory it is invoked from. A runner that checks a different
# tree depending on where you stood is a runner whose result means nothing.
ROOT = Path(__file__).resolve().parent.parent

# The one timeout the brief allows, applied to every checker. Long enough for
# `flutter analyze`, short enough that a wedged child cannot hold the run open
# until the heat death of the universe.
TIMEOUT_S = 600

# The interpreter running this script runs the checkers too, so a checker is
# never picked up by whatever `python3` happens to mean on this machine's PATH.
PY = sys.executable or "python3"


def _script(rel, *flags, network=False):
    """A checker that is a Python file inside this repo."""
    argv = [rel, *flags]
    return {"name": " ".join(argv), "argv": argv, "rooted": True,
            "network": network}


def _git(*args):
    """A checker that is a binary on PATH."""
    argv = ["git", *args]
    return {"name": " ".join(argv), "argv": argv, "rooted": False,
            "network": False}


# The order is fixed and is not alphabetical. The money gate goes first, so that
# if the thing that stops us spending is broken, that is the first row a reader
# sees and not a footnote under three others. git goes last, because the commit
# is the label on the whole table, and a table that cannot name its own commit
# should say so rather than print a hash it guessed.
CHECKERS = (
    _script("tools/ai_accuracy.py", "--self-test"),
    _script("tools/ai_accuracy.py", "--corpus"),
    _script("tools/check_external_claims.py", network=True),
    _script("tools/check_self_claims.py", "--skip-suite"),
    _git("rev-parse", "--short", "HEAD"),
)

GIT_CHECK = "git rev-parse --short HEAD"

VERDICT_PASS = "PASS"
VERDICT_FAIL = "FAIL"
VERDICT_ERROR = "ERROR"
VERDICT_SKIP = "SKIP"


def _first_line(text):
    for line in (text or "").splitlines():
        if line.strip():
            return line.strip()
    return ""


def _row(check, verdict, exit_code, first_line, error=None, skipped=False):
    # No elapsed-time field. A duration needs a clock, and a field that is
    # always 0.0 is a number whose producer is a constant - which is worse than
    # no field at all.
    return {"name": check["name"], "argv": list(check["argv"]), "verdict": verdict,
            "exit_code": exit_code, "first_line": first_line, "error": error,
            "skipped": skipped}


def _error_row(check, exception):
    """A checker that could not be run. Reported, never swallowed, never passed."""
    return _row(check, VERDICT_ERROR, None, f"ERROR {exception}",
                error=exception)


def run_checker(check, skip_network):
    """Run one checker. This function does not raise, ever.

    Every failure mode named in the brief - missing file, OSError, timeout - and
    every ordinary non-zero exit becomes a REPORTED row. The one thing it will
    not do is return a PASS for something it did not run.
    """
    if check["network"] and skip_network:
        # Printed as a row, not omitted. An omitted row reads as "nothing to
        # check here" to whoever reads the table, and a silently dropped check
        # is the same class of hole as a silently passing one.
        return _row(check, VERDICT_SKIP, None,
                    "not run (--skip-network) - NOT VERIFIED this run",
                    skipped=True)

    if check["rooted"] and not (ROOT / check["argv"][0]).is_file():
        return _error_row(
            check, f"FileNotFoundError: {check['argv'][0]} is missing from {ROOT}")

    cmd = list(check["argv"]) if not check["rooted"] else [PY, *check["argv"]]
    try:
        proc = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True,
                              errors="replace", timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return _error_row(
            check, f"TimeoutExpired: {check['name']} did not finish in {TIMEOUT_S}s")
    except OSError as exc:
        return _error_row(check, f"{type(exc).__name__}: {exc}")

    out = _first_line(proc.stdout)
    if proc.returncode != 0:
        return _row(check, VERDICT_FAIL, proc.returncode,
                    out or f"(no stdout; exit {proc.returncode})")

    if not out:
        # Rule 1. exit 0 is necessary and NOT sufficient: a checker that says
        # nothing has verified nothing. If it was loud on stderr, that is worth
        # more than the word "empty", so it is carried into the table.
        err = _first_line(proc.stderr)
        note = "(no stdout) - NOT a pass" if not err else f"(no stdout) stderr: {err}"
        return _row(check, VERDICT_FAIL, proc.returncode, note)

    return _row(check, VERDICT_PASS, proc.returncode, out)


def run_all(skip_network, as_json):
    """Run every checker in order, in table mode printing a row the moment each
    one finishes (so a hang is visible as a missing row rather than as silence).
    """
    rows = []
    if not as_json:
        print("running the claim checkers. each row appears when that checker "
              "finishes; a missing row is a checker still running.\n")
    for check in CHECKERS:
        row = run_checker(check, skip_network)
        rows.append(row)
        if not as_json:
            _print_row(row, [c["name"] for c in CHECKERS])
    return rows


def _print_row(row, all_names):
    width = max(len(n) for n in all_names)
    print(f"{row['name'].ljust(width)}  {row['verdict'].ljust(5)}  "
          f"{str(row['exit_code']).ljust(4)}  {row['first_line']}".rstrip(),
          flush=True)


def git_commit(rows):
    """The short hash, read from what git ACTUALLY printed - never guessed."""
    for row in rows:
        if row["name"] == GIT_CHECK and row["verdict"] == VERDICT_PASS:
            return row["first_line"]
    return None


def ok(rows):
    """The one verdict. A SKIP is allowed only because --skip-network asked for
    it, and a FAIL or an ERROR is never allowed."""
    return all(r["verdict"] in (VERDICT_PASS, VERDICT_SKIP) for r in rows)


def print_report(rows, commit, as_json):
    if as_json:
        print(json.dumps({
            "tool": "tools/check_all_claims.py",
            "root": str(ROOT),
            "commit": commit,
            "timeout_s": TIMEOUT_S,
            "ok": ok(rows),
            "checks": rows,
        }, indent=2))
        return
    print()
    print(f"commit: {commit or 'UNKNOWN - ' + GIT_CHECK + ' did not run'}")
    skipped = [r for r in rows if r["verdict"] == VERDICT_SKIP]
    for r in skipped:
        print(f"skipped: {r['name']} - NOT VERIFIED this run. A skip is not a "
              f"pass; re-run without --skip-network on a machine with network to "
              f"check it.")
    print("PASS means: ran, exit 0, and printed something. FAIL means it ran and "
          "did not do that. ERROR means it never ran.")
    print("RESULT: " + ("all checkers passed" if ok(rows)
                        else "AT LEAST ONE CHECKER IS NOT PASSING - see above"))


def main():
    ap = argparse.ArgumentParser(
        description="Run every claim checker in the repo and exit once.")
    ap.add_argument("--skip-network", action="store_true",
                    help="skip the checker that fetches the hosted pages, for a "
                         "machine with no network. It is reported as SKIP, which "
                         "is not a pass.")
    ap.add_argument("--json", action="store_true",
                    help="print machine-readable JSON instead of the table")
    args = ap.parse_args()

    rows = run_all(args.skip_network, args.json)
    print_report(rows, git_commit(rows), args.json)
    if ok(rows):
        return 0
    # The one non-zero exit this tool has. A runner that cannot fail is a
    # formality, and a FAIL, an ERROR or a checker that printed nothing must
    # never be reported to the caller as a pass.
    return 1


if __name__ == "__main__":
    sys.exit(main())
