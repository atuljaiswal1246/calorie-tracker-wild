#!/usr/bin/env python3
"""Apply batch 17 - khakra, found by the two things no batch had tried, and a correction.

MY OWN PREVIOUS CONCLUSION WAS WRONG, and that is the finding. At the end of batch 16 I
wrote: "KHAKRA IS NOW EXHAUSTED AS A SEARCH PROBLEM... Four names, four non-dishes." Six
queries had used four spellings of one word in one search mechanism, and I generalised from
that sample to the population. The very first query of batch 17 - the DOUBLE-K spelling,
khakhra, which no batch had tried - returned the dish.

That is this whole line of work's lesson applied to my own conclusion: a negative finding
needs a control, and "I tried N things" is not a control, it is a sample.

  5 queries (the control first, proven in batches 12 and 14-16), 2 downloaded,
  accepted 1, rejected 1.

  accepted 1  KHAKHRA. A white plate holding broken shards of a thin, crisp, deep-golden
               fried disc, with visible carom/ajwain seed, small fried onion pieces and a
               papery translucent flake. It is unmistakably a Gujarati crispbread, which
               is khakhra, and the class had been declared and empty since batch 9.
               HIGH confidence: the form, the fry colour, the ajwain and the onion are all
               characteristic, and nothing else in the corpus looks like it.

  rejected 1  "dhokla karachi": a real Gujarati dish, and NOT in DISH_CLASS - so class_of
               would put it through the fallback and manufacture a brand new UNDECLARED
               class, which is the exact fault test_the_dish_classes_are_distinct.py
               exists to prevent. Declaring a class because a photograph of it turned up
               is how the class count inflates without anybody deciding anything, so
               dhokla is recorded as a CANDIDATE for a deliberate decision instead.

AND THE MECHANISM FINDING, worth more than the photograph. The category-scoped query
reached real Gujarati food where the text search had been returning an 1784 map:
`incategory:"Gujarati cuisine" khakra` surfaced Gol dhokla, khandvi, muthia and methi
muthiya. So for a dish whose NAME IS A PROPER NOUN, the right question is not "what text
matches" but "what is filed under the cuisine" - a different instrument, not a better
query. Sixteen batches had used one instrument and been reading its failures as facts
about the food.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "khakhra_broken_on_plate": {
        "photo": "khakhra_jpg_73301a1a.jpg",
        "confidence": "high",
        "note": "A white plate holding broken shards of a thin, crisp, deep-golden fried "
                "disc, with visible carom/ajwain seed, small fried onion pieces and one "
                "papery translucent flake, on a dark counter. The form, the fry colour, "
                "the ajwain and the onion are all characteristic of a Gujarati crispbread, "
                "which is khakhra, and nothing else in the corpus resembles it. Found by "
                "the DOUBLE-K SPELLING, which no earlier batch tried, after batch 16 "
                "recorded this class as an exhausted search problem - so the exhaustion was "
                "a fact about four spellings in one search mechanism, not about the food. "
                "Khakra's first case; declared in batch 9, empty through batches 10-16.",
        "truth": [
            {"name": "Khakra", "aliases": ["Khakhra", "Khachra", "Khakro",
                                            "Gujarati Crispbread"],
             "kcal": 160},
        ],
    },
}

REJECT = {
    "dhokla_karachi_jpg_fafe5b88.jpg": (
        "a real Gujarati dish and NOT in DISH_CLASS, so class_of would put it through the "
        "fallback and manufacture a brand new UNDECLARED class - the exact fault "
        "test_the_dish_classes_are_distinct.py exists to prevent. Declaring a class "
        "because a photograph of it turned up is how the class count inflates without "
        "anybody deciding anything. Recorded as a CANDIDATE for a deliberate decision "
        "rather than added on the strength of one photograph"
    ),
}


def main() -> int:
    with open(CASES, encoding="utf-8") as fh:
        corpus = json.load(fh)
    with open(PHOTOS, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = {p["file"].split("/")[-1]: p for p in manifest["photos"]}

    added = rejected = 0
    for case_id, spec in ACCEPT.items():
        rec = photos.get(spec["photo"])
        if rec is None:
            print(f"  ! not in the manifest, skipped: {spec['photo']}")
            continue
        rec.pop("not_used", None); rec.pop("not_used_reason", None)
        rec["reviewed"] = True
        rec["truth_confidence"] = spec["confidence"]
        rec["review_note"] = spec["note"].split(". ")[0] + "."
        rec["accepted_as"] = case_id
        corpus["cases"].append({"id": case_id, "image": rec["file"],
                                "note": spec["note"], "truth": spec["truth"]})
        added += 1
        print(f"  + {case_id}")

    for name, reason in REJECT.items():
        rec = photos.get(name)
        if rec is None:
            print(f"  ! not in the manifest, skipped: {name}")
            continue
        rec["reviewed"] = True; rec["rejected"] = True
        rec["reject_reason"] = reason; rec["opened"] = False
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:48]}")

    for rec in manifest["photos"]:
        if rec.get("reviewed") is True or rec.get("not_used") is True:
            continue
        if rec["file"] in {c["image"] for c in corpus["cases"]}:
            continue
        rec["not_used"] = True
        rec["not_used_reason"] = (
            "Fetched and never reviewed, so it is not evidence. Declared not-used "
            "rather than left unreviewed, because an undecided photo is "
            "indistinguishable from an accepted one.")

    corpus["_readme"].extend([
        "",
        "BATCH 17 (2026-09-28): KHAKRA, FOUND - AND A CORRECTION TO MY OWN CONCLUSION.",
        "At the end of batch 16 this file said 'KHAKRA IS NOW EXHAUSTED AS A SEARCH",
        "PROBLEM... Four names, four non-dishes.' Six queries had used four spellings of",
        "one word in one search mechanism, and I generalised from that sample to the",
        "population. The FIRST query of batch 17 - the double-k spelling, khakhra, which",
        "no batch had tried - returned the dish.",
        "",
        "That is this whole line of work's lesson applied to my own conclusion: a negative",
        "finding needs a control, and 'I tried N things' is not a control, it is a sample.",
        "5 queries with the control first, 2 downloaded, accepted 1, rejected 1.",
        "  accepted 1  KHAKHRA - broken shards of a thin crisp deep-golden fried disc with",
        "               ajwain, fried onion and a papery flake. Unmistakable, and nothing",
        "               else in the corpus resembles it. Khakra's first case; declared in",
        "               batch 9, empty through batches 10-16",
        "  rejected 1  'dhokla karachi' - a real Gujarati dish and NOT in DISH_CLASS, so",
        "               it would manufacture a new UNDECLARED class through the fallback.",
        "               Recorded as a CANDIDATE for a deliberate decision rather than added",
        "               on the strength of one photograph",
        "",
        "AND THE MECHANISM FINDING, worth more than the photograph: the CATEGORY-SCOPED",
        "query reached real Gujarati food where the text search had been returning an 1784",
        "map. incategory:\"Gujarati cuisine\" khakra surfaced Gol dhokla, khandvi, muthia",
        "and methi muthiya. So for a dish whose NAME IS A PROPER NOUN the right question is",
        "not 'what text matches' but 'what is filed under the cuisine' - a different",
        "instrument, not a better query. Sixteen batches had used one instrument and been",
        "reading its failures as facts about the food.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
