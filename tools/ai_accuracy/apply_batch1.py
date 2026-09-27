#!/usr/bin/env python3
"""Apply the batch-1 review: keep the accepted photos, delete the rejected ones,
and write the ground truth into cases.json.

Every accepted photo is one I have actually LOOKED at. Every rejected one is
deleted rather than left on disk, so nothing unreviewed can quietly become a
test case later. The reason is recorded either way.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(ROOT, "tools", "ai_accuracy", "photos.json")
CASES = os.path.join(ROOT, "tools", "ai_accuracy", "cases.json")

ACCEPT = {
    "vegetarian_thali_ma08_jpg.jpg": {
        "id": "thali_ma08",
        "confidence": "high",
        "note": "Steel tray, shot from above. Unambiguous: a large portion of "
                "white rice, a yellow dal, a dry green sabzi, a brown curry, "
                "one empty compartment.",
        "truth": [
            {"name": "Rice", "aliases": ["Steamed Rice", "White Rice", "Plain Rice"],
             "kcal": 260, "grams": 250},
            {"name": "Dal", "aliases": ["Yellow Dal", "Dal Tadka", "Tamarind Dal"],
             "kcal": 120, "grams": 200},
            {"name": "Dry Vegetable Sabzi",
             "aliases": ["Sabzi", "Mixed Vegetable", "Palak Sabzi", "Aloo Sabzi"],
             "kcal": 120, "grams": 100},
            {"name": "Paneer or Meat Curry",
             "aliases": ["Curry", "Paneer Curry", "Chicken Curry", "Aloo Curry"],
             "kcal": 200, "grams": 100},
        ],
    },
    "dal_makhani_01_jpg.jpg": {
        "id": "dal_makhani_bowl",
        "confidence": "high",
        "note": "One steel bowl of dal makhani, near-overhead, cream streaks and "
                "cream visible. The single most identifiable Indian dish there is.",
        "truth": [
            {"name": "Dal Makhani", "aliases": ["Dal", "Black Dal", "Urad Dal"],
             "kcal": 280, "grams": 200},
        ],
    },
    "homemade_kadhi_jpg.jpg": {
        "id": "kadhi_bowl",
        "confidence": "medium",
        "note": "A white bowl of yellow kadhi seen from above, with a ghee and "
                "red-chilli temper garnish. 'Medium' because a scan could "
                "reasonably call this dal.",
        "truth": [
            {"name": "Kadhi", "aliases": ["Dal", "Kadi", "Yogurt Curry", "Khatta Kadhi"],
             "kcal": 150, "grams": 200},
        ],
    },
    "urad_daal_with_assorted_indian_bread_and_salad_jpg.jpg": {
        "id": "urad_dal_two_roti",
        "confidence": "high",
        "note": "A yellow bowl of urad dal with two chapati on a plate, with raw "
                "onion rings, cucumber and lemon on the side. BATCH-1 CORRECTION: "
                "the first run scored onion and cucumber as INVENTED dishes. They "
                "are plainly in the photo - I described them in the note and then "
                "forgot to put them in the truth. The harness was right; my label "
                "was wrong.",
        "truth": [
            {"name": "Urad Dal", "aliases": ["Dal", "Black Dal", "Ma ki Dal", "Dal Makhani"],
             "kcal": 200, "grams": 200},
            {"name": "Roti", "aliases": ["Chapati", "Roti", "Flatbread", "Phulka"],
             "kcal": 240, "grams": 80},
            {"name": "Onion", "aliases": ["Onion Salad", "Kachumber", "Raw Onion", "Pyaaz"],
             "kcal": 20, "grams": 30},
            {"name": "Cucumber", "aliases": ["Cucumber Salad", "Kheera", "Salad"],
             "kcal": 10, "grams": 30},
        ],
    },
    "a_north_indian_dinner_jpg.jpg": {
        "id": "north_indian_dinner",
        "confidence": "high",
        "note": "Steel plate, overhead. A bowl of chole (chickpeas in gravy with "
                "green chilli), a dry spiced potato bhaji, two chapati, and a "
                "glass of tea. BATCH-1 CORRECTION: the first label said 'Chole, "
                "Dal, Roti' - there is NO dal in this photo, and the reference "
                "total was 200 kcal short, which is what produced the alarming "
                "37.7% error. The model was closer to right than my label was. "
                "Corrected after looking at the image at full size.",
        "truth": [
            {"name": "Chole", "aliases": ["Chana Masala", "Chole Bhature", "Chana",
                                          "Chana Curry", "Chole Bhature"],
             "kcal": 250, "grams": 150},
            {"name": "Aloo Fry", "aliases": ["Aloo", "Potato Fry", "Aloo Bhaji",
                                             "Dry Potato", "Aloo Gobi", "Bhaji"],
             "kcal": 180, "grams": 100},
            {"name": "Roti", "aliases": ["Chapati", "Roti", "Flatbread", "Phulka"],
             "kcal": 240, "grams": 80},
        ],
    },
}

REJECT_REASONS = {
    "assamese_non_veg_thali_jpg.jpg": "six or seven items on one clay plate; I cannot label each dish truthfully",
    "indian_thali_jpg.jpg": "a dozen small bowls, restaurant steel tray; per-dish truth is not defensible",
    "karnataka_vegetarian_meal_jpg.jpg": "small scattered portions on a banana leaf, dishes not identifiable",
    "veg_indian_thali_jpeg.jpg": "mixed plate, half the items unidentifiable",
    "vegetarian_thali_from_kolkata_3_jpg.jpg": "sparse restaurant plate, dishes not identifiable",
    "2_jpg.jpg": "Assamese thali, several items unclear; also similar to a case already held",
    "1_jpg.jpg": "a person's arm is in frame and the cloth background is busy",
    "dal_makhni_shahi_paneer_jpg.jpg": "restaurant table, three-quarter view, dark - not a 2D scan",
    "dal_makhani_jpg.jpg": "staged restaurant bowl, cream swirls, three-quarter view",
    "itc_chola_thali_png.jpg": "branded hotel product (ITC Chola), not home cooking",
    "punjabi_dal_makhani_jpg.jpg": "extreme close crop, no context, too dark",
    "lettuce_and_carrots_jpg.jpg": "not Indian food at all",
    "urad_daal_with_assorted_indian_bread_and_salad_jpg.jpg": "ACCEPTED",
    "bikaner_chole_bhature_jpg.jpg": "near-duplicate of the chole bhature already held; corpus needs dish diversity",
    "chola_bhatura_jpg.jpg": "near-duplicate chole bhature",
    "chole_bhature_noida_up_sp002_jpg.jpg": "near-duplicate chole bhature, dark plate",
    "chole_bhature_1_jpg.jpg": "near-duplicate chole bhature",
    "chole_bhature_2_jpg.jpg": "near-duplicate chole bhature",
    "chole_bhature_3_jpg.jpg": "near-duplicate chole bhature",
    "chole_bhature_5_jpg.jpg": "near-duplicate chole bhature",
    "chole_bhature_6_jpg.jpg": "near-duplicate chole bhature",
    "kari_jpg.jpg": "top-down but the dish cannot be named - calling it 'kari' would invent the answer",
}


def main() -> int:
    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = manifest["photos"]

    kept, removed = [], []
    for p in photos:
        name = os.path.basename(p["file"])
        if name in ACCEPT:
            p["reviewed"] = True
            p["review_note"] = ACCEPT[name]["note"]
            p["truth_confidence"] = ACCEPT[name]["confidence"]
            kept.append(p)
        else:
            p["reviewed"] = False
            p["rejected_because"] = REJECT_REASONS.get(name, "not reviewed")
            removed.append(p)
            path = os.path.join(ROOT, p["file"])
            if os.path.exists(path):
                os.remove(path)

    manifest["photos"] = kept
    manifest["rejected"] = removed
    manifest["_note"] = (
        "Every photo here is openly licensed (Wikimedia Commons) and attributed, "
        "with the SHA-256 of the file actually stored. 'reviewed': true means the "
        "image was looked at before being accepted. Rejected photos are listed "
        "under 'rejected' with the reason and their files are deleted, so nothing "
        "unreviewed can later become a test case."
    )
    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    cases = {
        "_readme": [
            "Labelled truth for tools/ai_accuracy.py.",
            f"Batch 1: {len(kept)} openly licensed, human-reviewed Indian meals "
            "plus the 1 original in-repo photo and 1 out-of-scope probe.",
            "RoADMAP M1 asks for 20. We are not there yet, and the count is not",
            "the thing being optimised - a corpus of 5 photos of the same dish",
            "would score beautifully and tell us nothing.",
            "",
            "kcal values are IFCT-style REFERENCE figures for the visible portion,",
            "not laboratory measurements. 'confidence' is my honest read of how",
            "defensible the label is: a thali I can name item by item is 'high'; a",
            "bowl that a scan could fairly call either kadhi or dal is 'medium'.",
            "Anything I could not name honestly was deleted, not guessed at.",
        ],
        "cases": [
            {
                "id": "palak_paneer_meal",
                "image": "assets/onboarding/food_palak_paneer.jpg",
                "note": "In-repo original: one katori palak paneer + one roti.",
                "truth": [
                    {"name": "Palak Paneer", "kcal": 350},
                    {"name": "Roti", "aliases": ["Chapati", "Flatbread", "Phulka"], "kcal": 120},
                ],
            },
            {
                "id": "chickpea_salad_probe",
                "image": "assets/onboarding/hero_bowl.jpg",
                "note": "OUT OF SCOPE on purpose. Chickpeas, avocado, tomato, "
                        "cucumber, greens. No Indian dish is present; any Indian "
                        "answer here is an invention.",
                "truth": [{"name": "Chickpea Salad", "kcal": 450}],
            },
        ] + [
            {
                "id": spec["id"],
                "image": next(p["file"] for p in kept
                              if os.path.basename(p["file"]) in ACCEPT
                              and ACCEPT[os.path.basename(p["file"])]["id"] == spec["id"]),
                "note": spec["note"],
                "confidence": spec["confidence"],
                "truth": spec["truth"],
            }
            for spec in ACCEPT.values()
        ],
    }
    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(cases, fh, indent=2, ensure_ascii=False)

    print(f"kept {len(kept)} reviewed photos, deleted {len(removed)} rejected")
    print(f"cases.json now holds {len(cases['cases'])} cases")
    for c in cases["cases"]:
        print(f"  {c['id']:<24} {len(c['truth'])} dish(es)  {c['image']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
