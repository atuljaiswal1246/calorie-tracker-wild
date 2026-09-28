#!/usr/bin/env python3
"""The ledger's yield figures must be MEASURED, not remembered - because they move every
time a photograph is reviewed, and a stale precision figure is worse than none.

WHY THIS EXISTS. Twenty-six batches of searching have never had their yield stated. I knew
the accepted and rejected columns per batch, which sum to a total, and I had never asked
the only question that matters about a corpus built by fetching: what fraction of the
photographs I reviewed actually became cases. Measured on 2026-09-28:

    44 of 107 reviewed photographs became cases = 41%

So a batch of 5 downloads is worth about 2 cases, not 5 - and every batch estimate I had
been making in my head was optimistic by roughly half. That number belongs in the ledger
where the batch table lives, and a number in prose that nobody recomputes is the exact
fault this repo has been fixing all night.

So this module recomputes every figure in the ledger's yield section from `photos.json`
and `query_results.json`, and fails BY NAME if the file disagrees. It is the same pattern
as test_the_note_never_carries_a_class_count_other_than_the_two_published_ones, applied to
the one figure nobody had published yet.

WHAT IS ENFORCED, in both directions:

  * the stated precision, its numerator and its denominator must equal the measurement -
    a figure that is right but whose parts are wrong is a figure nobody can check;
  * the ranked table's ACCEPTED and JUDGED columns must match the manifest per query, so
    a row cannot claim a query produced a case it did not;
  * the count of zero-yield queries must match;
  * a query may not appear in BOTH tables - one row cannot be a producer and a
    non-producer, which is the two-copies shape in a table;
  * and the other direction: a query the manifest knows about must appear in one of the
    two tables or in neither, never silently in neither while the file implies it was
    counted. More precisely, the file's own total of listed queries must not exceed the
    number the manifest has, because a table listing more queries than exist is a table
    describing a corpus that is not this one.

WHAT THIS REFUSES TO CLAIM, deliberately. It does NOT assert any relationship between the
number of pages a query returned and how many cases it produced. There are 11 judged
photographs across 3 distinct page counts among the recorded queries, and the spread runs
the wrong way for it. Asserting a relationship there would be inventing a rule from noise,
which is the failure this repo has committed four times already and guards against by name.

Run with: python3 tools/ai_accuracy/test_the_query_yield_figure_is_measured.py
"""
from __future__ import annotations

import collections
import json
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PHOTOS = REPO / "tools" / "ai_accuracy" / "photos.json"
RECORD = REPO / "tools" / "ai_accuracy" / "query_results.json"
LEDGER = REPO / "notes" / "FREE_TIER_ACCOUNTING.md"


def _photos() -> list[dict]:
    return json.loads(PHOTOS.read_text(encoding="utf-8"))["photos"]


def _pages() -> dict[str, int]:
    """Highest recorded page count per query. A query may run in several batches and a
    later run can return fewer pages for reasons that have nothing to do with the query,
    so the figure quoted is the best the archive has ever given it - and the table says
    `n` is tiny rather than pretending otherwise."""
    if not RECORD.exists():
        return {}
    out: dict[str, int] = {}
    for runs in json.loads(RECORD.read_text(encoding="utf-8"))["runs"].values():
        for run in runs:
            for q in run.get("queries", []):
                if q.get("pages") is not None:
                    out[q["query"]] = max(out.get(q["query"], 0), q["pages"])
    return out


def _per_query() -> dict[str, tuple[int, int]]:
    out: dict[str, tuple[int, int]] = {}
    for p in _photos():
        q = p.get("query")
        if not q or not (p.get("accepted_as") or p.get("rejected")):
            continue
        a, j = out.get(q, (0, 0))
        out[q] = (a + (1 if p.get("accepted_as") else 0), j + 1)
    return out


def _totals() -> tuple[int, int]:
    a = sum(1 for p in _photos() if p.get("accepted_as"))
    r = sum(1 for p in _photos() if p.get("rejected"))
    return a, a + r


def _section() -> str:
    text = LEDGER.read_text(encoding="utf-8")
    i = text.find("## 5. Query yield")
    assert i != -1, ("the ledger has no '## 5. Query yield' section, so the figures this "
                     "module checks are not in the file at all. Do not delete the section "
                     "silently - the precision number lives there and nowhere else.")
    return text[i:]


class TheQueryYieldFigureIsMeasuredTests(unittest.TestCase):
    def setUp(self):
        self.sec = _section()

    def test_the_stated_precision_is_the_measurement(self):
        accepted, judged = _totals()
        want = 100 * accepted // judged
        m = re.search(r"\*\*PRECISION: (\d+) of (\d+) reviewed photographs became cases = (\d+)%",
                      self.sec)
        self.assertIsNotNone(
            m, "the ledger's yield section no longer states a precision figure. A corpus "
               "built by fetching has to say what its downloads are actually worth.")
        got = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        self.assertEqual(
            got, (accepted, judged, want),
            f"the ledger says {got[0]} of {got[1]} = {got[2]}%, and the manifest holds "
            f"{accepted} accepted of {judged} judged = {want}%. The corpus is the fact; "
            f"fix the ledger, not the photographs - and if the photographs really did "
            f"change, re-run the apply script rather than editing this sentence.")

    def test_every_ranked_row_matches_the_manifest(self):
        per = _per_query()
        rows = re.findall(r"^\| `([^`]+)` \| (\d+) \| (\d+) \|$", self.sec, re.M)
        self.assertTrue(rows, "the ranked table in the yield section is empty or unreadable.")
        bad = []
        seen = set()
        for q, a, j in rows:
            seen.add(q)
            real = per.get(q)
            if real is None:
                bad.append(f"{q!r} is listed but the manifest has no judged photo for it")
            elif (int(a), int(j)) != real:
                bad.append(f"{q!r}: ledger says {a}/{j}, manifest says {real[0]}/{real[1]}")
        self.assertEqual(
            bad, [],
            f"the ranked table disagrees with photos.json: {bad}. A yield table that "
            f"cannot be reproduced from the manifest is a table nobody can check, and it "
            f"is the one place a reader would most reasonably trust it.")

    def test_the_zero_yield_count_is_measured(self):
        per = _per_query()
        zero = sum(1 for a, j in per.values() if a == 0)
        m = re.search(r"\*\*(\d+) queries downloaded photographs and produced NO case at all",
                      self.sec)
        self.assertIsNotNone(m, "the yield section no longer states how many queries wasted "
                                "their downloads.")
        self.assertEqual(
            int(m.group(1)), zero,
            f"the ledger says {m.group(1)} queries produced no case; the manifest has {zero}. "
            f"Those rows are the expensive ones - a download, a licence, a SHA-256 and a "
            f"review, for nothing - so their count is the one a reader would act on.")

    def test_no_query_is_listed_as_both_a_producer_and_a_non_producer(self):
        producing = set(re.findall(r"^\| `([^`]+)` \| \d+ \| \d+ \|$", self.sec, re.M))
        nonproducing = set(re.findall(r"^\| `([^`]+)` \| \d+ \|$", self.sec, re.M))
        both = sorted(producing & nonproducing)
        self.assertEqual(
            both, [],
            f"these queries appear in BOTH tables: {both}. One row cannot have produced a "
            f"case and produced none - the same two-copies shape as a control list and the "
            f"queries it vouches for.")

    def test_the_table_never_lists_more_queries_than_the_manifest_has(self):
        per = _per_query()
        listed = set(re.findall(r"^\| `([^`]+)` \|", self.sec, re.M))
        invented = sorted(listed - set(per))
        self.assertEqual(
            invented, [],
            f"the yield section lists queries the manifest has never heard of: {invented}. "
            f"A table naming queries that do not exist is describing a corpus that is not "
            f"this one.")

    def test_the_section_refuses_to_claim_a_pages_relationship(self):
        """The trap this module is written around. It is natural to ask whether more pages
        means a better query, and with 11 judged photographs across 3 page counts the honest
        answer is that nobody knows. The file must therefore not assert one - so if a
        future round finds a real relationship, this check has to be DELETED WITH A REASON
        rather than quietly satisfied."""
        claims = re.findall(r"more pages (?:is|means) a better query|"
                            r"pages predict\w*\s+(?:acceptance|a case)", self.sec)
        hedged = ("far too small" in self.sec or "too small" in self.sec
                  or "noise, not a relationship" in self.sec)
        self.assertTrue(
            hedged or not claims,
            "the yield section appears to assert a relationship between pages returned and "
            "cases produced WITHOUT saying the sample is too small to support it. That is "
            "inventing a rule from noise, which this corpus has done four times already.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
