#!/usr/bin/env python3
"""Fail if the release artefact is older than the tree. It is a Bar 4 guard.

WHY THIS FILE EXISTS
--------------------
Measured on 2026-09-29 02:45 and re-measured since, unchanged:

    app-release.apk on disk   built 2026-09-22 22:52
    pubspec version now       0.9.10+15
    version last bumped       2026-09-23 09:54   <- ELEVEN HOURS AFTER the build
    commits since that build  129, of which 8 touch lib/
    files under lib/ newer than the artefact : 11

So any device testing since the 22nd has been against a build that is not this
code, and one of the eight missing lib/ commits is a trial-gate monetization fix.
I have reported that to the owner in report after report, which is the failure
this file exists to stop: A FINDING I DESCRIBE EVERY TWENTY MINUTES IS A COMMENT.

WHY IT IS A GUARD AND NOT A NOTE
---------------------------------
Learned from outside on 2026-09-29, from QA Lead, in the sharpest form of the
lesson available: their guard was GREEN while the product was still writing
`Starting her again (2 of 3)`, because the guard read the TREE and the launcher
processes predated the fix by more than an hour. A GUARD ON A FILE PROVES THE
FILE. IT DOES NOT PROVE THE THING THAT WILL ACTUALLY RUN.

This repo has no long-running process serving anyone - the claim runner spawns
fresh subprocesses per run, so it cannot have that gap - but the ARTEFACT is
exactly the same shape. It is a thing that will be handed to a customer, it was
built at a moment, and nothing has ever compared that moment to the tree since.
So this compares them, every run, and fails when they disagree.

WHAT IT WILL AND WILL NOT CLAIM
-------------------------------
It compares the artefact's mtime against the newest commit that touched `lib/`,
and it NAMES the commits the artefact is missing. It does not guess whether the
build is otherwise good, it does not know whether the artefact was ever installed
anywhere, and it cannot tell you which build a customer is holding - only that
this one cannot be the current tree.

USAGE
-----
    python3 tools/check_release_is_the_tree.py
    python3 tools/check_release_is_the_tree.py --json
    python3 tools/check_release_is_the_tree.py --allow-missing   # CI before a build

EXIT CODES
----------
    0  the artefact is at least as new as the newest product change
    1  the artefact is older, and the missing commits are named
    2  no artefact found (with --allow-missing, this is a pass)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARTEFACTS = [
    "build/app/outputs/flutter-apk/app-release.apk",
    "build/app/outputs/bundle/release/app-release.aab",
]
# Product code. A tools/ or test/ change does not make an APK stale, and counting
# them would make this fire on commits that genuinely do not ship.
PRODUCT = "lib"


def _git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=str(ROOT),
                          capture_output=True, text=True).stdout.strip()


def newest_product_commit() -> tuple[int, str] | None:
    sha = _git("log", "-1", "--format=%H", "--", PRODUCT)
    if not sha:
        return None
    ts = _git("log", "-1", "--format=%ct", "--", PRODUCT)
    return (int(ts), sha[:8]) if ts else None


def missing_since(epoch: int, cap: int = 12) -> list[str]:
    out = _git("log", f"--since=@{epoch}", "--format=%h %s", "--", PRODUCT)
    return [ln for ln in out.splitlines() if ln.strip()][:cap]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--allow-missing", action="store_true",
                    help="pass when no artefact exists yet (CI before a build)")
    args = ap.parse_args(argv)

    newest = newest_product_commit()
    if newest is None:
        msg = f"no commit touching {PRODUCT}/ in git history"
        if args.json:
            print(json.dumps({"tool": "check_release_is_the_tree", "ok": False,
                              "error": msg}))
        else:
            print(f"ERROR: {msg} - nothing was checked.")
        return 2

    new_epoch, new_sha = newest
    found = [(p, Path(ROOT) / p) for p in ARTEFACTS if (Path(ROOT) / p).exists()]

    if not found:
        if args.allow_missing:
            if not args.json:
                print("check_release_is_the_tree: no artefact on disk; "
                      "--allow-missing, so this is a pass.")
            else:
                print(json.dumps({"tool": "check_release_is_the_tree", "ok": True,
                                  "artefact": None, "reason": "allow-missing"}))
            return 0
        print("check_release_is_the_tree: NO ARTEFACT on disk.")
        print("  A product that has never been built cannot be stale, so this is")
        print("  not a failure - but nothing here has been shipped either.")
        return 2

    results = []
    stale = False
    for rel, path in found:
        mtime = int(path.stat().st_mtime)
        age = time.time() - mtime
        behind = missing_since(mtime) if mtime < new_epoch else []
        is_stale = mtime < new_epoch
        stale = stale or is_stale
        results.append({
            "artefact": rel,
            "built_epoch": mtime,
            "newest_product_commit": new_sha,
            "behind_product_commits": behind,
            "stale": is_stale,
        })

    if args.json:
        print(json.dumps({"tool": "check_release_is_the_tree", "ok": not stale,
                          "artefacts": results}, indent=2))
        return 1 if stale else 0

    for r in results:
        print(f"  {r['artefact']}")
        print(f"    built       : {time.strftime('%Y-%m-%d %H:%M:%S %Z', time.localtime(r['built_epoch']))}")
        print(f"    newest {PRODUCT}/ commit: {r['newest_product_commit']}")
        if r["stale"]:
            n = len(missing_since(r['built_epoch'], cap=999))
            print(f"    STALE: {n} product commit(s) are NOT in this artefact.")
            for ln in r["behind_product_commits"]:
                print(f"      missing: {ln}")
        else:
            print("    current: no product commit is newer than this artefact.")

    if stale:
        print("")
        print("The artefact is not the tree. Anyone who installs it, or tests a")
        print("device against it, is running older code than this repository - and")
        print("nothing in that sentence says which older, which is the problem.")
        print("Rebuild, and record the short hash beside the file so the name and")
        print("the contents cannot drift apart again.")
        return 1

    print("")
    print("Every artefact on disk is at least as new as the newest product commit.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
