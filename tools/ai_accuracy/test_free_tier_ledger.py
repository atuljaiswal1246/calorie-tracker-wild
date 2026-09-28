"""The free-tier accounting is a LEDGER, and a ledger nobody checks is a document.

WHY THIS EXISTS, and the defect is one I wrote down myself. `notes/FREE_TIER_ACCOUNTING.md` carries
a per-batch table of queries, candidates, accepted, rejected, model calls and money - and its own
falsification section admits: *"It cannot see money, so the money column above is asserted by the
next person who runs a batch."* That is the same fault the whole limits guard exists to prevent: a
number that nobody can check is a claim wearing a table's clothes. So the table is now checked
against the artefacts, and every number in it is derived rather than remembered.

WHAT IS AND IS NOT CHECKED, stated up front because a guard that implies more than it does is
worse than no guard:

  * CHECKED - every per-batch accepted/rejected count in the ledger, against cases.json and
    photos.json. If a batch's row drifts from what the corpus actually contains, this goes red.
  * CHECKED - the ledger's totals, against len(cases). A batch invented in the table fails.
  * CHECKED - that `tools/ai_accuracy.py --corpus` runs with the network poisoned, because the
    ledger's central claim is "no model is called to label or accept a photograph". If that
    command ever needs the network, the claim is false and this fails by name.
  * NOT CHECKED - the money column itself. A dollar figure cannot be asserted from inside the
    repo; it is a statement about spend, and this test says so rather than pretending. What IS
    checkable is the thing that makes it zero, and that is the network-poisoned producer above.

Run with: python3 tools/ai_accuracy/test_free_tier_ledger.py
Guarded by: test/free_tier_ledger_test.dart, which runs this module and fails the
Flutter suite - the same pattern corpus_independence_test.dart uses for --corpus.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]   # the calorie_tracker root
LEDGER = REPO / "notes" / "FREE_TIER_ACCOUNTING.md"
CASES = REPO / "tools" / "ai_accuracy" / "cases.json"
PHOTOS = REPO / "tools" / "ai_accuracy" / "photos.json"
PRODUCER = "tools/ai_accuracy.py"

# The ledger row shape: | batch | date | queries | candidates | accepted | rejected | models | money |
_ROW = re.compile(
    r"^\|\s*(\d+)\s*\|\s*([\d-]+)\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([^|]*)\|\s*([^|]*)\|"
)


def _ledger_rows() -> list[dict]:
    text = LEDGER.read_text(encoding="utf-8")
    rows = []
    for line in text.splitlines():
        m = _ROW.match(line.strip())
        if not m:
            continue
        batch, date, queries, cands, acc, rej, models, money = m.groups()

        def _count(cell: str) -> int | None:
            """A cell may be an em dash, meaning the number was not recorded. Batches
            1-4 predate the fetch log, so their query and candidate counts are "—".
            That is honest and it is skipped here rather than read as 0, because a
            missing count and a zero count are different claims."""
            cell = cell.strip()
            return int(cell) if cell.isdigit() else None

        rows.append({
            "batch": int(batch), "date": date, "queries": _count(queries),
            "candidates": _count(cands),
            "accepted": int(acc), "rejected": int(rej),
            "models": models.strip(), "money": money.strip(),
        })
    return rows


class FreeTierLedgerTests(unittest.TestCase):
    def test_the_ledger_exists_and_has_a_row_per_batch(self):
        rows = _ledger_rows()
        self.assertGreaterEqual(len(rows), 10,
                                f"{LEDGER.name} must carry a row per batch; found {len(rows)}")
        batches = [r["batch"] for r in rows]
        self.assertEqual(batches, list(range(1, len(batches) + 1)),
                         f"the ledger's batches are not 1..n with no gap or repeat: {batches}")

    def test_every_ledger_row_says_zero_model_calls_and_zero_money(self):
        """The ledger's whole claim is that this work is free. If a row ever says
        otherwise, the claim is false and this fails BY NAME rather than the file
        quietly becoming a different document."""
        for r in _ledger_rows():
            with self.subTest(batch=r["batch"]):
                # The cell may carry a trailing reason - batch 1 reads
                # "0 (in-repo originals)" - so the CLAIM is the leading token.
                self.assertRegex(
                    r["models"], r"^0\b",
                    f"batch {r['batch']} claims {r['models']!r} model calls, but the "
                    f"ledger's central claim is that no model labels a photograph. "
                    f"Reconcile the row and the claim together")
                self.assertIn("0.00", r["money"],
                              f"batch {r['batch']} claims money {r['money']!r}; every other "
                              f"row is $0.00, so this row needs a reason in the file")

    def test_the_ledger_totals_match_the_corpus(self):
        """A hand-written accounting drifts. This is the check that stops it: the
        accepted column summed over every batch must equal the number of cases in
        cases.json, so a row cannot be invented, dropped or double-counted."""
        cases = json.loads(CASES.read_text())["cases"]
        total_accepted = sum(r["accepted"] for r in _ledger_rows())
        self.assertEqual(
            total_accepted, len(cases),
            f"the ledger accepts {total_accepted} photographs across all batches but "
            f"cases.json holds {len(cases)} cases, so the table and the corpus have "
            f"drifted apart. The corpus is the fact; fix the ledger, not the cases")

    def test_no_batch_accepted_more_than_it_fetched(self):
        """The only direction the arithmetic actually runs in.

        I first wrote this as "rejected >= accepted past batch 1", on the theory
        that the per-query and per-author caps make rejecting the majority the
        expected shape. It is false and it went RED on batch 8, which fetched 94
        candidates, accepted 7 and rejected 4 - the other 83 were fetched, never
        opened, and declared not-used. The lesson is the one this card keeps
        paying for: a rule that fails on real data was never a rule, it was a
        guess with an assert on it. The true invariant is the one that cannot be
        evaded by arithmetic - you cannot judge a photograph you did not fetch.
        """
        for r in _ledger_rows():
            if r["candidates"] is None:
                continue          # batch predates the fetch log; see _count() above
            with self.subTest(batch=r["batch"]):
                self.assertGreaterEqual(
                    r["candidates"], r["accepted"] + r["rejected"],
                    f"batch {r['batch']} fetched {r['candidates']} candidates but "
                    f"accepted {r['accepted']} and rejected {r['rejected']} - more was "
                    f"judged than was fetched, so the row cannot be true")

    def test_the_producer_runs_with_the_network_poisoned(self):
        """The falsifier the ledger itself names, executed rather than described.

        `--corpus` is a pure read of cases.json. If it ever needs the network it is
        reaching a model, and then "0 model calls" across every batch is a lie. The
        environment is poisoned so a network call raises instead of succeeding, which
        makes the check about the producer's own behaviour rather than about this
        machine's connectivity.
        """
        env = {
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": "/nonexistent-home-for-the-poison-check",
            "http_proxy": "http://127.0.0.1:9", "https_proxy": "http://127.0.0.1:9",
            "HTTP_PROXY": "http://127.0.0.1:9", "HTTPS_PROXY": "http://127.0.0.1:9",
            "no_proxy": "", "NO_PROXY": "",
            "CURL_CA_BUNDLE": "/nonexistent", "REQUESTS_CA_BUNDLE": "/nonexistent",
        }
        proc = subprocess.run([sys.executable, PRODUCER, "--corpus"],
                              cwd=REPO, env=env, capture_output=True, text=True, timeout=120)
        self.assertEqual(
            proc.returncode, 0,
            f"`{PRODUCER} --corpus` failed with the network poisoned (rc={proc.returncode}). "
            f"The ledger claims no batch calls a model, and this is the check that would "
            f"catch it if one did.\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")
        for marker in ("CORPUS:", "DISH CLASSES:", "CONCENTRATION:"):
            self.assertIn(marker, proc.stdout,
                          f"the producer no longer prints {marker!r}, so the ledger cannot be "
                          f"re-derived from it. Rewrite the ledger or the producer, not both.\n"
                          f"{proc.stdout}")

    def test_the_ledger_says_what_it_cannot_check(self):
        """A ledger that claims to check money it cannot check is the defect this
        test was written to remove. The admission has to stay in the file, so this
        fails if someone tidies the honesty out of it."""
        text = LEDGER.read_text(encoding="utf-8")
        flat = " ".join(text.split())
        with self.subTest():
            self.assertIn("cannot see money", flat,
                          f"{LEDGER.name} must keep stating that the money column is not "
                          f"checkable from inside the repo. That admission is the reason "
                          f"this test exists; deleting it would restore the defect")
            self.assertIn("LABOUR", text.upper(),
                          f"{LEDGER.name} must keep saying the labour is not zero, or the "
                          f"$0.00 column will be read as 'the work was free'")


    def test_every_dash_in_the_table_is_a_DECLARED_gap(self):
        """A dash in a column of numbers is a decision, and this makes it a written one.

        The other checks SKIP an em dash rather than reading it as 0, because a missing
        count and a zero count are different claims. That is right, and it had a hole in
        it: skipping means a dash can be ADDED without anybody deciding anything, so a
        column can rot from four blanks to seven with the guard green throughout. So the
        dashes are collected and matched against the paragraph that names them.

        Both directions are checked, and that is the part worth having:
          - adding a dash fails until it is declared, so a new gap cannot appear quietly;
          - removing a declaration fails too, so a gap that gets fixed cannot be quietly
            forgotten while the paragraph still claims it.

        And the rule underneath is that a dash is never back-filled from memory, which is
        the failure this whole file exists to prevent.
        """
        unmeasured = {(r["batch"], col) for r in _ledger_rows()
                      for col in ("queries", "candidates") if r[col] is None}
        self.assertTrue(
            unmeasured,
            "no unmeasured cells were found, so this check is passing on an empty answer. "
            "If every cell is genuinely measured now, delete this test WITH the "
            "declaration paragraph - do not leave it green on nothing.")

        flat = " ".join(LEDGER.read_text(encoding="utf-8").split())
        for col in ("queries", "candidates"):
            with self.subTest(column=col):
                found = {b for b, c in unmeasured if c == col}
                declared: set[int] = set()
                for m in re.finditer(r"`" + col + r"`\s*\|\s*([^|]+?)\s*\|", flat):
                    declared |= {int(n) for n in re.findall(r"\d+", m.group(1))}
                self.assertEqual(
                    found, declared,
                    f"the table has batches {sorted(found)} unmeasured in `{col}`, but "
                    f"the declaration paragraph names {sorted(declared)}. Every dash must "
                    f"be declared AND every declaration must still be needed - both "
                    f"directions, because a silently added dash and a quietly forgotten "
                    f"fix are the same defect.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
