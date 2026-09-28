#!/usr/bin/env python3
"""Prove the free-tier ledger guard BITES, in a scratch tree, red by name.

A guard that has only ever been green is a comment. This breaches the artefacts one
at a time in a throwaway copy of the repo layout and asserts the named test goes
red, so "6 of 6 pass" is evidence rather than decoration.

  python3 tools/ai_accuracy/prove_the_ledger_guard_bites.py

Exits non-zero if ANY breach fails to turn the guard red - which is the failure that
matters, because it means the guard is blind in a place nobody suspected.

THE POISON IS PROVEN SEPARATELY, and it is the one worth reading. The network-poisoned
producer test could pass for the wrong reason: a command that fails for an unrelated
reason (a bad path, a missing import) looks identical to a command that was genuinely
blocked. So breach H installs a producer that DOES try to reach the network and
confirms the guard catches THAT, which is the only shape of evidence that says the
poison is doing the blocking.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TEST = "tools/ai_accuracy/test_free_tier_ledger.py"
LEDGER = "notes/FREE_TIER_ACCOUNTING.md"
CASES = "tools/ai_accuracy/cases.json"
PRODUCER = "tools/ai_accuracy.py"

COPIED = (TEST, LEDGER, CASES, "tools/ai_accuracy/photos.json", PRODUCER)


def _scratch() -> Path:
    root = Path(tempfile.mkdtemp(prefix="ledger-bite-"))
    for rel in COPIED:
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / rel, dst)
    return root


def _run(root: Path) -> tuple[int, str]:
    proc = subprocess.run([sys.executable, TEST], cwd=root, capture_output=True,
                          text=True, timeout=180)
    return proc.returncode, proc.stdout + proc.stderr


def _bypass(root: Path, rel: str, old: str, new: str) -> None:
    p = root / rel
    text = p.read_text(encoding="utf-8")
    assert old in text, f"the breach text is not in {rel}: {old!r}"
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def _drop_a_case(root: Path) -> None:
    p = root / CASES
    data = json.loads(p.read_text(encoding="utf-8"))
    data["cases"].pop()
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


# (label, test that must go red, the mutation)
BREACHES: list[tuple[str, str, object]] = [
    ("A. a batch row is deleted from the ledger",
     "test_the_ledger_exists_and_has_a_row_per_batch",
     lambda root: _bypass(root, LEDGER, "| 5 | 09-28 | 8 |", "| 99 | 09-28 | 8 |")),

    ("B. a row claims a model call",
     "test_every_ledger_row_says_zero_model_calls_and_zero_money",
     lambda root: _bypass(root, LEDGER, "| 0 (in-repo originals) |", "| 2 |")),

    ("C. a row claims money",
     "test_every_ledger_row_says_zero_model_calls_and_zero_money",
     lambda root: _bypass(root, LEDGER, "**$0.00**", "**$0.50**")),

    ("D. the accepted total drifts above the corpus",
     "test_the_ledger_totals_match_the_corpus",
     lambda root: _bypass(root, LEDGER, "| 94 | 7 | 4 |", "| 94 | 9 | 4 |")),

    ("E. a batch is credited with more judgements than it fetched",
     "test_no_batch_accepted_more_than_it_fetched",
     lambda root: _bypass(root, LEDGER, "| 6 | 21 | 2 | 3 |", "| 6 | 1 | 2 | 3 |")),

    ("F. the honesty admission is tidied out of the file",
     "test_the_ledger_says_what_it_cannot_check",
     lambda root: _bypass(root, LEDGER, "cannot see money", "is fully verified here")),

    ("G. a case is deleted from the corpus, so the ledger outnumbers it",
     "test_the_ledger_totals_match_the_corpus",
     _drop_a_case),
]


def _poison_proof(root: Path) -> None:
    """Install a producer that genuinely tries to reach the network."""
    (root / PRODUCER).write_text(
        "import urllib.request\n"
        "urllib.request.urlopen('https://example.com', timeout=5)\n"
        "print('CORPUS: DISH CLASSES: CONCENTRATION:')\n", encoding="utf-8")


def main() -> int:
    baseline_root = _scratch()
    rc, out = _run(baseline_root)
    if rc != 0:
        print("BASELINE IS RED - the guard is failing on the real artefacts, so no "
              "breach below means anything:")
        print(out[-2500:])
        return 2
    n = len(re.findall(r"^Ran \d+ tests", out, re.M))
    print(f"BASELINE green in the scratch tree (unbreached), so every breach below is "
          f"attributable to the mutation and nothing else.\n")

    failures = 0
    for label, named_test, mutate in BREACHES:
        root = _scratch()
        mutate(root)
        rc, out = _run(root)
        red = rc != 0
        by_name = named_test.split(".")[-1] in out or named_test in out
        ok = red and by_name
        print(f"  {'BITES ' if ok else 'BLIND '} {label}")
        print(f"         must red: {named_test}  ->  rc={rc}, named in output: {by_name}")
        if not ok:
            failures += 1
            print("         >>> THE GUARD DID NOT CATCH THIS")
        shutil.rmtree(root, ignore_errors=True)

    # The poison, proven on its own.
    root = _scratch()
    _poison_proof(root)
    rc, out = _run(root)
    ok = rc != 0 and "network poisoned" in out
    print(f"  {'BITES ' if ok else 'BLIND '} H. the producer itself starts calling the "
          f"network")
    print(f"         a real urlopen under the same poisoned env -> rc={rc}")
    if not ok:
        failures += 1
        print("         >>> THE POISON IS NOT BLOCKING, so test_the_producer_runs_with_"
              "the_network_poisoned passes VACUOUSLY")
    shutil.rmtree(root, ignore_errors=True)
    shutil.rmtree(baseline_root, ignore_errors=True)

    print(f"\n{len(BREACHES) + 1 - failures} of {len(BREACHES) + 1} breaches turned the "
          f"guard red by name.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
