#!/usr/bin/env python3
"""Collect openly licensed Indian meal photos for the accuracy harness.

The M1 bar is 20 measured real Indian meals. Those photos are MY job to source,
not the owner's. Wikimedia Commons publishes the licence, the author and the
source URL for every file, so anything there can be used with attribution.

What counts as a usable photo for this harness:
  * home-cooked Indian food, ON a plate or in a bowl
  * shot from above / near-above, so a 2D scan can read it
  * openly licensed (CC0, CC BY, CC BY-SA, PD) - never non-free, never a
    personal snapshot of a person

Rules this script enforces rather than trusts:
  * every accepted file gets URL, author, licence, licence URL and SHA-256
    written to the manifest. A photo without a record is not accepted.
  * images are stored as scaled copies (default 1000px wide) so the repo stays
    small; the hash recorded is of the file we actually store.
  * anything whose licence cannot be read is skipped, not guessed at.

    python3 tools/ai_accuracy/fetch_commons.py --limit 5 --batch 1
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import time
import urllib.parse
import urllib.error
import urllib.request

# this file lives at <repo>/tools/ai_accuracy/fetch_commons.py
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PHOTO_DIR = os.path.join(ROOT, "tools", "ai_accuracy", "photos")
MANIFEST = os.path.join(ROOT, "tools", "ai_accuracy", "photos.json")
API = "https://commons.wikimedia.org/w/api.php"
UA = "CalMattersAccuracyHarness/1.0 (openly licensed test fixture collection)"

# Overhead-friendly subjects: a plate or bowl a camera can look straight into.
QUERIES = [
    'filetype:bitmap "Vegetarian Thali"',
    'filetype:bitmap thali overhead',
    'filetype:bitmap "dal makhani"',
    'filetype:bitmap "palak paneer"',
    'filetype:bitmap "chana masala"',
    'filetype:bitmap biryani plate',
    'filetype:bitmap "aloo gobi"',
    'filetype:bitmap "rajma" bowl',
    'filetype:bitmap "chapati" plate',
    'filetype:bitmap "paneer tikka"',
    'filetype:bitmap "masala dosa"',
    'filetype:bitmap "vegetable curry" bowl',
    'filetype:bitmap "dal tadka"',
    'filetype:bitmap "matar paneer"',
]

# A batch-1 lesson: multi-dish thalis are abundant but almost useless here. With
# six or seven bowls in frame I cannot label each dish truthfully, and a
# reference truth I cannot defend poisons the whole measurement. A single katori
# of one dish is both defensible AND closer to what a user actually scans
# (one dish, one log). So the corpus is biased deliberately towards one-dish
# overhead shots.
SINGLE_QUERIES = [
    'filetype:bitmap "dal makhani" bowl',
    'filetype:bitmap "rajma" bowl',
    'filetype:bitmap "chole bhature"',
    'filetype:bitmap "kadhi pakora"',
    'filetype:bitmap "sambar" bowl',
    'filetype:bitmap "rasam" bowl',
    'filetype:bitmap "palak paneer" bowl',
    'filetype:bitmap "matar paneer" bowl',
    'filetype:bitmap "baingan bharta"',
    'filetype:bitmap "lauki ki sabzi"',
    'filetype:bitmap "poha" plate',
    'filetype:bitmap "upma" plate',
    'filetype:bitmap "idli" plate',
    'filetype:bitmap "dosa" plate',
    'filetype:bitmap "curd" bowl',
    'filetype:bitmap "pickle" bowl',
]

# Batch 2: dishes batch 1 does NOT already hold, so the corpus keeps widening
# instead of deepening on whatever the search happens to return most of.
BATCH2_QUERIES = [
    'filetype:bitmap "bhindi masala"',
    'filetype:bitmap "baingan bharta" bowl',
    'filetype:bitmap "lauki" curry',
    'filetype:bitmap "matar paneer"',
    'filetype:bitmap "paneer bhurji"',
    'filetype:bitmap "khichdi"',
    'filetype:bitmap "pulao" plate',
    'filetype:bitmap "jeera rice"',
    'filetype:bitmap "plain rice" bowl',
    'filetype:bitmap "dal fry"',
    'filetype:bitmap "moong dal"',
    'filetype:bitmap "masoor dal" bowl',
    'filetype:bitmap "chana dal" bowl',
    'filetype:bitmap "aloo paratha"',
    'filetype:bitmap "besan chilla"',
    'filetype:bitmap "paneer paratha"',
    'filetype:bitmap "egg curry"',
    'filetype:bitmap "chicken curry" bowl',
    'filetype:bitmap "raita" bowl',
    'filetype:bitmap "bhindi fry"',
]

OK_LICENCE = re.compile(r"\b(CC0|Public domain|CC BY(?:-SA)?\s*\d|Public domain|CC BY 2\.0|CC BY 3\.0|CC BY-SA 2\.0)", re.I)
BAD_LICENCE = re.compile(r"(non-?free|fair use|copyright(ed)?\s+by|all rights reserved)", re.I)


def api(params: dict) -> dict:
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    last = None
    for attempt in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=60).read())
        except urllib.error.HTTPError as exc:
            if exc.code != 429:
                raise
            last = exc
            wait = 8 * (attempt + 1)          # back off; Commons 429s on bursts
            print(f"    429 - backing off {wait}s")
            time.sleep(wait)
    raise last or RuntimeError("rate limited")


def clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text or "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


# Batch 3: dishes batches 1-2 do NOT hold, and regions batch 1-2 under-covered.
# Batch 1-2 leaned North/Northwest (thali, dal makhani, kadhi, chole) and one
# Bengali dish. The stated user eats what their region eats, so a corpus that is
# only "North Indian" would flatter the score for half the country.
BATCH3_QUERIES = [
    'filetype:bitmap "masala dosa"',
    'filetype:bitmap "idli sambar"',
    'filetype:bitmap "uttapam"',
    'filetype:bitmap "medu vada"',
    'filetype:bitmap "bisi bele bathu"',
    'filetype:bitmap "masoor dal" bowl',
    'filetype:bitmap "chana dal" bowl',
    'filetype:bitmap "dal tadka"',
    'filetype:bitmap "tarka dal"',
    'filetype:bitmap "egg curry" bowl',
    'filetype:bitmap "butter chicken" bowl',
    'filetype:bitmap "chicken tikka masala"',
    'filetype:bitmap "rogan josh"',
    'filetype:bitmap "gobi curry"',
    'filetype:bitmap "shahi paneer"',
    'filetype:bitmap "kadai paneer"',
    'filetype:bitmap "palak kofta"',
    'filetype:bitmap "malai kofta"',
    'filetype:bitmap "dhokla"',
    'filetype:bitmap "khandvi"',
    'filetype:bitmap "thepla" plate',
    'filetype:bitmap "khichdi"',
    'filetype:bitmap "halwa" bowl',
    'filetype:bitmap "gulab jamun"',
    'filetype:bitmap "payasam"',
]

def candidates(limit_per_query: int = 8, queries=None) -> list[dict]:
    seen, out = set(), []
    for q in (queries or QUERIES):
        try:
            data = api({
                "action": "query", "format": "json", "generator": "search",
                "gsrsearch": q, "gsrnamespace": "6", "gsrlimit": str(limit_per_query),
                "prop": "imageinfo",
                "iiprop": "url|size|mime|extmetadata|sha1",
                "iiurlwidth": "1000",
            })
        except Exception as exc:                      # noqa: BLE001
            print(f"  ! search failed for {q!r}: {exc}")
            continue
        time.sleep(1.5)          # Commons rate-limits bursts with HTTP 429
        for page in (data.get("query", {}).get("pages", {}) or {}).values():
            title = page.get("title", "")
            if title in seen:
                continue
            info = (page.get("imageinfo") or [{}])[0]
            if not info:
                continue
            meta = info.get("extmetadata", {}) or {}

            def m(key: str) -> str:
                return clean((meta.get(key) or {}).get("value", ""))

            licence = m("LicenseShortName")
            author = m("Artist")
            lic_url = m("LicenseUrl")
            desc = m("ImageDescription")

            if not licence or BAD_LICENCE.search(licence) or not OK_LICENCE.search(licence):
                continue                      # unreadable or not open: skip, never guess
            if not author:
                continue
            if info.get("mime") not in ("image/jpeg", "image/png"):
                continue
            if (info.get("width") or 0) < 800:
                continue
            seen.add(title)
            out.append({
                "title": title,
                "url": info.get("thumburl") or info.get("url"),
                "description_url": info.get("descriptionurl"),
                "commons_sha1": info.get("sha1"),
                "width": info.get("width"), "height": info.get("height"),
                "author": author, "licence": licence, "licence_url": lic_url,
                "description": desc, "query": q,
            })
    return out


def download(cand: dict) -> dict | None:
    os.makedirs(PHOTO_DIR, exist_ok=True)
    name = re.sub(r"[^a-z0-9]+", "_", cand["title"].lower().replace("file:", "")).strip("_")
    name = name[:60] + ".jpg"
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
            "stored_px": f"{cand['width']}x{cand['height']}"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=5, help="photos to add in this batch")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--set", choices=["mixed", "single", "batch2", "batch3"], default="mixed")
    args = ap.parse_args()

    print("searching Wikimedia Commons ...")
    sets = {"single": SINGLE_QUERIES, "batch2": BATCH2_QUERIES, "batch3": BATCH3_QUERIES}
    cands = candidates(queries=sets.get(args.set, QUERIES))
    print(f"openly licensed candidates: {len(cands)}")
    if args.dry_run:
        for c in cands[:25]:
            print(f"  {c['title'][:56]:<56} {c['licence']:<16} {c['author'][:28]}")
        return 0

    existing = []
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as fh:
            existing = json.load(fh).get("photos", [])

    added = 0
    for cand in cands:
        if added >= args.limit:
            break
        if any(p["file"] == cand["title"] for p in existing):
            continue
        got = download(cand)
        if not got:
            continue
        got["reviewed"] = False     # a human (me) must LOOK at it before it counts
        existing.append(got)
        added += 1
        print(f"  + {got['file']}")
        print(f"      {got['licence']} | {got['author'][:44]}")
        print(f"      sha256 {got['sha256'][:32]}...  {got['bytes'] // 1024} KB")

    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump({
            "_note": "Every photo here is openly licensed and attributed. "
                     "'reviewed': false means the image has been fetched but NOT "
                     "yet looked at - an unseen photo is not accepted into the "
                     "accuracy set.",
            "photos": existing,
        }, fh, indent=2)
    print(f"\nadded {added} this batch; manifest now holds {len(existing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
