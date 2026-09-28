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
# PHOTO_DIR, MANIFEST and UA now live in photo_store.py, which owns everything about a
# photograph as a FILE. They are imported below rather than defined here, because a
# second definition of a path is how a writer and a reader end up disagreeing about
# where the file is - and I wrote that lesson down an hour ago while fixing exactly
# that shape in save_manifest().
API = "https://commons.wikimedia.org/w/api.php"


# The photo store moved to photo_store.py (2026-09-28) when this file reached 786 lines
# and the next batch's queries would have pushed it over the 800-line rule. The concern
# is one coherent thing - a photograph as a FILE rather than as a search result - and it
# had its own reasons to change. These names are re-imported rather than left behind so
# that `from fetch_commons import dhash, hamming, NEAR_DUP_DISTANCE` keeps working: a cut
# that forces every caller to be rewritten is a relocation with a bill attached.
#
# NEAR_DUP_DISTANCE, dhash() and hamming() have exactly ONE home, which is the point. A
# second copy of that threshold is a second definition, and two definitions drift until
# the guard and the fetcher disagree about what a duplicate is.
from photo_store import (MANIFEST, NEAR_DUP_DISTANCE, PHOTO_DIR, UA,  # noqa: F401,E402
                         dhash, download, hamming, save_manifest)

# The query sets moved to query_sets.py (2026-09-28). This file reached 781 lines - 19
# under the 800-line rule - and every corpus batch adds to it, because a batch IS a query
# list with a record attached. Sixteen batches of query lists is one coherent concern and
# it is not this file's concern: this file is the API client, the licence filter, the
# per-query and per-author caps, and the rate-limit accounting. A query list is a DECISION
# about what to look for, and the reasoning for each one travels with it.
#
# The names are re-exported rather than reached into, so `--set <name>` keeps working and
# no caller changes - the same rule as the photo_store cut: a cut that forces every caller
# to be rewritten is a relocation with a bill attached.
from query_sets import (BATCH10_QUERIES, BATCH11_QUERIES, BATCH12_QUERIES,  # noqa: F401
                        BATCH13_QUERIES, BATCH14_QUERIES, BATCH15_QUERIES,
                        BATCH16_QUERIES, BATCH17_QUERIES, BATCH18_QUERIES, BATCH19_QUERIES, BATCH21_QUERIES, BATCH22_QUERIES, BATCH23_QUERIES, BATCH24_QUERIES, BATCH25_QUERIES, BATCH26_QUERIES, BATCH27_QUERIES, BATCH28_QUERIES,
                        BATCH2_QUERIES, BATCH3_QUERIES,
                        BATCH4_QUERIES, BATCH5_QUERIES, BATCH6_QUERIES,
                        BATCH7_QUERIES, BATCH8_QUERIES, BATCH9_QUERIES,
                        QUERIES, SINGLE_QUERIES)

OK_LICENCE = re.compile(r"\b(CC0|Public domain|CC BY(?:-SA)?\s*\d|Public domain|CC BY 2\.0|CC BY 3\.0|CC BY-SA 2\.0)", re.I)
BAD_LICENCE = re.compile(r"(non-?free|fair use|copyright(ed)?\s+by|all rights reserved)", re.I)


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



def category_exists(name: str) -> bool | None:
    """Does this Commons category actually exist? True, False, or None if unanswerable.

    WHY THIS EXISTS. Batch 19 used `incategory:"Indian sweets"` and
    `incategory:"Indian rice dishes"` - names I INVENTED - and got zero candidates, in
    exactly the shape a dish that does not exist would produce. Four batches in this
    corpus have now returned zero, and three of them were me: a 429, an over-constrained
    query, and a made-up category. An instrument whose name is wrong is indistinguishable
    from an empty world, so the name has to be checkable BEFORE it is used to conclude
    anything.

    Returns None rather than False when the API could not be asked, so a throttle is never
    recorded as "this category does not exist" - which would be the same mistake one
    level down.

    `Category:` is namespaced because Commons and Wikipedia share the API surface and
    only the former's categories are being asked about here.
    """
    try:
        data = api({"action": "query", "format": "json", "titles": f"Category:{name}"})
    except Exception as exc:                                  # noqa: BLE001
        print(f"  ! could not verify category {name!r}: {exc}")
        return None
    pages = data.get("query", {}).get("pages", {}) or {}
    for page in pages.values():
        if "missing" in page:
            return False
        if page.get("pageid"):
            return True
    return False



def clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", " ", text or "")
    return re.sub(r"\s+", " ", html.unescape(text)).strip()


SEARCH_FAILURES: list[tuple[str, str]] = []

# What each query ACTUALLY RETURNED, keyed by the query text: how many pages the search
# gave back before any filtering, how many survived into the candidate list, and the
# error if it never got to be asked. `pages` is None for a query that was not asked, and
# that is the whole point of keeping it distinct from 0.
#
# WHY THIS EXISTS, and it is a gap in the ACCOUNTING rather than in the corpus. The
# ledger's `candidates` column carries a dash for eight of twenty-four batches, and the
# declared reason was "unmeasured". It was not unknowable: the number was in hand at the
# moment the search returned, and it was printed and then discarded. So a reader of the
# ledger could not tell "this query found nothing" from "this query was never asked" -
# which is the same distinction SEARCH_FAILURES exists to protect, one level up, and it
# was the shape of all four false zeros in this corpus.
#
# `pages` is recorded BEFORE filtering, deliberately. `kept` counts candidates that
# survived the licence and duplicate filters, so it can be 0 on a perfectly healthy query
# whose results were all already in the corpus. Only `pages` answers the question the
# ledger is asking, which is whether the SEARCH found anything at all.
QUERY_OUTCOMES: dict[str, dict] = {}


def candidates(limit_per_query: int = 8, queries=None) -> list[dict]:
    # Queries that could not be SEARCHED AT ALL, as opposed to queries that were
    # searched and returned nothing. These are different facts about the world and the
    # difference is the whole point of this list.
    #
    # Found 2026-09-28, and it is the exact trap this repo already has a rule about: an
    # empty result is not a negative finding. Batch 13 printed "openly licensed
    # candidates: 0" for ten queries that were ALL HTTP 429 - rate-limited - including
    # a query that had returned results two batches earlier. The exception was caught
    # per-query, one line was printed, and the batch carried on, so a fact about US
    # (we were throttled) was about to be written into a case record as a fact about
    # the DISHES (Commons has no photograph of a khakra). The three classes would have
    # been declared permanently unfillable on the strength of a throttle.
    #
    # So the failures are counted, and main() refuses to report a batch as a zero when
    # any query never got to be asked.
    SEARCH_FAILURES.clear()
    QUERY_OUTCOMES.clear()
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
            # Recorded, not just printed. A query that was never asked is not a query
            # that found nothing, and the batch must not be able to say otherwise.
            SEARCH_FAILURES.append((q, f"{type(exc).__name__}: {exc}"))
            QUERY_OUTCOMES[q] = {"pages": None, "kept": 0, "error": f"{type(exc).__name__}"}
            print(f"  ! search FAILED for {q!r}: {exc}")
            continue
        time.sleep(1.5)          # Commons rate-limits bursts with HTTP 429
        _pages = (data.get("query", {}).get("pages", {}) or {})
        # HOW MANY PAGES THE SEARCH RETURNED, recorded before any filtering. This is the
        # number the ledger's `candidates` column has been carrying as a dash for eight
        # of twenty-four batches, and the dash was not because the number is unknowable -
        # it was because nobody wrote it down at the moment it was known. A query that
        # was asked and returned nothing left no trace whatsoever, so a zero and a query
        # that was never asked looked identical in the record, which is the same defect
        # as SEARCH_FAILURES itself, one level up.
        QUERY_OUTCOMES[q] = {"pages": len(_pages), "kept": 0, "error": None}
        for page in _pages.values():
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
            QUERY_OUTCOMES[q]["kept"] += 1
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


QUERY_RECORD = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "query_results.json")


def _write_query_record(batch: str, queries: list[str]) -> None:
    """Append what each query in this batch actually returned to query_results.json.

    APPEND, never overwrite: a record of what the search returned on the day is evidence
    about that day, and a later run of the same batch name is a DIFFERENT measurement. So
    each entry is keyed by batch AND carries its own timestamp, and re-running a batch
    adds a run rather than replacing the last one. Overwriting would make the file a
    statement about the most recent run, which is precisely the moving-window fault the
    /health reader was rebuilt to avoid - a fact read through whatever happened to be
    written last.

    Written even when the batch was throttled and main() is about to return 3. That is
    the run most worth recording: it is the one where a careless reader would see a count
    of 0 and write it up as a fact about three dishes.
    """
    run = {
        "recorded": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "queries": [{"query": q,
                     "pages": QUERY_OUTCOMES.get(q, {}).get("pages"),
                     "kept": QUERY_OUTCOMES.get(q, {}).get("kept"),
                     "error": QUERY_OUTCOMES.get(q, {}).get("error")}
                    for q in queries],
    }
    data = {"_what_this_is":
            "What each query in each batch ACTUALLY RETURNED, recorded at fetch time by "
            "fetch_commons.py. `pages` is the search's own hit count before any filtering, "
            "`kept` is what survived the licence and duplicate filters, and `pages` is null "
            "for a query that was never asked - which is a different fact from zero, and the "
            "distinction all four false zeros in this corpus turned on. Each batch holds a "
            "LIST of runs with timestamps, so a later run adds evidence rather than "
            "overwriting the measurement of an earlier day.",
            "runs": {}}
    if os.path.exists(QUERY_RECORD):
        try:
            with open(QUERY_RECORD, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, json.JSONDecodeError):
            pass                      # a corrupt record must not stop a fetch
    data.setdefault("runs", {}).setdefault(batch, []).append(run)
    tmp = QUERY_RECORD + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
    os.replace(tmp, QUERY_RECORD)      # atomic: never a half-written record
    zeros = sum(1 for r in run["queries"] if r["pages"] == 0)
    unasked = sum(1 for r in run["queries"] if r["pages"] is None)
    print(f"  recorded per-query results for {batch}: "
          f"{zeros} returned nothing, {unasked} were never asked "
          f"-> {os.path.basename(QUERY_RECORD)}")


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

    # ONE registry, and the CLI's choices are DERIVED from it. Found 2026-09-28 while
    # adding batch 17: `sets` and argparse's `choices` were two hand-maintained lists of
    # the same names, they had already drifted - batch 17 was in `sets` and not in
    # `choices`, so `--set batch17` was rejected by the tool that contained it. That is
    # the "the second implementation IS the defect" rule from
    # a-gate-must-read-what-the-reader-reads, and it is exactly the shape of the two
    # definitions drift this corpus has been fighting all day: a copy nobody chose. A new
    # query set is now reachable the moment it is added here, with nothing else to forget.
    sets = {"single": SINGLE_QUERIES, "batch2": BATCH2_QUERIES, "batch3": BATCH3_QUERIES,
            "batch4": BATCH4_QUERIES, "batch5": BATCH5_QUERIES, "batch6": BATCH6_QUERIES,
            "batch7": BATCH7_QUERIES, "batch8": BATCH8_QUERIES, "batch9": BATCH9_QUERIES,
            "batch10": BATCH10_QUERIES, "batch11": BATCH11_QUERIES,
            "batch12": BATCH12_QUERIES, "batch13": BATCH13_QUERIES,
            "batch14": BATCH14_QUERIES, "batch15": BATCH15_QUERIES,
            "batch16": BATCH16_QUERIES, "batch17": BATCH17_QUERIES,
            "batch18": BATCH18_QUERIES,
            "batch19": BATCH19_QUERIES,
            "batch21": BATCH21_QUERIES,
            "batch22": BATCH22_QUERIES,
            "batch23": BATCH23_QUERIES,
            "batch24": BATCH24_QUERIES,
            "batch25": BATCH25_QUERIES,
            "batch26": BATCH26_QUERIES,
            "batch27": BATCH27_QUERIES,
            "batch28": BATCH28_QUERIES}
    ap.add_argument("--set", choices=sorted(sets), default="mixed",
                    help="which query list to run. The choices are the keys of the "
                         "registry above, so a set is runnable as soon as it is added.")
    args = ap.parse_args()

    print("searching Wikimedia Commons ...")
    cands = candidates(queries=sets.get(args.set, QUERIES))
    _write_query_record(args.set, sets.get(args.set, QUERIES))
    if SEARCH_FAILURES:
        # Distinct exit code, and a message that cannot be skimmed past. A batch that
        # learned nothing must not look like a batch that found nothing, because the
        # second one gets written into a case record and the first one gets retried.
        throttled = sum(1 for _, e in SEARCH_FAILURES if "429" in e)
        print(f"\n!! {len(SEARCH_FAILURES)} of {len(sets.get(args.set, QUERIES))} queries "
              f"could not be searched at all ({throttled} of them HTTP 429 rate-limited).")
        print("!! THIS BATCH LEARNED NOTHING about the dishes. The candidate count below is "
              "NOT evidence that these foods lack photographs - it is evidence that we were "
              "not allowed to ask. Retry later; do not record a zero from this run.")
        for q, e in SEARCH_FAILURES:
            print(f"     not asked: {q}  ({e})")
        return 3
    print(f"openly licensed candidates: {len(cands)}")
    if args.dry_run:
        for c in cands[:25]:
            print(f"  {c['title'][:56]:<56} {c['licence']:<16} {c['author'][:28]}")
        return 0

    # Load the WHOLE manifest, not just its photos. Found 2026-09-28 by reconciling
    # the ledger's rejected column (78) against what photos.json could account for
    # (36): this function used to read `.get("photos", [])` and then WRITE A FRESHLY
    # CONSTRUCTED DICT of `_note` + `photos`, so it silently destroyed the top-level
    # `rejected` array that apply_batch1..3 had been filling in with the reason each
    # photograph was thrown away. Git history shows the key present at c9aae5d (batch
    # 3, 13 records) and gone by faaf963 (batch 4, 0) - because batch 4's FETCH ran
    # before its APPLY. So 24 rejection records and their reasons were deleted, the
    # 42 in between the ledger's 78 and the manifest's 36 were not a typo, they were
    # destroyed evidence, and every future batch would have done it again.
    #
    # The lesson, in the shape it actually took: a second writer that rebuilds a file
    # from the keys it happens to know is how an audit trail disappears. Nothing
    # errors, nothing warns, and the history is the only place the record still lives.
    # The fetch path must therefore round-trip every top-level key it did not create.
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as fh:
            manifest = json.load(fh)
    else:
        manifest = {}
    existing = manifest.get("photos", [])

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

    # Write the manifest back WHOLE. See load_manifest's comment and save_manifest():
    # dropping unknown top-level keys here is what destroyed the rejection record on
    # every batch from 4 onward.
    manifest["_note"] = (
        "Every photo here is openly licensed and attributed. "
        "'reviewed': false means the image has been fetched but NOT "
        "yet looked at - an unseen photo is not accepted into the "
        "accuracy set.")
    manifest["photos"] = existing
    save_manifest(manifest)
    print(f"\nadded {added} this batch; manifest now holds {len(existing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
