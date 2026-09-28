#!/usr/bin/env python3
"""A batch that learned nothing must not look like a batch that found nothing.

WHY THIS EXISTS, and it is the repo's own rule caught in the act. `an-empty-result-is-
not-a-negative-finding` says an empty output is evidence only if you saw the command run.
On 2026-09-28 batch 13 printed `openly licensed candidates: 0` for ten queries that were
ALL HTTP 429 - rate-limited - including a query that had returned results two batches
earlier. `candidates()` caught the exception per query, printed one line, and continued,
so `main()` reported a zero with the same confidence as a real one.

That zero was about to be written into a case record as "Commons has no photograph of a
khakra, a mushroom masala or a french-bean sabzi" - a durable claim about three dishes,
derived from a fact about US: we were throttled. The control query is what proved it. A
known-good query returning nothing either would have meant the fetcher was broken, and
that is a different bug with a different fix.

SO THE MECHANISM IS: `SEARCH_FAILURES` records every query that was never asked, and
`main()` refuses to report a candidate count when any query failed - it prints what it
could not ask and exits 3, a code distinct from both success and the per-query caps.

WHAT IS CHECKED, with the fetcher's own `api` swapped for a stub, so no network is
touched and the outcomes are exact:

  * every query raising an HTTP 429 is recorded, and the batch is refused;
  * a query raising any OTHER error is also recorded - a silent swallow is the defect
    whatever the error is;
  * a run where every query succeeds and genuinely returns nothing is NOT refused,
    because that is a real zero and must still be reportable. This is the check that
    stops the fix from being its own bug: a guard that refuses every empty result would
    make the fetcher unusable and would hide exactly the finding it was built to keep.

Run with: python3 tools/ai_accuracy/test_a_throttled_fetch_is_not_a_zero.py
"""
from __future__ import annotations

import io
import sys
import unittest
import urllib.error
from contextlib import redirect_stdout
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "ai_accuracy"))
import fetch_commons as F  # noqa: E402

QUERIES = ["q one", "q two", "q three"]


def _stub_api(behaviour):
    """Swap fetch_commons.api for a stub. `behaviour` maps a query to either a result
    dict or an exception to raise. No network, so the outcomes are exact."""
    def fake(params):
        q = params.get("gsrsearch")
        outcome = behaviour(q)
        if isinstance(outcome, Exception):
            raise outcome
        return outcome
    return fake


def _pages(*titles):
    return {"query": {"pages": {t: {"title": t, "imageinfo": [
        {"url": "https://example.invalid/x", "descriptionurl": "https://example.invalid/d",
         "extmetadata": {"LicenseShortName": {"value": "CC BY-SA 4.0"},
                         "Artist": {"value": "A"}, "Credit": {"value": "C"}},
         "width": 100, "height": 100, "size": 1000, "sha1": "abc" * 10, "mime": "image/jpeg"}
    ]} for t in titles}}}


def _run(behaviour):
    real, F.api = F.api, _stub_api(behaviour)
    F.SEARCH_FAILURES.clear()
    buf = io.StringIO()
    try:
        with redirect_stdout(buf):
            out = F.candidates(limit_per_query=2, queries=QUERIES)
        return out, list(F.SEARCH_FAILURES), buf.getvalue()
    finally:
        F.api = real


class ThrottledFetchIsNotAZeroTests(unittest.TestCase):
    def test_every_429_is_recorded_as_a_query_that_was_never_asked(self):
        def behaviour(q):
            if q == "q two":
                return urllib.error.HTTPError("u", 429, "Too Many Requests", None, None)
            return _pages(f"{q} result")
        out, failures, printed = _run(behaviour)
        self.assertEqual([q for q, _ in failures], ["q two"],
                         f"the 429 on 'q two' was not recorded, so the batch looks like a "
                         f"real zero. failures={failures}")
        self.assertTrue(any("429" in e for _, e in failures),
                        f"the recorded failure does not say it was a 429: {failures}")
        self.assertIn("FAILED", printed,
                      "the failure must be visible in the output as well as recorded, or "
                      "the next reader sees a quiet batch")

    def test_a_non_429_error_is_also_recorded_rather_than_swallowed(self):
        def behaviour(q):
            if q == "q one":
                return urllib.error.HTTPError("u", 500, "Server Error", None, None)
            return _pages(f"{q} result")
        out, failures, printed = _run(behaviour)
        self.assertEqual([q for q, _ in failures], ["q one"],
                         f"a 500 was swallowed exactly like a 429: {failures}")
        self.assertIn("500", " ".join(e for _, e in failures))

    def test_a_genuine_zero_is_still_reportable(self):
        """The check that stops the fix from being its own bug. Every query succeeded and
        every one returned nothing - that is a real finding about the dishes, and a
        guard that refused it would make the fetcher unusable and would hide the very
        case batch 13 was supposed to be able to record."""
        out, failures, printed = _run(lambda q: _pages())
        self.assertEqual(failures, [],
                         f"a genuinely empty result set was recorded as a failure: {failures}")
        self.assertEqual(out, [])
        self.assertEqual(F.SEARCH_FAILURES, [])

    def test_main_refuses_to_report_a_count_when_a_query_was_never_asked(self):
        """The end-to-end shape: the batch must not print a candidate count at all."""
        import argparse
        real_api, real_argv = F.api, sys.argv
        F.api = _stub_api(lambda q: urllib.error.HTTPError("u", 429, "Too Many Requests",
                                                          None, None))
        sys.argv = ["fetch_commons.py", "--set", "batch13"]
        buf = io.StringIO()
        try:
            with redirect_stdout(buf):
                rc = F.main()
        finally:
            F.api, sys.argv = real_api, real_argv
        printed = buf.getvalue()
        self.assertEqual(rc, 3,
                         f"a fully throttled batch must exit 3 so no caller records it as a "
                         f"zero; got rc={rc}")
        self.assertNotIn("openly licensed candidates:", printed,
                         "the candidate count was printed even though every query failed - "
                         "that is the exact line batch 13 printed and the reason this check "
                         "exists")
        self.assertIn("LEARNED NOTHING", printed)
        self.assertIn("not asked", printed,
                      "the output must name the queries that were never asked, so a reader "
                      "can retry those rather than conclude the dishes have no photographs")

    def test_the_fetcher_still_reports_a_real_count_when_everything_works(self):
        real_api, real_argv = F.api, sys.argv
        F.api = _stub_api(lambda q: _pages(f"{q} hit"))
        sys.argv = ["fetch_commons.py", "--set", "batch13"]
        buf = io.StringIO()
        try:
            with redirect_stdout(buf):
                rc = F.main()
        finally:
            F.api, sys.argv = real_api, real_argv
        printed = buf.getvalue()
        self.assertNotEqual(rc, 3, "a working batch was refused")
        self.assertIn("openly licensed candidates:", printed,
                      "a working batch must still print its count, or the fix has broken the "
                      "fetcher")


if __name__ == "__main__":
    unittest.main(verbosity=2)
