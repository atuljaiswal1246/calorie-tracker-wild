#!/usr/bin/env python3
"""Prove the photograph-distinctness guard BITES, in a scratch tree, red by name.

A guard that has only ever been green is a comment. Each breach below mutates one
thing in a throwaway copy of the repo layout and asserts the named test goes red.

  python3 tools/ai_accuracy/prove_the_photograph_guard_bites.py

Breach E is the one that matters. A re-encoded copy of a photograph has DIFFERENT
BYTES and the SAME PICTURE, so it defeats a sha256 check completely and inflates the
class count this card reports without changing a single byte-hash. Breach E builds
exactly that — photo A re-saved at a low JPEG quality and pasted over photo B — so
the dHash check is proven to be doing work that the cheap check cannot. Without E,
the perceptual test is unproven and might be a slower restatement of sha256.

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
TEST = "tools/ai_accuracy/test_the_corpus_photographs_are_distinct.py"
CASES = "tools/ai_accuracy/cases.json"
# The scratch tree needs the test, the corpus, and fetch_commons (imported for the
# dHash definition) plus the images the corpus points at.
COPIED = (TEST, CASES, "tools/ai_accuracy/fetch_commons.py")


def _scratch() -> Path:
    root = Path(tempfile.mkdtemp(prefix="photograph-bite-"))
    for rel in COPIED:
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / rel, dst)
    for rel in _all_images():
        dst = root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / rel, dst)
    return root


def _all_images() -> list[str]:
    return [c["image"] for c in
            json.loads((REPO / CASES).read_text(encoding="utf-8"))["cases"]]


def _run(root: Path) -> tuple[int, str]:
    proc = subprocess.run([sys.executable, TEST], cwd=root, capture_output=True,
                          text=True, timeout=600)
    return proc.returncode, proc.stdout + proc.stderr


def _delete_an_image(root: Path) -> None:
    (root / _all_images()[0]).unlink()


def _zero_an_image(root: Path) -> None:
    (root / _all_images()[0]).write_bytes(b"")


def _garbage_an_image(root: Path) -> None:
    """Exists, non-empty, and is not a picture — which is exactly what a truncated
    download or a text file saved with a .jpg name looks like to a file listing."""
    (root / _all_images()[0]).write_bytes(b"404 Not Found\n" * 200)


def _point_two_cases_at_one_image(root: Path) -> None:
    p = root / CASES
    data = json.loads(p.read_text(encoding="utf-8"))
    data["cases"][1]["image"] = data["cases"][0]["image"]
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _re_encode_one_photo_over_another(root: Path) -> None:
    """The duplicate that actually happens: different bytes, same picture.

    This is what makes the corpus quietly worse - a re-encoded copy of a dish the
    corpus already holds is a new case for an old class, and no byte-hash in the
    world will see it.
    """
    from PIL import Image
    a, b = _all_images()[0], _all_images()[1]
    with Image.open(root / a) as im:
        im.convert("RGB").save(root / b, format="JPEG", quality=8)
    assert (root / a).read_bytes() != (root / b).read_bytes(), \
        "the re-encode did not change the bytes, so this breach proves nothing"


BREACHES = [
    # A and B used to name test_every_case_image_exists_and_is_not_empty, which was a
    # duplicate of test/corpus_photos_present_test.dart and has been deleted. They now
    # name the check that replaced it, and they are still two distinct mutations rather
    # than one: a file that is ABSENT and a file that is PRESENT BUT EMPTY are
    # different failures, and dhash returns None for both, so the surviving check
    # catches each for its own reason.
    ("A. a case's photograph is deleted",
     "test_every_case_image_is_a_picture_and_not_a_zero_byte_file",
     _delete_an_image),
    ("B. a case's photograph is truncated to zero bytes",
     "test_every_case_image_is_a_picture_and_not_a_zero_byte_file",
     _zero_an_image),
    ("C. a case's photograph is replaced with something that is not a picture",
     "test_every_case_image_is_a_picture_and_not_a_zero_byte_file", _garbage_an_image),
    ("D. two cases point at the same file", "test_no_two_cases_are_byte_identical",
     _point_two_cases_at_one_image),
    ("E. one photograph is re-encoded over another: same picture, different bytes",
     "test_no_two_cases_are_perceptually_the_same_photograph", _re_encode_one_photo_over_another),
]


def main() -> int:
    base = _scratch()
    rc, out = _run(base)
    if rc != 0:
        print("BASELINE IS RED - the guard is failing on the real corpus, so no breach "
              "below means anything:")
        print(out[-2500:])
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
        print(f"         must red: {named}  ->  rc={rc}, named in output: "
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
