#!/usr/bin/env python3
"""Every release note must name the commit it describes, or nobody can trace it.

WHY THIS FILE EXISTS
--------------------
Measured on 2026-09-29, and it was true of every single one of them:

    notes/releases/CalMatters-play-notes-0.9.10.txt   NO COMMIT
    notes/releases/CalMatters-play-notes-0.9.8.txt    NO COMMIT
    notes/releases/CalMatters-play-notes-0.9.9.txt    NO COMMIT
    notes/releases/CalMatters-tester-note-0.9.6.txt   NO COMMIT
    notes/releases/CalMatters-tester-note-0.9.7.txt   NO COMMIT
    notes/releases/CalMatters-tester-note-0.9.8.txt   NO COMMIT
    notes/releases/CalMatters-whats-new-0.9.6.txt     NO COMMIT
    notes/releases/CalMatters-whats-new-0.9.7.txt     NO COMMIT
    notes/releases/CalMatters-whats-new-0.9.8.txt     NO COMMIT
    ... and there is no BUILD_INFO, or stamp, or anything of the kind anywhere.

So the owner's Desktop holds a shipped artefact that no document in this repository
can trace to a tree, and there was a second layer on top: the tree's version was
0.9.10+15 at build time and the copy was labelled 0.9.9. A release that cannot
say which build it is is a release whose behaviour cannot be reproduced and cannot
be rolled back to.

Learned from the other company on 2026-09-29, and it is the transferable part: the
build's own stamp and the gate that measures dirtiness read THE SAME EXCLUSION
FILE, so those two instruments could not disagree with each other. That is the one
property no other pair of instruments in that company had all night. Two
instruments reading the same source is what makes a number trustworthy; two
instruments reading different sources is how you get 189 versus 163 and a night of
arguing about which is real.

WHAT THIS CHECKS, and it is deliberately narrow
-----------------------------------------------
Only that a release note names a short commit hash somewhere in its first lines. It
does not judge the note's truth, the artefact, or whether anyone shipped anything.

IT WILL BE RED, AND THAT IS CORRECT. Nine notes exist and none names a commit. It
clears as notes are written with the hash, which is the practice this file exists to
start - and a guard that can only be made green by pretending is worse than one that
cannot.

USAGE
-----
    python3 tools/check_release_notes_trace.py
    python3 tools/check_release_notes_trace.py --json

EXIT CODES
----------
    0  every release note names a commit
    1  at least one does not, and the notes are named
    2  notes/ could not be read - nothing was checked, and that is not a pass
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOTES = ROOT / "notes" / "releases"

# A short commit hash. Anchored to word boundaries so a version number or a count
# is not mistaken for one.
COMMIT = re.compile(r"\b[0-9a-f]{7,40}\b")
# Only the head of the note is searched: a hash quoted deep in a wall of prose may
# be describing something else entirely, and a guard that accepts it is a guard that
# reads the whole file for a word.
HEAD_LINES = 12


def check(head: str) -> str | None:
    return COMMIT.search(head)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    # TEXT notes only. The first version globbed everything in the directory and
    # found two APK files sitting beside them - scanning an 84 MB binary for a
    # commit hash is meaningless, and a check that reports a binary as
    # "untraceable" is crying wolf in a new costume.
    SUFFIXES = {".txt", ".md"}
    try:
        notes = sorted(p for p in NOTES.glob("*")
                       if p.is_file() and p.suffix.lower() in SUFFIXES)
    except OSError as exc:
        if args.json:
            print(json.dumps({"tool": "check_release_notes_trace", "ok": False,
                              "error": str(exc)}))
        else:
            print(f"ERROR: cannot read {NOTES}: {exc} - nothing was checked.")
        return 2

    if not notes:
        print("check_release_notes_trace: no release notes exist yet, so there "
              "is nothing to trace and nothing wrong.")
        return 0

    untraceable = []
    for p in notes:
        try:
            head = "\n".join(p.read_text(encoding="utf-8",
                                         errors="replace").splitlines()[:HEAD_LINES])
        except OSError as exc:
            print(f"ERROR: cannot read {p.name}: {exc}")
            return 2
        if check(head) is None:
            untraceable.append(p.name)

    if args.json:
        print(json.dumps({"tool": "check_release_notes_trace", "notes": len(notes),
                          "untraceable": untraceable, "ok": not untraceable},
                         indent=2))
        return 1 if untraceable else 0

    print(f"check_release_notes_trace: {len(notes)} release note(s) in {NOTES}")
    if not untraceable:
        print("  every one names a commit, so every one can be traced to a tree.")
        return 0
    print(f"  {len(untraceable)} name NO commit in their first {HEAD_LINES} lines:")
    for name in untraceable:
        print(f"    UNTRACEABLE: {name}")
    print("")
    print("A shipped artefact that no note can trace to a tree cannot be")
    print("reproduced and cannot be rolled back to. Put the short hash in the note")
    print("when you write it - the commit you built from, read from git, never typed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
