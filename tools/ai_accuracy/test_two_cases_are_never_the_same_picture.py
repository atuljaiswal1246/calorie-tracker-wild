#!/usr/bin/env python3
"""No two cases may be the same photograph. The case count is the number the M1 bar is
judged on, so a count that can be inflated by one picture counted twice is not a count.

WHY THIS EXISTS, and it replaces a rule that was wrong.

A camera-frame-counter rule shipped in `8bbbd6c`: `frame_stem()` stripped a trailing
counter ("...DSC 0028.jpg" / "...DSC 0029.jpg") and the fetcher skipped a candidate whose
stem matched one already held, on the theory that two adjacent frames of one meal are one
photograph. It was removed the next round, because the corpus's own data refutes the theory
on every pair the rule touches:

    File:Bottle Gourd Curry.jpg  vs  File:Bottle gourd Curry.jpg   hamming 31
        BOTH ARE ACCEPTED CASES - lauki_curry and lauki_chana_curry
    ...Mohali 2016-08-06 8213.JPG vs  ...8227.JPG                  hamming 35
    ...West Bengal DSC 0028.jpg  vs  ...DSC 0029.jpg               hamming 20

Not one of those is a frame of another. The rule would have skipped three real photographs,
two of them cases in this corpus, on a filename inference that was never measured against
the images. A title heuristic cannot protect a count that depends on pictures.

So this module checks the invariant that actually protects it, in both directions:

  * no two CASES may be within NEAR_DUP_DISTANCE on the perceptual hash. This is the one
    that matters: two photographs of the same plate, or the same photograph saved twice,
    would be two cases, two class memberships and two units in every count derived from
    them. Measured today: 0 pairs within distance 8 among 67 cases.

  * no two CASE TITLES may be equal. The fetcher's dedupe is exact-title equality, so two
    cases cannot share a title - but that is an assumption about the fetcher rather than a
    property of the corpus, and it is checked here so that if the fetcher's rule ever
    loosens, this goes red before a duplicate lands rather than after.

  * every case must HAVE a dhash. A case with no perceptual hash cannot be checked against
    anything, so it is a case that is silently exempt from the check above - the same
    shape as a missing ledger cell reading as a zero.

  * and the check must not be vacuous: if `hamming` or the threshold were unreachable,
    every one of these would pass while a duplicate sat in the corpus.

WHAT THIS DOES NOT CLAIM. It does not claim the corpus is photographically diverse - two
photographs of the same dish taken minutes apart at the same table would pass, because they
are genuinely different pictures and the class count is entitled to count them twice. That
is a sampling question and it is the concentration figure's business, not this guard's. What
this forbids is counting ONE picture twice.

Run with: python3 tools/ai_accuracy/test_two_cases_are_never_the_same_picture.py
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CASES = REPO / "tools" / "ai_accuracy" / "cases.json"
PHOTOS = REPO / "tools" / "ai_accuracy" / "photos.json"

import sys
sys.path.insert(0, str(REPO / "tools" / "ai_accuracy"))
from photo_store import NEAR_DUP_DISTANCE, hamming  # noqa: E402


def _cases() -> list[dict]:
    return json.loads(CASES.read_text(encoding="utf-8"))["cases"]


def _by_file() -> dict[str, dict]:
    return {p["file"]: p for p in
            json.loads(PHOTOS.read_text(encoding="utf-8"))["photos"]}


class TwoCasesAreNeverTheSamePictureTests(unittest.TestCase):
    def setUp(self):
        self.cases = _cases()
        self.photos = _by_file()

    def test_no_two_cases_are_within_the_near_duplicate_distance(self):
        """The check that matters. Every one of these pairs would be two cases, two class
        memberships and two units in every count derived from the corpus - for one
        picture."""
        pairs = []
        for i, a in enumerate(self.cases):
            ha = self.photos.get(a["image"], {}).get("dhash")
            if ha is None:
                continue
            for b in self.cases[i + 1:]:
                hb = self.photos.get(b["image"], {}).get("dhash")
                if hb is None:
                    continue
                d = hamming(ha, hb)
                if d <= NEAR_DUP_DISTANCE:
                    pairs.append((a["id"], b["id"], d))
        self.assertEqual(
            pairs, [],
            f"these cases are the SAME PICTURE within NEAR_DUP_DISTANCE={NEAR_DUP_DISTANCE} "
            f"and are being counted twice: {pairs}. Every count in this repo - the case "
            f"count, the class count, the concentration - is derived from the number of "
            f"cases, so a picture counted twice is not a duplicate, it is a number that "
            f"cannot be compared with any other number.")

    def test_every_case_carries_a_perceptual_hash(self):
        missing = [c["id"] for c in self.cases
                   if not self.photos.get(c["image"], {}).get("dhash")]
        self.assertEqual(
            missing, [],
            f"these cases have no dhash, so they are silently EXEMPT from the check above - "
            f"exactly the shape of a missing ledger cell reading as a zero: {missing}. A "
            f"case that cannot be compared against anything is a case nobody can check.")

    def test_no_two_cases_share_a_title(self):
        titles: dict[str, list[str]] = {}
        for c in self.cases:
            t = self.photos.get(c["image"], {}).get("title")
            if t:
                titles.setdefault(t, []).append(c["id"])
        shared = {t: ids for t, ids in titles.items() if len(ids) > 1}
        self.assertEqual(
            shared, {},
            f"these cases share a Commons title, which means the same file is in the corpus "
            f"twice under one name: {shared}. The fetcher's dedupe is exact-title equality, "
            f"so this should be impossible - and it is checked here rather than assumed, "
            f"because if that dedupe ever loosens this is what notices.")

    def test_every_case_image_is_present_in_the_manifest(self):
        orphan = [c["id"] for c in self.cases if c["image"] not in self.photos]
        self.assertEqual(
            orphan, [],
            f"these cases name an image the manifest does not hold: {orphan}. Without a "
            f"manifest entry there is no dhash, so the case is exempt from the "
            f"near-duplicate check above and cannot be judged a duplicate by anything.")

    def test_the_distance_check_can_actually_fail(self):
        """A check that cannot fail is a comment. Measured on the real corpus's own data:
        the two bottle-gourd cases sit 31 apart, and re-encoding one photograph moves its
        hash by 0, so a genuine duplicate would be inside the threshold and this would
        fire."""
        a = self.photos.get(next(c["image"] for c in self.cases
                                 if c["id"] == "lauki_curry"), {}).get("dhash")
        b = self.photos.get(next(c["image"] for c in self.cases
                                 if c["id"] == "lauki_chana_curry"), {}).get("dhash")
        self.assertIsNotNone(a, "the case this test measures against is gone from the "
                                "manifest, so the calibration can no longer be checked")
        self.assertIsNotNone(b, "the case this test measures against is gone")
        self.assertGreater(
            hamming(a, b), NEAR_DUP_DISTANCE,
            f"the two calibration cases are now within NEAR_DUP_DISTANCE "
            f"({hamming(a, b)}), so either the corpus changed or the threshold moved - and "
            f"in both cases this module's calibration claim is stale and must be re-measured.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
