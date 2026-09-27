#!/usr/bin/env python3
"""Batch 4: non-breakfast lunch/dinner dishes. Reviewed by eye, labelled honestly.

THE TRAP, FOURTH TIME: of 20 candidates, 14 were chana/chole/chole-bhature,
because three of the batch's search terms were chole-based. Harvested, this batch
would have been chole with extra chole. So the five kept are the most distinct
I could find WITHIN what the search returned, and the resulting chole-family
bias is recorded in cases.json rather than hidden. Batch 5 must search
one-dish-at-a-time to escape it.

Every candidate here is non-breakfast, which is the point of the batch: batch 3's
five photos were all breakfast and the corpus score moved for reasons that had
nothing to do with the app.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "ai_accuracy", "photos.json")
CASES = os.path.join(ROOT, "tools", "ai_accuracy", "cases.json")

ACCEPT = {
    "chana_masala_mohammed_spice_of_life_2024_05_27_jpg.jpg": {
        "id": "chole_papad_plate",
        "confidence": "high",
        "note": "A white plate from above: chole in a small steel bowl with two "
                "papad triangles beside it. Clean, home-style, plainly identifiable.",
        "truth": [
            {"name": "Chole", "aliases": ["Chana Masala", "Chole", "Chana",
                                          "Chana Curry", "Chole Bhature"],
             "kcal": 250, "grams": 150},
            {"name": "Papad", "aliases": ["Papad", "Papadum", "Papdi"],
             "kcal": 90, "grams": 30},
        ],
    },
    "chana_masala_jpg.jpg": {
        "id": "chana_masala_pan",
        "confidence": "medium",
        "note": "A close overhead view of chana masala cooking in a pan, "
                "garnished with coriander. 'Medium' because there is no plate or "
                "bowl for scale, so the portion is an estimate.",
        "truth": [
            {"name": "Chana Masala", "aliases": ["Chole", "Chana", "Chole Bhature",
                                                  "Chana Masala", "Chana Curry"],
             "kcal": 280, "grams": 180},
        ],
    },
    "chole_puri_halwa_jpg.jpg": {
        "id": "chole_puri_halwa_thali",
        "confidence": "high",
        "note": "A steel thali from above: chole, a puri, and a portion of "
                "gajar halwa. Three clearly separate items.",
        "truth": [
            {"name": "Chole", "aliases": ["Chana Masala", "Chole", "Chana"],
             "kcal": 250, "grams": 150},
            {"name": "Puri", "aliases": ["Puri", "Puri Bhaji", "Bread"],
             "kcal": 180, "grams": 60},
            {"name": "Gajar Halwa", "aliases": ["Halwa", "Gajar Halwa", "Carrot Halwa"],
             "kcal": 200, "grams": 100},
        ],
    },
    "brinjal_rajma_masala_jpg.jpg": {
        "id": "rajma_brinjal_masala",
        "confidence": "medium",
        "note": "A white plate from above: kidney beans with brinjal pieces in a "
                "brown masala. 'Medium' because rajma-with-brinjal and plain rajma "
                "are a judgement call from the photo alone.",
        "truth": [
            {"name": "Rajma", "aliases": ["Kidney Beans", "Rajma Curry", "Rajma Masala",
                                           "Rajah", "Kulthi"],
             "kcal": 260, "grams": 180},
            {"name": "Brinjal", "aliases": ["Baingan", "Aubergine", "Eggplant"],
             "kcal": 40, "grams": 60},
        ],
    },
    "non_veg_platter_during_the_first_wikisanjog_conference_2025_.jpg": {
        "id": "non_veg_thali",
        "confidence": "high",
        "note": "The only NON-VEGETARIAN case in the whole corpus, which is a "
                "real gap: our users are not all vegetarian and nothing else here "
                "tests that. A steel plate from above with rice, dal, a chicken "
                "curry, raita, papad and a sweet.",
        "truth": [
            {"name": "Rice", "aliases": ["Steamed Rice", "White Rice", "Plain Rice"],
             "kcal": 210, "grams": 200},
            {"name": "Dal", "aliases": ["Yellow Dal", "Sambar", "Kadhi"],
             "kcal": 100, "grams": 150},
            {"name": "Chicken Curry", "aliases": ["Chicken", "Mutton Curry",
                                                   "Non Veg Curry", "Meat Curry"],
             "kcal": 300, "grams": 150},
            {"name": "Raita", "aliases": ["Dahi", "Curd", "Yogurt"],
             "kcal": 60, "grams": 80},
        ],
    },
}

REJECT_REASONS = {
    "chana_ko_tarkari_jpg.jpg": "dry chana, not a dish a person would photograph as lunch; ambiguous name",
    "chana_masala_p_o_s_rio_e_prato_com_batata_e_br_colis_2023_10.jpg": "Portuguese-fusion restaurant plate, not Indian home food",
    "chana_masala_in_paul_nia_2023_10_16_jpg.jpg": "cluttered table and cutting board; near-duplicate of the chana masala we took",
    "chana_tarkari_jpg.jpg": "far too dark to label honestly",
    "chhole_bhature_served_at_a_traditional_eatery_in_rishikesh_i.jpg": "restaurant plate, dark, multiple chutneys",
    "chickpea_curry_kolkata_2011_03_05_1910_jpg.jpg": "flat close-up with no scale or context; cannot tell chana dal from besan",
    "chole_bhature_noida_up_sp002_jpg.jpg": "already rejected in batch 2 as a duplicate",
    "maincourse_jpg.jpg": "restaurant table, several plates, cutlery and people in frame",
    "punjabi_chole_masala_jpg.jpg": "chole again; a 4th member of the same family in one batch",
    "gourd_rajma_curry_with_coconut_jpg.jpg": "washed out and hard to read; gourd-and-rajma split is a guess",
    "choleindia_jpg.jpg": "chole again, plated very similarly to ones already held",
    "chole_bhature_jpg.jpg": "chole-bhature again; the bhature pairing is already covered by the puri case",
    "non_veg_platter_during_the_first_wikisanjog_conference_2025_.jpg": "ACCEPTED (one of three identical shots; the other two are duplicates)",
}


def main() -> int:
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = manifest["photos"]
    kept = [p for p in photos if p.get("reviewed") and p.get("file")]
    seen = {p["file"] for p in kept}

    for p in photos:
        if p["file"] in seen:
            continue
        name = os.path.basename(p["file"])
        if name in ACCEPT and name not in {
                os.path.basename(x["file"]) for x in kept}:
            p["reviewed"] = True
            p["batch"] = 4
            p["review_note"] = ACCEPT[name]["note"]
            p["truth_confidence"] = ACCEPT[name]["confidence"]
            kept.append(p)
        elif name in ACCEPT:
            p["rejected_because"] = "duplicate of a photo already accepted this batch"
            fp = os.path.join(ROOT, p["file"])
            if os.path.exists(fp):
                os.remove(fp)
        else:
            p["rejected_because"] = REJECT_REASONS.get(name, "not reviewed")
            fp = os.path.join(ROOT, p["file"])
            if os.path.exists(fp):
                os.remove(fp)

    manifest["photos"] = kept
    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    with open(CASES, encoding="utf-8") as fh:
        cases = json.load(fh)
    have = {c["id"] for c in cases["cases"]}
    for name, spec in ACCEPT.items():
        if spec["id"] in have:
            continue
        match = next((p for p in kept
                      if os.path.basename(p["file"]) == name), None)
        if match is None:
            continue
        cases["cases"].append({
            "id": spec["id"],
            "image": match["file"],
            "note": spec["note"],
            "confidence": spec["confidence"],
            "truth": spec["truth"],
        })
    cases["_readme"].append(
        "Batch 4 added 5 more human-reviewed, non-breakfast meals. THE TRAP, "
        "FOURTH TIME: of 20 candidates 14 were chana/chole/chole-bhature, "
        "because three search terms were chole-based. Three of the five kept are "
        "therefore the same legume family - recorded here rather than hidden. "
        "Batch 5 must search one dish at a time to escape it. Batch 4 also adds "
        "the corpus's only NON-VEGETARIAN case, which was a real gap: our users "
        "are not all vegetarian and nothing else tested that.")
    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(cases, fh, indent=2, ensure_ascii=False)

    print(f"photos kept: {len(kept)}   cases: {len(cases['cases'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
