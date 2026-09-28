#!/usr/bin/env python3
"""27 is a count of KEYS. Nothing has ever checked the keys are not synonyms.

WHY THIS EXISTS. Every corpus guard so far has been about the photographs or the
arithmetic around them, and the one number this card leads with — the dish CLASS count
— is produced by a mapping: `DISH_CLASS` in tools/ai_accuracy.py, and `class_of()`
returns whichever key a case's truth names. The count is therefore the number of
distinct KEYS the corpus happens to hit, and a mapping can inflate that count without
anybody noticing, because a synonym pair is two keys for one dish:

    a photograph of kadhi lands in `kadhi`, a photograph of dal lands in `dal`,
    and the class count says 2 where a person would say "those are both dals".

That is the same defect as the duplicate photograph, one level up: there, two cases
wearing two names for one picture; here, two keys wearing two names for one dish. Both
inflate the exact number this card reports, and both are invisible to a count.

MEASURED, not asserted. The 27 keys the corpus actually uses are:

    dal 5, chole 4, aloo gobi 2, baingan 2, bhindi 2, biryani 2, dosa 2, kofta 2,
    paneer 2, sambar 2, and 17 singletons: chicken curry, egg, halwa, idli, jalebi,
    kadhi, keema, kheer, khichdi, lauki, legume salad, pulao, rajma, samosa,
    sarson da saag, sweet corn, vada

Five of those are pairs a reasonable reviewer could call one dish, and they are
declared below with the reason each is counted separately. The pairs are DISJOINT on
purpose, so the fold arithmetic is exact rather than approximate: folding all five
gives **22**, which is still inside the card's own 18-22 band. So the bar holds under
either reading, and the honest sentence is "27 keys, 22 if you fold every adjacent
pair" rather than a single number pretending the question does not exist.

WHAT IS AND IS NOT DECIDED HERE, because a guard that implies more than it does is
worse than no guard:
  * it does NOT decide that the five pairs are correctly separate. It records that the
    decision was made, with a reason, instead of being made by whichever alias a truth
    happened to use. That is the whole fix: the distinction is now stated where a
    reader meets it, and the alternative number is stated beside it.
  * it does NOT check that the LABELS are the right dish for the photograph. No machine
    here can. That is a judgement a person made batch by batch.

Run with: python3 tools/ai_accuracy/test_the_dish_classes_are_distinct.py
Bite proof: tools/ai_accuracy/prove_the_dish_class_guard_bites.py
"""
from __future__ import annotations

import json
import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools"))
from ai_accuracy import DISH_CLASS, class_of  # noqa: E402

CASES = REPO / "tools" / "ai_accuracy" / "cases.json"
NOTE = REPO / "notes" / "M1_BAR_STATUS.md"

# The bar this card is measured against, and the figure the note must carry.
CLASS_BAR = 20

# Five pairs that are adjacent enough to be counted as one dish by a reasonable
# reviewer, each kept separate on purpose. Disjoint, so folding all five is exact.
# `would_fold_to` is what the class count becomes if a reviewer merged that pair.
ADJACENT_CLASSES: dict[tuple[str, str], dict] = {
    ("dal", "kadhi"): {
        "why": "Kadhi is a yoghurt-and-besgram gram curry, dal is a plain lentil "
               "curry. They are different preparations with different ingredients, and "
               "a photo of one is not evidence about the other's calories.",
        "would_fold_to": "dal",
    },
    ("kofta", "keema"): {
        "why": "Both are minced meat, but kofta is formed and fried or simmered in "
               "whole pieces while keema is loose minced meat in a masala. Same base "
               "ingredient, different dish, and the forms are visible in the photo.",
        "would_fold_to": "keema",
    },
    ("chole", "rajma"): {
        "why": "Different legumes: chickpea against kidney bean. Calling them one "
               "class would make a legume class, and the corpus is not built to "
               "measure legumes in general.",
        "would_fold_to": "chole",
    },
    ("biryani", "pulao"): {
        "why": "A biryani is a pulao method with meat and fried onion; a plain pulao "
               "has neither. The class boundary is the meat, and it is visible.",
        "would_fold_to": "biryani",
    },
    ("bhindi", "lauki"): {
        "why": "Both are gourd-family curries but the vegetables are different and "
               "named differently on the plate: okra (bhindi) against bottle gourd "
               "(lauki). Their calories differ.",
        "would_fold_to": "bhindi",
    },
}


# Cases whose DISH NAME alone does not establish that the meal is Indian. The corpus's
# bar is 20 measured real Indian meals, so this is a caveat on a headline claim rather
# than a defect - and it is a DECLARED list so it cannot grow or rot unnoticed.
#
# Each entry says what the case rests on instead, because "not Indian" is almost never
# the finding; the honest finding is "we know this from the photograph or the caption,
# not from the name".
#
# MEASURED 2026-09-28 over all 53 cases. I began by suspecting five names; three of them
# - Legume Salad, Halwa and Egg - are in DISH_CLASS and appear in NO case at all, so the
# real figure is three. The suspicion list was longer than the finding, which is the usual
# direction of that error.
# The two structures are separate on purpose, and keeping them in one was the bug this
# check caught in me: a dict keyed by CASE ID cannot be matched against truth NAMES.
#   NAMES_WITHOUT_AN_INDIAN_MARKER - the truth strings that do not establish a cuisine
#   NOT_INDIAN_BY_NAME             - the cases those strings appear in, with the reason
NAMES_WITHOUT_AN_INDIAN_MARKER: set[str] = {"Mushroom", "Chicken Curry"}

NOT_INDIAN_BY_NAME: dict[str, str] = {
    "button_mushroom_fry_plate":
        "a dry fry with no masala, onion, rice or roti in frame. Indian-ness rests on "
        "'mushroom fry' being a standard Indian home dish - a claim about the CAPTION, "
        "recorded as medium confidence when the case was accepted in batch 16.",
    "chicken_curry_white_dish":
        "'Chicken Curry' exists across Thai, Indonesian, British and Indian cuisines, so "
        "the name does not establish the cuisine. The photograph may well show an Indian "
        "one; the truth string does not say so.",
    "non_veg_thali":
        "a thali of nine labelled items, one of which is 'Chicken Curry' with the same "
        "four-cuisine problem. The thali as a whole is plainly an Indian meal - dal, "
        "rajma, kheer, papad, pickle - so this is the weakest of the three and is listed "
        "because a truth string inside a case is part of the case.",
    "chicken_curry_kadai":
        "the same four-cuisine problem, listed in batch 24 rather than argued away. The "
        "FRAME is stronger evidence than the two cases above - a steel kadai, and a "
        "visible tadka of black mustard seed, curry leaves and a bay leaf in a "
        "red-orange gravy, which is a recognisably Indian home preparation. That is "
        "exactly why this is declared rather than waved through: the caveat is about what "
        "the TRUTH STRING establishes, and 'Chicken Curry' still does not, however Indian "
        "the photograph looks. A caveat that quietly widened to 'Indian if the photo looks "
        "right' would stop being a caveat.",
}


def _cases() -> list[dict]:
    return json.loads(CASES.read_text(encoding="utf-8"))["cases"]


def _classes_in_use() -> dict[str, int]:
    out: dict[str, int] = {}
    for c in _cases():
        k = class_of(c)
        if k is not None:
            out[k] = out.get(k, 0) + 1
    return out


class DishClassesAreDistinctTests(unittest.TestCase):
    def test_every_class_the_corpus_uses_is_a_declared_dish_class_key(self):
        """A class the corpus reaches that is not in DISH_CLASS could only happen via
        a fallback, and a fallback class is a class nobody chose. Measured: none."""
        keys = set(DISH_CLASS)
        undeclared = sorted(k for k in _classes_in_use() if k not in keys)
        self.assertEqual(
            undeclared, [],
            f"the corpus reaches class keys that DISH_CLASS does not declare: "
            f"{undeclared}. Those came from a fallback rather than a decision.")

    def test_both_halves_of_every_declared_adjacent_pair_are_actually_in_use(self):
        """A declaration that names classes the corpus no longer has is worse than no
        declaration: it reads as a live decision and is not one. So the adjacency list
        has to be checked against the corpus, not trusted."""
        in_use = set(_classes_in_use())
        for a, b in ADJACENT_CLASSES:
            for k in (a, b):
                with self.subTest(pair=f"{a}/{b}", cls=k):
                    self.assertIn(
                        k, in_use,
                        f"the adjacency declaration names `{k}`, but no case in the "
                        f"corpus lands in that class any more. Delete the pair or fix "
                        f"the mapping - a decision about dishes that are not in the "
                        f"sample is a decision nobody is reading.")

    def test_the_adjacency_declaration_is_not_empty(self):
        """A check that cannot fail is a comment. If every pair were folded and no
        adjacency remained, this list should be empty ON PURPOSE and this test should
        be deleted with it - not left behind passing on nothing."""
        self.assertGreaterEqual(
            len(ADJACENT_CLASSES), 5,
            f"only {len(ADJACENT_CLASSES)} adjacent pairs are declared. Either pairs "
            f"were folded into single classes on purpose - in which case this "
            f"declaration and this test should both go - or the declaration has been "
            f"trimmed and the number beside the class count is now wrong.")

    def test_the_folded_count_still_clears_the_bar_and_the_note_says_so(self):
        """The number this whole guard exists to keep honest, computed rather than
        quoted: 27 keys, and 22 if a reviewer folds every declared adjacent pair.

        Both are above the bar, which is the point worth recording: the class bar is
        not resting on how the reviewer treats kadhi versus dal. And the note has to
        carry both figures, so 27 is never read on its own.
        """
        keys = _classes_in_use()
        total = len(keys)
        folded = {ADJACENT_CLASSES[p]["would_fold_to"] for p in ADJACENT_CLASSES}
        after_fold = total - len(folded)
        print(f"\n  dish classes in use: {total} | folding all "
              f"{len(ADJACENT_CLASSES)} adjacent pairs: {after_fold} | bar: {CLASS_BAR}")
        self.assertGreaterEqual(
            after_fold, CLASS_BAR,
            f"folding every declared adjacent pair leaves {after_fold} classes, under "
            f"the bar of {CLASS_BAR}. The bar is resting on a distinction the "
            f"adjacency list makes, and that has to be said out loud.")
        self.assertGreaterEqual(total, CLASS_BAR)

        flat = " ".join(NOTE.read_text(encoding="utf-8").split())
        for figure in (str(total), str(after_fold)):
            self.assertIn(
                figure, flat,
                f"{NOTE.name} does not carry the figure {figure}. The class count is "
                f"read by the owner, and a count that arrives without its "
                f"fold-the-adjacent-pairs alternative is the claim this guard exists "
                f"to stop.")
        self.assertIn(
            "adjacent", flat.lower(),
            f"{NOTE.name} must name the adjacency question in words, not only in "
            f"digits - otherwise both figures are on the page and neither is explained")
        # Added because breach D proved the digit check alone is blind: replacing
        # "folds all five" with "if you squint" leaves the figure 22 sitting on the
        # page and every assertIn above still passes. A number nobody can tell what it
        # counts is not a reportable number, so the OPERATION has to be named too -
        # "folds" is what tells a reader that 22 is the fold-the-pairs count and not a
        # second measurement.
        self.assertIn(
            "folds", flat.lower(),
            f"{NOTE.name} carries the figure {after_fold} without saying what it counts. "
            f"Name the operation - that {after_fold} is the count once every adjacent "
            f"pair is folded - or a reader cannot tell it from a second measurement.")


    def test_the_note_never_carries_a_class_count_other_than_the_two_published_ones(self):
        """Found while building this module, and it is the reason a count needs a guard
        at all: the note said 27 classes in its summary and 25 in its analysis section
        three paragraphs apart, and `corpus_independence_test.dart` passed 12 of 12 the
        whole time — it re-derives the counts from cases.json, so it cannot notice that
        the prose disagrees with the data it is describing.

        So the note's own prose is checked here, against the two figures this module
        publishes. Any class count in the file that is neither the measured number nor
        the fold-the-adjacent-pairs number fails BY NAME. A stale figure in prose is
        the exact shape of a number nobody can check, and it is the one the owner reads.
        """
        allowed = {str(len(_classes_in_use())),
                   str(len(_classes_in_use()) - len(
                       {ADJACENT_CLASSES[p]["would_fold_to"] for p in ADJACENT_CLASSES}))}
        text = NOTE.read_text(encoding="utf-8")
        found = {(m.group(0).strip(), m.group(1))
                 for m in re.finditer(r"(\d+)\s+(?:distinct dish\s+)?classes?\b", text)}
        stale = sorted(f"{n} in {ctx!r}" for ctx, n in found if n not in allowed)
        self.assertEqual(
            stale, [],
            f"{NOTE.name} carries a class count that is neither of the two published "
            f"figures {sorted(allowed)}: {stale}. Every count in the prose has to be "
            f"one this module measured, or the note is quoting a number nobody can "
            f"reproduce.")


    def test_every_declared_pair_says_why_it_is_kept_separate(self):
        """A pair in the list with no reason is a decision nobody made, and it reads
        exactly like one that was.

        This check exists because the first attempt to prove it bit tried to blank a
        reason and instead corrupted the file's syntax — the guard went red with a
        traceback rather than with a named failure. That was my breach being wrong, not
        the guard, but it exposed the real gap: nothing required a reason to be there.
        So the requirement is now explicit, and the same placeholder bar the `meanwhile`
        field uses applies here for the same reason: 'n/a' passes a presence check while
        saying nothing.
        """
        for (a, b), spec in ADJACENT_CLASSES.items():
            with self.subTest(pair=f"{a}/{b}"):
                why = (spec.get("why") or "").strip()
                self.assertTrue(
                    why, f"the {a}/{b} pair is declared with no reason. A pair in this "
                         f"list with no stated reason is a distinction nobody decided, "
                         f"and it is indistinguishable from one that was.")
                self.assertGreater(
                    len(why), 40,
                    f"the {a}/{b} reason is {len(why)} chars: {why!r} — too short to be a "
                    f"reason. State what makes the two dishes different in a way a "
                    f"photograph could show.")
                # "same" was on this list and had to come off: the kofta/keema reason
                # legitimately reads "Same base ingredient, different dish", so a
                # substring bar refused a real sentence. That is the second time a
                # crude placeholder list has bitten honest prose (the first was the
                # `meanwhile` bar), so the list is now only words that cannot appear
                # in a real explanation. A guard that fails on true statements trains
                # the next reader to edit the guard.
                for empty in ("n/a", "tbd", "todo"):
                    self.assertNotIn(
                        empty, why.lower(),
                        f"the {a}/{b} reason is the placeholder {empty!r}.")
                self.assertIn(
                    "would_fold_to", spec,
                    f"the {a}/{b} pair does not say which class it would fold into, so "
                    f"the alternative count cannot be computed from the declaration.")


    def test_the_cases_whose_NAME_does_not_establish_an_Indian_meal_are_declared(self):
        """The corpus's bar is 20 measured REAL INDIAN MEALS, and that has never been
        examined. Every other check here asks whether a class is distinct; none asks
        whether the meal is Indian at all.

        MEASURED 2026-09-28 across all 53 cases: three truth names carry no Indian
        marker on their own - `Mushroom` (1 case, the batch 16 dry fry whose Indian-ness
        rests on the caption) and `Chicken Curry` (2 cases, a dish that exists across
        Thai, Indonesian, British and Indian cuisines). Three of 53, so the bar is not
        threatened - fifty remain Indian by name - but a headline claim of "real Indian
        meals" should say which cases rest on something weaker than the dish name.

        I listed FIVE names when I started measuring, and three of them - `Legume Salad`,
        `Halwa` and `Egg` - are in DISH_CLASS but appear in NO case at all. That is the
        check doing its job on me: a plausible-sounding list of doubts is worth less than
        the count, and the count is three.

        Checked in both directions, like the declared gaps in the ledger: a new
        non-Indian-by-name case must be declared, and a declaration that is no longer
        needed must go - otherwise the caveat is either silently widened or silently
        forgotten.
        """
        cases = _cases()
        found = {c["id"] for c in cases
                 for t in c["truth"] if t.get("name") in NAMES_WITHOUT_AN_INDIAN_MARKER}
        self.assertTrue(
            NOT_INDIAN_BY_NAME,
            "the NOT_INDIAN_BY_NAME list is empty, so this check is passing on nothing. "
            "If every case's name now establishes an Indian meal, delete this test WITH "
            "the list rather than leave it green on an empty declaration.")
        # SET EQUALITY, and it took a blind breach to learn why. The first version of
        # this check walked the DECLARATION and asked whether each declared id was still
        # found - one direction only - so adding a new Chicken Curry case, which is
        # exactly the case this check exists to catch, left it green. A guard that only
        # catches one direction is half a guard, and I had written that sentence into the
        # ledger's declared-dash check an hour earlier and then repeated the mistake here.
        self.assertEqual(
            found, set(NOT_INDIAN_BY_NAME),
            f"the cases whose truth names do not establish an Indian meal are "
            f"{sorted(found)}, but the declaration names {sorted(NOT_INDIAN_BY_NAME)}. "
            f"Both directions are required: a new such case must be declared, and a "
            f"declaration that is no longer needed must go. Either one alone lets the "
            f"caveat be silently widened or silently forgotten.")
        self.assertLessEqual(
            len(found), 10,
            f"{len(found)} of {len(cases)} cases now rest on something weaker than the "
            f"dish name ({sorted(found)}). The bar is 20 Indian meals; at this rate the "
            f"caveat is doing more work than the claim.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
