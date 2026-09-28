#!/usr/bin/env python3
"""Apply batch 26 - the batch that FALSIFIED the rule batch 25 wrote down, one hour after
batch 25 wrote it down in its own words.

9 queries (the control, then four PAIRS), 4 downloaded, accepted 1, rejected 3.

THE EXPERIMENT. Batch 25 measured, in one run with a positive control:

    "lauki sabzi" ..... 0        "bottle gourd curry" .. 8

and I concluded, in the batch 25 note and its commit message, that "Commons indexes the
ENGLISH name and not the transliterated one." That is a claim about a vocabulary, and one
dish is not a vocabulary - lauki could have been an exception the same way "gobi curry"
turned out to be a thali with no cauliflower in it. So this set ran four pairs in one
batch, on one day, against one instrument:

    "lauki sabzi"        0   vs  "bottle gourd curry"   8    English wins
    "makai curry"        0   vs  "corn curry"           1    English wins
    "capsicum curry"     7   vs  "bell pepper curry"    0    transliterated wins
    "beans curry"        8   vs  "green bean curry"     0    transliterated wins

TWO OF FOUR. The rule is FALSE as a general statement and lauki was a coincidence of that
dish. I am recording the retraction in the same commit that carries the cases, because the
batch 25 note currently states the false rule in its own words and a note that teaches a
false rule is worse than no note at all. The one number that carried the claim - lauki,
0 against 8 - was real; what was wrong was the generalisation from one dish to a
vocabulary, which is the same move as reading a green /health and calling the product
healthy.

WHAT SURVIVES IS SMALLER AND TRUE. The transliterated names are not dead, because both
losing English queries ALSO returned zero: "bell pepper curry" and "green bean curry" are
not in this archive either. And the queries that worked hardest all name a legume plus
"curry". So the working form is narrower than either rule I have now tested:

  * it is NOT English over transliterated (measured above, 2 of 4);
  * it is NOT simply two words (batch 24 measured "corn curry" at 1 hit in one run and
    "chicken biryani" at 8 in another);
  * it is two words where the SECOND IS A PREPARATION and the FIRST NAMES SOMETHING THE
    ARCHIVE HAS PHOTOGRAPHS OF.

And the other half of this batch, which is the more useful half: of four downloads,
THREE WERE NOT THE DISH THE QUERY NAMED. The bare-word rule from batch 22 - one word
finds the ingredient - is reappearing through a TWO-word query, so the rule was never
about word count. It is about whether the noun is a thing that gets photographed on its
own.

ACCEPTED 1.

  CHANA AUR TANDELA DAL - a dark steel bowl of pale yellow split pigeon peas (to dal) and
    whole chickpeas (chana) in a thick onion-and-tomato masala, over white rice, in dim
    warm light. Accepted MEDIUM and the medium is about a real ambiguity: the frame holds
    two pulses and the case names both, so the class is "chana and to dal" rather than
    either one alone. A photo claiming only chana would be describing half the bowl, and
    the calories of the two differ enough that folding them would be dishonest in the
    direction that matters.

    It is ALSO the honest answer to "beans curry" returning this file. There is no green
    bean in it, so the query found a dish by its TEXTURE and its yellow colour - the
    second time in two batches that a two-word query has reached a legume dish without
    naming the legume. The "beans" was a bridge, not a description.

REJECTED 3, and all three are refusals with the same shape: the query named a dish and
the frame is a different one.

  "rajbangshi thali with rice, taro leaf chhyaka, bottle gourd curry" - returned by
    "bottle gourd curry", the query that returned 8. The frame is a Bengali festival meal:
    a mound of white rice, a dark green leafy dish, a yellow dal, and a plate of small
    FRIED FISH on a skewer standing upright with a carved orange garnish. The filename says
    "bottle gourd curry" and there is no bottle gourd curry in the picture. Rejected on the
    frame, and the fish is the reason a reviewer would have been generous to call it a
    mixed meal: it is a different region, a different occasion and a different religion of
    dish from anything the query named. The 8 pages this query returned are not 8 chances
    at the dish - they are 8 chances at anything matching those three words.

  "mexican rice platter, homemade mumbai" - returned by "corn curry". White rice with
    sweetcorn kernels, diced carrot and green peas, a carved beetroot rose, papad, a glass
    of yellow dal and a scattering of roasted corn on the plate. Rejected: there is no
    curry in it, and the corn is one ingredient among five. This is vegetable pulao on a
    thali, and accepting it as a corn case would be the bare-word rule wearing a two-word
    query's clothes. Worth noting the filename says "mumbai", so even the record of it is
    about a place rather than the dish.

  "butter chicken beef vindaloo lunch thali, spice kitchen" - returned by "capsicum
    curry". A restaurant table: a steel thali with a mound of white rice, a pale orange
    butter chicken in one bowl and a dark red beef vindaloo in another, a fried bread, and
    shredded lettuce. No capsicum anywhere, and two curries where the query named a
    vegetable. Rejected. This is the same photograph the batch 23 capsicum query returned
    as an "all you can eat buffet" - a DIFFERENT file from the same uploader, which is
    itself the finding: the capsicum query keeps reaching one Melbourne restaurant's
    photographs, so its 7 pages are not 7 chances at capsicum.

THE YIELD IS 1 OF 4 AND THE ARITHMETIC IS THE POINT. Nine queries bought four downloads and
one case, and the round's real content is not the case: it is a rule I wrote down an hour
ago, tested properly, and had to withdraw. That is a cheaper outcome than finding out in
three more batches, and the withdrawal is recorded in the same file the claim was recorded
in, so the next person reading batch 25's note finds the correction next to it.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

ACCEPT = {
    "chana_to_dal_steel_bowl": {
        "photo": "khaja_1_jpg_e377dc49.jpg",
        "confidence": "medium",
        "note": "A dark steel bowl of pale yellow split pigeon peas (to dal) and whole "
                "chickpeas (chana) in a thick onion-and-tomato masala, served over white "
                "rice in dim warm light. Accepted MEDIUM, and the medium is about a real "
                "ambiguity rather than a hedge: the frame holds TWO pulses and the case "
                "names both, so the class is 'chana and to dal' rather than either alone. "
                "A photo claiming only chana would describe half the bowl, and the "
                "calories of the two differ enough that folding them would be dishonest "
                "in the direction that matters. It is also the honest answer to 'beans "
                "curry' returning this file: there is no green bean in it, so the query "
                "reached a legume dish by its TEXTURE and its yellow colour. The second "
                "time in two batches that a two-word query has reached a legume dish "
                "without naming the legume - the word 'beans' was a bridge, not a "
                "description.",
        "truth": [
            {"name": "Chana and To Dal", "aliases": ["Chana Dal", "To Dal", "Chana",
                                                      "Chole", "Chana Aur Tanda Dal"],
             "kcal": 220},
            {"name": "Rice", "aliases": ["Plain Rice", "Steamed Rice"], "kcal": 210},
        ],
    },
}

REJECT = {
    "rajbangshi_thali_with_rice_taro_leaf_chhyaka_bottle__0f192f0e.jpg": (
        "OPENED, and returned by the query that returned 8: a Bengali festival meal - a "
        "mound of white rice, a dark green leafy dish, a yellow dal, and a plate of small "
        "FRIED FISH on a skewer standing upright with a carved orange garnish. The "
        "filename says 'bottle gourd curry' and there is no bottle gourd curry in the "
        "picture. Rejected on the frame. The fish is why a generous reviewer would have "
        "been tempted to call it a mixed meal: a different region, a different occasion "
        "and a different kind of dish from anything the query named. THE POINT ABOUT THE "
        "8 PAGES: they are not 8 chances at bottle gourd curry, they are 8 chances at "
        "anything matching those three words, and this is what one of them looks like"
    ),
    "mexicanriceplatter_homemade_mumbai_jpg_d1e3afe7.jpg": (
        "OPENED, and returned by 'corn curry': white rice with sweetcorn kernels, diced "
        "carrot and green peas, a carved beetroot rose, papad, a glass of yellow dal and "
        "a scattering of roasted corn on the plate. Rejected: there is NO CURRY in it, and "
        "the corn is one ingredient among five. This is vegetable pulao on a thali, and "
        "accepting it as a corn case is the bare-word rule from batch 22 wearing a "
        "two-word query's clothes. The filename says 'mumbai', so even the record of it is "
        "about a place rather than the dish"
    ),
    "butter_chicken_beef_vindaloo_lunch_thali_spice_kitch_fd30935b.jpg": (
        "OPENED, and returned by 'capsicum curry': a restaurant table with a steel thali "
        "holding a mound of white rice, a pale orange butter chicken in one bowl and a "
        "dark red beef vindaloo in another, a fried bread and shredded lettuce. NO "
        "CAPSICUM ANYWHERE, and two curries where the query named a vegetable. Rejected. "
        "This is a DIFFERENT file from the same uploader as the 'all you can eat buffet' "
        "the batch 23 capsicum query returned, and that is itself the finding: the "
        "capsicum query keeps reaching one Melbourne restaurant's photographs, so its 7 "
        "pages are not 7 chances at capsicum either"
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
        print(f"  - {name[:56]}")

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
        "BATCH 26 (2026-09-28): THE BATCH THAT FALSIFIED THE RULE BATCH 25 WROTE DOWN, ONE",
        "HOUR AFTER BATCH 25 WROTE IT DOWN IN ITS OWN WORDS.",
        "  9 queries (the control, then four PAIRS), 4 downloaded, accepted 1, rejected 3",
        "",
        "Batch 25 measured \"lauki sabzi\" at 0 against \"bottle gourd curry\" at 8, with a",
        "positive control, and concluded that Commons indexes the ENGLISH name and not the",
        "transliterated one. One dish is not a vocabulary, so this batch ran four pairs in",
        "one run, on one day, against one instrument:",
        '  "lauki sabzi"       0  vs  "bottle gourd curry"  8   English wins',
        '  "makai curry"       0  vs  "corn curry"          1   English wins',
        '  "capsicum curry"    7  vs  "bell pepper curry"   0   transliterated wins',
        '  "beans curry"       8  vs  "green bean curry"    0   transliterated wins',
        "",
        "TWO OF FOUR. The rule is FALSE as a general statement and lauki was a coincidence",
        "of that dish. The retraction is recorded in this commit AND in query_sets.py next",
        "to the claim, because the batch 25 note states the false rule in its own words and",
        "a note that teaches a false rule is worse than no note. The one number carrying",
        "the claim was real; what was wrong was generalising from one dish to a vocabulary",
        "- the same move as reading a green /health and calling the product healthy.",
        "",
        "WHAT SURVIVES IS SMALLER AND TRUE. It is NOT English-over-transliterated (2 of 4).",
        "It is NOT simply two words (batch 24 measured \"corn curry\" at 1 hit and \"chicken",
        "biryani\" at 8). It is two words where the SECOND IS A PREPARATION and the FIRST",
        "NAMES SOMETHING THE ARCHIVE HAS PHOTOGRAPHS OF. The transliterated names are not",
        "dead either, because both losing English queries ALSO returned zero.",
        "",
        "AND THE MORE USEFUL HALF: of four downloads, THREE WERE NOT THE DISH THE QUERY",
        "NAMED. The bare-word rule from batch 22 is reappearing through a TWO-word query, so",
        "it was never about word count - it is about whether the noun is something that gets",
        "photographed on its own.",
        "",
        "  accepted 1  CHANA AND TO DAL - a dark steel bowl of pale yellow split pigeon peas",
        "               and whole chickpeas in a thick onion-and-tomato masala over white",
        "               rice, dim warm light. MEDIUM, and the medium is a real ambiguity:",
        "               the frame holds TWO pulses and the case names both, because a photo",
        "               claiming only chana would describe half the bowl. Also the honest",
        "               answer to 'beans curry' returning it - there is no green bean in",
        "               the frame, so the query reached a legume dish by its TEXTURE and its",
        "               yellow colour. Second time in two batches. The word was a bridge,",
        "               not a description.",
        "",
        "  rejected 3  a Bengali festival thali with FRIED FISH on a skewer, returned by",
        "               'bottle gourd curry' - no gourd curry in the frame. Its 8 pages are",
        "               not 8 chances at the dish, they are 8 chances at three words.",
        "             a vegetable pulao thali with a carved beetrose, returned by 'corn",
        "               curry' - no curry in it and the corn is one of five ingredients.",
        "             a restaurant thali with butter chicken AND beef vindaloo, returned by",
        "               'capsicum curry' - no capsicum, and a DIFFERENT file from the same",
        "               uploader as the batch 23 buffet, so the capsicum query keeps",
        "               reaching one Melbourne restaurant and its 7 pages are not 7 chances",
        "               at capsicum either.",
        "",
        "The yield is 1 of 4 and the arithmetic is the point: the round's real content is a",
        "rule written down an hour ago, tested properly, and withdrawn. Cheaper than",
        "finding out in three more batches.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted {added}, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
