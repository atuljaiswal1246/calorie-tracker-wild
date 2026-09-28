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

_SET = re.compile(r"^([A-Z][A-Z0-9_]*_QUERIES|QUERIES)\s*=\s*\[", re.M)
_QUERY = re.compile(r"'([^']+)'")


def _sets() -> dict[str, list[str]]:
    """Name -> the query strings in that set, parsed from the source rather than
    imported, so a set with a syntax error cannot make this file skip it silently."""
    out: dict[str, list[str]] = {}
    src = QUERY_SETS.read_text(encoding="utf-8")
    for m in _SET.finditer(src):
        start = m.end()
        end = src.find("]", start)
        out[m.group(1)] = _QUERY.findall(src[start:end])
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
