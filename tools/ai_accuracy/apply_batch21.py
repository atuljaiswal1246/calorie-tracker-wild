#!/usr/bin/env python3
"""Apply batch 21 - plain queries, and TWO of my own claims retracted by measurement.

THE DECISIVE TABLE, every query asked, SEARCH_FAILURES empty throughout:

    1 candidate  <- filetype:bitmap uthappam breakfast          (the control)
    0 candidates <- filetype:bitmap incategory:"Sweets" gajar halwa
    0 candidates <- filetype:bitmap incategory:"Sweets"
    0 candidates <- filetype:bitmap incategory:"Indian cuisine"
    2 candidates <- filetype:bitmap gajar halwa

`incategory:` yields NOTHING in every form - alone, with a dish name, and with
categories verified to exist. The instrument is dead in this harness whatever the
category is called. That kills two claims of mine:

  - batch 17's "mechanism finding", that a category-scoped query reaches food a dish-name
    search misses. What surfaced Gol dhokla, khandvi and muthia was the EXTRA TEXT of a
    non-existent quoted category, not any scoping.
  - batch 18's "gajar halwa, kheer and pulao returned nothing", which was wrong about
    gajar halwa: the plain query returns two candidates. The cap stopped it, not the
    query, and I wrote the query's name against it.

  5 plain queries, control first, 4 downloaded, accepted 2, rejected 2.

  accepted 2  GAJAR HALWA - a white plate with a dark rim holding a mound of bright
               orange coarse shredded material with visible green cardamom seed. The
               colour and the grated strands are unmistakable, and gajar halwa is
               distinctly Indian - gajar is the Hindi word for carrot - so this does not
               carry the "halwa exists in the Middle East too" doubt that a bare halwa
               would. Halwa's second case.
               AAM KHEER - two scalloped glass bowls of pale creamy white pudding with
               yellow mango pieces, on a glass table with a spoon. Kheer's second case.

  rejected 2  BOTH REJECTED ON THE FILENAME, and both for the same reason - a NATIONAL
              ADJECTIVE that is not Indian, in a corpus of Indian meals:
              "pilaf of uzbekistan yerevan" is an Uzbek dish, and "bangladeshi chicken
              khichuri" is Bangladeshi - khichuri is the Bangladeshi dish, khichdi the
              Indian one, and the difference is exactly what the corpus is trying to
              measure. This is the batch-9 lesson in its purest form: the cuisine
              constraint has to survive being named in English, and a title that says
              which country it is from is more informative than the dish's name.

FOUR ZEROS IN THIS CORPUS AND EVERY ONE WAS MY INSTRUMENT, NOT THE WORLD: a 429, an
over-constrained query, a category form that returns nothing, and a category name that
did not exist. Not one was a fact about a dish. The only reason any was caught is the
control query that sat in the set.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "gajar_halwa_on_plate": {
        "photo": "gajar_halwa_carrot_fudge_jpg_6560a4d0.jpg",
        "confidence": "high",
        "note": "A white plate with a dark green rim holding a mound of bright orange, "
                "coarse, shredded material with visible green cardamom seed, "
                "photographed warm and slightly dim. The colour and the grated strands "
                "are unmistakable gajar halwa. Gajar halwa is also DISTINCTLY Indian - "
                "gajar is the Hindi word for carrot - so this does not carry the doubt a "
                "bare halwa would, halwa being a sweet across the subcontinent and the "
                "Middle East alike. Halwa's second case.",
        "truth": [
            {"name": "Halwa", "aliases": ["Gajar Halwa", "Carrot Halwa", "Gajar Ka Halwa"],
             "kcal": 250},
        ],
    },
    "aam_kheer_two_bowls": {
        "photo": "aam_kheer_mango_kheer_jpg_045ec99a.jpg",
        "confidence": "high",
        "note": "Two scalloped glass bowls of pale creamy white pudding with visible "
                "yellow mango pieces, on a glass table with a spoon standing in the left "
                "bowl. The pale milk base with mango is aam kheer and nothing else. "
                "Kheer's second case.",
        "truth": [
            {"name": "Kheer", "aliases": ["Aam Kheer", "Mango Kheer", "Payasam"],
             "kcal": 200},
        ],
    },
}

REJECT = {
    "pilaf_of_uzbekistan_yerevan_jpg_ab1243a8.jpg": (
        "REJECTED WITHOUT BEING OPENED: the filename says UZBEKISTAN. Uzbek plov and "
        "Indian pulao are related in the region but they are different dishes in different "
        "cuisines, and a corpus of Indian meals does not get one because the English word "
        "is shared. The title is more informative than the dish name here, which is the "
        "opposite of the usual failure"
    ),
    "bangladeshi_chicken_khichuri_jpg_82429b21.jpg": (
        "REJECTED WITHOUT BEING OPENED: the filename says BANGLADESHI. Khichuri is the "
        "Bangladeshi dish and khichdi the Indian one, and the difference between them is "
        "exactly what this corpus exists to measure - so admitting a Bangladeshi khichuri "
        "under an Indian dish name would corrupt the very comparison the class count is "
        "supposed to support"
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
            cand = [k for k in photos if k.startswith(name[:44])]
            if len(cand) == 1:
                rec, name = photos[cand[0]], cand[0]
            else:
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
        "BATCH 21 (2026-09-28): PLAIN QUERIES, AND TWO OF MY OWN CLAIMS RETRACTED BY",
        "MEASUREMENT. The decisive table, every query asked, SEARCH_FAILURES empty:",
        "  1 candidate  <- filetype:bitmap uthappam breakfast          (the control)",
        "  0 candidates <- filetype:bitmap incategory:\"Sweets\" gajar halwa",
        "  0 candidates <- filetype:bitmap incategory:\"Sweets\"",
        "  0 candidates <- filetype:bitmap incategory:\"Indian cuisine\"",
        "  2 candidates <- filetype:bitmap gajar halwa",
        "",
        "incategory: YIELDS NOTHING in every form - alone, with a dish name, and with",
        "categories verified to exist. The instrument is dead in this harness whatever the",
        "category is called. That retracts two claims of mine:",
        "  batch 17's 'mechanism finding' - what surfaced Gol dhokla, khandvi and muthia was",
        "    the EXTRA TEXT of a non-existent quoted category, not any scoping",
        "  batch 18's 'gajar halwa returned nothing' - the plain query returns TWO",
        "    candidates; the cap stopped it, not the query, and I wrote the query's name",
        "    against it",
        "5 plain queries, 4 downloaded, accepted 2, rejected 2.",
        "  accepted 2  gajar halwa (orange grated carrot with visible cardamom; and",
        "               DISTINCTLY Indian, since gajar is the Hindi word for carrot, so it",
        "               does not carry the doubt a bare halwa would) and aam kheer (pale",
        "               pudding with yellow mango in two glass bowls)",
        "  rejected 2  both on the filename, both for the same reason - a NATIONAL",
        "               ADJECTIVE that is not Indian: 'pilaf of uzbekistan' and",
        "               'bangladeshi chicken khichuri'. Khichuri is Bangladeshi and khichdi",
        "               Indian, and admitting one under the other's name would corrupt the",
        "               very comparison the class count exists to support",
        "",
        "FOUR ZEROS IN THIS CORPUS AND EVERY ONE WAS MY INSTRUMENT, NOT THE WORLD: a 429,",
        "an over-constrained query, a category form that returns nothing, and a category",
        "name that did not exist. Not one was a fact about a dish. The only reason any was",
        "caught is the control query that sat in the set.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
