#!/usr/bin/env python3
"""Apply batch 10 - the keys that had none, queried harder. Still zero cost.

Batch 9 added eight DISH_CLASS keys in the same commit as the photographs, so
six of them still had no case: mushroom, capsicum, french beans, jalebi, samosa
and sweet corn (which batch 9 filled via the corn-capsicum masala). Batch 9's
own queries proved the failure mode - "mushroom curry bowl" returned a THAI green
curry, and the french beans query returned a four-item plate - so every query here
carries "indian" or "home", because Commons is a global library and the
unsuffixed term finds the wrong cuisine.

  accepted 2  jalebi with rabri, and a samosa with chutney - both classes that
               batch 9 opened and left empty
  rejected 2  ON POLICY, WITHOUT BEING OPENED, and the reason is arithmetic:
               "dahl curry and rice" is a sixth DAL, and dal is the worst single
               class in the corpus at 5; "kadai paneer" is a third PANEER, which
               would carry paneer past chole into the top 4 and make the
               concentration worse - the exact regression batch 8 was built to
               remove. Both are clean single-dish photographs and both are being
               thrown away anyway, which is the point: a good photo of a dish we
               already have too much of is worth nothing to the median
  rejected 1  "lamb curry, chicken curry, french beans and yellow split..." -
               the title alone is four non-staple components on one plate, so the
               class would be decided by the order I typed the truth in

  not_used 16  fetched, never looked at; declared not-used, not left unreviewed

The three policy rejections are recorded as NOT LOOKED, not as judged-and-failed,
because that is what happened: opening a photograph only to reject it on a class
count is a minute of the owner's laptop spent on an outcome arithmetic already
decided.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "jalebi_rabri_street_table": {
        "photo": "food_item_02_jpg_b118da32.jpg",
        "confidence": "high",
        "note": "Two foil plates of coiled, syrup-glazed orange sweets beside four "
                "paper cups of thick white rabri topped with pistachio slivers, on "
                "a wooden street-food table. The spiral coil shape is jalebi and "
                "nothing else, and the cups are rabri. Jalebi is a class batch 9 "
                "opened and left empty; this is its first case.",
        "truth": [
            {"name": "Jalebi", "aliases": ["Jalebi Rabri", "Kesar Jalebi",
                                           "Imarti", "Chirpy Jalebi"],
             "kcal": 300},
            {"name": "Rabri", "aliases": ["Khoya", "Reduced Milk", "Cream"],
             "kcal": 150},
        ],
    },
    "samosa_plate_restaurant": {
        "photo": "samosa_from_indian_resto_warsaw_poland_img_20191001__834beb1d.jpg",
        "confidence": "medium",
        "note": "One triangular fried samosa on a white plate with a mint chutney, "
                "a red sauce and a dark shredded accompaniment I could not name. "
                "The samosa is unambiguous; the chutney is a staple so class_of() "
                "skips it; the third accompaniment is not asserted because I could "
                "not identify it. Medium rather than high: it is a dim restaurant "
                "table, not the home plate the corpus mostly holds.",
        "truth": [
            {"name": "Samosa", "aliases": ["Samosas", "Singara", "Kachori"],
             "kcal": 250},
            {"name": "Chutney", "aliases": ["Mint Chutney", "Coriander Chutney",
                                            "Green Chutney"],
             "kcal": 40},
        ],
    },
}

REJECT = {
    "dahl_curry_and_rice_299982870_jpg_2720b7b5.jpg": (
        "REJECTED ON POLICY WITHOUT BEING OPENED: this is a sixth DAL, and dal is "
        "the worst single class in the corpus at 5 cases. A clean photograph of a "
        "dish we already have too much of does not move a median"
    ),
    "kadai_paneer_jpg_f9f96e92.jpg": (
        "REJECTED ON POLICY WITHOUT BEING OPENED: this is a third PANEER, and "
        "paneer sits at 2. Taking it would carry paneer past chole into the top 4 "
        "and make the concentration worse - the exact regression batch 8 removed, "
        "and the reason batch 8 rejected a perfectly good second kofta photo"
    ),
    "lamb_curry_chicken_curry_french_beans_and_yellow_spl_1f3534f9.jpg": (
        "the title alone names four non-staple components on one plate - lamb "
        "curry, chicken curry, french beans and a split-pea dish - so class_of() "
        "would score the case as whichever I listed first, and the class would be "
        "decided by my typing order rather than by the photograph"
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
        rec["opened"] = False
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
        "BATCH 10 (2026-09-28): the keys batch 9 opened, queried harder. Six of the",
        "eight new class keys still had no case, and batch 9's own queries proved the",
        "failure mode - an unsuffixed 'mushroom curry bowl' returned a THAI green",
        "curry. So every query here carries 'indian' or 'home'. 6 queries, 21",
        "candidates, per-query and per-author caps plus the dHash near-dup check.",
        "  accepted 2  jalebi with rabri, and a samosa with chutney - the two classes",
        "               batch 9 opened and left empty that Commons could fill cleanly",
        "  rejected 2  ON POLICY, NOT OPENED: a sixth DAL (dal is the worst single",
        "               class at 5) and a third PANEER (which would carry paneer past",
        "               chole into the top 4 and worsen the concentration). Both are",
        "               clean single-dish photographs, and both are thrown away",
        "               anyway: a good photo of a dish we already over-sample is",
        "               worth nothing to a median",
        "  rejected 1  a plate whose title alone names four non-staple components,",
        "               so class_of would score it by my typing order",
        "  not_used 16  fetched, never looked at; declared not-used",
        "The two policy rejections are recorded as NOT LOOKED rather than as",
        "judged-and-failed, because that is what happened - and because opening a",
        "photograph only to reject it on a class count is a minute of the owner's",
        "laptop spent on an outcome arithmetic has already decided.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
