#!/usr/bin/env python3
"""The corpus is 42 PHOTOGRAPHS. Nothing was checking that they are 42 photographs.

WHY THIS EXISTS, and the hole is not one I guessed at. `notes/FREE_TIER_ACCOUNTING.md`
turned out to be a ledger nobody checked, and the fix there produced the obvious
question about its neighbour. The corpus has two guards on it and both of them are
about ARITHMETIC:

  * `test/corpus_independence_test.dart` re-derives the declared counts and the
    concentration from `tools/ai_accuracy.py --corpus`, and goes red when the note
    goes stale. It is a guard on the arithmetic.
  * nothing whatsoever checked the PHOTOGRAPHS.

That gap is not theoretical for this card, because the card's own number is a CLASS
COUNT. A duplicate photograph is two cases wearing two names: it inflates the case
total, and — worse — a re-encoded copy of an existing dish is a fresh case for a
class the corpus already holds, which is precisely the regression batches 8 and 10
were built to remove. `fetch_commons.py` has a dHash near-duplicate check, but it
runs on CANDIDATES at fetch time. It says nothing about the 42 committed cases, and
a hand-written apply step can put anything in cases.json.

The two failure modes it was already bitten by, both on 2026-09-28 and both recorded
in that file's own comments:
  * the download path is a digest of the source URL, so re-fetching a photo we
    already held wrote the SAME path — the near-duplicate branch then deleted the
    file an accepted record pointed at;
  * `apply_batch*.py` DELETES the files it rejects, so a rejected photograph that
    some case still names is one commit away from being a case pointing at nothing.

MEASURED on the corpus as committed, by this module's own arithmetic, 2026-09-28:
42 cases, 42 hashed, 0 that PIL could not open, 0 byte-identical pairs, and 0 pairs
within NEAR_DUP_DISTANCE. The CLOSEST pair in the entire corpus is hamming 13
(baingan_bharta <-> kofta_curry_twelve) against a threshold of 8 — so the corpus is
not merely inside the floor, it is clear of it by a margin, and the three repeated
families (baingan, aloo gobi, kofta) are genuinely different photographs of the same
dish rather than the same photograph twice.

ONE DEFINITION OF "NEAR-DUPLICATE", which is the whole reason this is a separate
module that IMPORTS rather than a fifth rule written from scratch: dhash, hamming
and NEAR_DUP_DISTANCE are imported from fetch_commons. A second copy of that
threshold is a second definition, and two definitions drift until the guard and the
fetcher disagree about what a duplicate is — which is the fault this whole night has
been paying for, in a new costume.

Run with: python3 tools/ai_accuracy/test_the_corpus_photographs_are_distinct.py
Bite proof: tools/ai_accuracy/prove_the_photograph_guard_bites.py
Guarded in the suite by: test/corpus_photographs_distinct_test.dart

WHAT IT DOES NOT CHECK, said up front: whether each photograph's declared `truth` is
the right truth for that photograph. That is a judgement no machine here can make, it
is what a person did batch by batch, and this module will happily pass a corpus whose
labels are wrong. It checks that the corpus is 42 distinct real images, not that the
labels are correct.
"""
from __future__ import annotations

import hashlib
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fetch_commons import NEAR_DUP_DISTANCE, dhash, hamming  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
CASES = REPO / "tools" / "ai_accuracy" / "cases.json"


def _cases() -> list[dict]:
    return json.loads(CASES.read_text(encoding="utf-8"))["cases"]


def _path(case: dict) -> Path:
    """Case images are stored as the path the APP uses, e.g.
    assets/onboarding/food_palak_paneer.jpg for in-repo originals and
    tools/ai_accuracy/photos/<name>.jpg for fetched ones - so the case's own value is
    resolved from the repo root rather than being rebuilt here. Rebuilding it was the
    mistake I made first: a dead expression checked the repo root for a bare
    filename and reported all 42 photographs missing, which is a false finding, not
    a null one."""
    return REPO / case["image"]


class CorpusPhotographsAreDistinctTests(unittest.TestCase):
    def test_every_case_image_exists_and_is_not_empty(self):
        missing, empty = [], []
        for c in _cases():
            p = _path(c)
            if not p.exists():
                missing.append((c["id"], c["image"]))
            elif p.stat().st_size == 0:
                empty.append((c["id"], c["image"]))
        self.assertEqual(missing, [],
                         f"these cases name an image that is not on disk: {missing}. A "
                         f"case pointing at nothing inflates every count that reads "
                         f"cases.json, and the declared-counts guard cannot see it")
        self.assertEqual(empty, [],
                         f"these cases name a zero-byte file: {empty}. An empty file is "
                         f"not a photograph and opens to nothing")

    def test_every_case_image_can_actually_be_opened(self):
        """A file that exists is not a file that is an image. Measured across the
        corpus as committed: 42 of 42 open, so this is preventive — but the failure
        it catches (a truncated download, a .txt saved as .jpg) is invisible to a
        count and to a hash alike."""
        unopenable = [(c["id"], c["image"]) for c in _cases() if dhash(str(_path(c))) is None]
        self.assertEqual(
            unopenable, [],
            f"these case images could not be decoded, so they cannot be a photograph "
            f"of anything: {unopenable}")

    def test_no_two_cases_are_byte_identical(self):
        by_digest: dict[str, list[str]] = {}
        for c in _cases():
            by_digest.setdefault(hashlib.sha256(_path(c).read_bytes()).hexdigest(),
                                 []).append(c["id"])
        dupes = {d: ids for d, ids in by_digest.items() if len(ids) > 1}
        self.assertEqual(
            dupes, {},
            f"these cases are the same bytes under two ids: {dupes}. A straight copy is "
            f"the easy duplicate, and this is the cheap check for it")

    def test_no_two_cases_are_perceptually_the_same_photograph(self):
        """The check that earns its keep, because a re-saved copy has different bytes
        and is the duplicate that actually happens: the same photograph re-encoded,
        cropped, or re-compressed passes sha256 and is still the same case twice.

        The threshold is imported from fetch_commons, not restated, so the fetcher and
        this guard cannot disagree about what a duplicate is.
        """
        hashed = [(c["id"], dhash(str(_path(c)))) for c in _cases()]
        pairs = [(hamming(a[1], b[1]), a[0], b[0])
                 for i, a in enumerate(hashed) for b in hashed[i + 1:]
                 if a[1] is not None and b[1] is not None
                 and hamming(a[1], b[1]) <= NEAR_DUP_DISTANCE]
        self.assertEqual(
            sorted(pairs), [],
            f"these case pairs are within {NEAR_DUP_DISTANCE} bits of each other, the "
            f"same floor the fetcher applies: {sorted(pairs)}. A near-duplicate is two "
            f"cases of one class wearing two names, and the class count this card "
            f"reports is exactly the number that inflates when it happens")

    def test_the_closest_pair_is_reported_not_just_passed(self):
        """A threshold test that only ever says PASS tells nobody how close the corpus
        is to failing it. The floor is a cliff, and this is the altitude: the closest
        pair among all 861 comparisons, printed on every run, so a later batch that
        pushes the corpus toward the edge is visible as a number before it is a
        failure."""
        hashed = [(c["id"], dhash(str(_path(c)))) for c in _cases()]
        best = min((hamming(a[1], b[1]), a[0], b[0])
                   for i, a in enumerate(hashed) for b in hashed[i + 1:])
        print(f"\n  closest pair in the corpus: hamming {best[0]} "
              f"({best[1]} <-> {best[2]}) against a floor of {NEAR_DUP_DISTANCE}, "
              f"across {len(hashed) * (len(hashed) - 1) // 2} comparisons")
        self.assertGreater(
            best[0], NEAR_DUP_DISTANCE,
            f"the closest pair is hamming {best[0]} ({best[1]} <-> {best[2]}), which is "
            f"AT OR INSIDE the floor of {NEAR_DUP_DISTANCE} - so the corpus has a "
            f"perceptual duplicate in it. The first run of this file asserted the "
            f"opposite (`assertLess`, 13 not less than 8) because the relation was "
            f"written backwards: a pair below the floor is the FAILURE, not the "
            f"success. The sibling duplicate test is the one that reports it by name.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
