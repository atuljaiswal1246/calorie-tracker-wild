#!/usr/bin/env python3
"""The photo store: getting an openly licensed photograph onto disk, and recording it.

WHY THIS FILE EXISTS, and the reason is the 800-line rule rather than taste.
`fetch_commons.py` reached 786 lines and the next corpus batch's queries go into it, so
the batch that continued the work would have been the batch that broke the rule. The cut
is the work, and it should be its own commit rather than arriving alongside new queries.

THE CONCERN IS ONE COHERENT THING: everything about a photograph as a FILE rather than
as a search result. Searching is Commons and the API; storing is a directory, a filename
convention, a perceptual hash and the manifest file. Those are different reasons to
change, and they were in one file.

WHAT MOVED HERE, and nothing else:
  - PHOTO_DIR and MANIFEST, the two paths everything else is relative to
  - NEAR_DUP_DISTANCE, dhash(), hamming()  - the perceptual-duplicate definition
  - download()  - the filename convention and the provenance it records
  - save_manifest()  - and the rule it exists to enforce, which is the important one

WHAT STAYED IN fetch_commons.py: the API client, the query sets, the licence filters,
`candidates()`, `main()` and the rate-limit accounting. It re-imports the names below,
so `from fetch_commons import dhash, hamming, NEAR_DUP_DISTANCE` keeps working and no
existing test or batch script had to change. A cut that forces every caller to be
rewritten is not a cut, it is a relocation with a bill attached.

THE RULE save_manifest() ENFORCES, carried over intact because it is the whole reason
that function exists: **a writer mutates the keys it owns and writes the object it was
given; it never reconstructs the file from a subset of it.** That function used to be an
inline `json.dump({"_note": ..., "photos": existing})` and it silently deleted the
top-level `rejected` array on every fetch run - 24 records and their reasons, gone from
the tree, recoverable only from git history. Nothing errored. A second writer that
rebuilds a file from the keys it happens to know is how an audit trail disappears.

ONE DEFINITION OF "NEAR-DUPLICATE" IS THE POINT OF dhash LIVING HERE. Every guard that
judges a photograph imports these three names, so the threshold has one home. A second
copy of NEAR_DUP_DISTANCE is a second definition, and two definitions drift until the
guard and the fetcher disagree about what a duplicate is.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PHOTO_DIR = os.path.join(ROOT, "tools", "ai_accuracy", "photos")
MANIFEST = os.path.join(ROOT, "tools", "ai_accuracy", "photos.json")
UA = "CalMattersAccuracyHarness/1.0 (openly licensed test fixture collection)"

# Hamming distance on 64 bits; ~0 same, 8 very close. ONE definition - every guard that
# judges a photograph imports this name from here.
NEAR_DUP_DISTANCE = 8


def dhash(path: str) -> int | None:
    try:
        from PIL import Image
        with Image.open(path) as im:
            im = im.convert("L").resize((9, 8), Image.LANCZOS)
            px = list(im.getdata())
    except Exception:                                  # noqa: BLE001
        return None
    bits = 0
    for row in range(8):
        for col in range(8):
            bits = (bits << 1) | (1 if px[row * 9 + col] > px[row * 9 + col + 1] else 0)
    return bits


def hamming(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


_FRAME_TOKEN = re.compile(r"^(?:dsc|dscn|img|pict|photo|frame|shot)?[\s_\-]?\d{3,5}$", re.I)
_SPLIT = re.compile(r"[\s_\-]+")


def frame_stem(title: str) -> str:
    """A Commons title reduced to a frame-stripped, lowercased stem.

    WHY, measured 2026-09-28. Batch 28 downloaded a photograph already rejected in batch
    26, and that commit claimed the near-duplicate guard "compares against ACCEPTED
    photographs and a rejected one was never in the corpus to compare against". THAT WAS
    FALSE: both entries carry a dhash, the guard's `known` list takes every photo that has
    one, and the hamming distance is 20 against a threshold of 8 - so it compared them and
    correctly decided they were not the same picture.

    What they are, read in full rather than truncated: "...DSC 0028.jpg" and
    "...DSC 0029.jpg" - two consecutive frames of one meal, one photographer, one sitting.
    Different SHA-256, different URL, and 20 bits of a 64-bit difference hash apart because
    the camera moved. Measured for contrast: re-encoding the SAME file at quality 95, 70,
    60 and at 50-60% scale moves the hash by 0 or 1. So "same picture twice" and "next
    frame of the same scene" are far apart, and NEAR_DUP_DISTANCE = 8 sits correctly
    between them.

    WHICH IS WHY THE THRESHOLD IS NOT RAISED. Tuning a guard's number until a case stops
    being reported is the same fault as reshaping a record to match a disproved instrument,
    and it would start rejecting photographs of genuinely different dishes. Two titles that
    differ only by a frame counter are one series whatever the pixels say, and that is
    decidable from the title with no threshold at all.

    IT STRIPS EXACTLY ONE TRAILING TOKEN, and a test found that rather than me. The first
    version matched a run of digits at the end, which is not idempotent -
    "CameraZOOM-20150614100720279" lost four digits, then four more. Three to five digits
    and not two, because "Paneer Tikka 28" and "Paneer Tikka 29" are two dishes.

    It lives here, beside NEAR_DUP_DISTANCE, because a second copy of a definition is the
    two-copies fault - the same one argparse's `choices` and the query-set registry were.
    """
    name = (title or "").strip()
    if name.lower().startswith("file:"):
        name = name[5:]
    name = re.sub(r"\.(jpg|jpeg|png|tiff?|webp)$", "", name, flags=re.I)
    parts = [p for p in _SPLIT.split(name.strip()) if p]
    if len(parts) > 1 and _FRAME_TOKEN.match(parts[-1]):
        parts = parts[:-1]
    return " ".join(parts).strip(" _-,").lower()


def save_manifest(manifest: dict) -> None:
    """Write photos.json back WHOLE - every top-level key it did not create included.

    This used to be an inline `json.dump({"_note": ..., "photos": existing})` at the
    end of main(), and that is precisely how the rejection record was destroyed: a
    literal dict rebuilt from the two keys the fetcher happened to know about, so
    every fetch run deleted the top-level `rejected` array that apply_batch1..3 had
    filled in. 24 records and their reasons were gone from the tree and survived only
    in git history. Nothing errored and nothing warned.

    So the rule this function exists to enforce: a writer mutates the keys it owns and
    writes the object it was given. It never reconstructs the file from a subset of it.
    Extracted as a function (rather than left inline) so that
    test_the_rejection_record_survives.py can call the REAL write path with a sentinel
    key and prove it survives - a test against a copy of this logic would prove
    nothing, which is the same defect one level down.
    """
    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)


def download(cand: dict) -> dict | None:
    os.makedirs(PHOTO_DIR, exist_ok=True)
    name = re.sub(r"[^a-z0-9]+", "_", cand["title"].lower().replace("file:", "")).strip("_")
    # A short digest of the source URL, so two different Commons files whose
    # titles normalise to the same slug cannot overwrite each other. Found on
    # 2026-09-28: three downloads of the same-named platter silently shared one
    # path, and the duplicate-cleanup then deleted the file the accepted record
    # pointed at. Filenames must be a function of the source, not just the title.
    tag = hashlib.sha256(cand["url"].encode()).hexdigest()[:8]
    name = f"{name[:52]}_{tag}.jpg"
    path = os.path.join(PHOTO_DIR, name)
    try:
        req = urllib.request.Request(cand["url"], headers={"User-Agent": UA})
        blob = urllib.request.urlopen(req, timeout=120).read()
    except Exception as exc:                      # noqa: BLE001
        print(f"  ! download failed {cand['title']}: {exc}")
        return None
    if len(blob) < 8000:
        print(f"  ! suspiciously small, skipped: {cand['title']}")
        return None
    with open(path, "wb") as fh:
        fh.write(blob)
    return {**cand, "file": os.path.relpath(path, ROOT),
            "bytes": len(blob),
            "sha256": hashlib.sha256(blob).hexdigest(),
            "dhash": dhash(path),
            "stored_px": f"{cand['width']}x{cand['height']}"}
