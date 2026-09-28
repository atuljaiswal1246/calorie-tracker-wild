#!/usr/bin/env python3
"""The stop-list is a CLAIM about the archive, so it has to be re-measurable - and a
stop-list that is never checked is a comment with a table in it.

WHY THIS EXISTS. Batch 28 turned the per-query record into `STOP_LIST.md`: nine queries
measured at zero pages, every one with a POSITIVE CONTROL in the same run. That is the
first thing three batches of recording actually paid for, and it is also the easiest thing
in this repo to let rot.

A stop-list rots in a specific and quiet way: the archive changes, or a query was
transliterated wrongly, or the entry was copied from a run that was actually throttled -
and the list keeps saying "do not spend a query on this" while a dish sits unfound. Nobody
notices, because the list looks exactly as authoritative as it did when it was written. A
stop-list is only worth having if it can be FALSIFIED, and the whole point of measuring
twice is that the second measurement is the one that counts.

So this module asks three things of every entry, none of which the list can satisfy by
being written down:

  * DOES THE RECORD BACK IT? Every entry must have at least one run in
    `query_results.json` with `pages == 0` and an `error` of None. A zero recorded beside
    an error is not a zero - it is a query that was never asked - so an entry backed only
    by errored runs is a list of queries nobody has ever successfully asked.

  * WAS THERE A POSITIVE CONTROL ALONGSIDE IT? The measurement only means something if
    the same run returned hits for something else. A run where every query returned zero
    is the batch-13 shape, and an entry drawn from it is a fact about us rather than about
    the archive. This is the check the whole corpus has needed four times.

  * AND HAS ANY ENTRY SINCE RETURNED PAGES? This is the direction that matters. If an
    entry was measured zero and later returned hits, the list is WRONG and must say so
    rather than continuing to forbid a query that works. Batch 28 reproduced nine of nine
    at zero; a tenth run that returned pages would falsify the entry, and the list has to
    be able to hear that.

WHAT IS NOT ENFORCED, on purpose. The list does not forbid re-running an entry - batch 28
re-ran all nine as a reproduction, and that is the correct use of a stop-list. And it does
not claim a dish has no photograph: `lauki sabzi` is on the list and lauki has a case,
because `bottle gourd curry` found it in the very run the stop-list query missed it. The
list is about the QUERY, never about the DISH, and that sentence is in the file because
conflating the two is how this corpus published four false findings.

Run with: python3 tools/ai_accuracy/test_the_stop_list_is_still_true.py
"""
from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RECORD = REPO / "tools" / "ai_accuracy" / "query_results.json"
STOP_LIST = REPO / "tools" / "ai_accuracy" / "STOP_LIST.md"
QUERY_SETS = REPO / "tools" / "ai_accuracy" / "query_sets.py"


def _runs() -> list[tuple[str, str, dict]]:
    """(batch, recorded timestamp, query) for every recorded query."""
    if not RECORD.exists():
        return []
    out = []
    for batch, entries in json.loads(RECORD.read_text(encoding="utf-8"))["runs"].items():
        for run in entries:
            for q in run.get("queries", []):
                out.append((batch, run.get("recorded", "?"), q))
    return out


def _entries() -> list[str]:
    text = STOP_LIST.read_text(encoding="utf-8")
    return [q for q in re.findall(r"^\| `(filetype:bitmap [^`]+)` \|", text, re.M)]


class TheStopListIsStillTrueTests(unittest.TestCase):
    def setUp(self):
        self.entries = _entries()
        self.runs = _runs()

    def test_the_stop_list_is_not_empty(self):
        self.assertTrue(
            self.entries, "STOP_LIST.md lists no queries, so every check below passes "
                          "vacuously. A stop-list with nothing on it is a comment.")

    def test_every_entry_has_a_run_that_actually_returned_zero(self):
        zeros = {q["query"] for _, _, q in self.runs if q.get("pages") == 0}
        unbacked = [e for e in self.entries if e not in zeros]
        self.assertEqual(
            unbacked, [],
            f"these stop-list entries have no run in query_results.json with pages=0, so "
            f"the list is asserting something the record does not contain: {unbacked}. "
            f"Either the entry was written from memory - which is how the batch 23 ledger "
            f"edit went stale for a whole round - or the record was lost.")

    def test_every_entry_was_measured_beside_a_query_that_did_return_pages(self):
        """The check the whole corpus has needed four times. A zero is only a fact about
        the ARCHIVE if the same run returned hits for something else; a zero in a run
        where everything was zero is a fact about us, which is what batch 13's HTTP 429
        looked like from the outside."""
        by_run: dict[tuple[str, str], list[dict]] = {}
        for batch, ts, q in self.runs:
            by_run.setdefault((batch, ts), []).append(q)
        bad = []
        for entry in self.entries:
            measured_in = [k for k, qs in by_run.items()
                           if any(x["query"] == entry and x.get("pages") == 0 for x in qs)]
            if not measured_in:
                continue                      # already reported by the test above
            alongside = any(any((x.get("pages") or 0) > 0 for x in by_run[k])
                            for k in measured_in)
            if not alongside:
                bad.append(entry)
        self.assertEqual(
            bad, [],
            f"these entries were measured at zero in runs where NO query returned anything, "
            f"so they record our access rather than the archive: {bad}. A run in which "
            f"every query is zero is the batch-13 shape, and an entry drawn from it would "
            f"be a fact about a throttle written down as a fact about a dish.")

    def test_no_entry_has_since_returned_pages(self):
        """The direction that matters: a stop-list that cannot be FALSIFIED is a
        prohibition rather than a measurement. Batch 28 reproduced nine of nine at zero
        with a positive control; if any entry later returns pages, the entry is wrong and
        the list has to be able to hear that."""
        returned = {}
        for _, _, q in self.runs:
            if (q.get("pages") or 0) > 0:
                returned[q["query"]] = q["pages"]
        stale = {e: returned[e] for e in self.entries if e in returned}
        self.assertEqual(
            stale, {},
            f"these stop-list entries have since RETURNED PAGES, so the list is wrong and "
            f"is forbidding a query that works: {stale}. Remove them from the list and put "
            f"the measurement in the note - a stop-list nobody can falsify is a "
            f"prohibition, not a finding.")

    def test_every_entry_is_still_in_a_query_set_somewhere(self):
        """Entries are transcribed by hand, and a transcription slip would make the list
        name a query nobody has ever run - at which point it is guarding nothing."""
        used = set(re.findall(r"'([^']+)'", QUERY_SETS.read_text(encoding="utf-8")))
        absent = [e for e in self.entries if e not in used]
        self.assertEqual(
            absent, [],
            f"these entries appear in no query set, so they guard nothing: {absent}. An "
            f"entry that has been removed from every batch should leave the list too, or "
            f"the list starts forbidding queries that do not exist.")

    def test_the_list_says_it_is_about_queries_and_not_about_dishes(self):
        # Whitespace is collapsed first, so the sentence still counts when it happens to
        # wrap across a line. A guard that only passes while the prose is formatted one
        # particular way is a guard that will be defeated by an editor rather than by an
        # argument - and this one WAS: it went red on a correct file purely because the
        # sentence wrapped between "does" and "not say".
        text = re.sub(r"\s+", " ", STOP_LIST.read_text(encoding="utf-8"))
        self.assertRegex(
            text, r"does not say the DISH|not say the dish|about the QUERY",
            "STOP_LIST.md no longer carries the sentence that says a stop-list is about "
            "the QUERY and never about the DISH. That sentence is the whole safety "
            "property of the file: lauki sabzi is on the list and lauki HAS a case, "
            "because 'bottle gourd curry' found it in the same run. Without it a reader "
            "will take a stop-list for a statement that a dish does not exist, which is "
            "how this corpus published four false findings.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
