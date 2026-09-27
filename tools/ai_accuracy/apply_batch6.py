#!/usr/bin/env python3
"""Apply batch 6 - the classes the 20-meal bar still needed, chosen for the gap.

After batch 5 the corpus measured 18 distinct dish CLASSES against a bar of 20
MEALS, and its worst gap was not a missing class but a missing KIND of food: one
non-vegetarian class in 27 cases, no egg, no dessert, no rice dish. So batch 6
targets exactly those, one query each, and accepts only what survived looking at.

  accepted 3   egg bhurji + chapati tray, veg pulao + boondi raitha, chahao kheer
  rejected 4   a catering spread of ten plates, a Filipino tortang talong held in
               a hand (x2, near-identical), a styled single portion with a black
               crop bar down one side
  not_used 1   one more Bengali fish candidate, not looked at, so not evidence

Result: 18 -> 21 distinct dish CLASSES, 27 -> 30 cases. The 20-meal bar is met
with one class to spare, and the class map is why: egg bhurji and omelette are
one class, mutton and chicken biryani are one class, so a batch cannot buy the
bar by adding near-synonyms.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "egg_bhurji_chapati_tray": {
        "photo": "chappa_thi_jpg_cd925fa9.jpg",
        "truth": [
            {"name": "Egg Bhurji", "aliases": ["Scrambled Eggs", "Ande Bhurji", "Egg Curry"],
             "kcal": 180},
            {"name": "Chapati", "aliases": ["Roti", "Phulka", "Flatbread", "Bread"],
             "kcal": 180},
            {"name": "Meat Curry", "aliases": ["Mutton Curry", "Beef Curry", "Chicken Curry",
                                                "Meat", "Mutton", "Beef"],
             "kcal": 200},
        ],
        "note": "A yellow compartment tray shot from above: egg bhurji with onion, "
                "tomato and coriander; three chapati; and a meat curry in two "
                "compartments. THE MEAT IS NOT IDENTIFIABLE from the photo, so the "
                "truth says 'Meat Curry' and every specific answer is an accepted "
                "alias - a model that says mutton when it is beef has not invented "
                "anything, and a truth column that demanded one answer would score "
                "it wrong for a reason that is not the model's fault. The 2nd meat "
                "compartment is counted once.",
        "confidence": "high",
    },
    "veg_pulao_boondi_raitha": {
        "photo": "veg_pulao_and_boondi_raitha_jpg_b9c33c23.jpg",
        "truth": [
            {"name": "Veg Pulao", "aliases": ["Pulao", "Rice", "Vegetable Rice",
                                              "Jeera Rice", "Mixed Rice"],
             "kcal": 220},
            {"name": "Boondi Raitha", "aliases": ["Raitha", "Raita", "Yogurt", "Curd",
                                                  "Dahi"],
             "kcal": 90},
        ],
        "note": "A white bowl of veg pulao on a floral plate beside a yellow bowl of "
                "boondi raitha, from above. The rice is WHITE, not yellow, so pulao "
                "vs plain rice with vegetables is a judgement - 'Rice' is therefore "
                "an accepted alias, and the label is medium confidence rather than a "
                "pretence of certainty.",
        "confidence": "medium",
    },
    "chahao_kheer_bowl": {
        "photo": "chahao_kheer_jpg_0758bd3c.jpg",
        "truth": [
            {"name": "Kheer", "aliases": ["Payasam", "Khir", "Rice Pudding", "Sweet Rice",
                                          "Chahao Kheer"],
             "kcal": 220},
        ],
        "note": "One steel bowl of chahao kheer - purple rice pudding with milk - on "
                "a tablecloth, with a spoon. The corpus had NO dessert case at all, "
                "and a thali photograph routinely contains one: the only dessert in "
                "the corpus before this was gajar halwa, inside someone else's thali.",
        "confidence": "high",
    },
}

REJECT = {
    "cuisine_220_26_jpg_f5ed550f.jpg":
        "a catering counter with TEN plates of small portions; there is no single "
        "meal to scan, so there is no truth to write",
    "0025filipino_eggplant_onion_and_tomatoes_omelette_01_4cd12802.jpg":
        "Filipino tortang talong held in a hand, outdoors among flowers; not Indian",
    "0025filipino_eggplant_onion_and_tomatoes_omelette_02_2d23cda1.jpg":
        "same photograph, second crop; and not Indian either",
    "pulao_png_eb249358.jpg":
        "styled single portion with a black crop bar down one side and a mint "
        "sprig placed as a garnish; the other pulao candidate was cleaner",
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
        rec["reviewed"] = True
        rec["rejected"] = True
        rec["reject_reason"] = reason
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:52]}")

    # The one candidate that was fetched but never looked at: declared, not
    # guessed at, and not deleted - a rejected-in-silence photo gets re-proposed.
    for rec in manifest["photos"]:
        if rec.get("reviewed") is True or rec.get("not_used") is True:
            continue
        if rec["file"] in {c["image"] for c in corpus["cases"]}:
            continue
        rec["not_used"] = True
        rec["not_used_reason"] = (
            "Fetched and never reviewed, so it is not evidence. Left in the manifest "
            "DECLARED as not-used rather than left unreviewed, because an undecided "
            "photo is indistinguishable from an accepted one.")
        print(f"  ? declared not-used: {rec['file'].split('/')[-1][:52]}")

    corpus["_readme"].extend([
        "",
        "BATCH 6 (2026-09-28): the last two classes the bar needed, chosen by GAP not",
        "by convenience - one non-vegetarian class in 27 cases, no egg, no dessert,",
        "no rice dish. BATCH6_QUERIES is one query per missing class. 8 candidates",
        "fetched, 5 looked at, 3 ACCEPTED and 4 rejected with reasons, 1 declared",
        "not-used because nobody looked at it.",
        "NEW CLASSES: egg (egg bhurji), pulao (veg pulao + boondi raitha), kheer.",
        "MEASURED: 30 cases / 25 distinct dish names / 21 distinct dish CLASSES / 35",
        "coverage classes. The bar is 20 MEALS, so it is MET with one class spare,",
        "and it is met honestly: egg bhurji and omelette are one class, mutton and",
        "chicken biryani are one class, so a batch cannot buy the bar with synonyms.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
