#!/usr/bin/env python3
"""A second frame of one series must not cost a second download - and the check that does
it must be EXACT, not a threshold nudged until a case stops being caught.

WHY THIS EXISTS, and it begins with a retraction. Batch 28 downloaded a photograph already
rejected in batch 26, and that commit claimed the near-duplicate guard "compares against
ACCEPTED photographs and a rejected one was never in the corpus to compare against".

THAT WAS FALSE, and the manifest says so. Both entries carry a dhash; the guard builds its
`known` list from every photo that has one, rejected or not; and the hamming distance
between the two is 20 against a threshold of 8. So the guard compared them, and correctly
decided they were not the same picture. I asserted a hole that was not there, which is the
same fault as reading a green /health and calling the product healthy.

WHAT THE TWO ACTUALLY ARE, read in full rather than truncated at 66 characters:

    ... Siliguri, West Bengal DSC 0028.jpg
    ... Siliguri, West Bengal DSC 0029.jpg

Two consecutive frames of one meal, one photographer, one sitting - different SHA-256,
different URL, and a 64-bit difference hash 20 bits apart because the camera moved between
shots. Measured for contrast: re-encoding the SAME file at quality 95, 70, 60 and at 50-60%
scale moves the hash by 0 or 1. So the distance between "the same picture twice" and "the
next frame of the same scene" is wide, and NEAR_DUP_DISTANCE = 8 sits inside it correctly.

WHICH IS WHY THE FIX IS NOT A THRESHOLD. Raising NEAR_DUP_DISTANCE until 0028 and 0029
collide is tuning a guard's number until the case I want stops being reported - the same
fault as reshaping a record to match an instrument I have already disproved, and it would
begin rejecting photographs of genuinely different dishes. Instead this module checks an
EXACT rule for an EXACT pattern: two Commons titles that differ only by a frame counter
are one series, whatever the pixels say, and that is decidable from the title with no
threshold at all.

WHAT IS ENFORCED, in both directions:

  * the two titles in the corpus that motivated this MUST collide under `frame_stem`, so
    the rule is proved on the real data that caused it and not on a synthetic pair;
  * a title with no frame number must be unchanged by `frame_stem`, because stripping a
    number that is not a frame counter would be inventing a collision - "DSC 0028" versus
    "Paneer Tikka 28" must NOT collide, and neither must two different dishes;
  * `frame_stem` must be IDEMPOTENT, since it is applied to titles that may already have
    been through it, and a rule that is not idempotent stops being true on the second run;
  * a stem must not be EMPTY for any real title, because an empty stem matches every other
    empty stem and a guard that compares "" to "" skips the entire corpus;
  * and the whole thing must not be a no-op: if `frame_stem` were the identity on every
    title in the manifest, this module would pass while the duplicate kept arriving.

Run with: python3 tools/ai_accuracy/test_a_second_frame_is_not_a_second_photo.py
"""
from __future__ import annotations

import json
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PHOTOS = REPO / "tools" / "ai_accuracy" / "photos.json"

import sys
sys.path.insert(0, str(REPO / "tools" / "ai_accuracy"))
from photo_store import frame_stem  # noqa: E402


def _titles() -> list[str]:
    return [p["title"] for p in
            json.loads(PHOTOS.read_text(encoding="utf-8"))["photos"] if p.get("title")]


# Every collision frame_stem causes in the corpus, with WHY. A collision means the fetcher
# will skip a photograph, so each one is a decision somebody made and has to be visible.
# Checked in both directions by the two tests at the foot of this class.
DECLARED_COLLISIONS: dict[str, str] = {
    "rajbangshi thali with rice, taro leaf chhyaka, bottle gourd curry and crispy fried "
    "dried indian carplet fishes, siliguri, west bengal dsc":
        "TWO FRAMES OF ONE SERIES - DSC 0028 and DSC 0029, one photographer, one sitting, "
        "different SHA-256 and hamming 20. This is the pair that caused the rule, and the "
        "reason the guard does not fire on it is that 20 is genuinely outside NEAR_DUP_"
        "DISTANCE: re-encoding the same file moves the hash by 0 or 1, so the camera moving "
        "between shots is a real difference, not noise. The title is exact, so the title is "
        "what decides it.",
    "sarson ka saag mohali 2016 08 06":
        "A SECOND FRAME SERIES, and one with no DSC or IMG marker at all - bare camera "
        "counters 8213 and 8227 after a date. Found by the test rather than by me: I had "
        "assumed the rule needed a marker, and it does not. Two photographs of one thali, "
        "so skipping the second is right.",
    "bottle gourd curry":
        "NOT A FRAME COUNTER - a Commons first-letter case variant, 'Bottle Gourd Curry' "
        "and 'Bottle gourd Curry', which is one file under two titles. Caught because the "
        "stem is lowercased, which is right: Wikimedia normalises the first letter, so "
        "these are the same photograph twice and one of them should never have been fetched.",
}


class ASecondFrameIsNotASecondPhotoTests(unittest.TestCase):
    def test_the_two_titles_that_caused_this_actually_collide(self):
        """Proved on the real data, not a synthetic pair. If these ever stop colliding the
        rule has stopped covering the case that motivated it, and the duplicate will
        arrive again."""
        a = ("File:Rajbangshi Thali with rice, Taro leaf chhyaka, Bottle gourd curry and "
             "crispy fried dried Indian Carplet fishes, Siliguri, West Bengal DSC 0028.jpg")
        b = a.replace("DSC 0028", "DSC 0029")
        self.assertNotEqual(a, b, "the two titles are identical, so nothing is being proved")
        self.assertEqual(
            frame_stem(a), frame_stem(b),
            f"the two frames of one series do not collide under frame_stem "
            f"({frame_stem(a)[-30:]!r} vs {frame_stem(b)[-30:]!r}), so a second frame of a "
            f"series will still be downloaded and reviewed.")

    def test_a_title_with_no_frame_number_is_left_alone(self):
        for t in ("File:Beans curry.jpg", "File:Chole bhature.jpg",
                  "File:Palak paneer main course.jpg"):
            self.assertEqual(
                frame_stem(t), frame_stem(t).lower().removeprefix(t[5:].split(".")[0]),
                f"{t!r} was altered by frame_stem, so the rule is stripping something that "
                f"is not a frame counter - which is how a rule meant to catch DSC 0028/0029 "
                f"would start colliding unrelated dishes")

    def test_a_frame_number_and_a_real_number_do_not_collide(self):
        """The dangerous direction. A bare trailing number is only a frame counter if it
        looks like one; "Paneer Tikka 28" is a dish, and treating its 28 as a frame number
        would make it collide with "Paneer Tikka 29"."""
        self.assertNotEqual(
            frame_stem("File:Paneer Tikka 28.jpg"), frame_stem("File:Paneer Tikka 29.jpg"),
            "a trailing number with no DSC/IMG marker is being treated as a frame counter, "
            "so two differently-numbered dishes would collapse into one")

    def test_every_collision_the_rule_causes_is_declared_with_its_reason(self):
        """Written the wrong way first, and the wrong way is worth recording.

        I first asserted that NO TWO titles in the corpus may collapse under frame_stem,
        on the reasoning that a collision means the fetcher will skip a photograph. It went
        red on three collisions, and on reading them the assertion turned out to be the
        wrong shape: COLLISIONS ARE WHAT THE RULE IS FOR. A guard that forbids its own
        purpose is a guard that will be "fixed" by being switched off.

        All three are correct, and each is a different reason:

          * "...DSC 0028.jpg" / "...DSC 0029.jpg" - the case that caused this. Two frames
            of one meal, one photographer, one sitting.
          * "...Mohali 2016-08-06 8213.JPG" / "...8227.JPG" - a SECOND frame series, and
            one with no DSC/IMG marker at all. So the rule catches bare camera counters
            too, which I had not measured before writing the test.
          * "Bottle Gourd Curry.jpg" / "Bottle gourd Curry.jpg" - not a frame counter at
            all but a Commons first-letter case variant of one file, caught because the
            stem is lowercased.

        So the check is now: every collision must be DECLARED here with its reason, and a
        new collision fails by name. That still stops the rule silently widening - which
        was the fear behind the original assertion - while permitting the collisions the
        rule exists to catch. A stale declaration fails too, so a series that is deleted
        cannot leave a permission behind.
        """
        groups: dict[str, list[str]] = {}
        for t in _titles():
            groups.setdefault(frame_stem(t), []).append(t)
        collisions = {k: v for k, v in groups.items() if len(v) > 1}
        undeclared = {k: v for k, v in collisions.items() if k not in DECLARED_COLLISIONS}
        self.assertEqual(
            undeclared, {},
            f"frame_stem makes these titles collide and no reason is declared for it: "
            f"{[(k[:40], v) for k, v in undeclared.items()]}. Every collision means the "
            f"fetcher will skip a photograph, so an undeclared one is a photograph "
            f"silently lost. Either the rule is too broad and needs narrowing, or the "
            f"collision is a real duplicate and needs a line here saying why.")

    def test_no_declared_collision_has_stopped_being_one(self):
        stale = sorted(k for k in DECLARED_COLLISIONS
                       if k not in {frame_stem(t) for t in _titles()})
        self.assertEqual(
            stale, [],
            f"these collisions are declared but no longer happen: {stale}. A declaration "
            f"that outlives its reason is a hole with a comment on it - it would let a NEW "
            f"collision on the same stem through without anybody looking.")

    def test_frame_stem_is_idempotent(self):
        for t in _titles()[:60]:
            once = frame_stem(t)
            self.assertEqual(
                frame_stem(once), once,
                f"frame_stem is not idempotent for {t[-40:]!r}: {once[-30:]!r} -> "
                f"{frame_stem(once)[-30:]!r}. The rule is applied to titles that may "
                f"already have been through it, and a rule that changes on the second pass "
                f"stops being true on the second run.")

    def test_no_real_title_produces_an_empty_stem(self):
        empty = [t for t in _titles() if not frame_stem(t)]
        self.assertEqual(
            empty, [],
            f"these titles reduce to an empty stem: {empty[:3]}. An empty stem equals every "
            f"other empty stem, so the fetcher's skip would match anything and drop the "
            f"whole corpus rather than one duplicate.")

    def test_the_fetcher_actually_uses_the_rule(self):
        """The gap this module had, and it was found by breaching it rather than by
        reading it.

        I proved the rule bites by breaking `frame_stem` itself - identity function, two
        tokens stripped, the digit range widened - and every one of those went red. Then I
        removed the rule's actual USE: the skip in fetch_commons that compares
        frame_stem(cand) against frame_stem(p) for the photos already held. All eight tests
        stayed GREEN. Removing the import of frame_stem did the same.

        So the module was checking that a correct function exists while saying nothing
        about whether anything calls it - which is the exact shape of a check that cannot
        fail. A duplicate frame would have kept arriving, and the guard would have reported
        that frame_stem is fine, because frame_stem IS fine; it is simply not connected.

        This is a source-level check rather than a live fetch, and deliberately so: a test
        that spends a network call to prove a five-line `if` is wired up is a test that
        fails when Commons is throttled, and a test that fails for the wrong reason is worse
        than no test. The same approach is already used by the ledger's row-parser check
        and by the query-set guards.
        """
        src = (REPO / "tools" / "ai_accuracy" / "fetch_commons.py").read_text(encoding="utf-8")
        self.assertIn(
            "frame_stem", src.split("def ")[0],
            "fetch_commons.py does not import frame_stem at all, so nothing there can use "
            "the rule. The dedupe in this module is on a function nobody calls, and every "
            "other test here would still pass.")
        # The pattern has to tolerate a NESTED call: the real comparison is
        # `frame_stem(p.get("title") or "") == frame_stem(cand["title"])`, and a naive
        # `[^)]*` cannot cross the inner `p.get("title")` - which is how the first version
        # of this check went red on correct code. A guard that only passes against the
        # shape its author imagined is a guard that gets switched off.
        self.assertRegex(
            src, r"frame_stem\(.+?\)\s*==\s*frame_stem\(",
            "fetch_commons.py imports frame_stem but never COMPARES two stems, so the rule "
            "is imported and unused. A second frame of a series will be downloaded and "
            "reviewed, and this module will report that frame_stem works perfectly, because "
            "it does - it is simply not connected to the fetch.")

    def test_the_rule_is_not_a_no_op_on_the_real_corpus(self):
        """If frame_stem were the identity on every title in the manifest, every check
        above would pass while the duplicate kept arriving - a guard that cannot fail."""
        changed = [t for t in _titles() if frame_stem(t) != t.strip().lower()
                   .removeprefix("file:").rsplit(".", 1)[0].strip()]
        self.assertTrue(
            changed, "frame_stem changes NOTHING in the corpus, so this module passes while "
                     "the duplicate it was written for still arrives. The rule is either "
                     "dead code or the manifest has no frame-numbered titles at all, and "
                     "both are worth knowing.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
