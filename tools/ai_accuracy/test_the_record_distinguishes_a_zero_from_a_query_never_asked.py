#!/usr/bin/env python3
"""A recorded zero and a query that was never asked are different facts, and the record
must not be able to confuse them.

WHY THIS EXISTS. The ledger's `candidates` column carries a dash for eight of twenty-four
batches, declared as "unmeasured". It was not unknowable. `fetch_commons.py` had the
number in hand at the moment the search returned, printed it, and discarded it - so the
ledger could not say whether a batch's zero was a fact about the DISHES or a fact about
our ACCESS, and those are the two things this corpus has most often got wrong.

All four of the false zeros in this corpus were the second kind:

    batch 13 ......... HTTP 429 on every query            our access
    batch 13 retry ... over-constrained wording           my query
    batch 19 ......... a category name I invented         my instrument
    batch 20 ......... `incategory:` returns nothing      a dead instrument

Not one was a fact about a dish. And the reason they survived as published findings is
that a batch whose queries were never asked and a batch whose queries were asked and
found nothing produce the SAME printed line: "candidates: 0".

So the fetcher now records, per query, how many pages the search returned before any
filtering (`pages`), how many survived (`kept`), and the error if it never got to be
asked (`error`, with `pages: null`). This module is what stops that record from rotting
back into an indistinguishable number.

WHAT IS ENFORCED, in both directions:

  * a run with a zero must ALSO have a query that returned hits in the SAME run. A run
    where every query is zero is the batch-13 shape and cannot be a finding;
  * a run with an error must not claim zero pages - `pages: null` is the only honest
    value for a query that was not asked, and `pages: 0` beside an error is a lie that
    reads exactly like a negative finding;
  * `kept` may never exceed `pages` - a kept candidate that was not in the search results
    is a bookkeeping error, and it is the shape of a number nobody can check;
  * a batch present in `runs` must name at least one query, so an empty run cannot pass
    as a clean batch;
  * and the other direction: a query recorded with `error` set MUST have `pages: null`.
    That is the same fact from the other side, and without it the record could drift
    into recording a zero for a query that was never asked - which is the original defect
    with the original guard's name on it.

The batches that predate the record are declared EXEMPT below with the reason, checked in
both directions, exactly as everywhere else in this repo: a batch that gains a record must
lose its exemption, and an exemption for a batch that has a record is a hole.

Run with: python3 tools/ai_accuracy/test_the_record_distinguishes_a_zero_from_a_query_never_asked.py
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RECORD = REPO / "tools" / "ai_accuracy" / "query_results.json"

# Batches whose per-query results were never written down, because the fetcher did not
# write them down. The reason is the same for all of them and it is not a defence: the
# number existed and was discarded, so these rows are a permanent hole in the accounting
# that no later work can fill. Declared rather than guessed at.
EXEMPT_BATCHES: dict[str, str] = {
    **{f"batch{n}": f"batch {n}, run before the fetcher recorded per-query results"
       for n in (15, 16, 17, 18, 21, 22, 23)},
    "batch24": "batch 24, the last batch run before the record existed. Its per-query "
               "outcomes are NOT recoverable - I read them off the terminal after the "
               "fact and wrote '5 downloaded', which is the DOWNLOAD count and not the "
               "search's hit count, so it is not recorded here rather than recorded wrong",
}


def _runs() -> dict[str, list[dict]]:
    if not RECORD.exists():
        return {}
    data = json.loads(RECORD.read_text(encoding="utf-8"))
    return data.get("runs", {})


def _declared_proven() -> set[str]:
    """The queries the control guard has MEASURED to return candidates. Read from that
    module rather than restated here, because a second list of the same thing is how the
    two-copies fault happens - the same shape as argparse's `choices` versus the sets
    registry, which this repo already paid for once."""
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "_ctrl", REPO / "tools" / "ai_accuracy" / "test_every_query_set_carries_a_control.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return set(mod.PROVEN_QUERIES)


class TheRecordDistinguishesAZeroFromAQueryNeverAskedTests(unittest.TestCase):
    def test_a_run_whose_every_query_returned_nothing_is_declared_not_treated_as_a_finding(self):
        runs = _runs()
        suspicious = []
        for batch, entries in runs.items():
            for run in entries:
                asked = [q for q in run.get("queries", []) if q.get("pages") is not None]
                if asked and all(q.get("pages") == 0 for q in asked):
                    suspicious.append(f"{batch} @ {run.get('recorded')}")
        self.assertEqual(
            suspicious, [],
            f"every query in these runs returned zero AND none of them errored, so on the "
            f"evidence recorded this batch cannot tell 'no such dish' from 'our search "
            f"found nothing' - which is the batch-13 shape and the shape of all four "
            f"false zeros here: {suspicious}. Either the run has a query that returned "
            f"hits, or it is declared as a batch that learned nothing.")

    def test_an_errored_query_cannot_be_recorded_as_having_returned_zero_pages(self):
        bad = []
        for batch, entries in _runs().items():
            for run in entries:
                for q in run.get("queries", []):
                    if q.get("error") and q.get("pages") is not None:
                        bad.append(f"{batch}: {q.get('query')!r} pages={q.get('pages')}")
        self.assertEqual(
            bad, [],
            f"these queries carry an error AND a page count, so the record says they were "
            f"asked and found nothing when they were in fact never asked: {bad}. A query "
            f"that was not asked is not a query that found nothing, and this is the exact "
            f"confusion that produced a published false finding in this corpus.")

    def test_an_errored_query_does_record_a_null_page_count(self):
        """The other direction, because the check above alone can be satisfied by never
        writing an error at all. If a query failed, `pages` must be null - otherwise the
        record is claiming a measurement of something that did not happen."""
        bad = []
        for batch, entries in _runs().items():
            for run in entries:
                for q in run.get("queries", []):
                    if q.get("error") and q.get("pages") is None and q.get("kept"):
                        bad.append(f"{batch}: {q.get('query')!r} kept={q.get('kept')}")
        self.assertEqual(
            bad, [],
            f"these queries were never asked yet report kept candidates, so something "
            f"downstream believes results arrived from a search that never ran: {bad}")

    def test_kept_never_exceeds_pages(self):
        bad = []
        for batch, entries in _runs().items():
            for run in entries:
                for q in run.get("queries", []):
                    p, k = q.get("pages"), q.get("kept")
                    if isinstance(p, int) and isinstance(k, int) and k > p:
                        bad.append(f"{batch}: {q.get('query')!r} kept={k} > pages={p}")
        self.assertEqual(
            bad, [],
            f"these queries kept MORE candidates than the search returned, which is "
            f"bookkeeping rather than measurement: {bad}")

    def test_every_recorded_run_names_at_least_one_query(self):
        empty = [f"{b} @ {r.get('recorded')}" for b, entries in _runs().items()
                 for r in entries if not r.get("queries")]
        self.assertEqual(
            empty, [],
            f"these runs record no queries at all, so they would pass every check above "
            f"by being vacuous: {empty}")

    def test_every_recorded_query_is_one_a_query_set_actually_runs(self):
        """A record of a query nothing runs is a measurement of nothing. And the control
        is read from the control guard's PROVEN list rather than restated, because a
        second copy of that list is the two-copies fault this repo already paid for."""
        import re
        src = (REPO / "tools" / "ai_accuracy" / "query_sets.py").read_text(encoding="utf-8")
        used = set(re.findall(r"'([^']+)'", src))
        orphan = sorted({q.get("query") for entries in _runs().values()
                         for r in entries for q in r.get("queries", [])
                         if q.get("query") not in used})
        self.assertEqual(
            orphan, [],
            f"these queries are recorded as having been run but appear in no query set, "
            f"so the record describes a batch that cannot exist: {orphan}")

    def test_no_exempt_batch_has_gained_a_record(self):
        stale = sorted(b for b in EXEMPT_BATCHES if b in _runs())
        self.assertEqual(
            stale, [],
            f"these batches are declared exempt for having no per-query record, but they "
            f"HAVE one: {stale}. Remove the exemption, because a stale exemption is a "
            f"hole with a comment on it.")

    def test_the_exemption_list_is_not_a_lie_about_coverage(self):
        runs = _runs()
        self.assertTrue(
            runs, "no run has been recorded, so this whole module passes vacuously. The "
                  "record is written by fetch_commons.py at fetch time; if it is empty "
                  "then either no batch has run since, or the writer is broken, and both "
                  "are worth knowing rather than assuming.")
        self.assertTrue(
            _declared_proven(),
            "the control guard's PROVEN list is empty, so the zero-detection above has "
            "nothing to compare a run against.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
