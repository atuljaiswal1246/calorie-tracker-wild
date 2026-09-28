#!/usr/bin/env python3
"""Every query set must carry a control. A set without one cannot tell "no such dish"
from "my query is broken".

WHY THIS EXISTS, and the four it would have caught. This corpus has returned zero
candidates four times, and **every single zero was my instrument rather than the world**:

    batch 13 ...... HTTP 429 on every query          - our access
    batch 13 retry . over-constrained wording         - my query
    batch 19 ...... a category name I invented        - my instrument
    batch 20 ...... `incategory:` returns nothing     - a dead instrument

Not one was a fact about a dish. Three of them were published as findings before
anything caught them, and the reason is simple and unflattering: **a control query is a
convention I have to remember, and I added it in batch 15 — after the three zeros had
already been written up.** A rule I hold in my head is a rule I will drop, and this one
was dropped three times before it was written down.

So it is a check now. A query set must contain at least one query MEASURED to return
candidates. A set that does not can only ever produce a finding of the form "nothing
found", which is exactly the shape of a finding that turned out to be false four times.

WHAT IS AND IS NOT ENFORCED:
  * a set with no proven query in it FAILS - it is a set whose zeros mean nothing;
  * the twelve sets that predate the rule are DECLARED as exempt, with the reason, and
    the declaration is checked in both directions - a new set with no control cannot be
    added quietly, and an exemption cannot quietly outlive its reason;
  * a query may only be declared PROVEN if it appears in a query set, so the list cannot
    grow to contain a query nothing ever runs.

Run with: python3 tools/ai_accuracy/test_every_query_set_carries_a_control.py
"""
from __future__ import annotations

import ast
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUERY_SETS = REPO / "tools" / "ai_accuracy" / "query_sets.py"

# Queries MEASURED to return candidates on 2026-09-28, with the number that was seen.
# A control has to be something that COULD have been positive, so a control that returns
# nothing is not a control - it is one more thing that might be broken.
PROVEN_QUERIES: dict[str, str] = {
    "filetype:bitmap uthappam breakfast":
        "returned hits in batches 12 and 14-21 and is the standing control",
    "filetype:bitmap gajar halwa":
        "2 candidates, measured 2026-09-28, after batch 18 recorded it as a failure",
    'filetype:bitmap "mushroom curry"':
        "3 candidates, measured 2026-09-28 - and 0 with two extra form words added, which "
        "is what proved the over-constraint",
}

# Sets that ran before the rule existed. The reason is the same for all of them and it is
# not a defence of them: they predate the control, and three of their four zeros went
# uncaught as a result.
EXEMPT_SETS: dict[str, str] = {
    "QUERIES": "batch 1, before controls existed",
    "SINGLE_QUERIES": "batch 1, before controls existed",
    **{f"BATCH{n}_QUERIES": f"batch {n}, before the control was added in batch 15"
       for n in range(2, 12)},
    "BATCH13_QUERIES":
        "batch 13 - THE 429 BATCH, and the first of the four false zeros. This set has no "
        "control, which is why its zero could be a rate limit and be written up as a fact "
        "about three dishes. It is exempt because it already ran, not because the absence "
        "is acceptable; the guard going red on this exact set is the point of naming it",
}

# THE EXTRACTION, and it is the tree rather than the text because of a measured failure.
#
# This module used to parse `query_sets.py` with two regexes: one to find a set's name and
# one to pull its queries out with r"'([^']+)'". Measured against the file on 2026-09-28,
# that regex is wrong on ONE SET IN THIRTY:
#
#     BATCH26_QUERIES   the regex returns prose fragments such as
#                       "s finding inside this batch\n    "
#                       and MISSES ALL EIGHT of its real queries.
#
# The cause is one apostrophe. BATCH26's block carries the comment
# `# pair 1 - lauki, replicating batch 25's finding inside this batch`, and `[^']+` has no
# notion of a comment - it matches across newlines, so the span from that apostrophe to the
# next quote runs over the literals and the queries disappear. query_sets.py as a whole
# holds 609 single-quote characters, an ODD number, and fifteen lines with an odd count,
# every one of them ordinary prose.
#
# WHAT THAT MEANT FOR THIS CHECK SPECIFICALLY, and it is the part worth reading twice. The
# control guard asks whether every set carries a query measured to return candidates. Its
# BATCH26 entry had become eight fragments of a comment, none of which is a proven query -
# so BATCH26 should have been reported as MISSING ITS CONTROL, loudly, for hours. It was
# not, because the fragments it did find happened to include the set's own name and enough
# text to satisfy the other tests. The check passed on a file it could not read. That is
# `a-filter-that-excludes-its-own-target-reports-clean` exactly: the extraction could not
# see the thing it was checking for, and the empty-ish result read as a clean one.
#
# So the sets are read from the TREE with `ast`, which knows what a comment is. The set
# name and its queries come from the same assignment node, so they cannot drift apart. A
# file that will not parse RAISES, which is deliberate: a truncated list is the dangerous
# shape, because every caller then reports a confident answer about a file it only partly
# read. See tools/ai_accuracy/qstrings.py for the one home of this extraction.


def _sets() -> dict[str, list[str]]:
    """Name -> the query strings in that set, read from the parsed tree."""
    tree = ast.parse(QUERY_SETS.read_text(encoding="utf-8"), filename=str(QUERY_SETS))
    out: dict[str, list[str]] = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or not isinstance(node.value, ast.List):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and (
                    target.id.endswith("_QUERIES") or target.id == "QUERIES"):
                out[target.id] = [e.value for e in node.value.elts
                                  if isinstance(e, ast.Constant) and isinstance(e.value, str)]
    return out


class EveryQuerySetCarriesAControlTests(unittest.TestCase):
    def test_every_query_set_carries_a_query_proven_to_return_candidates(self):
        sets = _sets()
        self.assertGreater(len(sets), 15, f"only {len(sets)} query sets parsed; the "
                                          f"pattern may have stopped matching")
        missing = {name: EXEMPT_SETS.get(name) for name, qs in sets.items()
                   if not (set(qs) & set(PROVEN_QUERIES))}
        unexplained = {n: r for n, r in missing.items() if n not in EXEMPT_SETS}
        self.assertEqual(
            unexplained, {},
            f"these query sets carry no query that has been MEASURED to return "
            f"candidates, so a zero from any of them means nothing: {sorted(unexplained)}. "
            f"Add a proven query, or declare the set as exempt with a reason - because a "
            f"set with no control can only ever produce 'nothing found', which is the "
            f"shape of a finding that turned out to be FALSE four times in this corpus")

    def test_every_exemption_is_still_needed(self):
        """The other direction, because an exemption that outlives its reason is a hole
        with a comment on it. Twelve sets are exempt today; if a batch is re-run with a
        control, or a set is deleted, this goes red rather than leaving a stale
        exemption behind."""
        sets = _sets()
        stale = sorted(n for n in EXEMPT_SETS if n not in sets
                       or (set(sets[n]) & set(PROVEN_QUERIES)))
        self.assertEqual(
            stale, [],
            f"these sets are declared exempt but no longer need to be: {stale}. Remove "
            f"the exemption, or put the reason back in the query set - a stale exemption "
            f"is a way of letting a control-less set keep passing.")

    def test_a_proven_query_is_actually_used_by_some_set(self):
        used = {q for qs in _sets().values() for q in qs}
        unused = sorted(set(PROVEN_QUERIES) - used)
        self.assertEqual(
            unused, [],
            f"these are declared PROVEN but appear in no query set, so they are not "
            f"controls for anything: {unused}. A control list that has drifted from the "
            f"queries it is meant to vouch for is the two-copies shape again - the same "
            f"fault as argparse's choices and the sets registry.")

    def test_the_proven_list_is_not_empty(self):
        self.assertTrue(
            PROVEN_QUERIES,
            "no query is declared proven, so this module would pass every set vacuously. "
            "If no control has ever been measured, that is a finding, not a pass.")

    def test_the_extraction_can_see_a_set_whose_comment_owns_an_apostrophe(self):
        """THE ENFORCEMENT. A fix with no test that can fail is a note, and this file was
        the note: 57d8f0c's message said in prose that this guard "is green by luck" and
        named it as not fixed. Prose does not stop the next reader trusting it. A test does.

        Built deliberately: a query set whose comment carries a single apostrophe, with the
        set's real queries either side of it. The old `r"'([^']+)'"` extraction returns
        comment fragments and MISSES the queries; this extraction must return them.

        The second half is the half that matters. The old extraction did not fail this
        module loudly - BATCH26 has been carrying eight fragments of a comment for hours and
        the guard reported ok - because the fragments it did find satisfied the other tests.
        So the test also requires that a set with NO proven query in it is still reported,
        which is the failure the fix is actually preventing.
        """
        import tempfile
        body = [
            "CONTROL_QUERIES = [",
            "    'filetype:bitmap the control',",
            "    # batch 25's finding replicated here",
            '    \'filetype:bitmap "a dish"\',',
            "]",
            "BARE_QUERIES = [",
            '    \'filetype:bitmap "no control in this set"\',',
            "]",
        ]
        tmp = Path(tempfile.mkdtemp()) / "qs.py"
        tmp.write_text("\n".join(body) + "\n", encoding="utf-8")
        original = QUERY_SETS
        try:
            globals()["QUERY_SETS"] = tmp
            got = _sets()
            self.assertEqual(
                sorted(got.get("CONTROL_QUERIES", [])),
                sorted(["filetype:bitmap the control", 'filetype:bitmap "a dish"']),
                f"the tree extraction lost a query because a comment owned an apostrophe: "
                f"{got.get('CONTROL_QUERIES')}. That is the exact failure that made "
                f"BATCH26_QUERIES report eight comment fragments instead of eight queries.")
            self.assertEqual(
                got.get("BARE_QUERIES"), ['filetype:bitmap "no control in this set"'],
                f"a set with no control was not read at all: {got}. A check that cannot "
                f"see the class it is hunting reports clean, which is the whole fault.")
            # And the check this module exists to make, run against the same constructed file.
            unexplained = {n for n, qs in got.items() if not (set(qs) & set(PROVEN_QUERIES))}
            self.assertIn(
                "BARE_QUERIES", unexplained,
                "a set carrying no proven query was not reported as missing one. This is the "
                "whole point of the module and it is the thing the old extraction could not "
                "see.")
        finally:
            globals()["QUERY_SETS"] = original

    def test_every_declared_set_is_actually_read(self):
        """The extraction must not quietly return fewer sets than the file declares - the
        shape of a truncated list is the dangerous one, because every caller then reports a
        confident answer about a file it only partly read."""
        sets = _sets()
        self.assertGreaterEqual(
            len(sets), 30,
            f"only {len(sets)} query sets were read from the tree; query_sets.py declares "
            f"more. A short list here is a check that cannot see the rest of the file.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
