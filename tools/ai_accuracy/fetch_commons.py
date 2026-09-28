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


# BATCH 8 -- FLATTEN, and the arithmetic is the whole reason this batch exists.
#
# The class bar is met at 22 (bar = 20). The SAMPLE is the problem: the top 4
# classes hold 42% of 31 cases (dal x5, chole x4, paneer x2, sambar x2), and the
# readme names <= 35% as the target. So this batch is sized by that arithmetic,
# not by taste: adding N cases to classes that hold ONE each moves the top-4
# share to 13/(31+N), and 13/37 = 35.1%, 13/38 = 34.2%. So ~7-8 accepted photos
# in the thin classes HIT the target, and not one of them may be dal, chole,
# paneer or sambar.
#
# Concretely: one query per class that currently has exactly ONE case, and none
# of the four concentrated ones appears here. That is the "one query per missing
# class" rule applied to the real gap - the gap is not the class COUNT, it is the
# classes that are one photo deep.
#
# The owner's version of the same instruction: do not knowingly ask for dal,
# chole or sambar again, because those queries are what built the 42%.
BATCH8_QUERIES = [
    'filetype:bitmap "aloo gobi" curry',
    'filetype:bitmap "baingan bharta"',
    'filetype:bitmap "bhindi masala"',
    'filetype:bitmap "dum biryani" plate',
    'filetype:bitmap "masala dosa" plate',
    'filetype:bitmap "egg bhurji" bowl',
    'filetype:bitmap "gajar halwa" bowl',
    'filetype:bitmap "idli" plate south',
    'filetype:bitmap "kadhi" bowl',
    'filetype:bitmap "kheer" bowl',
    'filetype:bitmap "khichdi" plate',
    'filetype:bitmap "kofta curry"',
    'filetype:bitmap "lauki" sabzi',
    'filetype:bitmap "pulao" plate',
    'filetype:bitmap "rajma" bowl',
    'filetype:bitmap "sarson da saag"',
    'filetype:bitmap "medu vada"',
    'filetype:bitmap "uttappam"',
]


# BATCH 9 -- WIDEN, and the keys go in WITH the queries.
#
# Batch 8 flattened (42% -> 34%, target hit). The class count is 23 with a bar of
# 20, so the class COUNT is not the gap any more - the gap is that several very
# common home dishes have NO case at all, and a photo app fails on the dish a
# user actually eats on a Tuesday. Measured from cases.json @ 38 cases: no
# mushroom, capsicum, keema, french beans, sweet corn, jalebi or samosa case
# exists, and STAPLE_SIDES means none of them can be smuggled in as a side.
#
# BATCH9_QUERIES is one query per absent class, and the DISH_CLASS keys are added
# in the same commit, because a key added after the fact is how a bar gets bought
# with synonyms. Seven classes, seven queries.
BATCH9_QUERIES = [
    'filetype:bitmap "mushroom curry" bowl',
    'filetype:bitmap "capsicum masala"',
    'filetype:bitmap keema curry',
    'filetype:bitmap "french beans" curry',
    'filetype:bitmap "sweet corn" curry',
    'filetype:bitmap jalebi bowl',
    'filetype:bitmap samosa plate',
]


# BATCH 10 -- the six keys with no case yet, queried harder.
#
# Batch 9 added the class KEYS (mushroom, capsicum, french beans, jalebi, samosa
# and one more) in the same commit as the photographs, so six of them still have
# no case. Batch 9's own queries proved the failure mode: "mushroom curry bowl"
# returned a Thai green curry, and the french beans query returned a four-item
# plate. So the queries are TIGHTER here - the word "indian" or "home" in every
# one, because Commons is a global library and the unsuffixed term finds the
# wrong cuisine. Same per-query and per-author caps, same dHash near-dup check.
BATCH10_QUERIES = [
    'filetype:bitmap "mushroom curry" indian home',
    'filetype:bitmap "shimla mirch" masala indian',
    'filetype:bitmap "french beans" curry indian',
    'filetype:bitmap jalebi indian sweets',
    'filetype:bitmap samosa indian plate',
    'filetype:bitmap "aloo bhaji"',
]


# BATCH 11 -- the six DECLARED class keys that no case reaches, measured not guessed.
#
# `python3 tools/ai_accuracy/test_the_dish_classes_are_distinct.py` prints this list:
# capsicum, french beans, khakra, mushroom, raitha and uthappam are all in DISH_CLASS
# and none of the 42 cases lands in any of them. A declared key with no case is a
# promise the corpus is not keeping, and it is the cheapest possible win: the class
# already exists as a decision, so a photograph here raises the class count WITHOUT
# inventing a new category, keeps every dish family at one case - so the independence
# figure does not get worse - and pushes the concentration down.
#
# The queries are tight for the reason batch 9 recorded: Commons is a global library
# and an unsuffixed term finds the wrong cuisine. "mushroom curry bowl" returned a
# THAI green curry. So every one carries "indian" or "home" or a regional word.
BATCH11_QUERIES = [
    'filetype:bitmap "mushroom masala" indian home',
    'filetype:bitmap "shimla mirch" masala indian',
    'filetype:bitmap "french beans" sabzi indian',
    'filetype:bitmap uthappam south indian',
    'filetype:bitmap "boondi raitha" indian',
    'filetype:bitmap khakra gujarati',
]


# BATCH 12 -- the five classes batch 11 left empty, queried by REGIONAL SPELLING.
#
# Batch 11 got 1 usable photograph out of 3 downloaded across 6 "indian"-suffixed
# queries. The suffix was the right lesson from batch 9 (an unsuffixed term finds the
# wrong cuisine) but it is evidently not enough to find these five dishes, because
# Commons is thin on them and thin in a particular way: the uploads are usually
# captioned in a REGIONAL or TRANSLITERATED form, not the dictionary form.
#
# So every query here changes the NAME rather than adding another cuisine word:
#   khakra      -> khakro, khakra rotli          (Gujarati spellings)
#   mushroom    -> dhingra masala               (Hindi for mushroom)
#   raitha      -> raita, potato raita           (the short form, and the common dish)
#   uthappam    -> uttapam, neyyappam-adjacent   (Kerala/Malabar transliterations)
#   french beans-> gavar phali, beans poriyal     (Gujarati and South Indian names)
#
# This is the honest response to a thin result: widen the NAMES, not the rules. The
# cuisine constraint stays, because batch 9 proved what relaxing it costs - a Thai
# green curry accepted as a mushroom dish would be worse than an empty class.
BATCH12_QUERIES = [
    'filetype:bitmap khakra gujarati',
    'filetype:bitmap "khakro" gujarati snack',
    'filetype:bitmap "dhingra masala"',
    'filetype:bitmap raita indian',
    'filetype:bitmap "potato raita"',
    'filetype:bitmap uthappam breakfast',
    'filetype:bitmap uttapam kerala',
    'filetype:bitmap "beans curry" indian home',
    'filetype:bitmap gavar phali',
    'filetype:bitmap "beans poriyal" south indian',
]


# BATCH 13 -- the last three empty classes, and the dish FORM rather than the name.
#
# Batch 12 widened the NAMES (khakro, dhingra, gavar phali) and filled uthappam and
# raitha but not khakra, mushroom or french beans. Its own commit named the next move:
# change the dish FORM.
#
# There is a real trade-off here and it is worth writing down before the results, because
# it is the reason this round might fail in a new way. A wider form - "a whole thali" -
# finds the dish more often, but a thali is a COMPOSITE: class_of takes the first
# non-staple item, so on a Gujarati thali the class would be decided by whichever
# vegetable I happened to list first. That is the four-component-plate fault batch 10
# rejected. So this round widens the form WITHOUT going composite: bowl, gravy, curry,
# sabzi and fry words, which are still single dishes but photograph differently from a
# close-up.
#
# And the standing commitment from batch 12 is kept: if this comes back thin, the result
# is that these three stay EMPTY, recorded with the measured reason, rather than a case
# manufactured to fill a key. A class filled with a photograph that does not show the
# class is worse than an empty class, because the empty one is honest.
BATCH13_QUERIES = [
    'filetype:bitmap "mushroom curry" bowl gravy',
    'filetype:bitmap "mushroom masala" gravy',
    'filetype:bitmap "mushroom fry" indian',
    'filetype:bitmap "beans curry" bowl',
    'filetype:bitmap "french beans" masala gravy',
    'filetype:bitmap "beans poriyal" bowl',
    'filetype:bitmap khakra rotli',
    'filetype:bitmap "dal khichdi" gujarati',
    'filetype:bitmap khakra thepla gujarati',
    'filetype:bitmap "gavar phali" sabzi',
]


# BATCH 14 -- the queries were the problem, and a control is what proved it.
#
# Batch 13 also returned 0, but for a THIRD and completely different reason, and the
# control query is the only reason I know which one:
#
#   CONTROL, known-good, worked in batch 12 ....... 1 candidate   <- the API is fine
#   'filetype:bitmap "mushroom curry" bowl gravy'  0 candidates   <- batch 13's wording
#   'filetype:bitmap "mushroom curry"' ........... 3 candidates   <- same dish, fewer words
#   'mushroom curry' (no filetype filter) ........ 3 candidates
#   'khakra gujarati' (no filetype filter) ....... 0 candidates   <- this one really is thin
#
# So the cause was MY query construction, not Commons. `filetype:bitmap` plus a quoted
# phrase plus two form words is over-constrained, and batch 13's whole premise - widen
# the dish FORM - widened the query into uselessness. The dish was there the whole time.
#
# Three batches have now returned zero for three DIFFERENT reasons: a rate limit, an
# over-constrained query, and (for khakra) possibly a genuine absence. Only the third
# is a fact about the food, and separating them took a control every time.
#
# These queries drop the form words and keep the filter that demonstrably works.
BATCH14_QUERIES = [
    'filetype:bitmap "mushroom curry"',
    'filetype:bitmap "mushroom masala"',
    'filetype:bitmap mushroom sabzi',
    'filetype:bitmap "beans curry"',
    'filetype:bitmap "french beans"',
    'filetype:bitmap "green beans" curry',
    'filetype:bitmap khakra',
    'filetype:bitmap khakro',
]


# BATCH 15 -- khakra and mushroom, the last two empty classes, WITH THE CONTROL IN
# THE SAME RUN.
#
# Batch 14 proved the cause of the zeros was my own over-constrained wording, so these
# queries are plain: no quoted phrase plus form words, just the dish. And the control
# query is IN THE SET rather than run separately, because a control run minutes earlier
# is a claim about a moment that has passed - the whole lesson of the three zeros.
#
# If the control comes back empty, the batch refuses itself (exit 3, the mechanism from
# 8a7065a) and nothing may be concluded about khakra. If the control comes back with hits
# and khakra does not, then khakra is genuinely thin on Commons - the first
# negative finding in this line of work that would actually be supported by one.
BATCH15_QUERIES = [
    # the control, first, and named as such: proven in batches 12 and 14
    'filetype:bitmap uthappam breakfast',
    'filetype:bitmap khakra',
    'filetype:bitmap "khakra rotli"',
    'filetype:bitmap "gujarati khichdi"',
    'filetype:bitmap khakro',
    'filetype:bitmap "mushroom curry"',
    'filetype:bitmap "mushroom masala"',
]


# BATCH 16 -- the last two empty classes, attacked by SYNONYM rather than by form.
#
# Batch 15 produced the first control-supported negative finding, and its reading was
# precise: khakra "cannot be SEARCHED with the words available", because "khakra" is a
# proper noun a 1784 map and a palace both match. So the answer is not another spelling
# of khakra - it is a DIFFERENT NAME for the food, and I have never tried one.
#
#   khakra  -> mathari, and the bhakri it is eaten with, and farsi puri from the same
#              Gujarati snack family. A dish is findable by its NEIGHBOURS.
#   mushroom -> dhingra (the Hindi word, so the captions are in Hindi), and the visible
#              FORMS - a mushroom has to be VISIBLE, and a sabzi or a fry shows it where
#              a masala under a dosa does not.
#
# The control is in the set again, first, for the reason batch 15 established: a control
# run separately is a claim about a moment that has passed.
BATCH16_QUERIES = [
    'filetype:bitmap uthappam breakfast',            # the control, proven in 12/14/15
    'filetype:bitmap mathari',
    'filetype:bitmap "gujarati bhakri"',
    'filetype:bitmap "farsi puri"',
    'filetype:bitmap dhingra',
    'filetype:bitmap "mushroom sabzi"',
    'filetype:bitmap "mushroom fry"',
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

SEARCH_FAILURES: list[tuple[str, str]] = []


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
            print(f"  ! search FAILED for {q!r}: {exc}")
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
    ap.add_argument("--set", choices=["mixed", "single", "batch2", "batch3", "batch4", "batch5", "batch6", "batch7", "batch8", "batch9", "batch10", "batch11", "batch12", "batch13", "batch14", "batch15", "batch16"], default="mixed")
    args = ap.parse_args()

    print("searching Wikimedia Commons ...")
    sets = {"single": SINGLE_QUERIES, "batch2": BATCH2_QUERIES, "batch3": BATCH3_QUERIES, "batch4": BATCH4_QUERIES, "batch5": BATCH5_QUERIES, "batch6": BATCH6_QUERIES, "batch7": BATCH7_QUERIES, "batch8": BATCH8_QUERIES, "batch9": BATCH9_QUERIES, "batch10": BATCH10_QUERIES,
    "batch11": BATCH11_QUERIES,
    "batch12": BATCH12_QUERIES,
    "batch13": BATCH13_QUERIES,
    "batch14": BATCH14_QUERIES,
    "batch15": BATCH15_QUERIES,
    "batch16": BATCH16_QUERIES}
    cands = candidates(queries=sets.get(args.set, QUERIES))
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
