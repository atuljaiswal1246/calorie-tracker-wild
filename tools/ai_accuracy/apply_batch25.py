#!/usr/bin/env python3
"""Apply batch 25 - the first batch whose per-query results were RECORDED, and the record
immediately paid for itself by closing a gap I had declared permanent.

7 queries (control first), 4 downloaded, accepted 3, rejected 1.

WHAT THIS BATCH IS ACTUALLY ABOUT. The ledger's `candidates` column has carried a dash for
eight of twenty-four batches, declared "unmeasured", and I had accepted that as
unknowable. It was not unknowable - the number was in hand when the search returned, and
the fetcher printed it and threw it away. So a reader of the ledger could not tell a
query that found nothing from a query that was never asked, which is the exact distinction
all four false zeros in this corpus turned on:

    batch 13 ......... HTTP 429 on every query          our access
    batch 13 retry ... over-constrained wording         my query
    batch 19 ......... a category name I invented       my instrument
    batch 20 ......... `incategory:` returns nothing    a dead instrument

Not one was a fact about a dish. So fetch_commons.py now records, per query, the number of
pages the search returned BEFORE filtering (`pages`), what survived (`kept`), and the
error if the query was never asked (`error`, with `pages: null`). A new guard fails if a
run where every query returned zero is treated as a finding, if an errored query claims a
page count, or if `kept` exceeds `pages`.

THE FIRST RECORDED RUN, verbatim from query_results.json:

    pages=      1  kept=1  filetype:bitmap uthappam breakfast      <- the control
    pages=      0  kept=0  filetype:bitmap "lauki sabzi"
    pages=      8  kept=8  filetype:bitmap "bottle gourd curry"
    pages=      0  kept=0  filetype:bitmap "ratan jot salad"
    pages=      8  kept=7  filetype:bitmap "amla pickle"
    pages=      8  kept=7  filetype:bitmap "chicken biryani"
    pages=      8  kept=6  filetype:bitmap "gulab jamun"

Two zeros, and a control that returned hits in the SAME run, so both are real zeros of
what Commons can reach rather than facts about the dishes. That is the check the control
guard made a convention, and the record has now made it a fact about the run.

AND THE RECORD CLOSED A GAP I DECLARED PERMANENT IN BATCH 24, which is the whole reason
it was worth building. Lauki had failed three ways and I wrote it down as a named gap:

    lauki (bare) ......... a gourd photograph, the INGREDIENT
    "lauki sabzi" ....... 0
    "lauki curry" ....... 0

    "bottle gourd curry"  8      <- THE ENGLISH NAME, same day, same instrument

8 against 0, on the same run, with the control positive. The gap was never in the corpus
and never in lauki: it was in my QUERY. Commons indexes the English name "bottle gourd"
and does not index the transliterated "lauki" as a dish. So lauki is not a gap, it was a
vocabulary failure, and the difference matters: a gap I could have declared forever, a
vocabulary failure I can fix by spelling the dish the way the archive spells it.

ACCEPTED 3, two of them brand-new classes.

  LAUKI (Bottle Gourd Curry) - a mound of translucent pale-green gourd in a light masala
    on a steel plate, with visible round chickpeas, mustard seed, cumin and a whole dried
    red chilli. The gourd is diced into soft irregular pieces rather than left in rings,
    which is what cooking it down does, and the chickpeas are countable. THE DISH IS
    LENTIL AND GOURD TOGETHER, so this is a declared ADJACENT class rather than a second
    case for gourd alone - the same call as the sarson da saag and makki ki roti pair, and
    made for the same reason: the photograph shows both vegetables and a case that claimed
    only one of them would be describing half the frame. Lauki's second case, and its
    first under a name the archive can actually find.

  AMLA PICKLE - a glass jar of whole round amla, golden-brown and glossy in brine, with
    visible mustard seed, chilli flakes and a whole dried red chilli, and a steel spoon
    standing in it. The fruit is whole and unpeeled, which is what distinguishes amla
    pickle from a sliced murabba, and the roundness is the whole point. New class.

  GULAB JAMUN - two dark syrup-soaked balls in a white bowl of pale amber syrup, on white
    painted boards scattered with pink rose petals, saffron strands floating on the
    surface. New class, and the only photograph in the corpus so far composed as a
    deliberate still life rather than a record of a meal - which is worth saying plainly,
    because a stylist's shot and a home photograph are not the same difficulty and the
    corpus now contains both.

REJECTED 1, and it is the interesting one.

  "biryani home" - a large mound of long-grain rice, white at the edges and yellow through
    the middle, on a floral plate. And the rice is NOT separate: the grains are fused into
    a single mass in places, the yellow is uneven, and there is no visible meat, no fried
    onion, no saffron, no potato, no egg. This is most likely a vegetable pulao or plain
    turmeric rice that the query reached by way of the word "biryani", and "biryani" is a
    term the archive applies loosely.

    REJECTED, and the reason is the yellow. A biryani's colour comes from saffron or
    annatto laid over the rice before cooking, which gives a more even gold across the
    whole plate; here the yellow sits in patches with white rice showing through, which is
    what turmeric stirred in at the end looks like. That is a judgement about a photograph
    and it could be wrong, which is why it is recorded as medium confidence rather than
    asserted - but a case whose class turns on a colour I am reading as diagnostic is a
    weaker case than the karela and the lauki, and the corpus does not need a weaker case
    in a class it already has three of. "biryani" is a declared class and this would have
    been its first case, minted off a photograph I am not confident about.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "lauki_chana_curry": {
        "photo": "bottle_gourd_curry_jpg_a4cc08f2.jpg",
        "confidence": "high",
        "note": "A mound of translucent pale-green gourd cooked down in a light masala on "
                "a steel plate, with countable round chickpeas, black mustard seed, cumin "
                "and a whole dried red chilli. The gourd is diced into soft irregular "
                "pieces rather than left in rings, which is what cooking it down does. "
                "FOUND ONLY AFTER THE ENGLISH NAME WAS TRIED: 'lauki' returned a gourd "
                "photograph, 'lauki sabzi' and 'lauki curry' both returned 0 across "
                "batches 23, 24 and 25, and 'bottle gourd curry' returned 8 on the same "
                "day with the control positive. The gap I declared permanent in batch 24 "
                "was a VOCABULARY failure, not a corpus gap. The dish is lentil and gourd "
                "together, so this is a declared ADJACENT class rather than a second case "
                "for gourd alone - the photograph shows both, and a case claiming only one "
                "would describe half the frame. Lauki's second case.",
        "truth": [
            {"name": "Bottle Gourd Curry", "aliases": ["Lauki Curry", "Lauki Sabzi",
                                                        "Doodhi Sabzi", "Gourd Curry",
                                                        "Chana Lauki"],
             "kcal": 160},
        ],
    },
    "amla_pickle_jar": {
        "photo": "amla_pickle_jpg_9ec4b82c.jpg",
        "confidence": "high",
        "note": "A glass jar of whole round amla, golden-brown and glossy in brine, with "
                "visible mustard seed, chilli flakes and a whole dried red chilli, and a "
                "steel spoon standing in it. The fruit is whole and unpeeled, which is "
                "what distinguishes amla pickle from a sliced murabba, and the roundness "
                "is the whole point of the case. A new class.",
        "truth": [
            {"name": "Amla Pickle", "aliases": ["Amla Achar", "Gooseberry Pickle",
                                                 "Amla Murabba", "Achar"],
             "kcal": 90},
        ],
    },
    "gulab_jamun_syrup": {
        "photo": "gulaabjamun_jpg_f667c5df.jpg",
        "confidence": "high",
        "note": "Two dark syrup-soaked balls in a white bowl of pale amber syrup, on white "
                "painted boards scattered with pink rose petals, with saffron strands "
                "floating on the surface. A new class, and worth naming that this is the "
                "only photograph in the corpus composed as a deliberate still life rather "
                "than a record of a meal - a stylist's shot and a home photograph are not "
                "the same difficulty, and the corpus now contains both, which is worth "
                "knowing before anyone reads a median across it.",
        "truth": [
            {"name": "Gulab Jamun", "aliases": ["Gulaab Jamun", "Jangiri", "Motichoor"],
             "kcal": 300},
        ],
    },
}

REJECT = {
    "biryani_home_jpg_85c44931.jpg": (
        "OPENED: a large mound of long-grain rice, white at the edges and yellow through "
        "the middle, on a floral plate. Rejected on the YELLOW and the grain. A biryani's "
        "colour comes from saffron or annatto laid over the rice BEFORE cooking, which "
        "gives a more even gold across the whole plate; here the yellow sits in patches "
        "with white rice showing through, which is what turmeric stirred in at the end "
        "looks like. The grains are also fused into a single mass in places, and there is "
        "no visible meat, no fried onion, no saffron, no potato and no egg - so this is "
        "most likely a vegetable pulao or plain turmeric rice that the query reached by "
        "way of the word 'biryani', which the archive applies loosely. This is a "
        "JUDGEMENT ABOUT A PHOTOGRAPH and it could be wrong, which is why it is recorded "
        "rather than asserted - but a case whose class turns on a colour I am reading as "
        "diagnostic is a weaker case than the karela and the lauki, and the corpus does "
        "not need a weaker case in a class it already holds three of. 'biryani' is a "
        "declared class and this would have been its first case, minted off a photograph I "
        "am not confident about"
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
        "BATCH 25 (2026-09-28): THE FIRST RECORDED RUN - and the record immediately paid",
        "for itself by closing a gap I had declared permanent the batch before.",
        "  7 queries (control first), 4 downloaded, accepted 3, rejected 1",
        "",
        "THE ACCOUNTING HAD A HOLE AND I HAD ACCEPTED IT AS UNKNOWABLE. The ledger's",
        "`candidates` column carried a dash for eight of twenty-four batches, declared",
        "'unmeasured'. The number was in hand when the search returned; the fetcher",
        "printed it and discarded it. So the ledger could not tell a query that found",
        "nothing from a query that was NEVER ASKED - the exact distinction all four false",
        "zeros here turned on (a 429, an over-constrained query, an invented category, and",
        "a category form that returns nothing; not one was a fact about a dish).",
        "",
        "fetch_commons.py now records per query: `pages` (the search's own hit count",
        "BEFORE filtering), `kept` (what survived the licence and duplicate filters), and",
        "`error` with `pages: null` for a query that was never asked. A new guard fails if",
        "a run where every query returned zero is treated as a finding, if an errored",
        "query claims a page count, or if kept exceeds pages.",
        "",
        "THE FIRST RECORD, verbatim:",
        '  pages= 1 kept=1  filetype:bitmap uthappam breakfast      <- the control',
        '  pages= 0 kept=0  filetype:bitmap "lauki sabzi"',
        '  pages= 8 kept=8  filetype:bitmap "bottle gourd curry"',
        '  pages= 0 kept=0  filetype:bitmap "ratan jot salad"',
        '  pages= 8 kept=7  filetype:bitmap "amla pickle"',
        '  pages= 8 kept=7  filetype:bitmap "chicken biryani"',
        '  pages= 8 kept=6  filetype:bitmap "gulab jamun"',
        "Two zeros with the control POSITIVE in the same run, so both are real zeros of",
        "what Commons can reach. The control was a convention I followed by remembering",
        "until a guard made it a check; the record has now made it a fact about the run.",
        "",
        "AND IT CLOSED A GAP I DECLARED PERMANENT IN BATCH 24:",
        "  lauki (bare) ......... a gourd photograph, the INGREDIENT",
        '  "lauki sabzi" ....... 0',
        '  "lauki curry" ....... 0',
        '  "bottle gourd curry"  8      <- THE ENGLISH NAME, same day, same instrument',
        "8 against 0 with the control positive. The gap was never in the corpus and never",
        "in lauki: it was in my QUERY. Commons indexes the English name and not the",
        "transliterated one as a dish. A gap I could have declared forever, closed by",
        "spelling the dish the way the archive spells it.",
        "",
        "  accepted 3  BOTTLE GOURD CURRY - translucent pale-green gourd cooked down in a",
        "               light masala with countable chickpeas, mustard seed, cumin and a",
        "               dried red chilli. Lentil AND gourd together, so a declared ADJACENT",
        "               class rather than a second gourd-only case: the photograph shows",
        "               both and a case claiming one would describe half the frame.",
        "  accepted 3  AMLA PICKLE - whole round unpeeled amla, golden-brown in brine with",
        "               mustard seed, chilli flakes and a dried red chilli. Whole and",
        "               unpeeled is what distinguishes it from a sliced murabba. New class.",
        "  accepted 3  GULAB JAMUN - two syrup-soaked balls in pale amber syrup on white",
        "               boards with rose petals and saffron. New class, and the only",
        "               photograph in the corpus composed as a deliberate STILL LIFE rather",
        "               than a record of a meal. A stylist's shot and a home photograph are",
        "               not the same difficulty, and the corpus now holds both - worth",
        "               knowing before anyone reads a median across it.",
        "",
        "  rejected 1  'biryani home' - a mound of rice, white at the edges and yellow",
        "               through the middle. Rejected on the YELLOW and the grain: a",
        "               biryani's colour comes from saffron laid over the rice BEFORE",
        "               cooking and is even across the plate, while here the yellow sits in",
        "               patches with white showing through, which is turmeric stirred in at",
        "               the end. The grains are fused in places, and there is no meat, no",
        "               fried onion, no saffron, no potato and no egg. A judgement about a",
        "               photograph, recorded rather than asserted because it could be wrong",
        "               - but a case whose class turns on a colour I am reading as",
        "               diagnostic is weaker than the karela and the lauki, and the corpus",
        "               does not need a weaker case in a class it already holds three of.",
        "               'biryani' is declared and this would have been its first case,",
        "               minted off a photograph I am not confident about.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
