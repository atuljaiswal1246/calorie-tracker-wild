#!/usr/bin/env python3
"""A category a search uses must be a category that EXISTS.

WHY THIS EXISTS. Four batches in this corpus have returned zero candidates, and three of
them were me rather than the world:

    batch 13 ...... HTTP 429 on every query            - a fact about our access
    batch 13 retry  over-constrained wording             - a fact about my query
    batch 19 ...... `incategory:"Indian sweets"` and     - a fact about my INSTRUMENT
                    `incategory:"Indian rice dishes"`,
                    both names I invented

Batch 19 is the one this module exists for. An instrument whose name is wrong returns
zero in **exactly the same shape** as a dish that does not exist, and there is no way to
tell them apart from the output alone. So the name has to be checked before it is used
to conclude anything - and batch 19 nearly became "Commons has no photograph of kheer",
which is false, kheer being one of the commonest entries in this corpus's own coverage
list.

Batch 17 is the proof the mechanism is worth having: `incategory:"Gujarati cuisine"`
surfaced Gol dhokla, khandvi, muthia and methi muthiya where the text search had been
returning an 1784 antique map. That one worked because the category name happened to be
real. Guessing is what failed.

HOW IT IS CHECKED, and why this file is hermetic. The verification itself needs the
network, so it is NOT done here: a batch run records what it verified into
`verified_categories.json`, and this module checks the query sets against THAT FILE. A
test that phoned Commons would be a test that fails when the network is busy, and a
guard that fails for the wrong reason is a guard nobody reads.

  * every `incategory:"..."` used anywhere in query_sets.py must be in the verified file;
  * the verified file must be non-empty, so an empty declaration cannot pass this;
  * a name recorded as NOT EXISTING may not be used in a query - that is the batch-19
    mistake, made permanent until someone finds the real name;
  * and a name may not be recorded both ways, because a file that says "exists" and
    "missing" for the same category is worse than no file.

Run with: python3 tools/ai_accuracy/test_a_search_category_must_exist.py
"""
from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "ai_accuracy"))
from fetch_commons import category_exists  # noqa: E402,F401  (documents the verifier)

QUERY_SETS = REPO / "tools" / "ai_accuracy" / "query_sets.py"
VERIFIED = REPO / "tools" / "ai_accuracy" / "verified_categories.json"

# incategory:"Some Category"  - Commons uses the quoted form in CirrusSearch.
_INCATEGORY = re.compile(r'incategory:"([^"]+)"')


def _used() -> set[str]:
    return set(_INCATEGORY.findall(QUERY_SETS.read_text(encoding="utf-8")))


def _verified() -> dict:
    if not VERIFIED.exists():
        return {}
    return json.loads(VERIFIED.read_text(encoding="utf-8"))


class ASearchCategoryMustExistTests(unittest.TestCase):
    def test_every_category_a_query_uses_has_been_verified(self):
        used, ver = _used(), _verified()
        self.assertTrue(ver, f"{VERIFIED.name} is missing or empty, so this check would "
                             f"pass on nothing. A batch run records what it verified "
                             f"with fetch_commons.category_exists(); if no category has "
                             f"been verified yet, that is a finding, not a pass.")
        unknown = sorted(used - set(ver))
        self.assertEqual(
            unknown, [],
            f"these categories are used in a query but were never verified: {unknown}. "
            f"Run fetch_commons.category_exists(name) and record the answer in "
            f"{VERIFIED.name} before concluding anything from a query that uses it - an "
            f"invented category name returns zero exactly like a dish that is absent")

    def test_no_category_known_to_be_missing_is_used_in_a_query(self):
        used, ver = _used(), _verified()
        missing = {n for n, v in ver.items() if v is False}
        still_used = sorted(missing & used)
        self.assertEqual(
            still_used, [],
            f"these categories are recorded as NOT EXISTING on Commons and are still "
            f"used in a query: {still_used}. Every one of them is a query that will return "
            f"zero in the shape of a finding about a dish. That is the batch-19 mistake, "
            f"kept.")

    def test_no_query_uses_incategory_at_all(self):
        """`incategory:` is now forbidden outright, not merely required to be verified.

        "Must exist" turned out to be the wrong bar. MEASURED on 2026-09-28, with
        SEARCH_FAILURES empty so every query was genuinely asked:

            1 candidate  <- filetype:bitmap uthappam breakfast        (the control)
            0 candidates <- filetype:bitmap incategory:"Sweets" gajar halwa
            0 candidates <- filetype:bitmap incategory:"Sweets"
            0 candidates <- filetype:bitmap incategory:"Indian cuisine"
            2 candidates <- filetype:bitmap gajar halwa

        `incategory:` returns nothing ALONE, with a dish name, and with categories
        verified to exist. The instrument is dead in this harness whatever the category is
        called, so requiring it to be a real category was requiring the impossible - and
        the failure mode is the worst kind: a query that cannot return a result, sitting in
        a batch where every other query looks fine.

        The general lesson, and it is the reason this is a hard ban rather than a note: an
        instrument that cannot produce a result must not be used to conclude anything, and
        "the category exists" is not a substitute for "the category returns something".
        """
        used = _used()
        self.assertEqual(
            used, set(),
            f"these queries use incategory:, which is measured to return nothing in this "
            f"harness - alone, with a dish name, and with categories verified to exist: "
            f"{sorted(used)}. Remove them, or re-measure the instrument and change this "
            f"test in the same commit, because a dead instrument in a query set is a "
            f"query that cannot return a finding.")

    def test_no_category_is_recorded_as_both_existing_and_missing(self):
        text = VERIFIED.read_text(encoding="utf-8") if VERIFIED.exists() else "{}"
        data = json.loads(text)
        for name, verdict in data.items():
            with self.subTest(category=name):
                self.assertIsInstance(
                    verdict, bool,
                    f"{name!r} is recorded as {verdict!r}. Only true and false are "
                    f"allowed, because a third state - 'could not ask' - is exactly how a "
                    f"throttle becomes a finding about a category")
        self.assertTrue(
            data, "the verified file parses but is empty, so this whole module is green "
                  "on nothing")


if __name__ == "__main__":
    unittest.main(verbosity=2)
