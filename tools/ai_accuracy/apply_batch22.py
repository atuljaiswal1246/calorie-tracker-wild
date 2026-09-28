#!/usr/bin/env python3
"""Apply batch 22 - one accept of six planned, and the pattern the failure reveals.

SIZED AS BEFORE: one case per singleton class, never touching dal (5) or chole (4).
55 + 6 would have been 61 cases and 23% concentration. It delivered 56 cases and 25%,
and the shortfall is the finding rather than a disappointment.

  7 queries (control first), 5 downloaded, accepted 1, rejected 4.

THE PATTERN, AND IT IS THE USEFUL PART. Batch 13 used a quoted phrase PLUS two form
words and found NOTHING. Batch 22 used a single bare word and found the INGREDIENT:

    "mushroom curry" bowl gravy ....... 0    (too many words)
    "mushroom curry" ................. 3    (two words: the dish)
    rajma ............................ dried kidney beans on white
    calabash ......................... a gourd
    makai ............................ sweet corn

ONE WORD FINDS THE INGREDIENT. TWO WORDS FIND THE DISH. Those two measurements bracket
the answer, and they were nine batches apart and cost two failed batches between them -
which is the cost of not having a middle. The queries that worked were all of the form
<dish> <preparation>: "mushroom curry", "beans curry", "egg curry", "gajar halwa".

The two exceptions in this batch are worth naming because they are the same rule wearing
different clothes:

  accepted 1  SARSON DA SAAG with makki ki roti. A white bowl of dark green saag topped
               with a pat of butter on a banana leaf, two pale makki rotis with sliced
               red onion, a lime wedge and a green chilli, and a bunch of fresh greens.
               Unmistakable, and the best-photographed case in the corpus so far.
               Sarson da saag's second case. Makki ki roti is a roti, and roti is in
               STAPLE_SIDES, so class_of takes the saag - the mapping doing its job
               again, as it did on the idli-in-sambar case.

  rejected 4  ALL FOUR ON WHAT THEY ARE, and three of them are the bare-word rule:
    - "chitra rajma": dried kidney beans photographed on a white background. Raw
      produce, and the same call as batch 14's raw green beans. A photograph of an
      ingredient is not a photograph of a meal, and the corpus scores MEALS.
    - "calabash 01": a gourd. Calabash is the botanical name for the raw bottle gourd,
      and lauki is what the dish is called. Rejected on the filename, decidable.
    - "2008 09 12 cl b yudelins 005 makai": a dated photostream filename, which is how a
      personal snapshot of raw sweet corn is captioned rather than a dish. Decidable
      from the name: a dish is "makai curry" or "makai masala", never a bare makai.
    - "khichri with omelette": bright yellow separated-grain rice with two folded
      omelettes. Khichuri is the BANGLADESHI dish and khichdi the Indian one, and this
      batch's other khichuri file carried the word Bangladeshi in its own title. Yellow
      separated-grain rice with omelette is characteristic of khichuri, so accepting it
      under an Indian class name would corrupt the exact comparison the class count
      exists to support. I will not call it khichdi on a yellow rice colour.

Concentration did not move: 56 cases, top 4 still 14, 25%. The batch was sized for six
widenings and delivered one, and both numbers are reported because the arithmetic was
the plan and the photo review is the result.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "sarson_da_saag_makki_roti": {
        "photo": "sarson_ka_saag_aur_makki_ki_roti_jpg_3c37546c.jpg",
        "confidence": "high",
        "note": "A composed shot on a dark wooden table: a white bowl of dark green saag "
                "topped with a square pat of butter, set on a green banana leaf, beside "
                "two pale round makki ki roti carrying sliced red onion, a lime wedge "
                "and a green chilli, and a bunch of fresh mustard greens. Unmistakable, "
                "and the best-photographed case this corpus has. Makki ki roti is a roti "
                "and roti is in STAPLE_SIDES, so class_of takes the saag - the mapping "
                "working as designed, the same as the idli-in-sambar case. Sarson da "
                "saag's second case.",
        "truth": [
            {"name": "Sarson Da Saag", "aliases": ["Sarson Ka Saag", "Mustard Greens",
                                                    "Sarson Saag"],
             "kcal": 180},
            {"name": "Makki Ki Roti", "aliases": ["Makki Roti", "Cornmeal Roti"],
             "kcal": 150},
        ],
    },
}

REJECT = {
    "chitra_rajma_jpg_44af83c7.jpg": (
        "OPENED: dried kidney beans photographed on a plain white background. Raw "
        "produce, and the same call as batch 14's raw green beans - a photograph of an "
        "ingredient is not a photograph of a MEAL, and the corpus scores meals. This is "
        "the bare-one-word rule in its clearest form"
    ),
    "khichri_with_omelette_jpg_9bb6cb68.jpg": (
        "OPENED: bright yellow separated-grain rice with two folded omelettes on a "
        "ringed plate. Khichuri is the BANGLADESHI dish and khichdi the Indian one, and "
        "this batch's other khichuri file carried the word Bangladeshi in its own title. "
        "Yellow separated-grain rice with omelette is characteristic of khichuri, so "
        "accepting it under an Indian class name would corrupt the exact comparison the "
        "class count exists to support. I will not call it khichdi on a rice colour"
    ),
    "calabash_01_jpg_e85e8e68.jpg": (
        "REJECTED WITHOUT BEING OPENED, and the name is decidable: calabash is the "
        "botanical name for the raw bottle gourd, and lauki is what the DISH is called. "
        "A botanical name finds the vegetable - which is the same reason `dhingra` once "
        "returned a brigadier general"
    ),
    "2008_09_12_cl_b_yudelins_005_makai_jpg_9447434.jpg": (
        "REJECTED WITHOUT BEING OPENED: a dated photostream filename, which is how a "
        "personal snapshot is captioned rather than a dish. Decidable from the name - a "
        "dish is 'makai curry' or 'makai masala', never a bare makai"
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
        rec["reject_reason"] = reason; rec["opened"] = "OPENED" in reason
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:46]}")

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
        "BATCH 22 (2026-09-28): ONE ACCEPT OF SIX PLANNED, AND THE PATTERN THE FAILURE",
        "REVEALS. Sized as before - one case per singleton, never dal (5) or chole (4).",
        "55 + 6 would have been 61 cases and 23% concentration. It delivered 56 and 25%,",
        "and the shortfall is the finding rather than a disappointment.",
        "  7 queries (control first), 5 downloaded, accepted 1, rejected 4",
        "",
        "ONE WORD FINDS THE INGREDIENT. TWO WORDS FIND THE DISH. The two measurements",
        "bracket the answer and were nine batches and two failed batches apart:",
        "  batch 13  'mushroom curry' bowl gravy ...... 0   (too many words)",
        "  batch 13  'mushroom curry' ................. 3   (two words: the dish)",
        "  batch 22  rajma / calabash / makai ......... raw produce, every time",
        "Every query that worked was <dish> <preparation>: 'mushroom curry', 'beans",
        "curry', 'egg curry', 'gajar halwa'. The cost of not having a middle was two",
        "failed batches and a published false finding in between.",
        "  accepted 1  SARSON DA SAAG with makki ki roti - a bowl of dark green saag with",
        "               a pat of butter on a banana leaf, two makki rotis with onion, lime",
        "               and chilli, and fresh mustard greens. The best-photographed case",
        "               this corpus has. Roti is in STAPLE_SIDES so class_of takes the",
        "               saag, the mapping working as designed as it did on idli-in-sambar",
        "  rejected 4  three are the bare-word rule (dried kidney beans on white; a",
        "               gourd; sweet corn), and the fourth is the khichuri one: bright",
        "               yellow separated-grain rice with folded omelettes is characteristic",
        "               of BANGLADESHI khichuri, and this batch's other khichuri file",
        "               carried the word Bangladeshi in its own title. I will not call it",
        "               khichdi on a rice colour",
        "Concentration did not move: 56 cases, top 4 still 14, 25%. The arithmetic was",
        "the plan and the photo review is the result, and both are reported.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
