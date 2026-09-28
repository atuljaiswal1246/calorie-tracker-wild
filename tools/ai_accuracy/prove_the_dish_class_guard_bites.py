#!/usr/bin/env python3
"""Prove the dish-class guard BITES, in a scratch tree, red by name.

  python3 tools/ai_accuracy/prove_the_dish_class_guard_bites.py

The breach that matters is F, and it is the real defect rather than a proxy: it deletes
one of the seven IDENTITY declarations, which puts that class back on the fallback, and
asserts the "every class is declared" check catches it. Without F this guard could pass
on a mapping where a third of the class count is spelling again — which is exactly the
state it was found in.

Exits non-zero if ANY breach fails to turn the guard red.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TEST = "tools/ai_accuracy/test_the_dish_classes_are_distinct.py"
NOTE = "notes/M1_BAR_STATUS.md"
PRODUCER = "tools/ai_accuracy.py"
COPIED = (TEST, NOTE, PRODUCER, "tools/ai_accuracy/cases.json")


def _scratch() -> Path:
    root = Path(tempfile.mkdtemp(prefix="dishclass-bite-"))
    for rel in COPIED:
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / rel, dst)
    # the guard imports ai_accuracy, which imports its own package files
    for extra in REPO.glob("tools/ai_accuracy/*.py"):
        rel = extra.relative_to(REPO)
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(extra, dst)
    return root


def _run(root: Path) -> tuple[int, str]:
    p = subprocess.run([sys.executable, TEST], cwd=root, capture_output=True,
                       text=True, timeout=300)
    return p.returncode, p.stdout + p.stderr


def _patch(root: Path, rel: str, old: str, new: str) -> None:
    p = root / rel
    t = p.read_text(encoding="utf-8")
    assert old in t, f"breach text not found in {rel}: {old!r}"
    p.write_text(t.replace(old, new, 1), encoding="utf-8")


def _drop_an_identity_declaration(root: Path) -> None:
    """The real defect: `bhindi` put back on the fallback, so a class the corpus uses
    is no longer a DECLARED key and the count is spelling again."""
    _patch(root, PRODUCER, '"bhindi": "bhindi",\n    ', "")


def _blank_a_declared_reason(root: Path) -> None:
    """A pair whose reason is gone, rewritten as a WHOLE entry.

    The first attempt at this breach replaced only the opening line of a wrapped
    string, which orphaned the continuation lines and broke the module's syntax: the
    guard went red with a traceback rather than a named failure. `rc=1` plus
    `named: False` is a breach that proves nothing, so this one now swaps the whole
    tuple for a placeholder, leaving the file valid and forcing the guard to catch the
    empty reason by name.
    """
    _patch(root, TEST,
           '("dal", "kadhi"): {\n'
           '        "why": "Kadhi is a yoghurt-and-besgram gram curry, dal is a plain lentil "\n'
           '               "curry. They are different preparations with different ingredients, and "\n'
           '               "a photo of one is not evidence about the other\'s calories.",\n'
           '        "would_fold_to": "dal",\n'
           '    },',
           '("dal", "kadhi"): {\n'
           '        "why": "n/a",\n'
           '        "would_fold_to": "dal",\n'
           '    },')


def _shrink_the_adjacency_list(root: Path) -> None:
    _patch(root, TEST, '("bhindi", "lauki"): {', '("bhindi", "lauki_disabled"): {')


def _drop_the_folded_figure_from_the_note(root: Path) -> None:
    _patch(root, NOTE, "22 if a reviewer folds all five", "22 if you squint")


def _put_a_stale_class_count_back(root: Path) -> None:
    """The exact defect found on 2026-09-28: the note said 27 in its summary and 25 in
    its analysis, three paragraphs apart, and corpus_independence_test.dart passed 12 of
    12 throughout, because it re-derives the counts from cases.json and cannot notice
    that the prose disagrees with the data it describes."""
    _patch(root, NOTE, "The corpus is 27 classes and barely leans",
           "The corpus is 25 classes and barely leans")


def _remove_the_adjacency_words_from_the_note(root: Path) -> None:
    """Both figures left on the page, neither explained — the state the guard exists to
    prevent, and the harder half to catch by eye than a wrong digit."""
    _patch(root, NOTE, "Five pairs are\n  **adjacent**", "Five pairs are\n  **close**")


BREACHES = [
    ("A. a class key is no longer declared, so it falls back to spelling",
     "test_every_class_the_corpus_uses_is_a_declared_dish_class_key",
     _drop_an_identity_declaration),
    ("B. a declared adjacent pair loses its reason",
     "test_every_declared_pair_says_why_it_is_kept_separate", _blank_a_declared_reason),
    ("C. the adjacency declaration is trimmed below the count it claims",
     "test_the_adjacency_declaration_is_not_empty", _shrink_the_adjacency_list),
    ("D. the note drops the fold-the-pairs figure",
     "test_the_folded_count_still_clears_the_bar_and_the_note_says_so",
     _drop_the_folded_figure_from_the_note),
    ("E. the note's adjacency question is renamed so neither figure is explained",
     "test_the_folded_count_still_clears_the_bar_and_the_note_says_so",
     _remove_the_adjacency_words_from_the_note),
    ("F. a stale class count is put back into the note's prose",
     "test_the_note_never_carries_a_class_count_other_than_the_two_published_ones",
     _put_a_stale_class_count_back),
]


def main() -> int:
    base = _scratch()
    rc, out = _run(base)
    if rc != 0:
        print("BASELINE IS RED - the guard fails on the real corpus, so no breach below "
              "means anything:")
        print(out[-2000:])
        return 2
    print("BASELINE green in the scratch tree (unbreached), so every breach below is "
          "attributable to the mutation and nothing else.\n")

    failures = 0
    for label, named, mutate in BREACHES:
        root = _scratch()
        mutate(root)
        rc, out = _run(root)
        ok = rc != 0 and named.split(".")[-1] in out
        print(f"  {'BITES ' if ok else 'BLIND '} {label}")
        print(f"         must red: {named}  ->  rc={rc}, named: "
              f"{named.split('.')[-1] in out}")
        if not ok:
            failures += 1
            print("         >>> THE GUARD DID NOT CATCH THIS")
        shutil.rmtree(root, ignore_errors=True)

    shutil.rmtree(base, ignore_errors=True)
    print(f"\n{len(BREACHES) - failures} of {len(BREACHES)} breaches turned the guard red "
          f"by name.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
