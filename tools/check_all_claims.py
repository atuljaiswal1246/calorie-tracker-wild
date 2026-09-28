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
    0  every checker ran, exited 0, and printed something - nothing was skipped
    1  at least one checker failed, printed nothing, or could not be run at all
    2  nothing failed, but at least one claim was NOT VERIFIED because it was
       skipped (--skip-network). Added 2026-09-28. Before this, a skipped claim
       left `ok()` true, so the runner exited 0 AND printed
       "RESULT: all checkers passed" on the same line as "A skip is not a pass"
       - two sentences, one of which was false, and a caller reading only the
       exit code could not tell them apart. A run that did not check everything
       now has an exit code of its own.

WHY NOT JUST CALL A SKIP A FAILURE
---------------------------------
A skip is a deliberate, named choice made by the person who typed the flag, and
it is not a fault in a checker; folding it into 1 would make 1 mean two different
things and would train a reader to ignore it. 2 says exactly what happened: the
runnable checkers all passed, and these claims are unverified today.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
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
    # Order 11's own machine, asked a question it can answer without a working
    # tree being dirty: does the guard still run, and does it still know the
    # destructive verbs? A guard that has quietly rotted is worse than no guard,
    # because the next session trusts it. `check` on a path that is clean is a
    # real execution of the refusal path, not a source scan for its name.
    _script("tools/guard_uncommitted.py", "--self-test"),
    # Can a test file here RUN? Added 2026-09-29: the other company found 34
    # files whose runner discovers zero tests, and a file that discovers none is
    # INERT - it cannot fail, so it passes forever. This repo measured clean at
    # 03:05, and a measurement made by a shell loop that is then discarded is
    # worth nothing by morning. This row is the instrument that says so again.
    _script("tools/check_tests_can_run.py"),
    # The Play listing must describe the app we ship. It is a Play-submission
    # risk, and it is a claim with no machine behind it — two features the app
    # cannot open. Local, no network, no model.
    _script("tools/check_store_listing.py"),
    # Every company that can receive a food photo must be named in the published
    # privacy page. Static, local, no network: the tier list is read from the
    # Worker's own serving rotation.
    _script("tools/check_privacy_processors.py"),
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


def skipped_rows(rows):
    """The rows that did not run because the flag named them. Named, so a
    caller can print which claims are unverified rather than how many."""
    return [r for r in rows if r["verdict"] == VERDICT_SKIP]


def ok(rows):
    """Nothing FAILED and nothing could not be run.

    A SKIP is tolerated here, but NOT forgotten: `ok()` answers "did anything
    break?", and `exit_code()` answers "was everything verified?". Those are two
    different questions and collapsing them is how a run that checked nothing
    ends up reporting that all checkers passed."""
    return all(r["verdict"] in (VERDICT_PASS, VERDICT_SKIP) for r in rows)


def exit_code(rows):
    """The run's verdict as a number a caller can act on.

    A pure function over rows, on purpose: it is the whole contract and it must
    be checkable with synthetic rows, without arranging a real repo where one
    checker skips and every other checker passes. That arrangement is exactly
    what was never built, and it is why this contradiction survived - the real
    runs were all either all-passing or loudly broken, never this middle case."""
    if not rows:
        # An empty run is not a clean run. `all()` over nothing is True, so the
        # naive version reports a vacuous success - exit 0 and "all checkers
        # passed" - for having started no checker at all. That is the oldest
        # silence-as-success in this file and it was sitting in the function I
        # just added. A run with nothing in its table has verified nothing, and
        # a caller cannot tell that from a full pass by exit code alone.
        return 1
    if not ok(rows):
        return 1
    if skipped_rows(rows):
        return 2
    return 0


def print_report(rows, commit, as_json):
    if as_json:
        print(json.dumps({
            "tool": "tools/check_all_claims.py",
            "root": str(ROOT),
            "commit": commit,
            "timeout_s": TIMEOUT_S,
            "ok": ok(rows),
            # `ok` alone is NOT enough for a machine reader, and this is the
            # surface a script reads. `"ok": true` beside a skipped claim is the
            # same false sentence the table used to print, one layer down where
            # nobody reads it. So the skip travels WITH the verdict, by name, and
            # the code this process will exit with is included, so a caller does
            # not have to reimplement exit_code() to learn what happened.
            "not_verified": [r["name"] for r in skipped_rows(rows)],
            "exit_code": exit_code(rows),
            "checks": rows,
        }, indent=2))
        return
    print()
    print(f"commit: {commit or 'UNKNOWN - ' + GIT_CHECK + ' did not run'}")
    not_verified = skipped_rows(rows)
    for r in not_verified:
        print(f"skipped: {r['name']} - NOT VERIFIED this run. A skip is not a "
              f"pass; re-run without --skip-network on a machine with network to "
              f"check it.")
    print("PASS means: ran, exit 0, and printed something. FAIL means it ran and "
          "did not do that. ERROR means it never ran. SKIP means it was named by "
          "the flag and did not run - which is NOT a pass.")
    if not ok(rows):
        result = "AT LEAST ONE CHECKER IS NOT PASSING - see above"
    elif skipped_rows(rows):
        # Never "all checkers passed" in this branch. That sentence is false
        # while a named claim is unverified, and it is the sentence a reader
        # skims.
        result = (f"all RUNNABLE checkers passed - {len(skipped_rows(rows))} claim(s) "
                  "NOT VERIFIED this run (skipped). This is not a full pass; "
                  "exit 2.")
    else:
        result = "all checkers passed"
    print("RESULT: " + result)
    # THE NUMBER TRAVELS WITH THE FAILURE. Learned from outside on 2026-09-29: a
    # monitor that prints one line per sample makes a two-minute total failure and
    # a two-hour clean run the same shape of sentence, and the number nobody has
    # is not "it works" but "it worked N times in M".
    #
    # `--history` (7e47ed4) can print that, but asking for it separately is how the
    # number ends up looked-up-afterwards, which is the same gap one step on. So
    # the rate is appended HERE, on the line a reader is already reading - and
    # the N/M prints in the FAILING case too, which is the entire point: a
    # failure that does not say how often it has happened reads as a first
    # observation.
    _rate = _rate_suffix()
    if _rate:
        print(_rate)


HISTORY = ".agent-logs/claim-history.jsonl"


def _read_history() -> list[dict]:
    path = ROOT / HISTORY
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            continue  # a truncated tail; excluded, and counted in --history
    return out


def _rate_suffix() -> str | None:
    """`recorded: N of M runs exited 0` - or None if there is nothing to say.

    Deliberately quiet below 3 recorded runs: "0 of 1" is a worse sentence than no
    sentence, because it invites reading one sample as a rate. The threshold is
    the same one `--history` uses to say "that is a sample, not a rate"."""
    runs = _read_history()
    if len(runs) < 3:
        return None
    clean = sum(1 for r in runs if r.get("exit_code") == 0)
    return (f"recorded: {clean} of {len(runs)} recorded runs exited 0"
            + ("  (last 3 only: "
               f"{sum(1 for r in runs[-3:] if r.get('exit_code') == 0)}/3)"
               if len(runs) >= 3 else ""))


def record_run(rows, code: int) -> None:
    """Append ONE line per run. The point is the N in M, not the line.

    Learned from outside on 2026-09-29: the other company's monitor printed one
    line per sample, so a two-minute total failure and a two-hour clean run looked
    identical in the record. The number nobody had was the only one that mattered -
    not "it works", but "it worked N times in M, over a window that includes the
    restarts". This repo had the same gap and did not know it: every claim number
    in a report tonight was a single sample, and I re-ran the money gate by hand
    five times precisely because one sample could not tell me whether a tier had
    recovered.

    Append-only, one JSON object per line, gitignored - so it cannot be mistaken
    for evidence by a reviewer, and so a truncated write costs one run rather than
    the history. Never spends: this records what the run already decided.
    """
    path = ROOT / HISTORY
    path.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "epoch": int(time.time()),
        "commit": next((r["first_line"] for r in rows
                        if r["name"] == GIT_CHECK and r["verdict"] == VERDICT_PASS), None),
        "exit_code": code,
        "verdicts": {r["name"]: r["verdict"] for r in rows},
    }
    with path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry) + "\n")


def print_history() -> int:
    """N in M. How many of the last M runs were clean, and which checks moved."""
    path = ROOT / HISTORY
    if not path.exists():
        print("no recorded history yet - run with --record first.")
        print("One sample is not a rate, and a rate is what a reader needs.")
        return 0
    bad_lines = 0
    runs = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            runs.append(json.loads(line))
        except ValueError:
            # A truncated tail must not silently shorten the denominator, which
            # would turn "5 of 5" into "5 of 4" without anyone noticing.
            bad_lines += 1
    if not runs:
        print("history file has no readable run.")
        return 1
    clean = [r for r in runs if r.get("exit_code") == 0]
    print(f"claim history: {len(clean)} of {len(runs)} recorded runs exited 0")
    print(f"  window: {runs[0].get('at')}  ->  {runs[-1].get('at')}")
    if bad_lines:
        print(f"  {bad_lines} unreadable line(s) - the denominator excludes them, "
              f"on purpose")
    for r in runs[-10:]:
        notclean = {k: v for k, v in (r.get("verdicts") or {}).items()
                    if v != VERDICT_PASS}
        state = "clean" if not notclean else ", ".join(
            f"{k.split('/')[-1]}={v}" for k, v in notclean.items())
        print(f"  {r.get('at')}  exit={r.get('exit_code')}  {state}")
    if len(runs) < 5:
        print("")
        print(f"Only {len(runs)} run(s) recorded. That is a sample, not a rate.")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Run every claim checker in the repo and exit once.")
    ap.add_argument("--skip-network", action="store_true",
                    help="skip the checker that fetches the hosted pages, for a "
                         "machine with no network. It is reported as SKIP, which "
                         "is not a pass.")
    ap.add_argument("--json", action="store_true",
                    help="print machine-readable JSON instead of the table")
    ap.add_argument("--record", action="store_true",
                    help="append this run's verdicts to the history file, so the "
                         "next reader can ask how many of the last M runs were "
                         "clean instead of reading one row")
    ap.add_argument("--history", action="store_true",
                    help="print the recorded history and exit without running a "
                         "single checker")
    args = ap.parse_args()

    if args.history:
        return print_history()

    rows = run_all(args.skip_network, args.json)
    print_report(rows, git_commit(rows), args.json)
    # 1 = something broke or could not run. 2 = nothing broke, but a claim was
    # skipped and is therefore unverified. 0 = everything ran and passed. A
    # caller that only reads the exit code must still be able to tell a full
    # pass from a partial one.
    code = exit_code(rows)
    if args.record:
        record_run(rows, code)
    return code


if __name__ == "__main__":
    sys.exit(main())
