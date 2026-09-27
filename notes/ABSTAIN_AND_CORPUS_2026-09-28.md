# The abstain path, the corpus rule, and the deepseek cost question

**Landed 2026-09-28.** Two owner decisions executed, plus one measurement that
answers a money question without answering it wrongly.

---

## Decision 1 — ABSTAIN is a product path, not an error state

**Where it lives (you asked for the file):**

| file | what it does |
|---|---|
| `lib/services/openai_service.dart` | the prompt now asks for `unrecognised: true` and a per-dish `confidence`; `_parseResponse` returns a third field `unrecognised`; an explicit abstain **wins even if items are present**; empty items count as unrecognised |
| `lib/screens/capture_screen.dart` | new `_unrecognised` state renders a calm card — "I don't recognise this dish" + **Name the dish** (opens the existing manual picker) + **Scan again**. Deliberately *not* styled as an error: not recognising something is a normal outcome, and a red box teaches the user the app is broken |
| `lib/screens/manual_entry_screen.dart` | type widened for the new record field |
| `test/abstain_path_test.dart` | the guard + the canary |

**Why this and not a prompt tweak:** measured 2026-09-28, shown an uthappam the
model returned a *different dish* with a confident number. A wrong number enters
somebody's diet and they cannot catch it. "I don't know" is strictly better.

**Guard RED/GREEN, both numbers:**

| proof | RED | GREEN |
|---|---|---|
| delete the abstain copy from the screen | `The user must be told plainly that the dish was not recognised, rather than shown a generic failure.` | 7/7 pass |
| an explicit abstain that also lists items | `An explicit abstain must win even when items are present.` | passes |
| empty items | `Empty items count as unrecognised, not as a silent success` | passes |
| delete a canary case from the corpus | `Canary case(s) no longer exist in the corpus, so the canary would watch nothing` | passes |

**The canary watches 5 named cases** where invention actually happened, and
prints them on every run so it can never be green by looking at nothing:
`tamil_uthappam`, `kadhi_bowl`, `north_indian_dinner`, `masala_dosa_plate`,
`andhra_idli_vada_sambar`.

**I have to report that the canary is currently GREEN, and that is not yet
proof the feature works in production.** It proves the path exists and the
corpus still contains the cases. Whether the model now *emits* `unrecognised`
on those five photos is only answerable by running the live path, which is
batch 4's first job. A green canary that never ran against the model is a
weaker claim than it looks, and I am not going to dress it up.

## Decision 2 — no score without its corpus

`test/score_needs_corpus_test.dart` fails any note in `notes/` that quotes a
score without saying how many cases, which dishes, and the breakfast /
non-breakfast split.

**It immediately found five of my own notes** — `M1_BATCH1`, `M1_BATCH2`,
`LEGUME_RULE_NEGATIVE_RESULT`, `CARD_PAID_FALLBACK`, `ACCURACY_BASELINE`. All
five now carry a **CORPUS behind every number in this note** block stating the
exact corpus and composition. I annotated them; I did not weaken the rule.

## The deepseek cost question — measured, and the answer is inconvenient

Asked to compare a cheaper model on the canary photo (uthappam), forcing
`openrouter` three times:

| requested | actually served | tokens | time |
|---|---|---|---|
| `deepseek-v4.1-flash` | **`openai/gpt-4o-mini`** | 14261 / 84 | 4.7s |
| `gemini-3.8-flash` | **`openai/gpt-4o-mini`** | 14261 / 85 | 3.3s |
| `gpt-4o-mini` | `openai/gpt-4o-mini` | 14261 / 82 | 5.1s |

**All three were the same model.** The Worker's rotation **pins the model per
tier** (`FALLBACK_MODEL` for aicredits/openrouter), so a requested model id is
ignored. This is §0 rule 2 working exactly as written — the model is not chosen
by the caller.

**So I cannot verify the "13x cheaper" claim from here, and I will not repeat
it as fact.** Testing it would require changing the Worker's model routing,
which is the resource I am explicitly forbidden to touch without the
before/after protocol — and which is Asha's routing too. That is a
shared-resource decision, not mine.

What I *can* state, measured: today's bill is **$0.0041 a scan** on
`gpt-4o-mini` via `AICREDITS_KEY`, and this photo cost **14261 prompt tokens**
— token count scales with image size, so a cheaper image is a cheaper scan.
That is the one lever I control without touching the Worker, and it trades
accuracy, so it is not mine to pull either.

## Batch 4 — 20 candidates, deliberately **not** breakfast

Batch 3's five accepted photos were all South-Indian breakfast, so the score
moved for reasons that had nothing to do with the app. Batch 4 targets the gap:
chana masala, rajma, butter chicken, chicken tikka masala, rogan josh, Goa
egg curry, paneer butter masala, dal tadka, tarka dal, gobi curry, shahi
paneer, palak kofta, poha, khichdi, ghee roasti/paratha, eggs bhurji, methi
sabzi, tindora sabzi.

**Batch 4's first job is not photos. It is to run the live path against the five
canary cases and find out whether the model now abstains or still invents.**

Suite: 245 pass (was 235). `flutter analyze` 166 issues, 0 errors.
