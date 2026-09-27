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
| 1a | 20 measured real Indian meals | **MET** — 30 cases over **21 distinct dish classes** |
| 1b | one repeatable command, one table | **MET** — `python3 tools/ai_accuracy.py`, prompt extracted from the Dart source so it cannot drift from the app |
| 2 | side by side, old prompt vs new | **BUILT, NEVER RUN** — `--compare <git-ref>` exists and is tested; it has never produced two columns |
| 3 | baseline committed | **NOT MET** — `baseline_batch4_2026-09-28.json` exists but its number is **WITHDRAWN**: the run could not complete, and re-running is exactly what the CEO ordered me to stop doing |

## The corpus, with its producer

```
python3 tools/ai_accuracy.py --corpus      # reads cases.json, calls no model, costs nothing
```
- 30 cases · 25 distinct dish names · **21 distinct dish classes** · 37 coverage classes
- bar: 20 meals = 20 distinct dishes. **21, met with one class spare.**
- how it got there: 13 at 02:45 → 18 after batch 5 → 21 after batch 6. Nine free
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
- **Meeting a corpus bar is not meeting a product bar.** Nobody should tell the
  owner the scanner improved because I added photographs.

## The one run that closes M1 — for the morning

Zero spend until step 3, and the order is not optional.

```sh
# 1. read the budget FIRST. If it is not visible, nothing runs.
python3 tools/ai_accuracy.py --self-test          # proves the gate, 0 provider calls
python3 tools/ai_accuracy.py --repeat 1           # preflight runs first; MONEY BLOCKED exits 3

# 2. if that run is clean and has money for one more, the side-by-side M1 asks for:
python3 tools/ai_accuracy.py --compare <last-good-commit> --repeat 1

# 3. commit the baseline JSON and quote FOUR numbers, never one:
#    30 cases / 25 names / 21 classes / 37 coverage, and the median with all of them
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

- The corpus is 21 classes but still leans on dal (5 cases), chole (4), paneer
  (2), sambar (2) — 13 of 30 cases. The next batch should break that skew, and
  widening the corpus further is free while measuring is not.
- The owner's money decision gates the run. It is not a technical blocker and I
  am not treating it as one.
