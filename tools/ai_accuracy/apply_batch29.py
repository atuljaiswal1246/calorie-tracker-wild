#!/usr/bin/env python3
"""Apply batch 29 - aimed at a weakness I MEASURED in the top classes rather than at a
class that needs filling, and it found the real one.

7 queries (control first), 3 downloaded, accepted 1, rejected 2.

WHY THIS BATCH EXISTS. The concentration figure sat at 22% for two batches, and the cause
is not in the tail of the distribution - it is in the head. Measured from the corpus:

    dal ..... 5 cases from only 3 dish families - 'dal', 'dal makhani', 'urad dal'
    chole ... 4 cases from only 2 dish families - 'chole' and 'chana masala'
    sambar .. 3 cases from ONE family - 'sambar', three times

TWO OF THE THREE LARGEST CLASSES ARE INFLATED BY THE SAME DISH UNDER TWO NAMES. Chana
masala and chole are the same preparation - chickpea, onion, tomato, the same masala - and
dal makhani is a dal. So the corpus is partly counting one dish twice and calling it
independence, which is precisely the failure the class work exists to prevent, and it means
the 22% UNDERSTATES how concentrated this corpus really is.

The declared arithmetic was therefore about the families, not the case count. Adding a case
to the dal class makes dal 6 and the percentage worse. Adding a NEW DAL keeps dal at 5 while
making the five cases five different dishes. That is the same move as batches 18 and 21,
aimed at the head instead of the tail.

CHANA WAS DELIBERATELY ABSENT. "chana dal" would land in the chole class and make the worst
offender worse. I am not going to fix a concentration problem by making the concentration
worse, and saying so in advance meant the absence was a decision rather than an oversight.

THE PREDICTION WAS: 2-3 candidates, 1-2 cases. The fetcher recorded:

    pages=1  uthappam breakfast        <- the control
    pages=8  "moong dal"              8
    pages=8  "masoor dal"             8
    pages=8  "dal tadka"              8
    pages=0  "masoor dal fry"         0
    pages=0  "moong dal khichdi"      0
    pages=0  "dal makhani bowl"       0

3 candidates against a predicted 2-3: the recall half was right, which is the first time
that has happened. The interesting half is not the count and it is stated below.

ACCEPTED 1, and it is the case the batch was designed to find.

  DAL TADKA - a white bowl of yellow dal with a red chilli oil pool around the rim, two
    whole dried red chillies laid across the surface, visible cumin seed, black mustard
    seed, slivered garlic and coriander, on a dark wooden table with two red onions, a cut
    lemon and whole cardamom pods arranged around it. A textbook tadka - the tempered
    spices are the point, and they are countable.

    This is a FOURTH FAMILY inside the dal class, where the aim was three. And it matters
    that this is dal and not dal makhani: tadka is a plain dal finished with a tempered
    masala, makhani is a dal reduced overnight with butter and cream until it is thick and
    creamy, and the two carry different calories for the same bowl of lentils. One of the
    corpus's existing dal cases is already dal makhani, so this is not a second label for
    it - it is the other preparation.

REJECTED 2, and BOTH ARE THE BARE-WORD RULE, thirty batches after it was named, on the one
dish this corpus has queried most.

  "green gram field" - returned by "moong dal". A FIELD OF MOONG BEANS IN BLOOM, shot from
    the cab of a vehicle, with a camera watermark in the corner. There is no dal in it and
    no meal in it: it is agricultural photography, a crop. Rejected, and the reason is
    worth more than the photograph: "moong" is a CROP, a BEAN and a DAL all at once, and a
    query naming a crop reaches the field. This is the batch 22 finding - one word finds the
    ingredient - except "moong dal" is TWO words and it still found the field, because the
    two words share a crop name. So the surviving rule from batch 26 has to be narrowed
    again: two words is not sufficient when the FIRST word names a crop.

  "3 types of lentil" - returned by "masoor dal". Three piles of RAW DRY LENTILS on a
    white background - green gram, masoor and a third - photographed as a reference chart
    for pulses. No cooked lentil, no dal, no meal. The same call as batch 22's dried kidney
    beans on white and batch 14's raw green beans: a photograph of an INGREDIENT is not a
    photograph of a MEAL, and the corpus scores meals.

  The pair is the batch's real finding and it is a MEASURED WEAKNESS IN MY OWN QUERY
  FORM, not in the archive. Three of the six target queries returned zero pages and two of
  the three that returned pages returned raw produce. The form "legume + preparation" is
  right when the preparation word is a COOKING METHOD - curry, masala, tadka, bhurji - and
  wrong when it is absent or is a compound noun that keeps the crop name in it. "masoor dal
  fry" and "moong dal khichdi" are exactly that failure: both are real dishes, both returned
  zero, and both put the crop word first, which is where this archive's agricultural
  photography lives.

  "dal makhani bowl" also returned zero, and that is the one I would most have liked. It is
  already a family in the corpus with no reason to fetch it again - the batch was aimed at
  WIDENING the dal families, not at filling a gap, and I put a query in anyway. A query
  whose dish is already represented is a query that cannot help the number it was aimed at,
  and the record now says it cost one.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "dal_tadka_red_chilli_oil": {
        "photo": "dal_tadka_delhi_jpg_b5719d0a.jpg",
        "confidence": "high",
        "note": "A white bowl of yellow dal with a red chilli oil pool around the rim, two "
                "whole dried red chillies laid across the surface, visible cumin seed, "
                "black mustard seed, slivered garlic and coriander, on a dark wooden table "
                "with two red onions, a cut lemon and whole cardamom pods arranged around "
                "it. A textbook tadka - the tempered spices are the point and they are "
                "countable. A FOURTH FAMILY inside the dal class, where the batch was sized "
                "for three. It matters that this is dal and not dal makhani: tadka is a "
                "plain dal finished with a tempered masala, makhani is a dal reduced "
                "overnight with butter and cream until thick and creamy, and the two carry "
                "different calories for the same bowl of lentils. One existing dal case is "
                "already dal makhani, so this is the OTHER preparation and not a second "
                "label for it.",
        "truth": [
            {"name": "Dal Tadka", "aliases": ["Tadka Dal", "Dal Bhuna", "Jeera Dal",
                                               "Dal Tarka"], "kcal": 140},
        ],
    },
}

REJECT = {
    "green_gram_field_jpg_1043e73d.jpg": (
        "OPENED, and returned by 'moong dal': a FIELD OF MOONG BEANS IN BLOOM, shot from "
        "the cab of a vehicle, with a camera watermark in the corner. There is no dal in it "
        "and no meal in it - it is agricultural photography, a crop. Rejected. The reason is "
        "worth more than the photograph: 'moong' is a CROP, a BEAN and a DAL all at once, "
        "and a query naming a crop reaches the field. This is the batch 22 finding - one "
        "word finds the ingredient - except 'moong dal' is TWO words and it still found "
        "the field, because the two words share a crop name. So the surviving rule from "
        "batch 26 has to be narrowed again: two words is NOT sufficient when the FIRST word "
        "names a crop"
    ),
    "3_types_of_lentil_jpg_e0488f31.jpg": (
        "OPENED, and returned by 'masoor dal': three piles of RAW DRY LENTILS on a white "
        "background - green gram, masoor and a third - photographed as a reference chart "
        "for pulses. No cooked lentil, no dal, no meal. The same call as batch 22's dried "
        "kidney beans on white and batch 14's raw green beans: a photograph of an "
        "INGREDIENT is not a photograph of a MEAL, and the corpus scores meals"
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
        rec.pop("not_used", None)
        rec.pop("not_used_reason", None)
        rec["reviewed"] = True
        rec["truth_confidence"] = spec["confidence"]
        rec["review_note"] = spec["note"].split(". ")[0] + "."
        rec["accepted_as"] = case_id
        corpus["cases"].append({"id": case_id, "image": rec["file"],
                                "note": spec["note"], "truth": spec["truth"]})
        added += 1
        print(f"  + {case_id}  ({spec['confidence']})")

    for name, reason in REJECT.items():
        rec = photos.get(name)
        if rec is None:
            print(f"  ! not in the manifest, skipped: {name}")
            continue
        rec["reviewed"] = True
        rec["rejected"] = True
        rec["reject_reason"] = reason
        rec["opened"] = "OPENED" in reason
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name}")

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
        "BATCH 29 (2026-09-28): AIMED AT A MEASURED WEAKNESS IN THE TOP CLASSES - and it",
        "found the real one.",
        "  7 queries (control first), 3 downloaded, accepted 1, rejected 2",
        "",
        "The concentration figure sat at 22% for two batches and the cause is in the HEAD of",
        "the distribution, not the tail. Measured from the corpus:",
        "  dal ..... 5 cases from only 3 dish families - 'dal', 'dal makhani', 'urad dal'",
        "  chole ... 4 cases from only 2 dish families - 'chole' and 'chana masala'",
        "  sambar .. 3 cases from ONE family - 'sambar', three times",
        "",
        "TWO OF THE THREE LARGEST CLASSES ARE INFLATED BY THE SAME DISH UNDER TWO NAMES.",
        "Chana masala and chole are the same preparation - chickpea, onion, tomato, the same",
        "masala - and dal makhani is a dal. So the corpus is partly counting one dish twice",
        "and calling it independence, which is exactly the failure the class work exists to",
        "prevent, and it means the 22% UNDERSTATES how concentrated this corpus really is.",
        "",
        "So the arithmetic was about FAMILIES, not the case count. Adding a case to dal makes",
        "dal 6 and the percentage worse; adding a NEW DAL keeps dal at 5 while making the",
        "five cases five different dishes. Same move as batches 18 and 21, aimed at the head.",
        "CHANA WAS DELIBERATELY ABSENT: 'chana dal' would land in the chole class and make",
        "the worst offender worse. Saying so in advance made the absence a decision.",
        "",
        "  pages=1  uthappam breakfast        <- the control",
        '  pages=8  "moong dal"              8',
        '  pages=8  "masoor dal"             8',
        '  pages=8  "dal tadka"              8',
        '  pages=0  "masoor dal fry"         0',
        '  pages=0  "moong dal khichdi"      0',
        '  pages=0  "dal makhani bowl"       0',
        "",
        "3 candidates against a predicted 2-3: the recall half was right, the first time that",
        "has happened. The interesting half is not the count.",
        "",
        "  accepted 1  DAL TADKA - a white bowl of yellow dal with a red chilli oil pool",
        "               around the rim, two whole dried red chillies, visible cumin seed,",
        "               black mustard seed, slivered garlic and coriander, with red onions,",
        "               a cut lemon and whole cardamom pods arranged around it. A textbook",
        "               tadka, and a FOURTH FAMILY where the batch was sized for three. It",
        "               matters that this is dal and not dal makhani: tadka is a plain dal",
        "               finished with a tempered masala, makhani is reduced overnight with",
        "               butter and cream, and the two carry different calories for the same",
        "               bowl of lentils.",
        "",
        "  rejected 2  'green gram field' - a FIELD OF MOONG BEANS IN BLOOM shot from a",
        "               vehicle cab. No dal, no meal: agricultural photography. 'moong' is a",
        "               CROP, a BEAN and a DAL at once, and a query naming a crop reaches the",
        "               field. So the batch 26 rule narrows AGAIN: two words is not sufficient",
        "               when the FIRST word names a crop - and 'moong dal' is two words.",
        "             '3 types of lentil' - three piles of RAW DRY LENTILS on white, shot as a",
        "               reference chart for pulses. The same call as batch 22's dried kidney",
        "               beans and batch 14's raw green beans.",
        "",
        "THE MEASURED WEAKNESS IS IN MY OWN QUERY FORM, not the archive: 3 of 6 target",
        "queries returned zero pages and 2 of the 3 that returned pages returned raw",
        "produce. 'Legume + preparation' works when the preparation is a COOKING METHOD -",
        "curry, masala, tadka, bhurji - and fails when it is absent or is a compound noun",
        "keeping the crop name in it. 'masoor dal fry' and 'moong dal khichdi' are real",
        "dishes that both returned zero, and both put the crop word first, which is where",
        "this archive's agricultural photography lives.",
        "",
        "'dal makhani bowl' also returned zero, and that is the one I would most have liked:",
        "the dish is already a family in the corpus with no reason to fetch it again. The",
        "batch was aimed at WIDENING the dal families, and I put a query in anyway. A query",
        "whose dish is already represented cannot help the number it was aimed at, and the",
        "record now says it cost one.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
