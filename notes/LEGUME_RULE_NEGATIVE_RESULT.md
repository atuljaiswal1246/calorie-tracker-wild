# Negative result: the "pulses are the most confused" prompt rule made it worse

**Landed 2026-09-27.** Reverted. Evidence kept in
`legume_rule_AB_2026-09-27.json`. `lib/services/openai_service.dart` is
byte-identical to the commit before this experiment.

## What I tried

Batch 2 showed both remaining naming failures were legumes — `kadhi_bowl` came
back "Chana Masala" (100% calorie error) and `north_indian_dinner` came back
"Rajma" instead of Chole. So I added a block to the scan prompt naming the
visual cue for each pulse: kadhi is yogurt-based with no whole grains, chole
shows round chickpeas, rajma shows kidney beans, split dals have no whole beans,
and okra ridges mean bhindi.

It sounded obviously right. It was not.

## The A/B — 12 cases × 3 runs, both arms, same provider, same corpus

Producer `tools/ai_accuracy.py --compare HEAD --repeat 3`. 36 scans per arm,
**36 answered in both arms, 0 rate-limited, 0 retries.**

| | pre-fix | with my rule |
|---|---|---|
| median calorie error | **10.3%** | **20.0%** |
| missed dishes | 7 | **12** |
| invented dishes | 7 | 7 |
| calorie/macro disagreement | 3.4% | 5.2% |

**The median error doubled and the misses nearly doubled.** Reverted.

## What it actually did, case by case

- **`kadhi_bowl` — the case I was targeting — genuinely improved on naming.**
  Before: every run invented "Chana Masala" and missed "Kadhi". After: invented
  `[]` and missed `[]` on all three runs, so the name finally matched. But the
  calories stayed wrong (133%, 100%, 0%), so the scan is still unusable.
- **`thali_ma08` — got worse, and invented pulses that were not there.** Before:
  1.4% / 20% / 1.4%, **zero** invented. After: 20% / 2.9% / 2.9% with
  "Chole" invented on one run and "Chana Masala" on another. Telling the model
  that pulses are confusing made it **hunt for pulses**.
- **`urad_dal_two_roti` — worse.** 13.2% on all three runs before; 17.0 / 21.3 /
  25.5% after, and it now misses the onion and cucumber on two runs.
- **`north_indian_dinner` — not fixed at all.** Still "Rajma" for chole on all
  three runs, before and after.

## The lesson, which is worth more than the rule was

**More instructions did not make the model more careful; it made it more
assertive.** Naming a hard class of confusion primes the model to reach for that
class, and the invented-dish count — the failure users cannot detect for
themselves — went up on a case that previously had none.

So the fix for legume confusion is **not** a longer prompt. It is either a
different model, or asking the user: the app already has an "Add item" path and
tappable portion chips from 0.9.10, which is the honest answer for a dish the
model is unsure of.

**And the harness did its job.** This is the first experiment where it caught
*me* shipping a plausible-sounding change that made the product worse. Without
it I would have committed that rule on the strength of "it obviously should
help", which is exactly how the copy-magnet bug got in.

## Standing note for the next attempt

Before adding a rule to this prompt, run the A/B first and keep it only if the
corpus median does not regress. A rule that fixes one case and invents a dish
somewhere else is a net loss, because the invention is invisible to the user.

---

## CORPUS behind every number in this note

> Added 2026-09-28 after `test/score_needs_corpus_test.dart` caught this note
> quoting a score with no corpus. A score without its corpus cannot be
> interpreted, and the composition is the part that changes its meaning.

**12 cases x 3 runs per arm = 36 scans per arm. **0 breakfast, 12 non-breakfast.****

*These figures are not comparable with any other run unless the corpus is
the same. Quote the corpus with the score, always.*
