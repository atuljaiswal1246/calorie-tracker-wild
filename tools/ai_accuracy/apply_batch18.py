#!/usr/bin/env python3
"""Apply batch 18 - sized to move the CONCENTRATION, which is the number left worth moving.

Every class this corpus declares now has a case, so the class count cannot grow honestly
and the note's own guidance applies: "the number to watch next is the concentration, not
the class count."

SIZED BY ARITHMETIC. 22 of 33 classes held exactly one case; the top four held 13 of 49,
which is 27%. Adding one case to each of eight singleton classes gives 57 cases with the
top four still at 13, which is 23% - and dal and chole are never touched, because growing
the two largest classes is the regression batches 8 and 10 were built to remove.

  9 queries (the control first), 5 downloaded, accepted 4, rejected 1.

THE TRADE IS STATED RATHER THAN HIDDEN: eight families become repeated, so the
independence figure moves the other way - 20 of 49 becomes 28 of 57. Concentration falls,
independence falls, the sample gets bigger. A median over 57 cases in 33 classes is a
better instrument than one over 49. That is the trade, and it is a trade rather than a
free improvement, which is why the concentration number is reported next to the
independence number every time rather than alone.

  accepted 4  IDLI IN SAMBAR - a steel bowl of about nine whole steamed idlis, pale and
               porous with the characteristic grain, sitting in thick orange sambar with
               visible mustard seed, a spoon in the bowl. Truth is [Idli, Sambar]: the
               plate is named for the idlis and the sambar is the accompaniment, and
               saying so is better than pretending the sambar is not there.
               MEDU VADA - three craggy golden ring-shaped fritters on a steel plate.
               Unmistakable, and nothing else in the corpus has that form.
               JALEBI - a white plate piled with orange syrup-glossed coiled spirals.
               SAMOSA - four golden triangular fried pastries on a black plate with a
               small bowl of green coriander-garnished chutney.

  rejected 1  "2017 03 04 25 eierspeise im gasthaus sch nau in fr...": the `egg curry`
               query returned an AUSTRIAN dish - Eierspeise is a scrambled-egg plate and
               Gasthaus is a pub. Rejected on the filename, which is decidable: a German
               compound noun and a German venue are not an Indian egg curry, and the
               corpus is Indian meals. This is batch 9's lesson recurring in a new form -
               the cuisine constraint has to survive translation, not just survive being
               written in English.

The gajar halwa, kheer and pulao queries returned nothing that survived the caps, so those
three classes are still singletons. Recorded, not hidden: the batch yielded four of the
eight it was sized for, and the concentration moves 27% -> 25% rather than the 23% planned.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "idli_in_sambar_bowl": {
        "photo": "button_idli_jpg_ead252ee.jpg",
        "confidence": "high",
        "note": "A steel bowl holding about nine whole steamed idlis - pale golden, "
                "porous, each with the grain and the slightly flattened disc shape - "
                "sitting in a thick orange sambar with visible mustard seed and a metal "
                "spoon resting in the bowl. Truth is [Idli, Sambar]: the plate is named "
                "for the idlis and the sambar is the accompaniment, and saying so is "
                "better than pretending the sambar is not there. Idli's second case.",
        "truth": [
            {"name": "Idli", "aliases": ["Idlies", "Steamed Idli"], "kcal": 120},
            {"name": "Sambar", "aliases": ["Sambar", "Idli Sambar"], "kcal": 90},
        ],
    },
    "medu_vada_three_on_steel": {
        "photo": "aesthetic_medu_vadai_jpg_5983e0db.jpg",
        "confidence": "high",
        "note": "Three golden-brown craggy ring-shaped fritters on a steel plate, each "
                "with the crinkled batter surface and the central hole of a medu vada. "
                "The form is distinctive and nothing else in the corpus resembles it. "
                "High confidence. Vada's second case.",
        "truth": [
            {"name": "Vada", "aliases": ["Medu Vada", "Medu Vadai", "Vadai",
                                          "Lentil Fritter"],
             "kcal": 200},
        ],
    },
    "jalebi_coiled_on_plate": {
        "photo": "hot_jalebi_ma10_jpg_a697ddb6.jpg",
        "confidence": "high",
        "note": "A white plate piled with orange, glossy, syrup-soaked batter coiled into "
                "flat spirals, photographed close under warm light with the syrup "
                "sheen visible on every coil. Jalebi and nothing else. Jalebi's second "
                "case, and a different photograph from the rabri plate in batch 10 - "
                "which is the point of a second case: it tests whether the model is "
                "consistent on one dish across two photographs.",
        "truth": [
            {"name": "Jalebi", "aliases": ["Jalebi Rabri", "Kesar Jalebi", "Imarti"],
             "kcal": 300},
        ],
    },
    "samosa_four_with_chutney": {
        "photo": "indian_samosa_by_clumsy_home_chef_jpg_f0cc5b05.jpg",
        "confidence": "high",
        "note": "Four golden-brown triangular fried pastries on a black plate against a "
                "dark background, with a small black bowl of green chutney garnished with "
                "a coriander leaf. The triangular form and the blistered pastry are "
                "unambiguous. Samosa's second case, and a cleaner photograph than the "
                "dim restaurant plate in batch 10, which is why both are kept.",
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
    "2017_03_04_25_eierspeise_im_gasthaus_sch_nau_in_fran_f06e940f.jpg": (
        "REJECTED WITHOUT BEING OPENED, and the filename is decidable: the `egg curry` "
        "query returned an AUSTRIAN dish. Eierspeise is a scrambled-egg plate and "
        "Gasthaus is a pub. A German compound noun and a German venue are not an Indian "
        "egg curry, and the corpus is Indian meals. This is batch 9's lesson recurring "
        "in a form I had not anticipated: the cuisine constraint has to survive "
        "TRANSLATION, not merely survive being written in English"
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
        rec.pop("not_used", None); rec.pop("not_used_reason", None)
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
            cand = [k for k in photos if k.startswith(name[:44])]
            if len(cand) == 1:
                rec, name = photos[cand[0]], cand[0]
            else:
                print(f"  ! not in the manifest, skipped: {name}")
                continue
        rec["reviewed"] = True; rec["rejected"] = True
        rec["reject_reason"] = reason; rec["opened"] = False
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:48]}")

    for rec in manifest["photos"]:
        if rec.get("reviewed") is True or rec.get("not_used") is True:
            continue
        if rec["file"] in {c["image"] for c in corpus["cases"]}:
            continue
        rec["not_used"] = True
        rec["not_used_reason"] = (
            "Fetched and never reviewed, so it is not evidence. Declared not-used "
            "rather than left unreviewed, because an undecided photo is "
            "indistinguishable from an accepted one.")

    corpus["_readme"].extend([
        "",
        "BATCH 18 (2026-09-28): SIZED TO MOVE THE CONCENTRATION, the number left worth",
        "moving. Every declared class now has a case, so the class count cannot grow",
        "honestly, and the note's own guidance applies: watch the concentration, not the",
        "class count. 22 of 33 classes held exactly one case; the top four held 13 of 49,",
        "which is 27%. Adding one case to each of EIGHT singleton classes would give 57",
        "cases with the top four still at 13 - 23% - and dal and chole are never touched,",
        "because growing the two largest classes is the regression batches 8 and 10 were",
        "built to remove.",
        "THE TRADE, STATED RATHER THAN HIDDEN: eight families become repeated, so",
        "independence moves the other way - 20 of 49 becomes 24 of 53 here. Concentration",
        "falls, independence falls, the sample gets bigger. A median over more cases in",
        "more classes is a better instrument, and that is a trade rather than a free",
        "improvement, which is why both numbers are reported together every time.",
        "  9 queries with the control first, 5 downloaded, accepted 4, rejected 1",
        "  accepted 4  idli in sambar (a steel bowl of about nine whole steamed idlis in",
        "               thick orange sambar with mustard seed; truth [Idli, Sambar] because",
        "               the plate is named for the idlis and the sambar is there)",
        "               medu vada (three craggy golden rings - a form nothing else in the",
        "               corpus has), jalebi (orange syrup-glossed coils), samosa (four",
        "               golden triangles with green coriander chutney)",
        "  rejected 1  'eierspeise im gasthaus' - the `egg curry` query returned an",
        "               AUSTRIAN dish. Eierspeise is scrambled egg and Gasthaus is a pub.",
        "               Batch 9's lesson in a form I had not anticipated: the cuisine",
        "               constraint has to survive TRANSLATION, not merely being English",
        "YIELDED 4 OF THE 8 PLANNED. gajar halwa, kheer and pulao returned nothing that",
        "survived the caps, so those classes are still singletons. Recorded, not hidden:",
        "the concentration moves 27% -> 25%, not the 23% the arithmetic planned.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
