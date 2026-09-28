#!/usr/bin/env python3
"""Apply batch 24 - two words is NECESSARY, not sufficient, and a named gap for lauki.

7 queries (control first), 5 downloaded, accepted 4, rejected 1.

THE RULE FROM BATCH 23 WAS TOO STRONG, AND THIS BATCH NARROWS IT. Batch 22 measured that
one word finds the ingredient and too many words find nothing, and batch 23 confirmed
two words find the dish. Batch 23 then produced two real zeros IN THE SAME BATCH with the
control positive in that batch, so they were zeros of what the corpus can reach rather
than of the instrument:

    "rajma curry" ... HIT      "lauki sabzi" ... ZERO
    "capsicum curry" HIT      "makai curry" .. ZERO

So: ONE word finds the ingredient, TOO MANY words find nothing, and two words find the
dish only when the second word is one already measured working. "curry" has now worked
five times. "sabzi" and "masala" were guessed at and are not measured, and this batch
leans on the word that works instead of inventing a third.

LAUKI IS A NAMED GAP, NOT A RETRY, and this is the part of the round that matters most.
It has now been attempted three ways and failed three ways:

    lauki ............... a gourd          (the ingredient, not the dish)
    "lauki sabzi" ....... 0                 (control POSITIVE in the same batch)
    "lauki curry" ....... 0                 (control POSITIVE in the same batch)

Three attempts, two of them with a positive control in the same batch, so this is not
access and it is not a rate limit. Lauki stays a singleton with one case and the reason
is on the record. Declared rather than back-filled, because a class that cannot be
photographed is a fact about the instrument and a fact I would otherwise be tempted to
paper over with a case I cannot defend.

    58 + 4 = 62 cases, 33 + 1 = 34 classes, top 4 now 5+4+3+3 = 15  ->  15/62 = 24%

ACCEPTED 4 - one brand-new class, two singletons filled, one that grows a top-four class.

  KARELA (a class the corpus did not have) - the ridged, seeded, warty green half-rings
    are bitter gourd cut crosswise and nothing else looks like that: tomato, onion, whole
    green chillies and black mustard seed in a close-up on a steel plate. Added to
    DISH_CLASS as `"karela": "karela"` so the class is a DECISION rather than the
    `DISH_CLASS.get(n, n)` fallback, which is precisely what
    test_every_class_the_corpus_uses_is_a_declared_dish_class_key exists to catch. The
    first class in four batches, and it was added by looking at a photograph rather than
    by planning one.

  MUSHROOM MASALA - a white oval dish of red-orange gravy with rounded pale pieces
    consistent with button mushroom, angular potato and fresh coriander. Medium-high: the
    rounded pieces are mushroom, the angular ones are potato, and the class is decided by
    the former. Mushroom's second case.

  CHICKEN CURRY - boneless chicken in red-orange gravy with black mustard seed, curry
    leaves and a bay leaf, in a steel kadai with a serving spoon. High and
    uninteresting, which is what a good case looks like. Chicken curry's second case.

  MASALA DOSA - a crisp folded golden dosa with a bowl of orange sambar and a glass bowl
    of pale yellow coconut chutney. And this one is a trap I measured before labelling
    rather than after:

        class_of(["Masala Dosa", "Sambar", "Chutney"]) -> 'dosa'     correct
        class_of(["Dosa", "Sambar", "Chutney"])        -> 'sambar'   the trap

    "dosa" is in STAPLE_SIDES, so class_of SKIPS a truth item named "Dosa" and takes the
    next non-staple one - which would have filed this photograph of a dosa into SAMBAR,
    a class that already holds three cases, inflating it and the concentration, for a
    plate whose sambar is a side dish. Labelling it "Masala Dosa" is what keeps it where
    the photograph actually is. This is the third time STAPLE_SIDES has decided a class
    for me (idli in sambar, makki ki roti in sarson da saag) and the first time the trap
    was closed BEFORE the label was written instead of after.

  It is accepted even though it grows dosa from 2 to 3 and therefore grows the top four.
    The concentration arithmetic is reported below rather than engineered: refusing an
    honest case to protect a number is the same fault as tuning a record to match an
    instrument I have already disproved.

REJECTED 1.

  "gobi curry" - a thali photographed from above: steel plates, chapati, sliced tomato
    and onion, and a coarse granular brown curry in the middle. REJECTED because NO
    CAULIFLOWER IS VISIBLE ANYWHERE and the granular mass could equally be a dal or a dry
    sabzi. This is the same refusal as the vegetable pulao in batch 23 and for the same
    reason: the title is a claim about the dish and the frame is the evidence, and where
    they disagree the frame wins. Accepted on the title it would have created a gobi
    class on nothing but a filename.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "karela_ghassi": {
        "photo": "karela_curry_jpg_28c301cf.jpg",
        "confidence": "high",
        "note": "A close-up of the ridged, seeded, warty green half-rings that are bitter "
                "gourd cut crosswise - tomato, onion, whole green chillies and black "
                "mustard seed in an oiled masala, on a steel plate. Nothing else looks "
                "like that cross-section, and the rings are countable, so the class is "
                "certain. THE FIRST GENUINELY NEW CLASS IN FOUR BATCHES, and it arrived "
                "by looking at a photograph rather than by planning one. Added to "
                "DISH_CLASS as \"karela\": \"karela\" so the class is a DECISION rather "
                "than the DISH_CLASS.get(n, n) fallback - which is exactly what "
                "test_every_class_the_corpus_uses_is_a_declared_dish_class_key catches, "
                "and I did not want a class in the count that came from a fallback.",
        "truth": [
            {"name": "Karela", "aliases": ["Karela Curry", "Bitter Gourd Curry",
                                           "Bitter Gourd Fry", "Karela Ghassi",
                                           "Karela Sabzi"],
             "kcal": 150},
        ],
    },
    "mushroom_masala_plate": {
        "photo": "mushroom_masala_by_dr_raju_kasambe_img_20190701_5_jp_7d273b38.jpg",
        "confidence": "medium-high",
        "note": "A white oval dish of red-orange gravy holding rounded pale pieces "
                "consistent with halved button mushroom, angular potato and fresh "
                "coriander, on a dark stone surface. Medium-high and the reason is "
                "specific: the ROUNDED pieces are mushroom and the ANGULAR ones are "
                "potato, and the class is decided by the former, which is why this is "
                "not simply 'high'. Labelled 'Mushroom Masala' because that name is a "
                "DISH_CLASS key and resolves to the mushroom class rather than minting "
                "a 'mushroom masala' class of its own. Mushroom's second case.",
        "truth": [
            {"name": "Mushroom Masala", "aliases": ["Mushroom Curry", "Mushroom Sabzi",
                                                     "Button Mushroom Masala"],
             "kcal": 180},
        ],
    },
    "chicken_curry_kadai": {
        "photo": "chicken_curry_4_jpg_38f89bd8.jpg",
        "confidence": "high",
        "note": "Boneless chicken pieces in a red-orange gravy flecked with black mustard "
                "seed, curry leaves and a bay leaf, in a steel kadai with a serving "
                "spoon across it. High and unremarkable, which is what a good case looks "
                "like - the frame shows the whole preparation rather than a corner of "
                "it. Chicken curry's second case.",
        "truth": [
            {"name": "Chicken Curry", "aliases": ["Murgh Curry", "Chicken Masala",
                                                   "Murgh Masala"],
             "kcal": 280},
        ],
    },
    "masala_dosa_sambar_chutney": {
        "photo": "masaladosa_jpg_feac07c1.jpg",
        "confidence": "high",
        "note": "A crisp folded golden-brown dosa on a white plate, with a bowl of "
                "orange sambar carrying vegetable bits and a dried red chilli, and a "
                "scalloped glass bowl of pale yellow coconut chutney dotted with black "
                "mustard seed. LABELLED 'Masala Dosa' AND NOT 'Dosa' ON PURPOSE, and this "
                "is a measured trap rather than a style note: dosa is in STAPLE_SIDES, so "
                "class_of skips a truth item named 'Dosa' and takes the next non-staple "
                "one, which measured as class_of(['Dosa','Sambar','Chutney']) -> "
                "'sambar'. Filing a photograph of a dosa into sambar - a class already "
                "holding three cases - because the side dish came second in the label is "
                "exactly the kind of quiet corruption the class count exists to prevent. "
                "class_of(['Masala Dosa','Sambar','Chutney']) -> 'dosa'. Third time "
                "STAPLE_SIDES has decided a class for me, and the first time the trap "
                "was closed BEFORE the label was written. Accepted even though it grows "
                "dosa from 2 to 3 and therefore grows the top four: refusing an honest "
                "case to protect a concentration number is the same fault as tuning a "
                "record to match an instrument I have already disproved. Dosa's third "
                "case.",
        "truth": [
            {"name": "Masala Dosa", "aliases": ["Dosa", "Masaldosa", "Plain Dosa"],
             "kcal": 250},
            {"name": "Sambar", "aliases": ["Sambhar"], "kcal": 100},
            {"name": "Coconut Chutney", "aliases": ["Chutney", "Coconut Chutney"],
             "kcal": 150},
        ],
    },
}

REJECT = {
    "gobi_curry_jpg_e1b6be60.jpg": (
        "OPENED: a thali photographed from above - steel plates, chapati, sliced tomato "
        "and onion, and a coarse granular brown curry in the middle. Rejected because NO "
        "CAULIFLOWER IS VISIBLE ANYWHERE and the granular mass could equally be a dal or "
        "a dry sabzi. The same refusal as the vegetable pulao in batch 23 and for the same "
        "reason: the title is a CLAIM about the dish and the frame is the EVIDENCE, and "
        "where they disagree the frame wins. Accepted on the title alone it would have "
        "created a gobi class on nothing but a filename - and a class is supposed to be "
        "something the corpus can see, not something a search result asserted"
    ),
}

# Lauki, three ways, declared rather than retried forever.
NAMED_GAPS = {
    "lauki": (
        "A NAMED GAP, NOT A RETRY, and the most useful negative in four batches. Attempted "
        "three ways and failed three ways: a bare `lauki` returned a gourd (the "
        "ingredient, not the dish); \"lauki sabzi\" returned 0; \"lauki curry\" returned "
        "0. The last two were in batches whose control query was POSITIVE in the same "
        "batch, so this is neither access nor a rate limit. Lauki therefore stays a "
        "singleton holding one case, with the reason on the record. Declared rather than "
        "back-filled, because a class that cannot be photographed is a fact about the "
        "instrument, and a fact I would otherwise be tempted to paper over with a case I "
        "cannot defend."
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
        print(f"  + {case_id}  ({spec['confidence']})")

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
        print(f"  - {name}")

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
        "BATCH 24 (2026-09-28): TWO WORDS IS NECESSARY, NOT SUFFICIENT - and a NAMED GAP,",
        "which is the more useful of the two.",
        "  7 queries (control first), 5 downloaded, accepted 4, rejected 1",
        "    58 + 4 = 62 cases, 33 + 1 = 34 classes, top 4 now 5+4+3+3 = 15 -> 15/62 = 24%",
        "",
        "Batch 23's rule was too strong and this batch narrows it. Batch 23 produced two",
        "real zeros IN THE SAME BATCH with the control POSITIVE in that batch, so they",
        "were zeros of what the corpus can reach, not of the instrument:",
        '  "rajma curry" HIT    "lauki sabzi" ZERO    "capsicum curry" HIT    "makai curry" ZERO',
        "One word finds the ingredient, too many words find nothing, and two words find",
        "the dish only when the second word is one already MEASURED working. \"curry\" has",
        "now worked five times; \"sabzi\" and \"masala\" were guessed at.",
        "",
        "LAUKI IS A NAMED GAP, NOT A RETRY - three attempts, three failures:",
        "  lauki ............. a gourd        (the ingredient, not the dish)",
        '  "lauki sabzi" ..... 0               (control POSITIVE in the same batch)',
        '  "lauki curry" ..... 0               (control POSITIVE in the same batch)',
        "Neither access nor a rate limit. Lauki stays a singleton with one case and the",
        "reason is on the record. Declared rather than back-filled, because a class that",
        "cannot be photographed is a fact about the INSTRUMENT, and a fact I would",
        "otherwise be tempted to paper over with a case I cannot defend.",
        "",
        "  accepted 4  KARELA - a class the corpus did not have. The ridged, seeded, warty",
        "               green half-rings are bitter gourd cut crosswise and nothing else",
        "               looks like that. Added to DISH_CLASS as \"karela\": \"karela\" so",
        "               the class is a DECISION, not the DISH_CLASS.get(n, n) fallback",
        "               that test_every_class_the_corpus_uses_is_a_declared_dish_class_key",
        "               exists to catch. The first new class in four batches, and it came",
        "               from LOOKING at a photograph rather than from planning one.",
        "  accepted 4  MUSHROOM MASALA - red-orange gravy, ROUNDED pale pieces are",
        "               mushroom and the ANGULAR ones are potato; the class is decided by",
        "               the former, which is why this is medium-high and not high.",
        "  accepted 4  CHICKEN CURRY - boneless chicken in red-orange gravy with black",
        "               mustard seed, curry leaves and a bay leaf, in a steel kadai. High",
        "               and unremarkable, which is what a good case looks like.",
        "  accepted 4  MASALA DOSA - and a trap MEASURED BEFORE the label was written:",
        "               class_of(['Masala Dosa','Sambar','Chutney']) -> 'dosa'   correct",
        "               class_of(['Dosa','Sambar','Chutney'])        -> 'sambar' the trap",
        "               dosa is in STAPLE_SIDES, so class_of SKIPS an item named 'Dosa'",
        "               and takes the next non-staple one - filing a photograph of a dosa",
        "               into SAMBAR, a class already holding three, because the side dish",
        "               came second in the label. Third time STAPLE_SIDES has decided a",
        "               class for me (idli in sambar, makki ki roti in sarson da saag),",
        "               and the first time closed BEFORE the label rather than after.",
        "               Accepted even though it grows dosa 2 -> 3 and so grows the top four.",
        "               Refusing an honest case to protect a concentration number is the",
        "               same fault as tuning a record to match a disproved instrument.",
        "",
        "  rejected 1  'gobi curry' - a thali from above with a coarse granular curry and",
        "               NO VISIBLE CAULIFLOWER ANYWHERE; the mass could be a dal or a dry",
        "               sabzi. The same refusal as the vegetable pulao, for the same reason:",
        "               the title is a CLAIM and the frame is the EVIDENCE, and where they",
        "               disagree the frame wins. On the title alone it would have created a",
        "               gobi class out of a filename.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
