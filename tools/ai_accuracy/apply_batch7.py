#!/usr/bin/env python3
"""Apply batch 7 - the SKEW, not the count. A thin batch, reported as one.

The bar is met at 21 classes, but 13 of 30 cases are four classes (dal x5,
chole x4, paneer x2, sambar x2), so a median over the corpus is substantially a
median over dal and chole. Batch 7 went after five classes the corpus lacked.
Commons returned one usable photograph for them.

  accepted 1   gajar halwa (a second dessert class; kheer was the only one)
  rejected 3   a Bengali fish thali on a banana leaf, an unidentifiable pale
               protein curry, and a second gajar halwa that repeats the class
  not_used 1   fetched, never looked at

So the corpus moved 21 -> 22 classes and the skew barely moved, which is the
honest result: I am not going to inflate a batch by accepting photographs I cannot
label. The skew guard added alongside this pins the CURRENT concentration so it
cannot get worse, and names the target for the next batch rather than pretending
it has been reached.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "gajar_halwa_bowl": {
        "photo": "delicious_gajar_ka_halwa_jpg_698fbbb2.jpg",
        "truth": [
            {"name": "Gajar Ka Halwa", "aliases": ["Carrot Halwa", "Gajar Halwa",
                                                   "Halwa", "Gajar", "Carrot Pudding"],
             "kcal": 220},
            {"name": "Tomato", "aliases": ["Tomato Slices", "Salad"], "kcal": 15},
        ],
        "note": "A glass bowl of gajar ka halwa with two cashews on top, on a blue "
                "plate, three tomato slices beside it, shot from above. One clearly "
                "readable dish plus a garnish - the shape of case the corpus barely "
                "had, and a second dessert class after kheer.",
        "confidence": "high",
    },
}

REJECT = {
    "a_traditional_bengali_dish_served_on_a_banana_leaf_s_4e3a9a08.jpg":
        "a styled flat-lay - marigold petals scattered on a printed cloth - with "
        "eight items of which three I could not name (a yellow shoru, a white "
        "dessert, a second dark curry). Exactly the khichdi rejection again: a "
        "truth I cannot defend is not added",
    "asian_chicken_curry_4652719000_jpg_b9e9ed72.jpg":
        "the protein is not identifiable, the sauce is a pale generic one rather "
        "than a home chicken curry, and it is an angled snapshot on a plastic "
        "plate. The Commons title says 'Asian', not Indian",
    "carrot_gajar_halwa_with_kheer_india_sweets_jpg_4f4d5a05.jpg":
        "would repeat the halwa class; it is a sweets-shop shot of halwa with "
        "kheer, and kheer already has its own case",
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
        "BATCH 7 (2026-09-28): the SKEW, not the count. 13 of 30 cases were four",
        "classes (dal x5, chole x4, paneer x2, sambar x2) = 43% of the corpus, so a",
        "median over it is largely a median over dal and chole. Five classes were",
        "targeted; Commons returned one usable photograph.",
        "  accepted 1  gajar halwa (a second dessert class; kheer was the only one)",
        "  rejected 3  a styled Bengali banana-leaf fish thali with three",
        "               unnameable items, an unidentifiable pale protein curry, and",
        "               a sweets-shop shot that repeats the halwa class",
        "  not_used 1  fetched, never looked at",
        "So 21 -> 22 classes and the skew barely moved. Reported as it is: I am not",
        "inflating a batch by accepting photographs I cannot label. The skew guard",
        "pins the CURRENT concentration so it cannot worsen, and names <= 35% as the",
        "target for a future batch instead of pretending it has been reached.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
