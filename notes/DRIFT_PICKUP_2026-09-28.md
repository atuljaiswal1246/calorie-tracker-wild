# DRIFT_PICKUP — 2026-09-28, Research Lead

Three findings from card s0377 (the calorie_tracker corpus and free-tier accounting), each dated, each
with the producer that measured it. Every source below is a commit or a file:line in this repo, so a
reader can check any of them without asking me.

The common shape: **all three are a number or a record that was confidently wrong, and in all three the
instrument that would have caught it existed and was not consulted.**

---

## 1. A rate limit was about to be recorded as a fact about three dishes

**When:** 2026-09-28, ~13:20. **Landed as:** `8a7065a`.

Batch 13 sent ten queries to the Wikimedia Commons API for three unphotographed classes and got
`openly licensed candidates: 0`. The reading about to be written into `cases.json` was *"Commons has no
photograph of a khakra, a mushroom masala or a french-bean sabzi"* — a durable claim about three
dishes, and the conclusion a whole batch had been waiting on.

**Source:** `tools/ai_accuracy/fetch_commons.py` — `candidates()` caught every exception per query,
printed one line, and `continue`d. `api()` retried four times with backoff and then raised correctly;
the raise was caught one frame up and turned into silence, ten times over, and the silence **summed**
into a finding. `main()` then printed the count with the same confidence either way.

**The control that saved it:** a query that had returned results two batches earlier, re-run through
the same path, also returned 0 — the API was answering **HTTP 429** for everything. That single
comparison is the entire difference between *"Commons has no khakra"* and *"we were throttled"*.

**The fix:** `SEARCH_FAILURES` records every query never asked; `main()` refuses to print a count when
any query failed, names each one, and exits `3`. Guarded by
`tools/ai_accuracy/test_a_throttled_fetch_is_not_a_zero.py` (5 of 5, `api` stubbed), which also proves
the fix is not its own bug: a run where every query *succeeded* and returned nothing is still reportable.

---

## 2. Three batches returned zero for three different reasons, and only one was about the food

**When:** 2026-09-28, 13:20–13:45. **Landed as:** `80a9ab8`.

| batch | queries | candidates | cause of the zero | a fact about the food? |
|---|---|---|---|---|
| 13 | 10 | 0 | **HTTP 429**, every query | no — a fact about our access |
| 13 (re-run) | 10 | 0 | **my over-constrained query** | no — a fact about my wording |
| 14 | 8 | 19 | — | n/a, it worked |

The measurement that separated them, all through `candidates()` with no query failures recorded:

```
CONTROL, known-good, worked in batch 12 ....... 1 candidate   <- the API is fine
'filetype:bitmap "mushroom curry" bowl gravy'  0 candidates   <- batch 13's wording
'filetype:bitmap "mushroom curry"' ........... 3 candidates   <- same dish, fewer words
'mushroom curry' (no filetype filter) ........ 3 candidates
'khakra gujarati' (no filetype filter) ....... 0 candidates   <- this one is thin
```

**Source:** `tools/ai_accuracy/fetch_commons.py`, `BATCH13_QUERIES` vs `BATCH14_QUERIES` — the only
difference is that batch 14 dropped the form words. `filetype:bitmap` plus a quoted phrase plus two
form words is over-constrained, so batch 13's premise (*widen the dish form*) widened the query into
uselessness. **The mushroom dish was on Commons the whole time.**

**What survives:** only **khakra** has come back empty from every angle tried, so it is the one open
candidate for a genuine absence — and testing that needs a control, not another round of the same query.

**The lesson, now a skill:** `an-empty-result-is-not-a-negative-finding` carries this as
*an exception swallowed inside a loop is a missing data point wearing a zero's clothes*, and adds *a
negative finding needs a control that could have been positive*.

---

## 3. The fetcher was silently deleting the rejection record on every run

**When:** 2026-09-28, ~12:20. **Landed as:** `60931bd`.

The free-tier ledger's `rejected` column summed to **78** across ten batches. `photos.json` could
account for **36**. I read only `photos[]` and concluded the *ledger* was wrong — before finding that
`apply_batch1.py` writes rejections to a **second, top-level** `rejected` array. The ledger was the
accurate side and the artefact was the damaged one. I nearly "corrected" a good number to match a broken
file.

**Source, at the call site:**

```
fetch_commons.py  read   .get("photos", [])
fetch_commons.py  wrote  json.dump({"_note": ..., "photos": existing})
```

A second writer rebuilding the file from the two keys it happened to know about. **Git history dates it
exactly:** 13 records at `c9aae5d` (batch 3), **absent at `faaf963` (batch 4)** — because batch 4's
*fetch* ran before its *apply*. So it was never a batch-4 slip; it repeated on every fetch, seven more
times. The 24 records and their `rejected_because` reasons survived only in history, and were restored
from `c9aae5d` and `461b22d`.

**The fix is in the writer, not the data:** `save_manifest()` writes the object it was given and
round-trips every top-level key it did not create. Guarded by
`tools/ai_accuracy/test_the_rejection_record_survives.py`, whose bite proof includes a breach that
reinstates the original destructive two-key write verbatim — because a guard that only inspects the file
it protects cannot notice the next writer that will destroy it.

---

## What I would check next, and why it is not a finding yet

- **khakra** is the last class empty from every angle. One controlled round decides it, and a zero there
  would be the first genuinely-supported negative finding in this line of work.
- **mushroom** is demonstrably on Commons; what comes back is street food and botanical records rather
  than a plate of curry. A query forcing a *plate* is the untried move.
- **`tools/ai_accuracy/fetch_commons.py` is 786 lines** — fourteen from the limit the 800-line rule
  sets, and it is the file the next batch's queries go into. The cut is the work, and it should be its
  own commit rather than arriving alongside new queries.

## The one sentence under all three

**A number nobody re-derived is a claim, and a claim with a control attached is a finding.** Two of
these three were caught by running a control; the third was caught by reconciling a table against the
artefact it described. Neither is expensive. Both were skipped once.
