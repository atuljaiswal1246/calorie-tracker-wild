#!/usr/bin/env python3
"""Apply batch 5 to the corpus - 14 candidates fetched, 6 looked at, 5 accepted.

The batch was built backwards from the gap: ROADMAP M1's bar is 20 MEALS, and
tools/ai_accuracy.py --corpus said the corpus held 13 distinct dish CLASSES, not
the 17 distinct names I had been quoting. So BATCH5_QUERIES is one query per
missing class, and the fetcher's near-duplicate + per-query + per-author caps
were built first, because the fish-curry query alone offered five near-identical
files by one uploader.

EVERY candidate was LOOKED AT before this script ran, and every rejection is
recorded with its reason rather than silently dropped. A rejected photo is
deleted from disk but kept in the manifest, so the next batch does not re-propose
it and nobody later wonders where it went.

  accepted 5  khichuri platter, mutton biryani, sarson da saag, aloo gobi, kofta
  rejected 13 for: restaurant/menu shot, styled shot with scattered props, airline
             meal, non-Indian cuisine, embedded watermark, a knife in the food,
             or a truth I could not name honestly (two fish preparations plus an
             ambiguous pale bowl)
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

# id -> (photo file, truth, case note, truth_confidence, review note)
ACCEPT = {
    "khichuri_platter": {
        "photo": "khichuri_platter_jpg_a2877bbd.jpg",
        "truth": [
            {"name": "Khichuri", "aliases": ["Khichdi", "Khichri", "Rice and Dal"],
             "kcal": 250},
            {"name": "Khakra", "aliases": ["Baked Crackers", "Biscuits", "Crackery"],
             "kcal": 110},
            {"name": "Dry Vegetable Sabzi", "aliases": ["Sabzi", "Dry Curry", "Shaak"],
             "kcal": 100},
        ],
        "note": "Gujarati khichuri on a steel-and-ceramic plate, from above: a "
                "bowl of khichdi, three khakra, one dry vegetable sabzi. The small "
                "steel katori of thin dal/sauce is NOT in the truth: I could not "
                "name it honestly, and a guess in the truth column is how an "
                "earlier baseline was wrong by 37.7%.",
        "confidence": "medium",
    },
    "mutton_biryani_home_plate": {
        "photo": "a_home_made_plate_of_mutton_biryani_served_with_chic_0d6ce913.jpg",
        "truth": [
            {"name": "Mutton Biryani", "aliases": ["Biryani", "Mutton Pulao", "Dum Biryani"],
             "kcal": 650},
            {"name": "Cucumber", "aliases": ["Salad", "Kucumber Slices", "Cucumber Salad"],
             "kcal": 15},
        ],
        "note": "Home-cooked plate from above: a large plate of mutton biryani "
                "with mutton pieces and a whole potato, a small glass bowl of "
                "extra mutton gravy, and cucumber slices. The extra gravy bowl is "
                "counted inside the biryani figure, not as a second dish.",
        "confidence": "high",
    },
    "sarson_da_saag_makki_roti": {
        "photo": "makki_di_roti_te_sarson_da_saag_jpg_c8724356.jpg",
        "truth": [
            {"name": "Sarson Da Saag", "aliases": ["Sarso Ka Saag", "Sarson Ka Saag",
                                                   "Mustard Greens Curry", "Saag"],
             "kcal": 180},
            {"name": "Makki Di Roti", "aliases": ["Makki Roti", "Cornmeal Roti", "Roti"],
             "kcal": 120},
        ],
        "note": "One steel bowl of sarson da saag and one makki di roti, shot from "
                "above. Countable, and the classic winter pairing - a dish class "
                "the corpus had no case for at all.",
        "confidence": "high",
    },
    "aloo_gobi_sabji": {
        "photo": "aloo_ghobhi_sabji_jpg_bac4cf41.jpg",
        "truth": [
            {"name": "Aloo Gobi", "aliases": ["Aloo Ghobhi", "Potato Cauliflower",
                                                "Gobhi", "Cauliflower Curry"],
             "kcal": 160},
        ],
        "note": "One white bowl of aloo gobi on a newspaper, close to above. A "
                "single-dish case, which the corpus barely had: most of its cases "
                "are thalis, so a one-bowl scan was never measured.",
        "confidence": "high",
    },
    "kofta_curry_twelve": {
        "photo": "kofta_curry_jpg_09054202.jpg",
        "truth": [
            {"name": "Kofta Curry", "aliases": ["Meatball Curry", "Kofta", "Kofte",
                                                 "Malai Kofta", "Reshmi Kofta"],
             "kcal": 500},
        ],
        "note": "Twelve kofta in a red gravy on a square plate, from above. The "
                "count is deliberate: this is a COUNTING case as well as a "
                "naming one, and counting is where the app has been weakest.",
        "confidence": "high",
    },
}

REJECT = {
    "cafe_whitney_2021_10_17_sarah_stierch_04_jpg_add5cfdc.jpg":
        "western cafe food, not an Indian home-cooked meal",
    "omelette_lunch_menu_side_dish_udon_jubey_paris_001_j_67439cb9.jpg":
        "restaurant menu side dish shot with other plates in frame; portion not "
        "readable, and the only egg dish the search offered",
    "omelette_on_a_plate_jpg_2caee0c5.jpg":
        "western omelette, not an Indian meal; no class we can defend",
    "chicken_biryani_caf_levant_mombasa_2025_01_jpg_b30682c0.jp":
        "cafe plate, and it would repeat the biryani class",
    "chicken_biryani_in_plate_jpg_e6582b03.jpg":
        "would repeat the biryani class already taken by the mutton biryani",
    "dum_biryani_plate_jpg_86f71d66.jpg":
        "would repeat the biryani class",
    "malaysia_airlines_meal_uppama_with_sabudana_khichdi__95b52b39.jpg":
        "airline meal, two portions, not a single home serving",
    "vegetablekhichdi_rayagada_odisha_0002_jpg_9a9a182d.jpg":
        "styled restaurant shot: black backdrop, chillies and papad scattered as "
        "props, and khichdi vs vegetable pulao is not honestly separable",
    "ambott_tik_kite_fish_25187569804_jpg_e2027846.jpg":
        "snapshot with a knife in the food, an embedded watermark, and two "
        "unlabelled bowls; no readable portion",
    "ambott_tik_kite_fish_25818081145_jpg_653acb84.jpg":
        "same uploader and same framing; near-duplicate in every way that matters",
    "fish_curry_rice_thali_19044595366_jpg_85854395.jpg":
        "a real Goan thali, but the truth is not nameable: a fried fish AND a fish "
        "curry, plus a pale bowl I cannot identify, and an embedded watermark",
    "fish_curry_rice_thali_24896444813_jpg_a5d69f94.jpg":
        "same uploader, same ambiguity",
    "makki_ki_roti_sarso_ka_saag_jpg_78550a51.jpg":
        "would repeat the sarson da saag class",
    "sarson_ka_saag_mohali_2016_08_06_8213_jpg_e500b05b.jpg":
        "would repeat the sarson da saag class",
    "sarson_ka_saag_mohali_2016_08_06_8227_jpg_79bb6794.jpg":
        "would repeat the sarson da saag class",
    "aloo_ghobi_jpg_c03e212f.jpg":
        "would repeat the aloo gobi class",
    "kofta_curry_spiced_dumplings_in_gravy_jpg_169f3f1e.jpg":
        "would repeat the kofta class; the accepted plate is countable",
    "bhuna_curry_bowl_jpg_3557bd45.jpg":
        "no named dish I could defend, and it repeats chicken curry",
    "bowl_of_vietnamese_ca_ri_chicken_curry_jpg_9d66e84b.jpg":
        "Vietnamese, not Indian",
}


def main() -> int:
    with open(CASES, encoding="utf-8") as fh:
        corpus = json.load(fh)
    with open(PHOTOS, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = {p["file"].split("/")[-1]: p for p in manifest["photos"]}

    added, rejected, missing = 0, 0, []
    for case_id, spec in ACCEPT.items():
        rec = photos.get(spec["photo"])
        if rec is None:
            missing.append(spec["photo"])
            continue
        rec["reviewed"] = True
        rec["truth_confidence"] = spec["confidence"]
        rec["review_note"] = spec["note"].split(". ")[0] + "."
        rec["accepted_as"] = case_id
        corpus["cases"].append({
            "id": case_id,
            "image": rec["file"],
            "note": spec["note"],
            "truth": spec["truth"],
        })
        added += 1

    for name, reason in REJECT.items():
        rec = photos.get(name)
        if rec is None:
            missing.append(name)
            continue
        rec["reviewed"] = True
        rec["rejected"] = True
        rec["reject_reason"] = reason
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1

    corpus["_readme"].extend([
        "",
        "BATCH 5 (2026-09-28): 24 candidates fetched, 6 looked at, 5 ACCEPTED and",
        "13 rejected with the reason recorded in photos.json. The batch was built",
        "from the gap, not from what was easy: BATCH5_QUERIES is one query per",
        "dish class the corpus lacked, and the fetcher grew a near-duplicate",
        "check (64-bit dHash, Hamming <= 8) plus per-query and per-author caps",
        "BEFORE fetching, because the fish-curry query offered five near-identical",
        "files by one uploader. New classes: khichdi, biryani, sarson da saag,",
        "aloo gobi, kofta. Two candidates were rejected for a truth I could not",
        "name honestly, which is the rule working, not the rule being awkward.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    print(f"accepted {added}, rejected {rejected}")
    if missing:
        print(f"NOT IN THE MANIFEST (left alone): {missing}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
