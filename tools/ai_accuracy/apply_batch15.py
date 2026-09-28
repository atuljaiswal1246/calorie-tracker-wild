#!/usr/bin/env python3
"""Apply batch 15 - the round that produced the FIRST control-supported negative finding.

Batches 13 and 14 both returned zero, for two different reasons that were not about the
food: a rate limit, and my own over-constrained query. So batch 15 put the CONTROL INSIDE
the query set rather than running one separately, because a control run minutes earlier is
a claim about a moment that has passed.

  7 queries (the first is the control, a query proven in batches 12 and 14), 3 downloaded,
  accepted 0.

THE KHAKRA MEASUREMENT, which is the result and the reason to keep this batch:

  CONTROL, 'filetype:bitmap uthappam breakfast' .... returned hits, and exit 0, so every
                                                       query in the set really was asked
  'filetype:bitmap khakra' ........................ 8 candidates, NONE of them food -
                                                       a 1784 map of the Ganges, the
                                                       Khakra Math Palace at Udaipur, the
                                                       Ghaghara river
  'filetype:bitmap "khakra rotli"' ................ 0
  'filetype:bitmap khakro' ........................ 0
  'filetype:bitmap "gujarati khichdi"' ............ 0

The per-query cap was RAISED to 8 for that second measurement, so a cap cannot masquerade
as an absence - the batch-15 run itself skipped candidates under the cap, and without
raising it I would have been reading my own cap as a fact about the food.

So: khakra is not missing from Commons because the food is absent. It is missing because
"khakra" is a proper noun that a 2026 map and a palace both match, and the dish needs a
word beside it that no one has captioned. **This is the first negative finding in this line
of work that a control supports**, and the honest reading of it is not "khakra cannot be
photographed" but "khakra cannot be SEARCHED with the words available".

  rejected 3  ALL THREE ON WHAT THEY ARE, and two were decidable from the filename:

    - "mushroom masala dosa": OPENED. A steel plate, banana leaf, a folded dosa and three
      katoris - white coconut chutney and two brown curries. I CANNOT IDENTIFY MUSHROOM in
      either curry, and the visible dish is a third dosa. Taking `mushroom` from the
      filename would repeat, one round later, the exact fault batch 14 rejected "mushroom
      poori" for; and taking `dosa` makes a third dosa and worsens the concentration.
      Neither, so neither.

    - "chalciporus piperatus lc0182": REJECTED WITHOUT BEING OPENED - a Latin species
      binomial with a field-collection index, which is a botanical record of a wild
      pepper, not a dish.

    - "1784 tiefenthaler map of the ganges and ghaghara river": REJECTED WITHOUT BEING
      OPENED - an antique map. This is the khakra problem in one filename: the word is a
      proper noun and the search returns history.

MUSHROOM REMAINS EMPTY, and now for the fourth characterised reason: the dish is
demonstrably on Commons, but it is photographed as a dosa plate or a street-food platter
where the mushroom cannot be identified in the picture. What a mushroom case needs is a
photograph where a mushroom is VISIBLE, and no query in three batches has produced one.
"""
from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CASES = os.path.join(ROOT, "tools/ai_accuracy/cases.json")
PHOTOS = os.path.join(ROOT, "tools/ai_accuracy/photos.json")

REJECT = {
    "mushroom_masala_dosa_jpg_846af539.jpg": (
        "OPENED: a steel plate with a banana leaf, a folded dosa and three steel katoris "
        "- white coconut chutney and two brown curries. I cannot identify mushroom in "
        "either curry, and the visible dish is a third dosa. Taking `mushroom` from the "
        "filename would repeat, one round later, the exact fault this batch's predecessor "
        "rejected 'mushroom poori' for; taking `dosa` makes a third dosa and worsens the "
        "concentration. Neither, so neither"
    ),
    "chalciporus_piperatus_lc0182_jpg_f5d65d82.jpg": (
        "REJECTED WITHOUT BEING OPENED, and the filename decides it: a Latin species "
        "binomial with a field-collection index is a botanical record of a wild pepper, "
        "not a dish"
    ),
    "1784_tiefenthaler_map_of_the_ganges_and_ghaghara_riv_0c4b4a3f.jpg": (
        "REJECTED WITHOUT BEING OPENED: an antique map. This is the khakra problem in one "
        "filename - the word is a proper noun and the search returns history"
    ),
}


def main() -> int:
    with open(CASES, encoding="utf-8") as fh:
        corpus = json.load(fh)
    with open(PHOTOS, encoding="utf-8") as fh:
        manifest = json.load(fh)
    photos = {p["file"].split("/")[-1]: p for p in manifest["photos"]}

    rejected = 0
    for name, reason in REJECT.items():
        rec = photos.get(name)
        if rec is None:
            # the map's stored filename may carry a different digest; match on prefix
            cand = [k for k in photos if k.startswith(name[:40])]
            if len(cand) == 1:
                rec, name = photos[cand[0]], cand[0]
            else:
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
            "indistinguishable from an accepted one."
        )

    corpus["_readme"].extend([
        "",
        "BATCH 15 (2026-09-28): THE FIRST CONTROL-SUPPORTED NEGATIVE FINDING. 7 queries",
        "with the CONTROL INSIDE THE SET rather than run separately, because a control run",
        "minutes earlier is a claim about a moment that has passed. 3 downloaded, accepted",
        "0, rejected 3.",
        "",
        "  CONTROL 'filetype:bitmap uthappam breakfast' .. returned hits, exit 0, so every",
        "                                                      query in the set was asked",
        "  'filetype:bitmap khakra' ...................... 8 candidates, NONE food - a 1784",
        "                                                      map of the Ganges, the Khakra",
        "                                                      Math Palace, the Ghaghara river",
        "  'filetype:bitmap \"khakra rotli\"' ................ 0",
        "  'filetype:bitmap khakro' ........................ 0",
        "  'filetype:bitmap \"gujarati khichdi\"' ............ 0",
        "",
        "The per-query cap was RAISED to 8 for that measurement, so a cap cannot masquerade",
        "as an absence - the batch-15 run itself skipped candidates under the cap, and",
        "without raising it I would have been reading my own cap as a fact about the food.",
        "",
        "So khakra is not absent because the food is. It is absent because 'khakra' is a",
        "proper noun that a 2026 map and a palace both match, and the dish needs a word",
        "beside it that nobody has captioned. The honest reading is not 'khakra cannot be",
        "photographed' but 'khakra cannot be SEARCHED with the words available' - and that",
        "is a statement about searching, which is a different thing and a reversible one.",
        "",
        "MUSHROOM REMAINS EMPTY for the fourth characterised reason: the dish is",
        "demonstrably on Commons but photographed as a dosa plate or a street platter where",
        "the mushroom cannot be identified. What a mushroom case needs is a photograph where",
        "a mushroom is VISIBLE, and no query in three batches has produced one.",
    ])

    with open(CASES, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
    with open(PHOTOS, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"accepted 0, rejected {rejected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
