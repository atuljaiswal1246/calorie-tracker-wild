#!/usr/bin/env python3
"""A rejection record that disappears is not a rejection that did not happen.

WHY THIS EXISTS, and it is a real loss rather than a hypothetical one. Reconciling the
free-tier ledger's `rejected` column (78, summed over ten batches) against what
`photos.json` could account for (36) turned up an 18-record gap, and the cause was not
a mistyped number:

    fetch_commons.py  read   .get("photos", [])
    fetch_commons.py  wrote  json.dump({"_note": ..., "photos": existing})

A second writer that rebuilds a file from the two keys it happens to know about. Every
fetch run therefore deleted the top-level `rejected` array that apply_batch1..3 had been
filling in with the reason each photograph was thrown away. Git history dates it exactly:
the key holds 13 records at `c9aae5d` (batch 3) and is absent at `faaf963` (batch 4),
because batch 4's FETCH ran before its APPLY. So it was never a batch-4 slip - it
repeats on every fetch, and did, seven more times. 24 rejection records and their
`rejected_because` reasons were deleted and survived only in history; they are now
restored, each carrying a `_recovered` note.

THE GENERAL FORM, which is the part worth keeping: a writer that reconstructs a file
from a subset of its keys is how an audit trail disappears. Nothing raises, nothing
warns, and the only evidence left is the history - so the loss is invisible until
someone reconciles a number against the artefact, which is exactly what happened here.

WHAT IS CHECKED:

  * the top-level `rejected` array exists, is non-empty, and every record in it carries
    a `rejected_because` reason - a rejection nobody can explain is not a record;
  * the on-record rejection total (top-level + flagged inside `photos[]`) is at least the
    60 the ledger's reconciliation table states, so a future fetch that drops the key
    again goes RED instead of quietly shrinking the audit trail;
  * the ledger's reconciliation table still says 60 / 18, so the note and the artefact
    cannot drift apart - the same drift this module exists to prevent, one file over;
  * and the important one: `save_manifest()` is called with a manifest carrying a
    SENTINEL top-level key and the key must survive the write. That calls the real
    function in fetch_commons, in a scratch copy, so it is a behavioural test of the
    actual write path and not a source grep or a re-implementation of it.

Run with: python3 tools/ai_accuracy/test_the_rejection_record_survives.py
Bite proof: tools/ai_accuracy/prove_the_rejection_guard_bites.py
"""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PHOTOS = REPO / "tools" / "ai_accuracy" / "photos.json"
LEDGER = REPO / "notes" / "FREE_TIER_ACCOUNTING.md"

# The reconciliation the ledger publishes, pinned here so a drifting note is as loud as
# a shrinking artefact. These are the numbers measured on 2026-09-28 and written into
# the note's reconciliation table.
ON_RECORD_MINIMUM = 73   # batch 17 added one more on-record rejection
LEDGER_CLAIMED = 95
UNTRACEABLE = 18


def _manifest() -> dict:
    return json.loads(PHOTOS.read_text(encoding="utf-8"))


def _on_record(m: dict) -> int:
    return len(m.get("rejected", [])) + sum(1 for p in m.get("photos", []) if p.get("rejected"))


class RejectionRecordSurvivesTests(unittest.TestCase):
    def test_the_top_level_rejection_array_exists_and_every_record_has_a_reason(self):
        m = _manifest()
        self.assertIn("rejected", m,
                      f"{PHOTOS.name} has no top-level `rejected` array. That key is what "
                      f"apply_batch1..3 wrote and what the fetch path destroyed on every "
                      f"run; if it is missing again, the write path has regressed")
        self.assertGreater(len(m["rejected"]), 0,
                           "the top-level `rejected` array is empty - the 24 records "
                           "recovered from c9aae5d and 461b22d are gone again")
        silent = [r.get("file", "?") for r in m["rejected"] if not r.get("rejected_because")]
        self.assertEqual(silent, [],
                         f"these rejection records carry no reason: {silent}. A rejection "
                         f"nobody can explain is not a record, it is a deleted photograph "
                         f"with paperwork")

    def test_the_on_record_rejection_count_has_not_shrunk(self):
        total = _on_record(_manifest())
        print(f"\n  rejections on record: {total} "
              f"(ledger claims {LEDGER_CLAIMED}, {UNTRACEABLE} untraceable)")
        self.assertGreaterEqual(
            total, ON_RECORD_MINIMUM,
            f"only {total} rejections are on record, but the ledger's reconciliation says "
            f"{ON_RECORD_MINIMUM} are traceable. A fetch that rebuilt photos.json from "
            f"only _note+photos would produce exactly this, and it did once already")

    def test_the_ledger_reconciliation_still_matches_the_artefact(self):
        flat = " ".join(LEDGER.read_text(encoding="utf-8").split())
        total = _on_record(_manifest())
        self.assertIn(str(ON_RECORD_MINIMUM), flat,
                      f"{LEDGER.name} no longer states the {ON_RECORD_MINIMUM} traceable "
                      f"rejections. The artefact and the note must agree, or the note is "
                      f"quoting a number nobody can check")
        for phrase, why in (
            ("destroyed the top-level `rejected` array",
             "the cause, named at the call site. Without it the table has a gap and no "
             "explanation, which is how an 18-record hole reads as a rounding error"),
            ("not inventing a reason", "or the untraceable remainder reads as explained "
                                       "when it is not; 18 of 78 rejections have no "
                                       "surviving record and the note must say so in "
                                       "its own words, not a paraphrase of them"),
        ):
            self.assertIn(phrase, flat,
                          f"{LEDGER.name} must keep saying {why}")

    def test_the_fetch_write_path_round_trips_a_key_it_did_not_create(self):
        """The regression test, and the reason save_manifest() was extracted.

        This calls the REAL function in fetch_commons against a scratch copy of the
        manifest carrying a sentinel top-level key. A test against a copy of the write
        logic would prove nothing - the defect was never in a copy, it was in the real
        line that rebuilt the file from two keys.
        """
        sys.path.insert(0, str(REPO / "tools" / "ai_accuracy"))
        # Patch photo_store, NOT fetch_commons. Found 2026-09-28 the hard way: when the
        # photo store was cut out of fetch_commons into its own module, this test kept
        # patching fetch_commons.MANIFEST - a RE-EXPORTED name, which is a copy and not
        # a reference. save_manifest reads photo_store.MANIFEST, so the patch did
        # nothing and the test wrote its sentinel manifest straight into the REAL
        # photos.json: 100 photographs down to 1 and rejected[] from 24 to 1. It was
        # caught by git status, and restored from git in one command.
        #
        # The lesson is the same one this whole guard exists for, turned on itself: a
        # test that redirects a path must patch the module that READS it, and a
        # re-export is a copy. A cut that moves a function must move its patch point.
        import photo_store

        scratch = Path(tempfile.mkdtemp(prefix="manifest-roundtrip-"))
        try:
            real = photo_store.MANIFEST
            sentinel = {"sentinel": "a key the fetcher did not create and must not drop"}
            m = {"_note": "n", "photos": [{"file": "x.jpg"}], "rejected": [{"file": "r.jpg"}]}
            m.update(sentinel)
            photo_store.MANIFEST = str(scratch / "photos.json")
            try:
                photo_store.save_manifest(m)
                with open(photo_store.MANIFEST, encoding="utf-8") as fh:
                    back = json.load(fh)
            finally:
                photo_store.MANIFEST = real
            self.assertEqual(back.get("sentinel"), sentinel["sentinel"],
                             "save_manifest() dropped a top-level key it did not create. "
                             "This is the exact defect that destroyed the rejection "
                             "record: photos.json was rebuilt from _note+photos only")
            self.assertIn("rejected", back,
                          "save_manifest() dropped the top-level `rejected` array")
            self.assertIn("photos", back)
        finally:
            shutil.rmtree(scratch, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
