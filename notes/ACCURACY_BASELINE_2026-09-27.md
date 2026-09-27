# M1 — accuracy harness: baseline, and a correction to my own claim

**Landed:** `tools/ai_accuracy.py` + `tools/ai_accuracy/cases.json`.
**Command:** `python3 tools/ai_accuracy.py --compare ba7d8d6 --repeat 5`
**Run:** 2026-09-27, live proxy, served model `gpt-4o-mini-2024-07-18`.

---

## 1. The correction I have to make

Earlier today I told the owner, and wrote into
`design/ceo/ai-scan-before-after.png`, that the prompt fix was **proven**:
before = 500 kcal with an invented Naan, after = 470 kcal, both real.

**That was overstated.** It was one run of each prompt. The harness, 5 runs per
prompt on the same photo, says something different:

| | palak_paneer_meal, 5 runs each | result |
|---|---|---|
| pre-fix prompt (`ba7d8d6`) | 470 / 470 / 470 / 470 / 470 | 0% error, 0 invented, 0 missed |
| shipped prompt | 470 / 470 / 470 / 470 / 470 | 0% error, 0 invented, 0 missed |

**On this photo the two prompts are indistinguishable.** The fix did not
demonstrably improve anything. I should have run it repeatedly before claiming
it, and I did not.

**What survives as true:** the old prompt *did* once return the example's own
numbers (250 / 12 / 30 / 8) plus an invented "Naan" — that transcript is real
and is why the change was made. The example was a genuine copy magnet. But the
failure is **intermittent**, so one run proves the risk exists and proves
nothing about the fix. The PNG overstates the case and I am correcting it
rather than leaving a flattering artefact in the repo.

## 2. What the harness measured (10 runs per prompt)

| metric | pre-fix | shipped |
|---|---|---|
| invented dishes | 0 | 0 |
| missed dishes | **1** | 0 |
| median kcal error | 22.2% | 22.2% |
| median Atwater disagreement | 3.3% | 3.3% |
| median latency | 4.4s | 4.0s |

## 3. Three real findings that came out of building it

1. **The upstream is not deterministic.** Same photo, same prompt: the salad
   came back 300 / 300 / 300 / 350 / 250 kcal. **Any single run is a
   measurement of noise.** Hence `--repeat`. This invalidates one-shot testing
   in general — including anything a past session "verified" by running once.
2. **"No food detected" on a photo full of food — 1 run in 10.** The salad
   returned `items: []` once. This is the audit's old issue #1, now with a
   rate. Mitigated in the app: `analyzeImage` retries up to 3× on an empty
   result, so the user-visible failure rate is below 10%. Not eliminated.
3. **Accuracy on non-Indian food is mediocre (22–33% kcal error).** The salad
   is out of scope for our user, but it is the honest limit: this model is
   tuned for nothing in particular, and it is the paid fallback, not the model
   our prompts were written for.

## 4. Honest status of ROADMAP M1

| bar | status |
|---|---|
| a repeatable command scores real Indian meals | **MET** — `tools/ai_accuracy.py` |
| old vs new prompt, side by side, committed | **MET** — this file + the JSON |
| **20 measured real Indian meals** | **NOT MET — 2 cases, and only 1 is an Indian meal** |

**The 20-photo set cannot be built by me.** The photos are what our users take;
the repo contains exactly one real Indian meal photo. The remaining 19 have to
come from the owner or the 12 testers. This is the one part of M1 that is
blocked on a human, and it is a *collection* task, not an engineering one.

**Do not pad `cases.json` with stock images to make the number look better.**
That would defeat the milestone.

## 5. What the next run must include

Once real photos exist: run `--repeat 5`, and treat any single-run claim as
noise. The first milestone worth aiming at is not "high accuracy" — it is
**0 invented dishes across 20 meals × 5 runs**, because an invented dish is
the one failure a user cannot detect for themselves.

---

## CORPUS behind every number in this note

> Added 2026-09-28 after `test/score_needs_corpus_test.dart` caught this note
> quoting a score with no corpus. A score without its corpus cannot be
> interpreted, and the composition is the part that changes its meaning.

**2 cases x 5 runs = 10 scans. **0 breakfast, 2 non-breakfast.****

**Distinct dish families in that corpus: 2 of 2 cases — no family repeats, so the case count and the fact count are the same number here.**
*These figures are not comparable with any other run unless the corpus is
the same. Quote the corpus with the score, always.*
