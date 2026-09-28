#!/usr/bin/env python3
"""Apply batch 14 - the round where the QUERIES were the problem, and a control said so.

Batch 13 also returned zero. Three batches have now returned zero for three DIFFERENT
reasons, and a control query is the only reason I know which one is which:

    CONTROL, known-good, worked in batch 12 ....... 1 candidate   <- the API is fine
    'filetype:bitmap "mushroom curry" bowl gravy'  0 candidates   <- batch 13's wording
    'filetype:bitmap "mushroom curry"' ........... 3 candidates   <- same dish, fewer words
    'mushroom curry' (no filetype filter) ........ 3 candidates
    'khakra gujarati' (no filetype filter) ....... 0 candidates   <- this one is thin

So batch 13's cause was MY query construction, not Commons. `filetype:bitmap` plus a
quoted phrase plus two form words is over-constrained, and batch 13's premise - widen the
dish FORM - widened the query into uselessness. The dish was there the whole time. Only
khakra has now come back empty from every angle, which makes it the one candidate for a
genuine absence.

  8 queries, 19 openly licensed candidates, 5 downloaded.

  accepted 1  BEANS AND POTATO, in a steel bowl. Chopped green beans with visible
               cubed potato, a dried red chilli and cumin seeds - a dry beans
               preparation rather than a gravy, and the photograph is the bowl of the
               cooked dish. The beans are the dish; the potato is a second component and
               class_of takes the beans. French beans' first case, and the class has been
               declared and empty since batch 9.

  rejected 3  OPENED, AND THE REASON IN EVERY CASE IS THAT THE PIXELS DO NOT SHOW THE
               DISH THE TITLE PROMISES:

    - "mushroom poori": a street plate in a fluted foil dish held in one hand, with
      plastic spoons - chopped raw onion, carrot shreds, red chilli sauce and golden
      fried crinkly poori. NO MUSHROOM IS VISIBLE. The class this batch wanted was
      mushroom, and taking the label from the filename would be asserting an ingredient
      I cannot see. Same fault as batch 11's uthappam plate and its garlic bread.

    - "38 cimg1598" (french beans query): a close-up of a pile of RAW green beans, a
      market photograph of uncooked produce. Not a meal, and a photo of raw vegetables
      carries no dish truth to score against.

    - "boletus luridus 2011 g1": REJECTED ON THE FILENAME WITHOUT BEING OPENED, and the
      ground is decidable. A Latin species binomial with a "2011 g1" field-record suffix
      is a botanical record of a wild bolete, not a dish, and no reading of those pixels
      would make it a curry.

  not_used 1  "curry chicken green beans" names two non-staple components on one plate -
              chicken and beans - so class_of would score it by whichever I typed first,
              and the class would be decided by my ordering rather than the photograph.
              Decidable from the title, so it was not opened; recorded as not-used
              rather than as judged-and-failed, which is what happened.

MUSHROOM IS STILL EMPTY, and this time for an honest reason rather than a throttle: the
dish is demonstrably on Commons - three candidates came back the moment the form words
came off - but the ones fetched under a looser query are street food and botanical
records rather than a plate of mushroom curry. The next attempt should query the dish
with a word that forces a PLATE, and should expect to look at more candidates to find
one.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "beans_potato_bowl": {
        "photo": "dry_beans_curry_jpg_7c44ee2d.jpg",
        "confidence": "medium",
        "note": "A shallow steel bowl of a cooked dry beans preparation: chopped green "
                "beans cut short, visible cubes of boiled potato, one dried red chilli "
                "and cumin seeds. It is a dry sabzi rather than a gravy curry, and the "
                "photograph is a close view into the bowl on a stovetop. The beans are "
                "the dish and the potato is a second component, so class_of takes the "
                "beans. Medium rather than high because the photograph is a bowl being "
                "cooked rather than a plated serving, so there is no portion context. "
                "French beans' first case; the class has been declared and empty since "
                "batch 9.",
        "truth": [
            {"name": "French Beans", "aliases": ["Green Beans", "Beans Curry",
                                                 "Beans Poriyal", "Gavar Phali"],
             "kcal": 130},
            {"name": "Potato", "aliases": ["Aloo", "Boiled Potato"], "kcal": 90},
        ],
    },
}

REJECT = {
    "mushroom_poori_jpg_0e652f4c.jpg": (
        "OPENED, and no mushroom is visible. A street plate in a fluted foil dish held in "
        "one hand with plastic spoons: chopped raw onion, carrot shreds, red chilli "
        "sauce and golden fried crinkly poori. The class this batch wanted was mushroom, "
        "and taking the label from the filename would be asserting an ingredient I "
        "cannot see - the same fault as batch 11's uthappam plate and its garlic bread"
    ),
    "38_cimg1598_jpg_c426bbde.jpg": (
        "OPENED: a close-up of a pile of RAW green beans, a market photograph of "
        "uncooked produce. Not a meal, and a photograph of raw vegetables carries no dish "
        "truth to score against"
    ),
    "boletus_luridus_2011_g1_jpg_dae030f2.jpg": (
        "REJECTED ON THE FILENAME WITHOUT BEING OPENED, and the ground is decidable: a "
        "Latin species binomial with a '2011 g1' field-record suffix is a botanical "
        "record of a wild bolete, not a dish, and no reading of those pixels would make "
        "it a curry"
    ),
}

NOT_USED_TITLE_DECIDED = {
    "curry_chicken_green_beans_jpg_fc6297ca.jpg": (
        "NOT OPENED, and the title decides it: the name carries two non-staple "
        "components on one plate - chicken and beans - so class_of would score the case "
        "by whichever I typed first, and the class would be decided by my ordering rather "
        "than by the photograph. Declared not-used rather than judged-and-failed, "
        "because that is what happened: opening it to reject it on a title I had already "
        "read would have spent a minute of the owner's laptop to re-decide a fact"
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
        rec["opened"] = "OPENED" not in reason
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:50]}")

    for name, reason in NOT_USED_TITLE_DECIDED.items():
        rec = photos.get(name)
        if rec is None:
            print(f"  ! not in the manifest, skipped: {name}")
            continue
        rec["reviewed"] = True
        rec["not_used"] = True
        rec["not_used_reason"] = reason
        print(f"  ~ {name[:50]} (not opened)")

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
        "BATCH 14 (2026-09-28): THE QUERIES WERE THE PROBLEM, AND A CONTROL SAID SO. Batch",
        "13 also returned zero, so three batches have now returned zero for three",
        "DIFFERENT reasons and a control query is the only reason I know which is which:",
        "  CONTROL, known-good, worked in batch 12 ..... 1 candidate   <- the API is fine",
        "  'filetype:bitmap \"mushroom curry\" bowl gravy'  0         <- batch 13's wording",
        "  'filetype:bitmap \"mushroom curry\"' ........... 3         <- same dish, fewer words",
        "  'mushroom curry' (no filetype filter) ........ 3",
        "  'khakra gujarati' (no filetype filter) ....... 0         <- this one is thin",
        "So batch 13's cause was MY query construction. filetype:bitmap plus a quoted",
        "phrase plus two form words is over-constrained, and batch 13's premise - widen the",
        "dish FORM - widened the query into uselessness. The dish was there the whole time.",
        "8 queries, 19 candidates, 5 downloaded.",
        "  accepted 1  beans and potato in a steel bowl - a dry sabzi, not a gravy, with",
        "               visible potato cubes, a dried red chilli and cumin. French beans'",
        "               first case; the class has been declared and empty since batch 9",
        "  rejected 3  two OPENED, both because the pixels do not show the dish the title",
        "               promises: 'mushroom poori' is a street plate of onion, carrot,",
        "               chilli sauce and poori with NO MUSHROOM VISIBLE, and one is raw",
        "               green beans at market. One rejected on the filename WITHOUT being",
        "               opened - a Latin species binomial with a field-record suffix is a",
        "               botanical record - recorded as not-looked, not judged-and-failed",
        "  not_used 1  'curry chicken green beans' names two non-staple components, so the",
        "               class would be decided by my typing order; decidable from the title",
        "MUSHROOM IS STILL EMPTY, and now for an honest reason rather than a throttle: the",
        "dish is demonstrably on Commons - three candidates the moment the form words came",
        "off - but what comes back is street food and botanical records rather than a plate",
        "of mushroom curry. Only KHAKRA has now come back empty from every angle, which",
        "makes it the one real candidate for a genuine absence.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
