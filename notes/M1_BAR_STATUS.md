# M1 bar status — 2026-09-28, 04:10 IST

## The short version

**The corpus half of M1 is met. The run half is not. M1 is NOT met, and M2 cannot
be evaluated at all yet.**

I am writing this the moment the corpus crossed the line, because the temptation
on a milestone is to write "bar met" and let the next session — or the owner —
assume the product got more accurate. It did not. The evidence got better.

## What M1 actually asks for

`notes/ROADMAP_DRAFT.md` §M1, three obligations, not one:

1. a **repeatable command** scores **20 measured real Indian meals** and prints
   one table;
2. run **twice** — old prompt vs new prompt, **side by side**;
3. the **baseline committed to the repo**.

| # | obligation | state |
|---|---|---|
| 1a | 20 measured real Indian meals | **MET** — 65 cases over **37 distinct dish classes** — and every declared class now has a case |
| 1b | one repeatable command, one table | **MET** — `python3 tools/ai_accuracy.py`, prompt extracted from the Dart source so it cannot drift from the app |
| 2 | side by side, old prompt vs new | **MECHANISM NOW VERIFIED, STILL NEVER RUN FOR REAL** — `--stub` executes the whole A/B path (both prompts extracted and fingerprinted, both sides scored, the A/B table, the JSON) with **zero** provider calls, and `test/compare_path_test.dart` drives it. What is still missing is a run with a real model on both sides. |
| 3 | baseline committed | **NOT MET** — `baseline_batch4_2026-09-28.json` exists but its number is **WITHDRAWN**: the run could not complete, and re-running is exactly what the CEO ordered me to stop doing |

## The corpus, with its producer

```
python3 tools/ai_accuracy.py --corpus      # reads cases.json, calls no model, costs nothing
```
- 65 cases · 44 distinct dish names · **37 distinct dish classes** · 54 coverage classes
- bar: 20 meals = 20 distinct dishes. **37, met with seventeen classes spare.**
- how it got there: 13 at 02:45 → 18 after batch 5 → 22 after batches 6-7 → 28 after batch 11 → 30 after batch 12 → 31 after batch 14 → 32 after batch 16 → 33 after batch 17 → 34 after batch 24 (karela). Batch 18 added no class and moved the
  concentration instead, 27% -> 26%. Ten free
  Wikimedia photographs, all attributed, all with licence and SHA-256, **zero
  model budget**.
- every photo was looked at before it was accepted; 23 were rejected with the
  reason recorded, including a real Goan fish thali I turned down because its
  truth was not nameable.

## What this does NOT mean

- **It does not mean the app is accurate.** It means the evidence is now good
  enough to measure it honestly. No number about accuracy has changed tonight.
- **The last measured median was 20.0%** — on the *breakfast-heavy 17-case* corpus
  of batch 3, not on these 30. It is not comparable with the new corpus and must
  not be quoted as if it were.
- **"0 invented dishes" has never been measured.** That is the M2 bar's first
  clause, and the only invention data I have is from 7–12 case corpora and one
  flaky abstain canary where `kadhi_bowl` abstained on run 1 and invented
  "Chana Masala" on run 2.
- **The abstain rate has never been measured either — and the instrument could
  not measure it until 06:50 tonight.** The prompt asks the model for
  `"unrecognised": true` and the app honours it, but `score_case` ignored the
  flag and scored an abstention as **zero calories with every item missed** —
  the worst-looking number a correct behaviour can produce. A median containing
  abstentions would have argued against the decision the owner personally made,
  and the "fix" it invites is the exact failure that decision prevents. The
  harness now scores an abstention as an abstention, reports an abstain RATE
  next to the median, and the median is over answered scans only. No run could
  ever have told me, because no abstention had ever been measured.
- **Meeting a corpus bar is not meeting a product bar.** Nobody should tell the
  owner the scanner improved because I added photographs.
- **Meeting a class-count bar is not being a sample.** 24% of the corpus is four
  classes; the number to watch next is the concentration, not the class count.
- **The bar says 20 real INDIAN meals, and that had never been examined.** Every other
  check asks whether a class is distinct; none asked whether the meal is Indian at all.
  Measured across all 53 cases: **3 truth names carry no Indian marker on their own** —
  `Mushroom` (1 case, the batch 16 dry fry whose Indian-ness rests on the caption) and
  `Chicken Curry` (2 cases, a dish that exists across Thai, Indonesian, British and Indian
  cuisines). So **50 of 53 are Indian by name** and the bar is not threatened, but a
  headline claim of "real Indian meals" should say which three rest on something weaker
  than the dish name. Declared in `test_the_dish_classes_are_distinct.py` and checked in
  both directions, because the first version of that check only walked the declaration
  and a new such case left it green.
- **I suspected five such names and three were in no case at all** — `Legume Salad`,
  `Halwa` and `Egg` are in `DISH_CLASS` and appear in zero cases. The suspicion list was
  longer than the finding, which is the usual direction of that error, and the count is
  three.
- **A class count is a count of KEYS, and two keys can be one dish.** Every class guard
  here counts the distinct `DISH_CLASS` keys the corpus hits, so a synonym pair is two
  keys for one dish and the count says 2 where a person would say 1. Five pairs are
  **adjacent** enough for that, and each is kept separate on purpose with the reason
  recorded in `tools/ai_accuracy/test_the_dish_classes_are_distinct.py`:
  **kadhi/dal** (yoghurt curry against plain lentil), **kofta/keema** (formed against
  loose minced meat), **chole/rajma** (chickpea against kidney bean), **biryani/pulao**
  (the meat is the boundary and it is visible), **bhindi/lauki** (okra against bottle
  gourd). The pairs are deliberately **disjoint**, so the arithmetic is exact:
  **37 classes as measured, and 31 if a reviewer folds all six** — and 28 is still
  inside the card's own 18-22 band. So the bar is not resting on how anyone treats kadhi
  against dal, and the honest sentence is both numbers, never 27 alone.
- **A class count is also a claim about photographs, and that claim was unchecked
  until 2026-09-28.** A duplicate photograph is two cases of one class wearing two
  names, so a re-encoded copy of a dish the corpus already holds inflates the class
  count without changing a single byte-hash. Measured by
  `tools/ai_accuracy/test_the_corpus_photographs_are_distinct.py` on the corpus as
  committed: **58 cases, 58 open, 0 byte-identical pairs, 0 pairs within
  `NEAR_DUP_DISTANCE`, and the closest pair in the whole corpus is hamming 13 against
  a floor of 8** across 990 comparisons. So the repeated families — baingan, uthappam,
  aloo gobi, kofta — are different photographs of the same dish, not the same
  photograph twice, and the 33 above is not counting one plate twice. Guarded in the
  suite by `test/corpus_photographs_distinct_test.dart`, with a 5-of-5 bite proof
  including a re-encoded-copy breach.

## The one run that closes M1 — for the morning

Zero spend until step 3, and the order is not optional.

```sh
# 1. read the budget FIRST. If it is not visible, nothing runs.
python3 tools/ai_accuracy.py --self-test          # proves the gate, 0 provider calls
python3 tools/ai_accuracy.py --repeat 1           # preflight runs first; MONEY BLOCKED exits 3

# 2. if that run is clean and has money for one more, the side-by-side M1 asks for:
python3 tools/ai_accuracy.py --compare <last-good-commit> --repeat 1

# 3. commit the baseline JSON and quote FOUR numbers, never one:
#    65 cases / 44 names / 37 classes / 54 coverage, AND the concentration, and
#    the median with all of them
python3 tools/ai_accuracy.py --corpus              # after the run, to re-declare
```

Stop conditions, all of them mine, none of them negotiable at 3am:
- `MONEY BLOCKED` → stop. That is a budget decision, not a retry (standing order 8).
- 402/429 seen before a run → the run does not start.
- the spend ceiling (`--max-cost-usd`, default $0.50) stops a run that cannot
  finish — 66 scans that could never complete is the cheapest mistake there is.
- **no force header.** A forced-tier failure is not an app failure, and I
  reported one as the other at 01:20 tonight.

## What is not mine to decide

- The corpus is 37 classes and leans less than it did: dal (5), chole (4), dosa (3),
  sambar (3), then a flat run - batch 24 added a dosa case and broke the flat tail
  at 2 (paneer, bhindi, baingan, mushroom, chicken curry) — 15 of 65 cases, so the
  top four hold **23%**.
  Batch 8 took it 42% -> 34% and hit the ≤35% target, sizing the batch by
  13/(31+N); batches 9 and 10 widened instead of flattening and took it to 31%.
  The bar is met; the sample is not yet even, and a median over this corpus is
  partly a median over dal and chole. Batch 7 tried to fix exactly this and
  Commons returned one usable photograph out of six queries, so the skew barely
  moved. Widening the corpus is free while measuring is not; the guard now pins
  the concentration so it cannot get worse, with ≤ 35% named as the target.
- The owner's money decision gates the run. It is not a technical blocker and I
  am not treating it as one.
