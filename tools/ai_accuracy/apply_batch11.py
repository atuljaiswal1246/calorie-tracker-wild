#!/usr/bin/env python3
"""Apply batch 11 - the six DECLARED class keys that no case reached. Still zero cost.

The target was not chosen by taste. `test_the_dish_classes_are_distinct.py` prints
the classes DISH_CLASS declares and the corpus never reaches: capsicum, french beans,
khakra, mushroom, raitha, uthappam. A declared key with no case is a promise the corpus
is not keeping, and it is the cheapest win available - the class already exists as a
decision, so one photograph raises the class count without inventing a category, keeps
every dish family at a single case so the independence figure does not get worse, and
pushes the concentration down.

  6 queries, 6 openly licensed candidates, 3 downloaded after the per-query and
  per-author caps and the dHash near-duplicate check.

  accepted 1  STUFFED CAPSICUM - a whole green bell pepper, stem on, slit and packed
              with a rice-and-vegetable filling with visible corn and carrot. The
              pepper is unambiguous; the filling I will not assert beyond what is
              visible, so the truth names the pepper and the note says what the
              filling looks like rather than claiming paneer. Capsicum's first case.

  rejected 2  BOTH ON WHAT THE PHOTOGRAPH SHOWS, and both reasons are the point:

    - "uttpam and dal vada homemade southindian": the title claims uthappam, but the
      pale portion is a chunky cooked rice with diced carrot, tomato and beans - it
      reads as vegetable rice, not as a thick porous pancake. The two unmistakable
      items are vada (a class that already has its case) and a mustard-seed coconut
      chutney (a staple, so class_of skips it). So the class would be decided by which
      of two readings of the same pixels I happened to choose. Rejecting it leaves
      uthappam empty, which is the honest state.

    - "different dinner home nashik": garlic bread in four triangles, brushed with
      butter and topped with chopped garlic and green and red chilli, with a green
      chutney and a translucent onion-tomato pickle alongside. The dominant item is
      garlic bread, which is not an Indian dish and is not a class in DISH_CLASS - so
      class_of would put it through the fallback and produce a brand new UNDECLARED
      class. That is precisely the defect this batch's own guard exists to catch, and
      the honest way to meet it is not to add the case.

  not_used 0  of the 3 downloaded; the other 3 candidates were skipped before download
              by the per-query and per-author caps, so there is nothing to declare.

FIVE OF THE SIX TARGET CLASSES ARE STILL EMPTY, and that is the result, not a failure
to be hidden: khakra, mushroom, raitha, uthappam and french beans remain unphotographed
after 6 targeted queries. Batch 7 recorded the same shape - six queries, one usable
photograph. Commons is thin on these particular dishes, and the honest next move is a
second round with regional spellings (dhingra, khakra Gujarati, raita) rather than
loosening the cuisine constraint that batch 9 proved is what makes a query find the
wrong food.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "stuffed_capsicum_home": {
        "photo": "stuffed_peppers_1337055553_jpg_688cd99e.jpg",
        "confidence": "high",
        "note": "One whole green bell pepper on a white plate, stem and all, slit "
                "lengthwise and packed with a pale cooked filling in which corn "
                "kernels, diced carrot and green peas are individually visible, "
                "photographed in low light on a dark table. The pepper is "
                "unambiguous. The filling is a rice-and-vegetable mixture and I am "
                "not claiming paneer for it, because at this light I cannot tell "
                "whether the pale grains are rice or crumbled paneer - so the truth "
                "names the capsicum, which is what the class is decided on, and this "
                "note records what the filling looks like instead of guessing at it. "
                "Capsicum's first case; the class was declared and empty.",
        "truth": [
            {"name": "Capsicum", "aliases": ["Shimla Mirch", "Bell Pepper",
                                              "Stuffed Capsicum", "Capsicum Masala"],
             "kcal": 180},
        ],
    },
}

REJECT = {
    "uttpam_and_dal_vada_homemade_southindian_origin_imag_054f98be.jpg": (
        "the title claims uthappam, but the pale portion is a chunky cooked rice with "
        "diced carrot, tomato and beans - vegetable rice, not a thick porous pancake. "
        "The two unmistakable items are vada, which already has its case, and a "
        "mustard-seed coconut chutney, which is a staple class_of skips. So the class "
        "would be decided by which of two readings of the same pixels I picked. "
        "Uthappam stays empty, which is the honest state"
    ),
    "different_dinner_home_nashik_mh_3_jpg_9e02d5a2.jpg": (
        "the dominant item is garlic bread - four buttered triangles under chopped "
        "garlic, green chilli and red chilli - with a green chutney and an "
        "onion-tomato pickle. Garlic bread is not an Indian dish and is not a class in "
        "DISH_CLASS, so class_of would send it through the fallback and manufacture a "
        "brand new UNDECLARED class. That is the exact defect "
        "test_the_dish_classes_are_distinct.py exists to catch, and the honest way to "
        "meet that guard is not to add the case"
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
        rec["opened"] = True
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:50]}")

    for rec in manifest["photos"]:
        if rec.get("reviewed") is True or rec.get("not_used") is True:
            continue
        if rec["file"] in {c["image"] for c in corpus["cases"]}:
            continue
        rec["not_used"] = True
        rec["not_used_reason"] = (
            "Fetched and never reviewed, so it is not evidence. Declared not-used "
            "rather than left unreviewed, because an undecided photo is "
            "indistinguishable from an accepted one."
        )

    corpus["_readme"].extend([
        "",
        "BATCH 11 (2026-09-28): the six DECLARED class keys no case reached. The",
        "target was measured, not chosen - test_the_dish_classes_are_distinct.py",
        "prints DISH_CLASS keys the corpus never lands in: capsicum, french beans,",
        "khakra, mushroom, raitha, uthappam. A declared key with no case is a promise",
        "the corpus is not keeping, and it is the cheapest win there is: the class is",
        "already a decision, so a photograph raises the count without inventing a",
        "category, keeps every family at one case so independence does not worsen,",
        "and lowers the concentration.",
        "  6 queries, 6 candidates, 3 downloaded after the caps and the dHash check",
        "  accepted 1  stuffed capsicum - the pepper is unambiguous; the filling is",
        "               recorded as what it looks like and NOT asserted as paneer,",
        "               because at that light rice and crumbled paneer are not",
        "               separable and guessing would be a false label",
        "  rejected 2  'uttpam and dal vada': the title claims uthappam but the pale",
        "               portion is vegetable rice, and the two certain items are vada",
        "               (already a class) and a staple chutney - so the class would be",
        "               decided by which reading I picked. Uthappam stays empty.",
        "               'different dinner nashik': the dominant item is garlic bread,",
        "               which is not an Indian class, so it would manufacture a new",
        "               UNDECLARED class through the fallback - the exact defect this",
        "               batch's own guard exists to catch",
        "FIVE OF THE SIX TARGET CLASSES ARE STILL EMPTY - khakra, mushroom, raitha,",
        "uthappam, french beans - and that is the result, not something to hide. Batch",
        "7 recorded the same shape: six queries, one usable photograph. Commons is",
        "thin on these dishes, and the honest next move is a second round with",
        "regional spellings rather than loosening the cuisine constraint that batch 9",
        "proved is what makes a query find the wrong cuisine.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
