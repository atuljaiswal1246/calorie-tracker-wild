#!/usr/bin/env python3
"""Apply batch 9 - WIDEN. New classes, and the keys land WITH the photographs.

Batch 8 flattened the skew (42% -> 34%, target hit). The class COUNT was already
23 against a bar of 20, so count was not the gap - the gap was that common home
dishes had no case at all, and a photo app fails on the dish someone actually
eats on a Tuesday. Measured from cases.json @ 38 cases: no mushroom, capsicum,
keema, french beans, sweet corn, jalebi or samosa case existed, and STAPLE_SIDES
meant none of them could be smuggled in as a side.

So the DISH_CLASS keys are added in the SAME commit as the photographs. A key
added after the fact is how a bar gets bought with near-synonyms, which is the
trap batches 5-7 each closed by hand.

  accepted 2  keema, and a corn-capsicum masala scored as sweet corn
  rejected 3  a Thai green curry with oyster mushrooms (not Indian); a plate
              carrying french beans, rice, a bone-in lamb curry AND fried fish
              (three non-staple judgements, so class_of would just pick whichever
              was listed first - that is me choosing the class); and a sadya
              spread on a banana leaf whose non-rice items I cannot each name and
              whose dominant component is a staple

  not_used 17  fetched, never looked at; declared not-used, not left unreviewed

THE CORN-CAPSICUM NOTE, because it is the interesting judgement: the dish
genuinely contains BOTH, and the truth names both. class_of() takes the first
non-staple, so the class is the dominant component - corn kernels are everywhere
and capsicum is a component. That is a scoring rule doing its job, and it is
recorded rather than hidden, because a case that lands on a class by ordering
rather than by exclusivity should be visible to whoever reads the count.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "keema_matar_steel_bowl": {
        "photo": "keema_matar_a_dish_from_india_jpg_6639930a.jpg",
        "confidence": "high",
        "note": "A steel bowl of minced meat in a masala, with green peas, "
                "chopped coriander, ginger julienne and a tomato wedge on top. "
                "The mince is unmistakably keema, and the bowl holds one dish "
                "and nothing else. Keema is a NEW dish class: the corpus had no "
                "mince case at all, and it is a very common home dish.",
        "truth": [
            {"name": "Keema", "aliases": ["Kheema", "Keema Curry", "Minced Meat Curry"],
             "kcal": 300},
            {"name": "Peas", "aliases": ["Matar", "Green Peas"], "kcal": 80},
        ],
    },
    "corn_capsicum_masala_kadai": {
        "photo": "corn_capsicum_masala_jpg_9362322e.jpg",
        "confidence": "medium",
        "note": "A metal kadai of sweet corn kernels with red and green capsicum "
                "in a thick brown masala, shot close and slightly out of focus. "
                "Both vegetables are genuinely present, so the truth names both "
                "and the class lands on corn, which is the dominant component. "
                "Medium rather than high: the frame is soft, and a scan could "
                "reasonably call this capsicum-forward instead.",
        "truth": [
            {"name": "Sweet Corn", "aliases": ["Corn", "Corn Curry", "Makai"],
             "kcal": 160},
            {"name": "Capsicum", "aliases": ["Shimla Mirch", "Bell Pepper",
                                             "Capsicum Masala"],
             "kcal": 50},
        ],
    },
}

REJECT = {
    "3_mushroom_curry_noodle_soup_with_ph_pho_2025_11_12__e8bc4baa.jpg": (
        "a Thai green curry with oyster mushrooms, Thai basil and a red chilli, "
        "on a wooden restaurant table with chopsticks and a beer can. The dish is "
        "not Indian and the setting is a restaurant, and the Commons title says "
        "pho. A mushroom curry case has to be an Indian home mushroom preparation"
    ),
    "fried_fish_lamb_curry_french_beans_with_basmatic_ric_81cbc566.jpg": (
        "four non-staple components on one plate - sauteed french beans, white "
        "rice, a bone-in lamb curry and a piece of fried fish - plus a diner in "
        "frame. class_of() takes the first non-staple, so the class would be "
        "decided by the order I happened to write the truth in, which is me "
        "choosing the class rather than the photograph"
    ),
    "south_indian_celebration_jpg_18120b1d.jpg": (
        "a sadya spread on a banana leaf: rice, a papad, salt, and three red and "
        "orange preparations I cannot each name. The dominant component is rice, "
        "which is a STAPLE, so class_of() would fall through the staple rule to "
        "the fallback and score the case as whatever came first - a class from "
        "the fallback rather than from a judgement"
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

    corpus["_readme"].extend([
        "",
        "BATCH 9 (2026-09-28): WIDEN, and the keys land WITH the photographs. Batch 8",
        "flattened to 34%; the class count was 23 against a bar of 20, so count was",
        "not the gap. The gap was that common home dishes had NO case at all: no",
        "mushroom, capsicum, keema, french beans, sweet corn, jalebi or samosa, and",
        "STAPLE_SIDES meant none could be smuggled in as a side. 7 queries, 24",
        "candidates, per-query and per-author caps plus the dHash near-dup check.",
        "  accepted 2  keema (a new class), and a corn-capsicum masala scored as sweet",
        "               corn because corn is the dominant component",
        "  rejected 3  a Thai green curry with oyster mushrooms, not Indian; a plate",
        "               with french beans, rice, a bone-in lamb curry AND fried fish,",
        "               where class_of would take whichever I listed first; and a",
        "               sadya spread whose dominant component is a staple, so the",
        "               class would come from the fallback rather than a judgement",
        "  not_used 17  fetched, never looked at; declared not-used, not left",
        "               unreviewed",
        "DISH_CLASS gains 8 new class keys IN THE SAME COMMIT as the photographs, with",
        "their synonyms, because a key added after the fact is how a bar gets bought",
        "with near-synonyms. Six of the eight have no case yet - the keys are there",
        "so that when a photograph arrives it lands on ONE class, not a new one.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
