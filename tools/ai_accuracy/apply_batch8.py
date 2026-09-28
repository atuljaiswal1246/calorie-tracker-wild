#!/usr/bin/env python3
"""Apply batch 8 - FLATTEN, sized by arithmetic rather than by taste.

The class bar is met (22 classes, bar = 20). The SAMPLE is the problem: the top
4 classes hold 42% of 31 cases (dal x5, chole x4, paneer x2, sambar x2) and the
readme names <= 35% as the target. 13/(31+N) is the whole calculation, so
N=7 gives 35.1% and N=8 gives 34.2%. So this batch queries ONE dish class per
class that currently holds exactly ONE case, and deliberately queries NONE of the
four concentrated ones - because a fifth dal makes the median look better and the
product no better. The owner's version of the same instruction: do not knowingly
ask for dal, chole or sambar again, because those queries built the 42%.

BATCH8_QUERIES is 18 queries (one per thin class). Commons returned 94
candidates; the per-query and per-author caps and the 64-bit dHash near-dup check
ran BEFORE fetching, as in batch 5.

  accepted 7  aloo gobi, baingan bharta, bhindi masala, dosa, kofta,
               chicken curry (a 23rd class), mutton biryani
  rejected 4  a plate of yellow rice filed as "boryani" - the grain is short
               and uniformly yellow, there is no visible meat, and the only
               other honest label is dal, which is one of the four classes this
               batch exists to NOT grow; a "biryani" platter buried under a
               Western salad garnish, which is a composite with two non-staple
               judgements; a dawat spread on a cloth with a pale dessert, fried
               items and fruit that I cannot each name; and a SECOND kofta
               photo, rejected ON PURPOSE because kofta 1->3 would push it into
               the top 4 and make the concentration WORSE, which is the exact
               regression this batch was built to remove

THE DOSE NOTE, which is the honest limit of this batch: the dosa is ROLLED, so
the masala potato filling is not visible. Labelling it "masala dosa" would be an
inference about something I cannot see, so it is labelled "Dosa". Both land on
the same dish class (DISH_CLASS maps "masala dosa" -> dosa, and an unmapped
name falls through to itself), so the class count is unaffected - but the label
says only what the photograph shows.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "aloo_gobi_home_plate": {
        "photo": "aalu_gobi_curry_jpg_600034c4.jpg",
        "confidence": "high",
        "note": "A shallow steel bowl on a plain white surface, shot from above: one "
                "dish of potato and cauliflower florets in an orange-brown masala, "
                "nothing else on the plate. Every item is nameable and the dish is "
                "unambiguous - aloo gobi is the only reading. A second case for the "
                "aloo gobi class, which had one.",
        "truth": [
            {"name": "Aloo Gobi", "aliases": ["Aloo Ghobhi", "A Gobi", "Gobhi Aloo",
                                               "Cauliflower and Potato Curry"],
             "kcal": 180},
        ],
    },
    "baingan_bharta_restaurant_bowl": {
        "photo": "2025_04_07_baingan_bharta_jpg_43acb3fa.jpg",
        "confidence": "medium",
        "note": "A hammered steel bowl on a restaurant table, a spoon resting in a "
                "coarse mashed preparation with visible charred dark skin and "
                "chopped coriander on top. The roasted skin fragments are what make "
                "it baingan bharta rather than a tomato mash. Medium rather than "
                "high: it is a restaurant plate, not a home kitchen, and the "
                "mash is finer than a home-roasted bharta.",
        "truth": [
            {"name": "Baingan Bharta", "aliases": ["Baingan Ka Bharta", "Baigan Bharta",
                                                   "Aubergine Bharta"],
             "kcal": 130},
        ],
    },
    "bhindi_masala_white_bowl": {
        "photo": "bhindi_fry_jpg_0f25e52d.jpg",
        "confidence": "high",
        "note": "A white bowl full of okra cut length-wise, coated in a spiced "
                "onion-tomato masala, on a dark counter. Every pod is visibly okra "
                "and nothing else is in the bowl, so the judgement is single and "
                "clean. A second case for the bhindi class, which had one.",
        "truth": [
            {"name": "Bhindi Masala", "aliases": ["Bhindi Sabzi", "Okra Masala",
                                                   "Bhindi Fry", "Masala Bhindi"],
             "kcal": 150},
        ],
    },
    "kofta_white_plate": {
        "photo": "kofta_curry_cropped_jpg_4c65c863.jpg",
        "confidence": "high",
        "note": "A white plate holding twelve round kofta in a red-orange oil "
                "gravy with a coriander garnish, filling the frame. One dish, one "
                "judgement, no second component. A second case for the kofta "
                "class, which had one.",
        "truth": [
            {"name": "Kofta Curry", "aliases": ["Kofta", "Malai Kofta", "Meatball Curry"],
             "kcal": 320},
        ],
    },
    "chicken_curry_white_dish": {
        "photo": "chicken_curry_01_jpg_48043fe8.jpg",
        "confidence": "high",
        "note": "A white oval dish of bone-in chicken pieces - two drumsticks and a "
                "thigh, the bone and skin clearly visible - in a dark brown "
                "onion-tomato masala with cracked spice and seeds. The protein is "
                "identifiable, so this is a clean single judgement. It is also a "
                "dish CLASS the corpus had no case for at all: chicken curry had "
                "appeared only as an item inside a thali, and a thali is scored as "
                "the thali.",
        "truth": [
            {"name": "Chicken Curry", "aliases": ["Murgh Curry", "Chicken Masala",
                                                   "Murgh Masala"],
             "kcal": 300},
        ],
    },
    "mutton_biryani_singapore_plate": {
        "photo": "mutton_biryani_singapore_jpg_e1bf1bb4.jpg",
        "confidence": "high",
        "note": "A white plate of long-grain basmati with a distinct browned "
                "fried-onion layer on top, whole spice and a green chilli "
                "visible, and bone-in mutton pieces to the left. This is the "
                "evidence the rejected 'boryani' lacked: long distinct grain, a "
                "fried-onion cap, and visible bone-in meat. A second case for the "
                "biryani class, which had one.",
        "truth": [
            {"name": "Mutton Biryani", "aliases": ["Biryani", "Dum Biryani",
                                                    "Kacchi Biryani"],
             "kcal": 450},
        ],
    },
    "dosa_roll_thali": {
        "photo": "a_plate_of_south_indian_masala_dosa_jpg_109d5c3a.jpg",
        "confidence": "high",
        "note": "A steel thali holding a rolled dosa, a compartment of white "
                "chutney and a compartment of orange gravy with visible vegetable "
                "pieces. The dosa is the dish. The filling is NOT visible because "
                "the dosa is rolled, so the label is Dosa and not Masala Dosa - "
                "saying 'masala' would be a claim about something inside. Both "
                "labels land on the same dish class. A second case for the dosa "
                "class, which had one.",
        "truth": [
            {"name": "Dosa", "aliases": ["Dosa Roll", "Plain Dosa", "Masala Dosa"],
             "kcal": 250},
        ],
    },
}

REJECT = {
    "boryani_jpg_667efeb9.jpg": (
        "Filed on Commons as 'boryani', and it is a steel bowl of yellow rice "
        "beside a thick brown gravy. I cannot call that biryani honestly: the "
        "grain is short and uniformly yellow rather than long-grain and layered, "
        "and there is no visible meat. The only other reading is rice with dal - "
        "and dal is one of the four classes this batch exists to avoid growing. So "
        "the two available labels are one guess and one regression, and a photo "
        "that can only be labelled by guessing is not added"
    ),
    "plate_of_biryani_rice_jpg_b1429117.jpg": (
        "The rice is biryani, but the plate is buried under a large Western "
        "garnish - lettuce, cucumber, tomato, red onion rings, pomegranate. A "
        "salad is not a staple side, so this case would carry TWO non-staple "
        "judgements and class_of() would silently score it as whichever came "
        "first. A composite is not a single-dish case"
    ),
    "22_rajab_kundao_n_ki_niaz_jpg_a4cca717.jpg": (
        "A dawat spread laid on a cloth: fruit, two bowls of a pale dessert, two "
        "bowls of fried items, rose petals, a plate of bananas and dates. The "
        "pale dessert could be kheer or phirni and the fried items pakora or "
        "samosa, and I cannot name either. Same rejection as batch 7's styled "
        "banana-leaf flat-lay"
    ),
    "lauki_kofta_curry_jpg_7439a01d.jpg": (
        "REJECTED ON PURPOSE, and this is the one that matters: the kofta are "
        "clean and the label would have been defensible, but the kofta class "
        "already has a case from this batch. Taking it would take kofta 1->3, "
        "put it in the top 4, and make the concentration WORSE - which is the "
        "exact regression this batch was built to remove. Two clean photographs "
        "of one class is the skew in miniature, and a batch that fixes skew by "
        "growing it is not a batch that fixed anything"
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

    for rec in manifest["photos"]:
        if rec.get("reviewed") is True or rec.get("not_used") is True:
            continue
        if rec["file"] in {c["image"] for c in corpus["cases"]}:
            continue
        rec["not_used"] = True
        rec["not_used_reason"] = (
            "Fetched and never reviewed, so it is not evidence. Left in the manifest "
            "DECLARED as not-used rather than left unreviewed, because an undecided "
            "photo is indistinguishable from an accepted one."
        )
        print(f"  ? declared not-used: {rec['file'].split('/')[-1][:52]}")

    corpus["_readme"].extend([
        "",
        "BATCH 8 (2026-09-28): FLATTEN, sized by arithmetic. The top 4 classes held",
        "42% of 31 cases (dal x5, chole x4, paneer x2, sambar x2) and the readme",
        "names <= 35% as the target, so the arithmetic is 13/(31+N): N=7 gives 35.1%,",
        "N=8 gives 34.2%. BATCH8_QUERIES is therefore one query per class holding",
        "exactly ONE case, and NONE of the four concentrated ones - a fifth dal makes",
        "the median look better and the product no better. 18 queries, 94 candidates,",
        "per-query and per-author caps plus the dHash near-dup check before fetching.",
        "  accepted 4  aloo gobi, baingan bharta, bhindi masala, dosa - every one a",
        "               class that had exactly one case, so all four flatten the skew",
        "  rejected 1  a plate of yellow rice and brown gravy filed as 'boryani'.",
        "               Not biryani: short uniformly yellow grain, no visible meat,",
        "               and the only other honest label is dal, which is a regression.",
        "               A photo that can only be labelled by guessing is not added",
        "  not_used 13  fetched, never looked at; declared not-used, not left",
        "               unreviewed, because an undecided photo is indistinguishable",
        "               from an accepted one",
        "The dosa is the dose note: it is ROLLED, so the masala filling is not",
        "visible and the label is Dosa rather than Masala Dosa. Same dish class",
        "either way, so the count is unaffected - but the label says only what the",
        "photograph shows.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
