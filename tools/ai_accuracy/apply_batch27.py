#!/usr/bin/env python3
"""Apply batch 27 - a batch SIZED BY the measured precision, and the prediction is wrong
for a reason that is not about precision at all.

7 queries (control first), 2 downloaded, accepted 1, rejected 1.

THE PREDICTION, WRITTEN BEFORE THE FETCH, because the number I keep being wrong about is
this one. Batch 26's commit published the figure twenty-six batches ought to have had:

    44 of 107 reviewed photographs became cases = 41%

So a download is worth about 0.4 cases, and every batch estimate I had been making in my
head was optimistic by roughly half. This batch is the first sized from it:

    6 candidates x 0.41  ->  DECLARED EXPECT 2 CASES

AND THE PREDICTION FAILED, AND NOT BECAUSE THE PRECISION WAS WRONG. Four of the six target
queries returned ZERO pages:

    pages=1  uthappam breakfast     <- the control
    pages=0  "gwar curry"           cluster bean
    pages=3  "soya curry"           soy chunk
    pages=0  "tinda curry"          round gourd
    pages=0  "kacche kele curry"    raw banana
    pages=3  "methi malai"          fenugreek and pea
    pages=0  "amla murabba"         candied amla

Only 2 candidates existed. The precision figure was never applied to anything, because
there was nothing for it to apply to. PRECISION IS NOT THE BINDING CONSTRAINT - PAGES
RETURNED IS. That is a real distinction and it took a declared prediction to see it, which
is the argument for declaring predictions: the arithmetic can be right and the input can
be wrong, and only writing the number down separates the two.

AND THE PREDICTION WAS BARELY FALSIFIABLE, which is worth saying rather than claiming a
clean miss. The ceiling was 2 - the batch could not return more than 2 cases - so I
predicted 2 and got 1. A prediction is only informative when the ceiling sits above it,
and I did not check the ceiling before writing the number, which is the same error as
sizing a batch by a precision figure without checking how many candidates it would
actually see.

THE TARGET LIST IS ALSO THE FINDING. Four of six new dishes - cluster bean, round gourd,
raw banana, candied amla - returned nothing at all, against a control that returned hits
in the same run, so these are real zeros of the archive rather than faults of the
instrument. The yield table's ranked list said the form that works is <legume or
vegetable> + a preparation word, and three of these are exactly that form and still found
nothing. So the form is necessary and NOT sufficient, which is the third time this corpus
has narrowed a rule I wrote down one round earlier - the same shape as batch 23 narrowing
batch 22's two-word rule, and batch 26 retracting batch 25's English-name rule.

ACCEPTED 1.

  METHI MALAI MATAR - a yellow leaf-shaped dish holding a pale cream gravy with countable
    whole green peas, chopped fenugreek leaves, a coriander sprig and two cashews, on a
    dark stone counter. High confidence and unremarkable, which is what a good case looks
    like.

    The frame holds peas AND fenugreek, so this is a declared ADJACENT class rather than a
    second methi case - the same call as chana and to dal in batch 26, where one bowl held
    two pulses, and the same reason: a case claiming only methi would be describing half
    the bowl, and a cream-pea curry and a dry fenugreek curry do not carry the same
    calories. So it does NOT become methi's second case; it is a class of its own.

REJECTED 1, and the reason is a limit rather than a disagreement.

  "2024_05_04 chicken soya curry" - a hammered-metal plate holding a red-orange gravy
    with sesame seed, green chilli and coriander over yellow rice, with orange slices and
    cucumber. The pieces in the gravy are the entire question, and I cannot resolve them
    from the frame: soya chunks take the colour of the gravy completely and become
    uniformly red-orange, which is exactly what these are, and chicken does the same. Their
    shape is irregular and rounded, consistent with either. Colour, which is what I would
    normally lean on, carries no information here.

    So the central truth label is UNRESOLVABLE and the file's own title - "chicken soya
    curry" - is itself ambiguous, naming both. I will not label a photograph "chicken"
    because the pieces look meaty, nor "soya" because the query asked for it, and a case
    whose one truth label cannot be established from the image is not a case: it is a
    photograph with a guess attached, and a wrong label in this corpus is the expensive
    kind of error - a wrong ANSWER rather than a missing one.

    Declared rather than filed, because "I could not tell" is a fact about the photograph
    and it is worth more on the record than a coin-flip case.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "methi_malai_matar_leaf_dish": {
        "photo": "methi_malai_matar_jpg_a499b343.jpg",
        "confidence": "high",
        "note": "A yellow leaf-shaped dish holding a pale cream gravy with countable whole "
                "green peas, chopped fenugreek leaves, a coriander sprig and two cashews, "
                "on a dark stone counter. High and unremarkable, which is what a good case "
                "looks like. The frame holds peas AND fenugreek, so this is a DECLARED "
                "ADJACENT class rather than a second methi case - the same call as chana "
                "and to dal in batch 26 where one bowl held two pulses, and for the same "
                "reason: a case claiming only methi would describe half the bowl, and a "
                "cream-pea curry and a dry fenugreek curry do not carry the same calories. "
                "So it does NOT become methi's second case; it is a class of its own.",
        "truth": [
            {"name": "Methi Malai", "aliases": ["Methi Malai Matar", "Fenugreek Cream",
                                                "Methi Matar", "Creamy Fenugreek"],
             "kcal": 190},
        ],
    },
}

REJECT = {
    "2024_05_04_chicken_soya_curry_jpg_2a1e39d3.jpg": (
        "OPENED, and REJECTED AS UNRESOLVABLE rather than as wrong: a hammered-metal plate "
        "holding a red-orange gravy with sesame seed, green chilli and coriander over "
        "yellow rice, with orange slices and cucumber. The pieces in the gravy are the "
        "entire question and I cannot resolve them from the frame. Soya chunks take the "
        "colour of the gravy completely and become uniformly red-orange, which is exactly "
        "what these are, and chicken does the same; their shape is irregular and rounded, "
        "consistent with either. COLOUR, which is what I would normally lean on, carries "
        "no information here. So the central truth label is unresolvable, and the file's "
        "own title - 'chicken soya curry' - is itself ambiguous, naming both. I will not "
        "label a photograph 'chicken' because the pieces look meaty, nor 'soya' because "
        "the query asked for it. A case whose one truth label cannot be established from "
        "the image is not a case: it is a photograph with a guess attached, and a wrong "
        "label in this corpus is the expensive kind of error - a wrong ANSWER rather than "
        "a missing one. Declared rather than filed, because 'I could not tell' is a fact "
        "about the photograph and it is worth more on the record than a coin-flip case"
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
        "BATCH 27 (2026-09-28): A BATCH SIZED BY THE MEASURED PRECISION - and the prediction",
        "fails for a reason that is NOT about precision.",
        "  7 queries (control first), 2 downloaded, accepted 1, rejected 1",
        "",
        "DECLARED BEFORE THE FETCH, from the 41% precision figure batch 26 published:",
        "  6 candidates x 0.41  ->  EXPECT 2 CASES",
        "",
        "AND FOUR OF THE SIX TARGET QUERIES RETURNED ZERO PAGES:",
        '  pages=1  uthappam breakfast     <- the control',
        '  pages=0  "gwar curry"           cluster bean',
        '  pages=3  "soya curry"           soy chunk',
        '  pages=0  "tinda curry"          round gourd',
        '  pages=0  "kacche kele curry"    raw banana',
        '  pages=3  "methi malai"          fenugreek and pea',
        '  pages=0  "amla murabba"         candied amla',
        "",
        "Only 2 candidates existed. PRECISION IS NOT THE BINDING CONSTRAINT - PAGES",
        "RETURNED IS. The precision figure was never applied to anything, because there was",
        "nothing to apply it to. That took a declared prediction to see, which is the",
        "argument for declaring them: the arithmetic can be right and the input can be",
        "wrong, and only writing the number down separates the two.",
        "",
        "AND THE PREDICTION WAS BARELY FALSIFIABLE, which I am not going to dress up. The",
        "ceiling was 2 - the batch could not return more than 2 cases - so I predicted 2 and",
        "got 1. A prediction is only informative when the ceiling sits above it, and I did",
        "not check the ceiling before writing the number. Same error as sizing a batch by a",
        "precision figure without checking how many candidates it would actually see.",
        "",
        "THE TARGET LIST IS ALSO THE FINDING. Four of six new dishes - cluster bean, round",
        "gourd, raw banana, candied amla - returned nothing against a control that returned",
        "hits in the same run, so these are real zeros of the archive. The yield table said",
        "the form that works is <legume or vegetable> + a preparation word, and three of",
        "these are exactly that form and found nothing. So the form is NECESSARY AND NOT",
        "SUFFICIENT - the third time this corpus has narrowed a rule written down one round",
        "earlier, after batch 23 narrowed batch 22 and batch 26 retracted batch 25.",
        "",
        "  accepted 1  METHI MALAI MATAR - a yellow leaf-shaped dish of pale cream gravy",
        "               with countable whole green peas, chopped fenugreek, a coriander",
        "               sprig and two cashews. The frame holds peas AND fenugreek, so a",
        "               DECLARED ADJACENT class rather than a second methi case - same call",
        "               as chana and to dal in batch 26 where one bowl held two pulses. It",
        "               does NOT become methi's second case.",
        "",
        "  rejected 1  'chicken soya curry' - REJECTED AS UNRESOLVABLE rather than as wrong.",
        "               Soya chunks take the colour of the gravy completely and become",
        "               uniformly red-orange, which is exactly what the pieces are, and",
        "               chicken does the same; their shape is consistent with either, and",
        "               COLOUR carries no information here. The title names both proteins.",
        "               I will not label a photograph 'chicken' because the pieces look",
        "               meaty, nor 'soya' because the query asked. A case whose one truth",
        "               label cannot be established from the image is not a case, and a wrong",
        "               label here is a wrong ANSWER rather than a missing one.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
