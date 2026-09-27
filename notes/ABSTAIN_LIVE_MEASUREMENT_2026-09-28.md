# The abstain path, measured against the live model — and one idea I killed

**2026-09-28.** The canary is no longer theoretical. Here is what actually
happens when the shipped prompt meets the five cases that used to invent dishes.

**Producer:** `tools/ai_accuracy.py` using the prompt extracted from
`lib/services/openai_service.dart`, model `gpt-4o-mini-2024-07-18` via
`AICREDITS_KEY` (production rotation, no provider forced). Live probes, 5 cases.

## Corpus behind every number in this note

**5 cases, all non-breakfast, all from the same corpus as batch 3.** These are
the five known invention cases, so this measures a worst case, not typical
performance. Two runs, because the first run taught me the answer is unstable.

## Run 1 — 2 of 5 abstained

| case | outcome |
|---|---|
| `tamil_uthappam` | answered: "Vegetable Uttapam" + sambar + chutney |
| `kadhi_bowl` | **ABSTAINED** (`unrecognised: true`) |
| `north_indian_dinner` | answered: Rajma, Roti, Aloo Gobi |
| `masala_dosa_plate` | **ABSTAINED** |
| `andhra_idli_vada_sambar` | answered: Idli, Chutney, Sambar (missed the vada) |

## A correction I have to make about my own claim

I reported `tamil_uthappam` as **the worst failure in the corpus** — the model
"inventing" a dish. **That was wrong, and the bug was my label.** The model
answered *"Vegetable Uttapam"*, which **is** uthappam. My alias list had
`Uttappam` and `Uthapam` but not `Uttapam` (double-t, no h) — the exact spelling
it used, so the harness scored a correct answer as a miss.

Corrected in `cases.json` with the reason recorded. A false accusation is worse
than no measurement, because it sends you fixing the wrong thing — which is
exactly what I nearly did.

## Run 2, corrected labels — and the answer is FLAKY

| case | outcome |
|---|---|
| `tamil_uthappam` | answered, **0 invented, 0 missed** (450 kcal vs ref 310) |
| `kadhi_bowl` | **ANSWERED** with invented "Chana Masala" — after ABSTAINING in run 1 |
| `north_indian_dinner` | answered, invented "Rajma", missed "Chole" (520 vs 670) |
| `masala_dosa_plate` | **ABSTAINED** |
| `andhra_idli_vada_sambar` | answered, invented "Coconut Chutney", missed "Vada" |

**`kadhi_bowl` abstained once and invented the next time.** So the honest
statement is: **the abstain path works, but the model's willingness to use it is
intermittent — roughly 2 in 5 per run, and unstable between runs.**

That matters for the product. A user will sometimes be told "I don't recognise
this dish" and sometimes be given a wrong dish, for the same photo. That is
better than always being wrong, and worse than always being honest.

## The model's self-reported confidence is not usable as a gate

The model returned `confidence: 0.8` on the **wrong** "Rajma" answer. It is not
calibrated, so the app cannot threshold its way to safety using a number the
model made up. Recorded because the obvious next idea was "gate on confidence"
and that idea is dead on arrival.

## The idea I killed: verify the dish name against the food database

The obvious deterministic guard is "if we have never heard of this dish, it is
an invention". **I checked the database and it does not work:**

```
Palak Paneer    exact=False   near=['Spinach poori (Palak poori)']
Chana Masala    exact=False   near=[]
Uthappam        exact=False   near=[]
Kadhi           exact=False   near=['Besan kadhi with pakodies']
Masala Dosa     exact=True
Dal Makhani     exact=True
```

`assets/merged_foods.json` is **1,712 IFCT/USDA-style ingredient entries**, not a
dictionary of Indian dishes. Most correct dishes are absent. A verification gate
built on it would abstain on nearly **every** real Indian meal — a catastrophic
false-abstention rate that would make the app useless.

So this is not built, and the reason is written down so nobody rebuilds it.

## Where this leaves the product

| lever | status |
|---|---|
| model self-abstention | works, ~2/5, **intermittent** |
| model self-confidence | **uncalibrated, unusable** |
| food-DB verification | **impossible — the DB is ingredient-level** |
| asking the user | already in the app: "Add item", tappable portion chips, manual picker — and the abstain card now links straight to it |

**That last row is the real answer.** The three machine-side routes are all
closed, so the honest path is the one the product already has: say when you are
unsure, and hand the user the keyboard. The abstain card does exactly that, and
it is now reachable from a scan that previously would have logged a confident
wrong number.

## Corpus

5 cases, 2 runs, non-breakfast, all five being known-failure cases. This measures
a **worst case**, not typical performance, and must not be quoted as an accuracy
figure for the app.
