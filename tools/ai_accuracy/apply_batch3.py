#!/usr/bin/env python3
"""Batch 3: five South-Indian breakfast meals, reviewed by eye, labelled honestly.

Same discipline as batches 1-2: an unseen photo is not accepted, a duplicate dish
is rejected so the corpus measures breadth, and a hotel or food-court shot is
rejected because it is not home cooking.

THE TRAP, THIRD TIME: of 18 candidates, 8 were masala dosa and 7 were idli.
Commons returns whatever a dish is famous for, so a corpus harvested rather than
curated scores beautifully and means nothing. Five dosas in a row would have
hidden every other weakness.

THE HONEST LIMIT OF THIS BATCH: because the queries were breakfast items, all
five accepted photos are South-Indian breakfast. That is a real bias and it is
recorded here rather than hidden - batch 4 must target curries, eggs and
non-breakfast home cooking before any overall score is quoted.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "ai_accuracy", "photos.json")
CASES = os.path.join(ROOT, "tools", "ai_accuracy", "cases.json")

ACCEPT = {
    "masala_dosa_10_jpg.jpg": {
        "id": "masala_dosa_plate",
        "confidence": "medium",
        "note": "A folded masala dosa on a steel plate with two small bowls of "
                "chutney, shot from above. 'Medium' because the filling inside "
                "the fold is not visible, so the potato-vs-onion split is a "
                "judgement call, and the two chutneys cannot be told apart.",
        "truth": [
            {"name": "Masala Dosa", "aliases": ["Dosa", "Masala Dosa", "Dosa Plain"],
             "kcal": 250, "grams": 120},
            {"name": "Chutney", "aliases": ["Coconut Chutney", "Mint Chutney",
                                             "Chutney", "Dosa Chutney"],
             "kcal": 40, "grams": 40},
        ],
    },
    "camerazoom_20150614100720279_jpg.jpg": {
        "id": "idli_sambar_chutney_plate",
        "confidence": "high",
        "note": "A white plate from above: four steamed idli and two small bowls, "
                "one pale brown and one orange. Home-style, not styled.",
        "truth": [
            {"name": "Idli", "aliases": ["Steamed Idli", "Idli", "Idli Medu"],
             "kcal": 120, "grams": 100},
            {"name": "Sambar", "aliases": ["Sambar", "Dal", "Idli Sambar"],
             "kcal": 90, "grams": 120},
            {"name": "Chutney", "aliases": ["Coconut Chutney", "Chutney"],
             "kcal": 40, "grams": 30},
        ],
    },
    "rava_idli_jpg.jpg": {
        "id": "rava_idli_home",
        "confidence": "high",
        "note": "Rava idli in a steel bowl on a home table, with sambar in a "
                "black bowl and two chutney bowls. Overhead and plainly home-cooked.",
        "truth": [
            {"name": "Rava Idli", "aliases": ["Idli", "Rava Idli", "Steamed Idli"],
             "kcal": 150, "grams": 100},
            {"name": "Sambar", "aliases": ["Sambar", "Dal"],
             "kcal": 90, "grams": 120},
            {"name": "Chutney", "aliases": ["Coconut Chutney", "Chutney"],
             "kcal": 40, "grams": 30},
        ],
    },
    "tamil_uthappam_jpg.jpg": {
        "id": "tamil_uthappam",
        "confidence": "high",
        "note": "A single uthappam on a banana leaf with small bowls of sambar "
                "and chutney. Unmistakable and clearly a home serving.",
        "truth": [
            {"name": "Uthappam", "aliases": ["Uttappam", "Uthapam", "Dosa",
                                              "Uthappam", "Idli Dosa"],
             "kcal": 180, "grams": 100},
            {"name": "Sambar", "aliases": ["Sambar", "Dal"],
             "kcal": 90, "grams": 100},
            {"name": "Chutney", "aliases": ["Coconut Chutney", "Chutney"],
             "kcal": 40, "grams": 30},
        ],
    },
    "idli_with_sambar_chutney_tirupati_andhra_pradesh_dsc_0009_jp.jpg": {
        "id": "andhra_idli_vada_sambar",
        "confidence": "medium",
        "note": "On a banana leaf: two idli, one golden vada, a bowl of sambar "
                "and chutney, with a steel tumbler. 'Medium' because vada and "
                "boondi in the sambar can be confused at this size.",
        "truth": [
            {"name": "Idli", "aliases": ["Idli", "Steamed Idli"],
             "kcal": 90, "grams": 70},
            {"name": "Vada", "aliases": ["Medu Vada", "Vada", "Uttapam Vada"],
             "kcal": 150, "grams": 60},
            {"name": "Sambar", "aliases": ["Sambar", "Dal"],
             "kcal": 90, "grams": 100},
        ],
    },
}

REJECT_REASONS = {
    "benne_masala_dosa_jpg.jpg": "second dosa; 8 of 18 candidates were dosa",
    "dosa_thali_jpg.jpg": "restaurant banana-leaf thali, not home cooking",
    "dosai_chutney_hotel_saravana_bhavan_jpg.jpg": "hotel (Saravana Bhavan), styled, brass tray",
    "food_court_01_jpg.jpg": "food-court tray, and a person's hand is in frame",
    "masala_dosa_from_kerala_3_jpg.jpg": "third dosa, and the tray contents are ambiguous",
    "mushroom_masala_dosa_jpg.jpg": "fourth dosa",
    "mylari_dosa_01_jpg.jpg": "fifth dosa",
    "idli_sambar_south_indian_jpg.jpg": "dark and low contrast, and a near-duplicate of the idli we took",
    "idli_plate_with_sambar_and_coconut_cue.jpg": "second idli; filename truncated, contents ambiguous",
    "idli_plate_with_sambar_and_coconut_chutney_jpg.jpg": "third idli, near-duplicate",
    "rava_idli_recipe_by_sonia_goyal_jpg.jpg": "near-duplicate of the rava idli we took",
    "round_idli_sambhar_jpg.jpg": "another idli; 7 of 18 candidates were idli",
    "mini_uttappam_jpg.jpg": "near-duplicate of the uthappam we took",
    "onion_uttappam_01_jpg.jpg": "near-duplicate uthappam",
}


def main() -> int:
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = manifest["photos"]
    kept = [p for p in photos if p.get("reviewed") and p.get("file")]

    for p in photos:
        if p in kept:
            continue
        name = os.path.basename(p["file"])
        if name in ACCEPT:
            p["reviewed"] = True
            p["batch"] = 3
            p["review_note"] = ACCEPT[name]["note"]
            p["truth_confidence"] = ACCEPT[name]["confidence"]
            kept.append(p)
        else:
            p["rejected_because"] = REJECT_REASONS.get(name, "not reviewed")
            path = os.path.join(ROOT, p["file"])
            if os.path.exists(path):
                os.remove(path)

    manifest["photos"] = kept
    manifest.setdefault("rejected", []).extend(
        [p for p in photos if p.get("reviewed") is not True and
         os.path.basename(p["file"]) not in ACCEPT])
    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    with open(CASES, encoding="utf-8") as fh:
        cases = json.load(fh)
    have = {c["id"] for c in cases["cases"]}
    for name, spec in ACCEPT.items():
        if spec["id"] in have:
            continue
        cases["cases"].append({
            "id": spec["id"],
            "image": next(p["file"] for p in kept
                          if os.path.basename(p["file"]) == name),
            "note": spec["note"],
            "confidence": spec["confidence"],
            "truth": spec["truth"],
        })
    cases["_readme"].append(
        "Batch 3 added 5 more openly licensed, human-reviewed meals. THE TRAP, "
        "THIRD TIME: of 18 candidates 8 were masala dosa and 7 were idli, so "
        "only 5 distinct dishes were taken. THE HONEST LIMIT: because the "
        "queries were breakfast items, all five are South-Indian breakfast. "
        "That is a real bias in the corpus; batch 4 must target curries, eggs "
        "and non-breakfast home cooking before any overall score is quoted.")
    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(cases, fh, indent=2, ensure_ascii=False)

    print(f"photos kept: {len(kept)}   cases: {len(cases['cases'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
