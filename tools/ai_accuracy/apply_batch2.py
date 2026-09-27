#!/usr/bin/env python3
"""Batch 2: keep the five reviewed photos, delete the rest, add the truth.

Same discipline as batch 1: an unseen photo is not accepted, a photo whose
dishes I cannot name honestly is deleted rather than guessed at, and duplicates
of a dish we already hold are rejected so the corpus measures breadth.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "ai_accuracy", "photos.json")
CASES = os.path.join(ROOT, "tools", "ai_accuracy", "cases.json")

ACCEPT = {
    "bhindi_masala_49657981033_jpg.jpg": {
        "id": "bhindi_masala_rice",
        "confidence": "high",
        "note": "White oval plate from above: a mound of white rice and bhindi "
                "masala (okra in a red gravy, coriander and green chilli).",
        "truth": [
            {"name": "Rice", "aliases": ["Steamed Rice", "White Rice", "Plain Rice"],
             "kcal": 210, "grams": 200},
            {"name": "Bhindi Masala", "aliases": ["Bhindi", "Okra", "Bhindi Curry",
                                                   "Masala Bhindi", "Lady Finger"],
             "kcal": 180, "grams": 150},
        ],
    },
    "baingan_ka_bhurta_cropped_jpg.jpg": {
        "id": "baingan_bharta",
        "confidence": "high",
        "note": "One white plate, overhead: a mound of roasted mashed eggplant "
                "with visible seeds and green chilli. A single dish.",
        "truth": [
            {"name": "Baingan Bharta", "aliases": ["Baingan", "Bharta", "Eggplant",
                                                    "Baingan Ka Bharta", "Aubergine"],
             "kcal": 120, "grams": 150},
        ],
    },
    "bottle_gourd_curry_jpg.jpg": {
        "id": "lauki_curry",
        "confidence": "high",
        "note": "A steel bowl on a plain blue background, shot from above: pale "
                "green bottle-gourd cubes in a thin yellow-brown gravy.",
        "truth": [
            {"name": "Lauki Ki Sabzi", "aliases": ["Bottle Gourd", "Lauki", "Doodhi",
                                                    "Bottle Gourd Curry", "Gourd Curry"],
             "kcal": 110, "grams": 200},
        ],
    },
    "matar_paneer_jpg.jpg": {
        "id": "matar_paneer_bowl",
        "confidence": "medium",
        "note": "A yellow bowl of matar paneer (paneer strips and green peas in an "
                "orange-red gravy). Loose peas and a block of paneer sit beside "
                "the bowl as styling, and are NOT labelled - a person "
                "photographing their lunch would log the bowl. That choice is why "
                "this case is 'medium'.",
        "truth": [
            {"name": "Matar Paneer", "aliases": ["Paneer", "Paneer Curry", "Matar",
                                                 "Peas Paneer", "Shaahi Paneer"],
             "kcal": 280, "grams": 200},
        ],
    },
    "bhendi_chapati_and_dal_rice_jpg.jpg": {
        "id": "chapati_dal_bhindi_plate",
        "confidence": "medium",
        "note": "A square plate: two chapati, a chopped green bhindi sabzi and a "
                "yellow dal. NOTE: the file is named '...and_dal_rice' but there "
                "is NO rice in the photo - I labelled from the image, not the "
                "filename. There is also a small dark item at the plate edge I "
                "cannot identify, so it is left unlabelled rather than guessed.",
        "truth": [
            {"name": "Roti", "aliases": ["Chapati", "Roti", "Flatbread", "Phulka"],
             "kcal": 240, "grams": 80},
            {"name": "Dal", "aliases": ["Yellow Dal", "Dal Tadka", "Kadhi"],
             "kcal": 100, "grams": 150},
            {"name": "Bhindi Sabzi", "aliases": ["Bhindi", "Okra", "Bhindi Masala",
                                                  "Sabzi", "Lady Finger"],
             "kcal": 120, "grams": 100},
        ],
    },
}

REJECT_REASONS = {
    "bhindi_fry_jpg.jpg": "second bhindi; we already hold bhindi in batch 2 and the corpus needs breadth",
    "bhindi_masala_jpg.jpg": "third bhindi - near-duplicate of the accepted one",
    "bhindi_masala6b28f933_2ad2_4ad5_8d5d_7105f119c55f_jpg.jpg": "fourth bhindi, and a restaurant starter plate",
    "fried_okra_jpg.jpg": "extreme macro close-up, out of focus, unusable",
    "karari_bhindi_jpg.jpg": "another bhindi; ornate plate, dry garnish",
    "masala_bhindi_jpg.jpg": "another bhindi, and too dark to label honestly",
    "lauki_kofta_curry_jpg.jpg": "second lauki, and the kofta count is not countable - I would be guessing",
    "lauki_and_chana_dal_curry_jpg.jpg": "third lauki",
    "home_made_matar_paneer_img_20210331_214025_01_jpg.jpg": "duplicate matar paneer and far too dark to label",
    "looking_towards_muchelney_from_the_river_parrett_geograph_or.jpg": "NOT FOOD - a river photograph, the search matched the word 'parrett'",
    "walk_along_the_parrett_trail_taken_near_muchelney_bridge_geo.jpg": "NOT FOOD - a bridge/field photograph",
    "bhindi_chapati_and_dal_rice_jpg.jpg": "ACCEPTED",
    "bhindi_masala_49657981033_jpg.jpg": "ACCEPTED",
    "baingan_ka_bhurta_cropped_jpg.jpg": "ACCEPTED",
    "bottle_gourd_curry_jpg.jpg": "ACCEPTED",
    "matar_paneer_jpg.jpg": "ACCEPTED",
}


def main() -> int:
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = manifest["photos"]
    already = {p["file"] for p in manifest.get("photos", [])
               if p.get("reviewed") and "photos/" in p.get("file", "")}

    kept = [p for p in photos if p["file"] in already]
    for p in photos:
        if p["file"] in already:
            continue
        name = os.path.basename(p["file"])
        if name in ACCEPT:
            p["reviewed"] = True
            p["batch"] = 2
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
        [p for p in photos if p["file"] not in already
         and os.path.basename(p["file"]) not in ACCEPT])
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
        "Batch 2 added 5 more openly licensed, human-reviewed meals, chosen for "
        "dish BREADTH: 8 of the 16 candidates were bhindi, exactly the trap "
        "batch 1 hit with chole bhature, so only one bhindi was taken.")
    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(cases, fh, indent=2, ensure_ascii=False)

    print(f"photos kept: {len(kept)}   cases: {len(cases['cases'])}")
    for c in cases["cases"]:
        print(f"  {c['id']:<26} {len(c['truth'])} dish(es)  {c['image']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
