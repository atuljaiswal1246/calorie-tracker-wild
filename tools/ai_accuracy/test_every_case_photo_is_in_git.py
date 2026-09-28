#!/usr/bin/env python3
"""A case whose photograph is not in git is a case a clone cannot score.

WHY THIS EXISTS, and the hole was in MY work, found on 2026-09-28 while proving a commit
hash rather than while looking for it.

Batches 11 through 15 each ran `git add` with an explicit file list, and
`tools/ai_accuracy/photos/` was never in any of them. So `cases.json` and `photos.json`
have been committed since batch 11 referencing FIVE images that exist in the working tree
and in no commit:

    stuffed_capsicum_home, uthappam_plate_chutney, onion_uthappam_banana_leaf,
    aloo_raita_bowl, beans_potato_bowl

A fresh clone therefore has 47 cases and 5 photographs that do not exist, and
`test/corpus_photos_present_test.dart` — *"every case points at a photo that exists on
disk"* — goes red on that clone. **And the guard is right**: the repository is broken, in
a way nobody could diagnose from inside the clone, because the working tree is fine and
every local check is green.

That is the shape this module exists to close, and it is the same shape as a guard that
passed while destroying `photos.json`, one level up: **a check that can only see the
working tree is not a check on what ships.** Every other guard in this directory asks
"does the file exist?" — which is true in my tree and false in yours.

So this one asks git, not the filesystem, and it is the only check here that would have
caught it. `git ls-files` is the instrument: it answers what is IN THE COMMIT, which is
the question a clone will ask.

WHAT IT DOES NOT DO: it does not fetch a clone, and it does not run the suite. It reads
git's own index, which is the same answer `git ls-files` gives in CI and on a fresh
checkout, and it costs one subprocess.

Run with: python3 tools/ai_accuracy/test_every_case_photo_is_in_git.py
"""
from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CASES = REPO / "tools" / "ai_accuracy" / "cases.json"


def _tracked() -> set[str]:
    """What is IN THE COMMIT. Not what exists - existence is the other guard's job, and
    conflating the two is how a working-tree check passes while a clone is broken."""
    out = subprocess.run(["git", "ls-files"], cwd=REPO, capture_output=True,
                         text=True, timeout=120)
    if out.returncode != 0:
        raise RuntimeError(f"git ls-files failed: {out.stderr.strip()}")
    return set(out.stdout.split())


class EveryCasePhotoIsInGitTests(unittest.TestCase):
    def test_every_case_image_is_tracked_by_git(self):
        tracked = _tracked()
        missing = [(c["id"], c["image"]) for c in json.loads(
            CASES.read_text(encoding="utf-8"))["cases"] if c["image"] not in tracked]
        self.assertEqual(
            missing, [],
            f"{len(missing)} case(s) name an image that is NOT in git, so a fresh clone "
            f"has a case it cannot score: {missing}.\n\n"
            f"The working tree has them, which is why every other check here is green and "
            f"why this one exists. The commit is missing them, not the disk. "
            f"`git add tools/ai_accuracy/photos/` and commit.")

    def test_the_manifest_records_nothing_that_is_both_absent_and_untracked(self):
        """A photo the manifest records as REJECTED must have had its file freed, and a
        photo it records as unused must still be accounted for somewhere. This is the
        second half of the same question - the manifest and the commit have to agree."""
        tracked = _tracked()
        m = json.loads((REPO / "tools/ai_accuracy" / "photos.json").read_text(
            encoding="utf-8"))
        ghosts = [p["file"] for p in m["photos"]
                  if p.get("rejected") and p["file"] in tracked]
        self.assertEqual(
            ghosts, [],
            f"these are recorded as rejected but their files are still committed, "
            f"wasting repo size: {ghosts}")

    def test_git_ls_files_actually_ran(self):
        """The check above is only as good as its instrument. If `git ls-files` fails, or
        returns an implausibly small set because it ran in the wrong directory, the test
        above would pass for the wrong reason - which is the fault this whole directory
        exists to prevent. So the instrument is measured, not trusted."""
        tracked = _tracked()
        self.assertGreater(
            len(tracked), 50,
            f"git ls-files returned only {len(tracked)} paths, which cannot be this "
            f"repository. Either it ran somewhere else or the index is not what the "
            f"commit contains - and a guard that passes on an empty answer is a guard "
            f"that protects nothing.")
        self.assertIn("tools/ai_accuracy/cases.json", tracked,
                      "git ls-files does not list cases.json, so it is not reporting this "
                      "repository's index and every check built on it is meaningless")


if __name__ == "__main__":
    unittest.main(verbosity=2)
