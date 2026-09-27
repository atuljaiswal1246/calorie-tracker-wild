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


# BATCH 5 — one query per DISH CLASS that cases.json does not already contain.
#
# The trap, three times now: 8 of 16 candidates were bhindi, 8 of 18 were masala
# dosa, and 4x chole. Each batch fixed it by hand and it came back, because a
# dish-shaped query returns dish-shaped results. So this set is built from the
# corpus's own gap list rather than from what is easy to find, and it takes ONE
# query per missing class: egg, biryani, khichdi, fish curry, sarson da saag,
# aloo gobi, kofta, chicken curry. Eight queries, eight different classes, so a
# duplicate cannot dominate this batch even if every query returns its own dish
# twice.
#
# Deliberately NOT queried: anything mapping to dal, chole, paneer or sambar in
# tools/ai_accuracy.py DISH_CLASS. A tenth photo of dal does not move a 13-class
# corpus to 20, it only makes the median better. That is the trap wearing a
# productive hat.
BATCH5_QUERIES = [
    'filetype:bitmap "omelette" plate',
    'filetype:bitmap biryani plate',
    'filetype:bitmap khichdi bowl',
    'filetype:bitmap "fish curry" bowl',
    'filetype:bitmap "sarson da saag"',
    'filetype:bitmap "aloo gobi"',
    'filetype:bitmap kofta curry',
    'filetype:bitmap "chicken curry" bowl',
]


# BATCH 6 — the last two classes the 20-meal bar needs, and the two biggest gaps
# in what a real user photographs.
#
# 18 of 20 after batch 5. The corpus has exactly ONE non-vegetarian case class
# (biryani) while a home-cooked Indian kitchen eats egg and chicken most weeks,
# and the product promise is a photo of whatever is on the plate. So the two
# classes I want most are the two the corpus is worst at, which happens to be
# exactly what the bar still needs.
#
# Targets, one query each, none of them mapping to an existing class:
#   egg bhurji / omelette (egg)   methi sabzi (fenugreek)   chicken curry
#   cabbage poriyal               kheer (a thali dessert)
#   veg pulao                     bhindi do pyaz
# "chicken curry" and "fish curry" already appear in the COVERAGE list, as items
# inside a thali. Coverage is not a class: a thali case is scored as that thali,
# so a standalone chicken curry the model must name is a different judgement.

BATCH6_QUERIES = [
    'filetype:bitmap "egg bhurji"',
    'filetype:bitmap omelette indian',
    'filetype:bitmap "methi sabzi"',
    'filetype:bitmap "cabbage poriyal"',
    'filetype:bitmap "veg pulao" plate',
    'filetype:bitmap kheer bowl',
]


# BATCH 7 — break the SKEW, not the count.
#
# The bar is met at 21 classes, but 13 of 30 cases are four classes: dal x5,
# chole x4, paneer x2, sambar x2. That is 43% of the corpus, and it means a
# median over it is substantially a median over dal and chole. The next
# milestone is not a bigger number, it is a flatter distribution - and widening
# the corpus is the one piece of M1 work that costs nothing at all.
#
# So: five classes the corpus has none of, all of them things a home kitchen in
# India actually eats. None of them is dal, chole, paneer or sambar, because
# adding a sixth dal makes the median look better and the product no better.
#   chicken curry, fish curry, methi sabzi, raita, gajar halwa
# bhindi do pyaz is in the list on purpose even though it lands in the existing
# bhindi class: it dilutes nothing on the class axis but it does add the dal-
# free, chole-free meal a real evening has.

BATCH7_QUERIES = [
    'filetype:bitmap "chicken curry" home plate',
    'filetype:bitmap "fish curry" bowl indian',
    'filetype:bitmap "methi sabzi"',
    'filetype:bitmap "boondi raita" bowl',
    'filetype:bitmap "gajar halwa"',
    'filetype:bitmap "bhindi do pyaz"',
]


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

# Batch 4: DELIBERATELY NON-BREAKFAST. Batch 3 accepted five South-Indian
# breakfast photos and the corpus score moved for reasons that had nothing to do
# with the app - which is the whole reason the corpus rule exists. Every query
# here is a lunch/dinner dish, plus the region coverage batches 1-3 missed
# (Kashmiri, Awadhi, Bengali, Gujarati, Goan, Hyderabadi, Kerala, Punjabi).
BATCH4_QUERIES = [
    'filetype:bitmap "chana masala"',
    'filetype:bitmap "chole" curry',
    'filetype:bitmap "rajma" curry',
    'filetype:bitmap "butter chicken"',
    'filetype:bitmap "chicken curry" bowl',
    'filetype:bitmap "rogan josh"',
    'filetype:bitmap "egg curry"',
    'filetype:bitmap "shahi paneer"',
    'filetype:bitmap "paneer butter masala"',
    'filetype:bitmap "gobi curry"',
    'filetype:bitmap "dal tadka"',
    'filetype:bitmap "tarka dal"',
    'filetype:bitmap "eggs bhurji"',
    'filetype:bitmap "methi sabzi"',
    'filetype:bitmap "tindora"',
    'filetype:bitmap "kashmiri dum aloo"',
    'filetype:bitmap "awadhi kebab"',
    'filetype:bitmap "bengali fish curry"',
    'filetype:bitmap "gujarati dal"',
    'filetype:bitmap "goan pork"',
    'filetype:bitmap "hyderabadi biryani"',
    'filetype:bitmap "kerala fish curry"',
    'filetype:bitmap "dhaba dal"',
    'filetype:bitmap "punjabi chole"',
    'filetype:bitmap "khichdi"',
    'filetype:bitmap "poha"',
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


# ------------------------------------------------------------- DUPLICATE GUARD
# The trap is not only in the SEARCH, it is in the DOWNLOAD: the fish-curry query
# returned five near-identical "Fish curry rice Thali" files by one uploader, and
# the omelette query returned two restaurant menu photographs. Five near-copies of
# one dish is a corpus that reads as 5 and measures as 1, and a median over it is
# a median over a photographer's habit.
#
# So the fetcher now MEASURES similarity instead of trusting titles: a 64-bit
# difference hash per photo, and a photo within NEAR_DUP_DISTANCE of one already
# accepted (this batch OR the existing corpus) is rejected with a printed reason.
# --max-per-query and --per-author caps stop one query, or one prolific uploader,
# from dominating a batch. Review still happens: this is a floor, not a judge.

NEAR_DUP_DISTANCE = 8          # Hamming distance on 64 bits; ~0 same, 8 very close


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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=5, help="photos to add in this batch")
    ap.add_argument("--max-per-query", type=int, default=2,
                    help="at most this many accepted photos from ONE query. A "
                         "dish-shaped query returns the same dish; without a cap "
                         "one query can be the whole batch.")
    ap.add_argument("--per-author", type=int, default=2,
                    help="at most this many accepted photos from ONE uploader in "
                         "this batch. One prolific photographer's habit is not a "
                         "sample of Indian home cooking.")
    ap.add_argument("--no-near-dup", action="store_true",
                    help="escape hatch for checking, not for accepting.")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--set", choices=["mixed", "single", "batch2", "batch3", "batch4", "batch5", "batch6", "batch7"], default="mixed")
    args = ap.parse_args()

    print("searching Wikimedia Commons ...")
    sets = {"single": SINGLE_QUERIES, "batch2": BATCH2_QUERIES, "batch3": BATCH3_QUERIES, "batch4": BATCH4_QUERIES, "batch5": BATCH5_QUERIES, "batch6": BATCH6_QUERIES, "batch7": BATCH7_QUERIES}
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

    # Known photos, for the near-duplicate floor. Older records predate the hash.
    known = [(p.get("file"), p.get("dhash")) for p in existing if p.get("dhash")]
    for p in existing:
        if p.get("file") and not p.get("dhash"):
            h = dhash(os.path.join(ROOT, p["file"]))
            if h is not None:
                p["dhash"] = h
                known.append((p["file"], h))

    added = 0
    per_query: dict[str, int] = {}
    per_author: dict[str, int] = {}
    for cand in cands:
        if added >= args.limit:
            break
        # Dedupe on TITLE. This compared a photo's file path against a
        # candidate's title, so it never matched anything and a second fetch of
        # the same URL re-downloaded over a file the manifest already pointed at.
        if any(p.get("title") == cand["title"] for p in existing):
            print(f"  - skip (already have it): {cand['title'][:56]}")
            continue
        if per_query.get(cand["query"], 0) >= args.max_per_query:
            print(f"  - skip (query cap): {cand['title'][:56]}")
            continue
        if per_author.get(cand["author"], 0) >= args.per_author:
            print(f"  - skip (author cap): {cand['title'][:56]} "
                  f"by {cand['author'][:28]}")
            continue
        got = download(cand)
        if not got:
            continue
        if not args.no_near_dup and got.get("dhash") is not None:
            for other_file, other_hash in known:
                if hamming(got["dhash"], other_hash) <= NEAR_DUP_DISTANCE:
                    print(f"  - skip (near-duplicate of {os.path.basename(other_file)}, "
                          f"hamming "
                          f"{hamming(got['dhash'], other_hash)}): {cand['title'][:40]}")
                    # Only delete a file no record depends on. Found 2026-09-28:
                    # the download path is a digest of the URL, so re-fetching a
                    # photo we already had wrote the SAME path, and the
                    # near-duplicate branch then removed the file the manifest
                    # pointed at. Three accepted photos vanished and three cases
                    # were left pointing at nothing. Deleting is the dangerous
                    # half of a duplicate check, so it now asks first.
                    if other_file != got["file"] and not any(
                            p.get("file") == got["file"] for p in existing):
                        os.remove(os.path.join(ROOT, got["file"]))
                    got = None
                    break
        if not got:
            continue
        got["reviewed"] = False     # a human (me) must LOOK at it before it counts
        existing.append(got)
        known.append((got["file"], got["dhash"]))
        per_query[cand["query"]] = per_query.get(cand["query"], 0) + 1
        per_author[cand["author"]] = per_author.get(cand["author"], 0) + 1
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
