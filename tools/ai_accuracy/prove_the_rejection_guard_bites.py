#!/usr/bin/env python3
"""Prove the rejection-record guard BITES, in a scratch tree, red by name.

  python3 tools/ai_accuracy/prove_the_rejection_guard_bites.py

Breach D is the one that matters, and it is the real defect rather than a proxy for it:
it restores the original destructive write — `json.dump({"_note":..., "photos": ...})`,
rebuilt from two keys — and asserts the round-trip test catches a sentinel key being
dropped. Every other check in this module is about the manifest's contents; that one is
about the WRITER, which is where the loss actually came from. A guard that only inspects
the file it is protecting cannot notice the next writer that will destroy it again.

Exits non-zero if ANY breach fails to turn the guard red.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TEST = "tools/ai_accuracy/test_the_rejection_record_survives.py"
PHOTOS = "tools/ai_accuracy/photos.json"
LEDGER = "notes/FREE_TIER_ACCOUNTING.md"
COPIED = (TEST, PHOTOS, LEDGER, "tools/ai_accuracy/fetch_commons.py",
          "tools/ai_accuracy/photo_store.py",
          "tools/ai_accuracy.py", "tools/ai_accuracy/cases.json")


def _scratch() -> Path:
    root = Path(tempfile.mkdtemp(prefix="rejection-bite-"))
    for rel in COPIED:
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / rel, dst)
    return root


def _run(root: Path) -> tuple[int, str]:
    p = subprocess.run([sys.executable, TEST], cwd=root, capture_output=True,
                       text=True, timeout=300)
    return p.returncode, p.stdout + p.stderr


def _load(root: Path) -> dict:
    return json.loads((root / PHOTOS).read_text(encoding="utf-8"))


def _save(root: Path, m: dict) -> None:
    (root / PHOTOS).write_text(json.dumps(m, indent=2), encoding="utf-8")


def _drop_the_top_level_key(root: Path) -> None:
    m = _load(root)
    m.pop("rejected", None)
    _save(root, m)


def _empty_the_top_level_key(root: Path) -> None:
    m = _load(root)
    m["rejected"] = []
    _save(root, m)


def _strip_a_reason(root: Path) -> None:
    m = _load(root)
    m["rejected"][0].pop("rejected_because", None)
    _save(root, m)


def _shrink_the_on_record_total(root: Path) -> None:
    """Below the 60 the ledger publishes - the shape of the loss as it first appeared,
    when the tree could account for 36 and the ledger claimed 78."""
    m = _load(root)
    m["rejected"] = m["rejected"][:5]
    _save(root, m)


def _restore_the_destructive_write(root: Path) -> None:
    """The real defect, reinstated verbatim: the fetch path rebuilds photos.json from
    only `_note` and `photos`, so a key it did not create cannot survive a fetch."""
    # photo_store.py, NOT fetch_commons.py: the photo store was cut out into its own
    # module on 2026-09-28 and the body this breach reinstates now lives there. A breach
    # that edits a file the function has left is a breach that asserts on a string in
    # the wrong place, and the assertion error reads like a broken breach rather than a
    # mis-targeted one - the same trap B13 in the limits guard documents.
    p = root / "tools" / "ai_accuracy" / "photo_store.py"
    src = p.read_text(encoding="utf-8")
    marker = "    with open(MANIFEST, \"w\", encoding=\"utf-8\") as fh:\n        json.dump(manifest, fh, indent=2)"
    assert marker in src, "save_manifest's body changed; update this breach"
    p.write_text(src.replace(marker, "    with open(MANIFEST, \"w\", encoding=\"utf-8\") as fh:\n"
                                  "        json.dump({\"_note\": manifest.get(\"_note\"), "
                                  "\"photos\": manifest.get(\"photos\", [])}, fh, indent=2)", 1),
                 encoding="utf-8")


def _quiet_the_note(root: Path) -> None:
    p = root / LEDGER
    t = p.read_text(encoding="utf-8")
    assert "not inventing a reason" in t
    p.write_text(t.replace("not inventing a reason", "fully explained elsewhere", 1),
                 encoding="utf-8")


BREACHES = [
    ("A. the top-level `rejected` key is gone again",
     "test_the_top_level_rejection_array_exists_and_every_record_has_a_reason",
     _drop_the_top_level_key),
    ("B. the top-level `rejected` array is emptied",
     "test_the_top_level_rejection_array_exists_and_every_record_has_a_reason",
     _empty_the_top_level_key),
    ("C. a rejection record loses its reason",
     "test_the_top_level_rejection_array_exists_and_every_record_has_a_reason",
     _strip_a_reason),
    ("D. the on-record total falls under the 60 the ledger publishes",
     "test_the_on_record_rejection_count_has_not_shrunk", _shrink_the_on_record_total),
    ("E. the destructive two-key write is reinstated in the fetcher",
     "test_the_fetch_write_path_round_trips_a_key_it_did_not_create",
     _restore_the_destructive_write),
    ("F. the note stops admitting the 18 are untraceable",
     "test_the_ledger_reconciliation_still_matches_the_artefact", _quiet_the_note),
]


def main() -> int:
    base = _scratch()
    rc, out = _run(base)
    if rc != 0:
        print("BASELINE IS RED - the guard fails on the real artefacts, so no breach "
              "below means anything:")
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
