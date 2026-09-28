#!/usr/bin/env python3
"""Apply batch 28 - a batch that was mostly a REPRODUCTION, and the reproduction is worth
more than the photograph it produced.

11 queries (the control, one proven query, and nine measured-at-zero queries), 1
downloaded, accepted 0, rejected 1.

THE BET, STATED IN ADVANCE. Batch 27 declared its expectation from the 41% precision
figure and was wrong, and the reason was written down: four of six target queries returned
ZERO pages, so only two candidates existed and the precision was never applied to anything.
Pages returned is the binding constraint. So this batch is deliberately ASYMMETRIC - nine
queries measured at zero pages in a run whose control returned hits, and one query with an
unbroken measured record:

    9 dead queries x 0 pages  +  1 proven query
    EXPECT 1-2 CANDIDATES, and therefore 0-1 CASES.

THE RESULT, as recorded by the fetcher rather than by me:

    pages=1  uthappam breakfast          <- the control, hits
    pages=8  "bottle gourd curry"        <- the proven query, hits again, third batch
    pages=0  "lauki sabzi"               0
    pages=0  "makai curry"               0
    pages=0  "ratan jot salad"           0
    pages=0  "bell pepper curry"         0
    pages=0  "green bean curry"          0
    pages=0  "gwar curry"                0
    pages=0  "tinda curry"               0
    pages=0  "kacche kele curry"         0
    pages=0  "amla murabba"              0

NINE OF NINE REPRODUCED AT ZERO, with a positive control in the same run. That is not a
finding about a dish; it is a finding about the QUERIES, and it is the first thing in
three batches of recording that has actually paid. The precision figure has been sitting in
the ledger for a round, and the thing that makes a corpus expensive is not the fraction of
downloads that survive review - it is how many queries come back with nothing at all,
because a zero costs a query and yields no photograph to review.

"bottle gourd curry" returned 8 pages for the THIRD batch running, which is what makes it
the most reliable query in the corpus: three independent runs, 8 pages every time. That is
a reproducibility claim, not a yield claim, and the two are different - 8 pages produced a
case in batch 25 and a rejection in this one, because pages returned says the archive has
photographs matching three words, not that any of them is a bottle gourd curry.

THE STOP-LIST IS THE ARTEFACT. tools/ai_accuracy/STOP_LIST.md now carries the nine, each
with the batch that measured it zero and the control that ran alongside. It says the QUERY
found nothing; it does NOT say the dish has no photograph, and conflating those two is how
this corpus produced four false findings. Lauki is on that list AND lauki has a case,
because "bottle gourd curry" found it in the very run the stop-list query missed it - so
the list is about spelling, not about existence.

THE TWO ENGLISH NAMES ARE THE ENTRY THAT MATTERS MOST. "bell pepper curry" and "green bean
curry" have now returned zero in TWO separate batches, each with a positive control, where
their transliterated counterparts returned 7 and 8. That is strong enough to say those two
names are not in this archive at all, and that a future batch should not spend a query on
them. It is a fact about Commons, not about the vegetables.

AND THE ONE PHOTOGRAPH IS A NEAR-DUPLICATE OF ONE I REJECTED IN BATCH 26, which the fetcher
did not catch. Batch 26 rejected "rajbangshi thali with rice, taro leaf chhyaka, bottle
gourd curry" - a Bengali festival meal with a fried fish on a skewer, no gourd curry in
frame. This run returned the SAME photograph under a different filename
(...dfef0cb9 rather than ...0f192f0e) and the near-duplicate guard did not fire, because
the guard compares against ACCEPTED photographs and that one was rejected, so it was never
in the corpus to be compared against.

So the guard has a real hole and this batch found it: a query that keeps returning a
photograph already judged worthless will keep returning it, and each rejection costs a
review. The fix is to record a rejection's perceptual hash as well as an acceptance's, so
a known-bad photograph is recognised on sight. That is a change to photo_store.py and it is
NOT in this commit - it needs its own round and its own proof, and doing it here would put
an unproven fix in a corpus commit.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

REJECT = {
    "rajbangshi_thali_with_rice_taro_leaf_chhyaka_bottle__dfef0cb9.jpg": (
        "OPENED, and REJECTED - it is the SAME photograph batch 26 already rejected under a "
        "different filename (...dfef0cb9 against ...0f192f0e): a Bengali festival meal with "
        "a mound of white rice, a dark green leafy dish, a yellow dal and small FRIED FISH "
        "on a skewer, and still no bottle gourd curry anywhere in the frame. Rejected on "
        "the same grounds as its twin. THE INTERESTING PART IS NOT THE PHOTOGRAPH, IT IS "
        "THAT THE FETCHER RETURNED IT AGAIN: the near-duplicate guard compares a "
        "photograph against ACCEPTED ones, and this file was rejected in batch 26 so it was "
        "never in the corpus to be compared against. So a query that keeps returning a "
        "photograph already judged worthless will keep returning it, and every one costs a "
        "review. That is a real hole in the guard and this batch found it. The fix is to "
        "record a rejection's perceptual hash as well as an acceptance's, so a known-bad "
        "photograph is recognised on sight - and that fix is deliberately NOT in this "
        "commit, because it belongs to photo_store.py and needs its own round and its own "
        "proof rather than riding along inside a corpus commit"
    ),
}


def main() -> int:
    with open(PHOTOS, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = {p["file"].split("/")[-1]: p for p in manifest["photos"]}

    rejected = 0
    for name, reason in REJECT.items():
        rec = photos.get(name)
        if rec is None:
            print(f"  ! not in the manifest, skipped: {name}")
            continue
        rec["reviewed"] = True
        rec["rejected"] = True
        rec["reject_reason"] = reason
        rec["opened"] = "OPENED" in reason
        rec["already_rejected_as"] = "rajbangshi_thali_with_rice_taro_leaf_chhyaka_bottle__0f192f0e.jpg"
        path = os.path.join(ROOT, rec["file"])
        if os.path.exists(path):
            os.remove(path)
        rec["file_removed"] = True
        rejected += 1
        print(f"  - {name[:56]}  (re-rejection: same photograph as batch 26)")

    for rec in manifest["photos"]:
        if rec.get("reviewed") is True or rec.get("not_used") is True:
            continue
        rec["not_used"] = True
        rec["not_used_reason"] = (
            "Fetched and never reviewed, so it is not evidence. Declared not-used "
            "rather than left unreviewed, because an undecided photo is "
            "indistinguishable from an accepted one.")

    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted 0, rejected {rejected}  (the corpus is unchanged by this batch)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
