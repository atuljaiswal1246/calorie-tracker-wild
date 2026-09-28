#!/usr/bin/env python3
"""Apply batch 16 - the last two empty classes, attacked by SYNONYM instead of by form.

Batch 15's control-supported negative finding said khakra "cannot be SEARCHED with the
words available", because "khakra" is a proper noun a 1784 map and a palace both match.
So batch 16 stopped trying other spellings of khakra and used a DIFFERENT NAME for the
food - mathari, the bhakri it is eaten with, farsi puri from the same snack family - and
for mushroom used the Hindi dhingra plus the visible FORMS, because a mushroom case needs
a photograph where a mushroom is VISIBLE.

  7 queries (the control first, proven in 12/14/15), 3 downloaded, accepted 1.

  accepted 1  BUTTON MUSHROOM FRY. Whole button mushrooms on a white plate, stems and
               caps unmistakable, lightly glazed and flecked with pepper. This is what
               batch 15 said the class needed and three previous batches failed to find:
               a photograph where the mushroom is VISIBLE rather than hidden under a
               dosa or dissolved in a katori of gravy.
               MEDIUM confidence, and the reason is stated rather than buried: the
               mushrooms are certain and the preparation is a dry fry, but the
               photograph carries NO Indian marker - no masala, no onion, no rice, no
               roti. The identification as an Indian preparation rests on "mushroom fry"
               being a standard Indian home dish, not on anything visible in the frame.
               The corpus's bar is Indian meals, so that is a claim about the caption and
               it is recorded as one.

  rejected 2  BOTH DECIDABLE FROM THE FILENAME, and one of them is the best illustration
              of the khakra problem in this whole line of work:

    - "brig gen ashok dhingra exits a uh60 black hawk helicopter": the query was
      `dhingra`, the Hindi word for mushroom, and the search returned a photograph of a
      BRIGADIER GENERAL NAMED ASHOK DHINGRA getting out of a helicopter. The Hindi word
      for mushroom is also an Indian surname. A name search is not a dish search, and no
      amount of query engineering fixes a term that is a person.

    - "githunguri tea farm": a tea plantation in Java. That is what `mathari` returned, so
      the Gujarati snack synonym does not reach the food on Commons either.

KHAKRA IS NOW EXHAUSTED AS A SEARCH PROBLEM, which is a different statement from "khakra
cannot be photographed" and the distinction is the whole value of batches 15 and 16: the
word is a proper noun that a map, a palace and a river match, and its synonyms reach a
tea plantation in Java. Four names, four non-dishes. The remaining honest options are a
photograph from a human hand, or accepting a corpus with 29 of its 33 declared classes
filled - which is a decision, not a failure, and it is not mine to take silently.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "button_mushroom_fry_plate": {
        "photo": "button_mushroom_fry_jpg_b17ec9da.jpg",
        "confidence": "medium",
        "note": "Whole button mushrooms on a white plate, stems and caps unmistakable, "
                "lightly glazed and flecked with cracked pepper and a few fried spice "
                "fragments, with one loose fragment off to the side. This is what batch 15 "
                "said the class needed and three previous batches failed to find: a "
                "photograph where the mushroom is VISIBLE rather than hidden under a dosa "
                "or dissolved in a katori of gravy. MEDIUM confidence and the reason is "
                "stated rather than buried - the mushrooms are certain and the "
                "preparation is a dry fry, but the frame carries no Indian marker: no "
                "masala, no onion, no rice, no roti. The identification as an Indian "
                "preparation rests on 'mushroom fry' being a standard Indian home dish, "
                "which is a claim about the caption and not about the picture. The "
                "corpus's bar is Indian meals, so that is exactly what this is.",
        "truth": [
            {"name": "Mushroom", "aliases": ["Dhingra", "Mushroom Masala",
                                              "Mushroom Fry", "Button Mushroom"],
             "kcal": 180},
        ],
    },
}

REJECT = {
    "brig_gen_ashok_dhingra_exits_a_uh60_black_hawk_helic": (
        "REJECTED WITHOUT BEING OPENED, and it is the clearest lesson in the whole "
        "synonym round: the query was `dhingra`, the Hindi word for mushroom, and the "
        "search returned a photograph of a BRIGADIER GENERAL NAMED ASHOK DHINGRA getting "
        "out of a UH-60 helicopter. The Hindi word for mushroom is also an Indian "
        "surname. A name search is not a dish search, and no query engineering fixes a "
        "term that is a person"
    ),
    "githunguri_tea_farm_jpg_c196082a.jpg": (
        "REJECTED WITHOUT BEING OPENED: a tea plantation in Java, which is what `mathari` "
        "returned. The Gujarati snack synonym does not reach the food on Commons either"
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
        "BATCH 16 (2026-09-28): THE LAST TWO EMPTY CLASSES, ATTACKED BY SYNONYM. Batch 15's",
        "control-supported negative finding said khakra 'cannot be SEARCHED with the words",
        "available', so this round stopped trying other spellings and used a DIFFERENT NAME",
        "for the food: mathari, the bhakri it is eaten with, farsi puri, and dhingra (the",
        "Hindi word for mushroom) plus the visible forms sabzi and fry - because a mushroom",
        "case needs a photograph where a mushroom is VISIBLE. 7 queries with the control",
        "first, 3 downloaded, accepted 1, rejected 2.",
        "  accepted 1  BUTTON MUSHROOM FRY - whole button mushrooms, stems and caps",
        "               unmistakable, lightly glazed with pepper. What batch 15 said the",
        "               class needed and three batches failed to find. MEDIUM confidence,",
        "               stated rather than buried: the mushrooms are certain, but the frame",
        "               carries no Indian marker - no masala, no onion, no rice, no roti. The",
        "               identification as an Indian preparation rests on 'mushroom fry'",
        "               being a standard Indian home dish, which is a claim about the",
        "               CAPTION and not about the picture, and the corpus's bar is Indian",
        "               meals, so that is recorded as what it is",
        "  rejected 2  'brig gen ashok dhingra exits a uh60 black hawk helicopter' - the",
        "               query was `dhingra`, the Hindi word for mushroom, and the search",
        "               returned a photograph of a BRIGADIER GENERAL NAMED ASHOK DHINGRA",
        "               getting out of a helicopter. The Hindi word for mushroom is also",
        "               an Indian SURNAME. A name search is not a dish search. And",
        "               'githunguri tea farm' - a tea plantation in Java, which is what",
        "               `mathari` returned",
        "KHAKRA IS NOW EXHAUSTED AS A SEARCH PROBLEM, which is a different statement from",
        "'khakra cannot be photographed': the word is a proper noun a map, a palace and a",
        "river all match, and its synonyms reach a tea plantation in Java. Four names, four",
        "non-dishes. The remaining honest options are a photograph from a human hand, or",
        "accepting a corpus with 29 of its 33 declared classes filled - a decision, not a",
        "failure, and not mine to take silently.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
