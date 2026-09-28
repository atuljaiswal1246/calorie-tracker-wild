#!/usr/bin/env python3
"""Apply batch 23 - batch 22's failures retried in the two-word form, and the fork the
labelling nearly caused.

7 queries (control first), 4 downloaded, accepted 2, rejected 2.

THE TWO-WORD FORM WORKS, AND IT WORKS ON THE VERY QUERIES THAT FAILED AS ONE WORD.
Batch 22 rejected three photographs for a single reason - the query was a bare
ingredient. `rajma` returned dried kidney beans, `calabash` a gourd, `makai` sweet
corn. Batch 13 had already measured the other end: a quoted phrase plus two form words
finds NOTHING. So the two measurements bracket the working form, and it is two words:

    "mushroom curry" bowl gravy ....... 0    too many words
    "mushroom curry" ................. 3    the dish
    rajma / calabash / makai .......... raw produce, every time
    "rajma curry" ..................... a curry with countable beans in it

Every query here is <dish> <preparation>, the form of every query that has ever worked
in this corpus: "mushroom curry", "beans curry", "egg curry", "gajar halwa", "sarson
da saag", "rajma curry", "egg bhurji", "vegetable pulao".

    56 + 2 = 58 cases, top 4 still 14  ->  14/58 = 24%

ACCEPTED 2, both singleton classes gaining their second case.

  egg     EGG BHURJI - scrambled egg in yellow and white curds with distinct chunks of
          red tomato, on a dark plate, under fresh coriander, a whole star anise and
          cumin seed. Unmistakable. The class is `egg` and it is `egg` whichever way the
          dish is named: class_of(["Egg Bhurji"]) and class_of(["Egg Curry"]) both return
          'egg', so the bhurji-or-curry ambiguity does not touch the comparison the
          class count exists to support. The visible evidence is a dry-ish scramble
          rather than a gravy, which is why this is labelled bhurji - and the alias list
          carries "Egg Curry" so a model that answers the other name is not punished for
          it. The "lemonar" in the filename is a place or herb name and has no bearing
          on what is in the frame.

  rajma   GOURD RAJMA CURRY WITH COCOONUT - a steel bowl of pale coconut gravy holding
          countable dark red kidney beans and slices of dark-skinned bottle gourd, with
          curry leaf and a whole dried red chilli. Accepted MEDIUM, and the medium is
          honest: the beans are countable so the class is certain, but the dish is a
          two-vegetable curry and the gourd is doing about half the visual work.

REJECTED 2, and both are refusals I have made before.

  "indian vegetable pulao": a moulded cylinder of WHITE rice on a glass plate, with
    mustard seed, cumin, a lime wedge, a carved tomato rose, cucumber slices and raw
    onion rings, served with a bowl of green chutney and a bowl of an unidentified red
    liquid. Rejected on the strongest cue the dish has: pulao is characteristically
    YELLOW, ghee-rich, spiced grain, and this rice is white with no vegetable visible
    enough to confirm the title. The red bowl is unidentified, which would make a second
    judgement impossible. This is the same standard as refusing to call the batch 22
    khichuri "khichdi" on a rice colour - and consistency is the whole point, because a
    corpus that applies its standard on a good day and not on another is not a corpus,
    it is a mood. I could have accepted it on the title alone. I did not, and `pulao`
    stays a singleton rather than gaining a case I cannot defend.

  "all you can eat lunch buffet, spice kitchen, Aud12/95": rejected WITHOUT being
    opened, and the title is decidable - an all-you-can-eat buffet is a spread of many
    dishes, not a dish, and the corpus scores MEALS. It surfaced under "capsicum curry",
    so nothing in the title promises a single capsicum preparation.

AND THE FINDING THIS BATCH PRODUCED BY ACCIDENT, which is worth more than the two
cases. class_of is `DISH_CLASS.get(n, n)` - the name is its own fallback - and
DISH_CLASS carries 'rajma': 'rajma' but NOT 'rajma curry'. So labelling this photograph
the way it is titled, "Rajma Curry", measures as:

    class_of(["Gourd Rajma Curry"]) -> 'gourd rajma curry'     a NEW class
    class_of(["Rajma Curry"])       -> 'rajma curry'           a NEW class
    class_of(["Rajma"])             -> 'rajma'                 the real one

THE CLASS COUNT HAS A HOLE IN IT, AND IT IS NOT A MISSING BAR - IT IS A MISSING MAP. Any
truth name that is not a key in DISH_CLASS does not fall back to the dish it names, it
becomes a brand-new class, and the corpus would then count one dish twice and call the
result independence. It was avoided here by labelling the item "Rajma", which is what
the existing rajma_brinjal_masala case already does.

The honest fix is not a rename in this one photograph. It is a check that a class cannot
silently fork off another, which is what test_the_dish_classes_are_distinct.py now
carries.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "egg_bhurji_star_anise": {
        "photo": "egg_burji_lemonar_jpg_0944fd0b.jpg",
        "confidence": "high",
        "note": "Scrambled egg in yellow and white curds with distinct chunks of red "
                "tomato, served on a dark plate and topped with fresh coriander, one "
                "whole star anise and cumin seed. Unmistakable, and the class is 'egg' "
                "whichever way the dish is named - class_of returns 'egg' for both 'Egg "
                "Bhurji' and 'Egg Curry', so the ambiguity does not touch the comparison "
                "the class count exists to support. The visible evidence is a dry-ish "
                "scramble rather than a gravy, which is why this is labelled bhurji, and "
                "the alias list carries 'Egg Curry' so a model answering the other name "
                "is not punished for it. The 'lemonar' in the filename is a place or herb "
                "name and has no bearing on what is in the frame. Egg's second case.",
        "truth": [
            {"name": "Egg Bhurji", "aliases": ["Egg Curry", "Anda Bhurji",
                                                "Scrambled Egg", "Egg Keema"],
             "kcal": 220},
        ],
    },
    "rajma_gourd_coconut_curry": {
        "photo": "gourd_rajma_curry_with_coconut_jpg_aec19af8.jpg",
        "confidence": "medium",
        "note": "A steel bowl of pale coconut gravy holding countable dark red kidney "
                "beans and slices of dark-skinned bottle gourd, with curry leaf and a "
                "whole dried red chilli. The beans are countable, so the class is "
                "certain; the MEDIUM is honest because the dish is a two-vegetable curry "
                "and the gourd is doing about half the visual work. LABELLED 'Rajma' AND "
                "NOT 'Rajma Curry' ON PURPOSE: class_of is DISH_CLASS.get(n, n), the name "
                "is its own fallback, and DISH_CLASS has 'rajma' but not 'rajma curry' - so "
                "the title of the photograph would have measured as a brand-new class and "
                "counted one dish twice. This is the same labelling the existing "
                "rajma_brinjal_masala case already uses. Rajma's second case.",
        "truth": [
            {"name": "Rajma", "aliases": ["Rajma Curry", "Gourd Rajma Curry",
                                           "Kulthigha", "Kidney Bean Curry"],
             "kcal": 200},
        ],
    },
}

REJECT = {
    "indian_vegetable_pulao_jpg_f3c35caf.jpg": (
        "OPENED: a moulded cylinder of WHITE rice on a glass plate with mustard seed, "
        "cumin, a lime wedge, a carved tomato rose, cucumber slices and raw onion rings, "
        "served beside a bowl of green chutney and a bowl of an unidentified red liquid. "
        "Rejected on the strongest cue the dish has - pulao is characteristically YELLOW, "
        "ghee-rich spiced grain, and this rice is white with no vegetable visible enough to "
        "confirm the title, and the red bowl is unidentified so a second judgement would "
        "be impossible. This is the same standard as refusing to call batch 22's khichuri "
        "khichdi on a rice colour; consistency is the whole point, because a corpus that "
        "applies its standard on a good day and not on another is a mood. I could have "
        "accepted this on the title alone and pulao would have stopped being a singleton, "
        "and that is exactly the trade the class count is not allowed to make"
    ),
    "all_you_can_eat_lunch_buffet_spice_kitchen_aud12_95__ea964cf7.jpg": (
        "REJECTED WITHOUT BEING OPENED, and the title is decidable: an all-you-can-eat "
        "lunch buffet is a SPREAD of many dishes, not a dish, and the corpus scores "
        "MEALS. It surfaced under 'capsicum curry', so nothing in the title promises a "
        "single capsicum preparation. Recorded as not-looked rather than judged-and-"
        "failed, because that is what it is"
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
        rec["opened"] = "OPENED" in reason
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
            "Fetched and never reviewed, so it is not evidence. Declared not-used "
            "rather than left unreviewed, because an undecided photo is "
            "indistinguishable from an accepted one.")

    corpus["_readme"].extend([
        "",
        "BATCH 23 (2026-09-28): THE TWO-WORD FORM WORKS ON THE VERY QUERIES THAT FAILED",
        "AS ONE WORD - and the class-count hole the labelling nearly walked into.",
        "  7 queries (control first), 4 downloaded, accepted 2, rejected 2",
        "    56 + 2 = 58 cases, top 4 still 14  ->  14/58 = 24%",
        "",
        "The bracket from batch 22 is now closed on both sides, and the middle is two",
        "words - the form of every query that has ever worked in this corpus:",
        "  'mushroom curry' bowl gravy ..... 0   too many words",
        "  'mushroom curry' ............... 3   the dish",
        "  rajma / calabash / maki ........ raw produce, every time",
        "  'rajma curry' ................. countable kidney beans in a curry",
        "",
        "  accepted 2  EGG BHURJI - scrambled egg with red tomato chunks under coriander,",
        "               a whole star anise and cumin. The class is 'egg' either way, since",
        "               class_of returns 'egg' for both 'Egg Bhurji' and 'Egg Curry', so",
        "               the naming ambiguity does not touch the comparison. Egg's 2nd case.",
        "  accepted 2  GOURD RAJMA CURRY WITH COCOCONUT - steel bowl, pale coconut gravy,",
        "               countable dark red kidney beans and dark bottle-gourd slices, curry",
        "               leaf and a dried red chilli. MEDIUM and honestly so: the beans are",
        "               countable so the class is certain, but the gourd does about half",
        "               the visual work. Rajma's second case.",
        "",
        "  rejected 2  'indian vegetable pulao' - WHITE rice, where pulao is characteristi-",
        "               cally YELLOW ghee-rich grain; no vegetable visible enough to confirm",
        "               the title; the red bowl is unidentified. Same standard as refusing",
        "               to call batch 22's khichuri khichdi on a rice colour, and consistency",
        "               is the point: a corpus that applies its standard on a good day and",
        "               not on another is a mood. Accepted on the title alone, pulao would",
        "               have stopped being a singleton, and that is the trade the class",
        "               count is not allowed to make.",
        "             an all-you-can-eat buffet - a SPREAD, not a dish, decidable from the",
        "               title, recorded as not-looked.",
        "",
        "AND THE FINDING THIS BATCH PRODUCED BY ACCIDENT, worth more than the two cases.",
        "class_of is DISH_CLASS.get(n, n): the name is its OWN FALLBACK, and DISH_CLASS",
        "carries 'rajma': 'rajma' but NOT 'rajma curry'. Measured, not assumed:",
        "  class_of(['Gourd Rajma Curry']) -> 'gourd rajma curry'   a NEW class",
        "  class_of(['Rajma Curry'])       -> 'rajma curry'         a NEW class",
        "  class_of(['Rajma'])             -> 'rajma'               the real one",
        "THE CLASS COUNT'S HOLE IS NOT A MISSING BAR, IT IS A MISSING MAP. A truth name",
        "that is not a key in DISH_CLASS does not fall back to the dish it names - it",
        "becomes a brand-new class, and the corpus would count one dish twice and call the",
        "result independence. Avoided here by labelling 'Rajma', as the existing",
        "rajma_brinjal_masala case already does, and the check that stops it recurring is",
        "in test_the_dish_classes_are_distinct.py.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
