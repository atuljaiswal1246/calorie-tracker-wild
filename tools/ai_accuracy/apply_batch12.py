#!/usr/bin/env python3
"""Apply batch 12 - the five classes batch 11 left empty, queried by REGIONAL SPELLING.

Batch 11 got 1 usable photograph from 3 downloaded. This round changes the NAMES
rather than adding more cuisine words, because Commons is thin on these dishes and thin
in a particular way: the uploads are captioned regionally or transliterated, not in the
dictionary form. 10 queries, 18 openly licensed candidates, 5 downloaded.

  accepted 3  UTHAPPAM x2 - a pink plate holding three thick white savoury rice
               pancakes flecked with onion, green chilli, tomato and coriander beside a
               small glass bowl of pale chutney; and a separate onion uthappam on a
               banana leaf on a steel tray, with turmeric-tinted patches and a red
               pickle at the edge. Both are unmistakably uthappam, and two photographs
               of one dish is legitimate sampling for a vision model rather than
               duplication - 2 is a normal count, nowhere near the concentrated
               classes. Uthappam's first two cases, and the class batch 11 left empty.
               ALOO RAITA - a pale pink-white yogurt dish in an orange bowl with cubed
               potato, chopped green chilli, coriander and a dusting of red chilli
               powder. Unambiguous. Raitha's first case, also empty since batch 9.

  rejected 2  BOTH FOR REASONS THAT ARE THE POINT:

    - "cyamopsis tetragonoloba": a BOTANICAL photograph - a guar plant in flower, a
      stalk of small white-lilac blossoms against leaves. Not a dish at all. The
      "gavar phali" query found the plant rather than a meal made from it, which is a
      lesson worth keeping: a botanical name on Commons finds a botanical photograph,
      so a class named after a plant needs a DISH word in the query, never the plant's
      own name.

    - "biryani and raita": the dominant item is a vegetable biryani, which would be a
      THIRD biryani and pushes an already-large class further into the top four. The
      raita beside it is a side dish. Putting raita first in the truth would have made
      the class raitha - a class this batch wanted - but the class would then have been
      decided by the order I typed the items in, which is the same fault batch 10
      rejected a four-component plate for. A wanted class is not a reason to reorder
      the truth.

STILL EMPTY AFTER THIS ROUND: khakra, mushroom and french beans. The regional-spelling
strategy worked for uthappam and raitha and did not work for the other three, and the
honest reading is that Commons has very few photographs of khakra, a mushroom masala or
a french-bean sabzi that are unambiguously those dishes. The next attempt, if there is
one, should change the DISH FORM rather than the name - a whole sabzi thali rather than
a close-up - and if that also comes back thin, the right conclusion is that these three
stay empty and the bar is met without them.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "uthappam_plate_chutney": {
        "photo": "uthappam_jpg_578f643e.jpg",
        "confidence": "high",
        "note": "Three thick white savoury rice pancakes on a bright pink square plate, "
                "each roughly a hand across, with visible chopped onion, green chilli "
                "slices, diced tomato and coriander, browned and blistered in patches "
                "from the pan. A small glass bowl of pale speckled chutney sits at the "
                "top of the plate. The thick porous white batter with onion and chilli "
                "is uthappam and nothing else, and this is its first case in the "
                "corpus.",
        "truth": [
            {"name": "Uthappam", "aliases": ["Uttapam", "Idiappam", "Neerappam"],
             "kcal": 250},
            {"name": "Chutney", "aliases": ["Coconut Chutney", "Chutney"],
             "kcal": 40},
        ],
    },
    "onion_uthappam_banana_leaf": {
        "photo": "onion_uttappam_01_jpg_f536e1c5.jpg",
        "confidence": "high",
        "note": "One large onion uthappam served on a green banana leaf on a stainless "
                "steel tray, the pancake pale and glossy with translucent onion, green "
                "chilli rings, coriander and turmeric-tinted fried patches across its "
                "surface. A red-orange pickle or chutney is partly visible at the lower "
                "left edge. A second, different photograph of the same dish is "
                "legitimate sampling rather than duplication: it tests whether the "
                "model is consistent on one dish across two photographs.",
        "truth": [
            {"name": "Uthappam", "aliases": ["Uttapam", "Onion Uthappam", "Idiappam"],
             "kcal": 250},
        ],
    },
    "aloo_raita_bowl": {
        "photo": "aloo_raita_recipe_by_sonia_goyal_jpg_eae35953.jpg",
        "confidence": "high",
        "note": "A shallow orange bowl of aloo raita: a pale pink-white yogurt base "
                "thick with visible cubes of boiled potato, chopped green chilli, "
                "roughly torn coriander leaves and a dusting of red chilli powder "
                "across the surface. A sliver of a white plate is visible at the top "
                "left corner. The potato cubes in a yogurt base make this potato raita "
                "rather than plain raita, and the class is the same either way. "
                "Raitha's first case.",
        "truth": [
            {"name": "Raitha", "aliases": ["Raita", "Aloo Raita", "Boondi Raitha",
                                           "Dahi Raita"],
             "kcal": 120},
        ],
    },
}

REJECT = {
    "cyamopsis_tetragonoloba_4663783848_jpg_434f56cb.jpg": (
        "a BOTANICAL photograph, not a dish: a guar plant in flower, a stalk of small "
        "white-lilac blossoms against out-of-focus leaves. The 'gavar phali' query "
        "found the plant rather than a meal made from it. Kept as a lesson: a botanical "
        "name on Commons finds a botanical photograph, so a class named after a plant "
        "needs a DISH word in the query and never the plant's own name"
    ),
    "biryani_and_raita_jpg_93a98cc2.jpg": (
        "the dominant item is a vegetable biryani, which would be a THIRD biryani and "
        "push an already-large class further into the top four. The raita beside it is "
        "a side dish, and putting raita first in the truth would have made the class "
        "raitha - a class this batch wanted - but the class would then have been "
        "decided by the order I typed the items in, which is the same fault batch 10 "
        "rejected a four-component plate for. A wanted class is not a reason to "
        "reorder the truth"
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
        "BATCH 12 (2026-09-28): the five classes batch 11 left empty, queried by",
        "REGIONAL SPELLING. Batch 11 got 1 usable photograph from 3 downloaded, so this",
        "round changes the NAMES rather than adding more cuisine words: Commons is thin",
        "on these dishes and thin in a particular way - the uploads are captioned in a",
        "regional or transliterated form, not the dictionary form. Khakra -> khakro;",
        "mushroom -> dhingra; raitha -> raita and potato raita; uthappam -> uttapam;",
        "french beans -> gavar phali and beans poriyal. 10 queries, 18 candidates, 5",
        "downloaded after the per-query and per-author caps and the dHash check.",
        "  accepted 3  uthappam x2 (its first two cases) and aloo raita (its first)",
        "  rejected 2  a botanical photograph of a guar plant in flower - not a dish,",
        "               and the lesson kept is that a botanical NAME finds a botanical",
        "               photograph, so a plant-named class needs a DISH word in the query",
        "               and a vegetable biryani that would be a THIRD biryani, with the",
        "               raita beside it a side dish. Putting raita first would have won",
        "               this batch the raitha class, but the class would then have been",
        "               decided by my typing order - the fault batch 10 rejected a",
        "               four-component plate for. A wanted class is not a reason to",
        "               reorder the truth",
        "STILL EMPTY: khakra, mushroom and french beans. The regional-spelling strategy",
        "worked for uthappam and raitha and did not work for the other three. The honest",
        "reading is that Commons has very few photographs of a khakra, a mushroom masala",
        "or a french-bean sabzi that are unambiguously those dishes. If there is a next",
        "attempt it should change the DISH FORM - a whole thali rather than a close-up -",
        "and if that is thin too, the right conclusion is that these three stay empty and",
        "the bar is met without them.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
