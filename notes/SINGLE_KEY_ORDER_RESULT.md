# Single-key order: measured, and the premise fails

**Order (owner, 2026-09-27 ~23:0x IST):** *"Sirf ek key use kare jo tum karte ho,
jo Asha karti hai. Sabhi ek hi key par chalenge."* One key — `OPENCODE_KEY` —
for everything, with vision coming from the **same key** via a different model,
cheapest first (`gemini-3.5-flash-lite` → `gemini-3.8-flash` → the rest), each
measured on 3–5 photos for (a) does it actually look, and (b) what does one scan
cost. Then remove `AICREDITS_KEY`, `OPENROUTER_KEY`, `ZEN_KEY` — **but only once
the single-key path works**, because those keys run Asha's brain and removing
them could stop it.

I am not copying the order. I am running it, and here is what it measured.

## 1. Step 1 — every call on `OPENCODE_KEY` only ✅ built, and it is the probe

`x-cm-probe-model: <model>` makes one real call per configured secret and returns
the secret's **name** and an **HTTP status only**. A key value is never read,
logged or returned, and the probe cannot be used to obtain one. Deployed
`2c80cc5c`.

```
$ wrangler secret list        EXIT=0
AICREDITS_KEY  OPENCODE_KEY  OPENROUTER_KEY  ZEN_KEY      (4 secret_text)
```

## 2. Step 2 — the same key, a different model. **This is where it fails.**

Every model the owner listed, probed on `OPENCODE_KEY` (the `go` tier):

| model | `go` (OPENCODE_KEY) | why |
|---|---|---|
| `gemini-3.5-flash-lite` | **400** | `Model is unavailable` |
| `gemini-3.8-flash` | **400** | `Model is unavailable` |
| `gemini-3.7-flash` | **400** | `Model is unavailable` |
| `gemini-3.6-flash` | **400** | `Model is unavailable` |
| `gemini-3.5-flash` | **400** | `Model is unavailable` |
| `gemini-3.1-pro` | **400** | `Model is unavailable` |
| `claude-sonnet-4-5` | **400** | `Model is unavailable` |
| `claude-opus-4-6` | **400** | `Model is unavailable` |
| `deepseek-v4.1-flash` | **429** | `GoUsageLimitError` |
| `mimo-v2.5` | **429** | `GoUsageLimitError` |
| `space-bunny-free` | **429** | `GoUsageLimitError` |

**Two separate walls, and neither is a request I can fix:**

1. **Model availability.** Every Gemini and Claude id the owner listed answers
   `400 Model is unavailable` on `OPENCODE_KEY`. OpenCode Go's catalogue is open
   *coding* models (the list in its own docs is MiMo, DeepSeek, GLM, Kimi,
   LongCat, Qwen…). Gemini and Claude are not in it. **The vision models the
   owner named cannot be served by the one key, at any price, because that key's
   plan does not carry them.** This is a catalogue fact, not a quota fact.
2. **Quota.** The models Go *does* carry — `mimo-v2.5`, `space-bunny-free`,
   `deepseek-v4.1-flash` — all answer `429 GoUsageLimitError: usage limit
   exceeded, limitName: monthly` on workspace `wrk_01M1NKGRQ3XPRCHAWEBXKE0EM3`.
   The monthly allowance is spent.

Where the vision models *do* work today: **`OPENROUTER_KEY` and `AICREDITS_KEY`**
both answer `200` and serve `gemini-3.5-flash-lite` and `gemini-3.8-flash`. Those
are precisely two of the three secrets the order says to delete.

`ZEN_KEY` is separately out of funds: `402 Insufficient account funds` on every
model tried, and `429 Rate limit exceeded` on `space-bunny-free`.

## 3. Step 3 — remove the three secrets? **NO, and here is the proof**

The order's own condition is *"only once the single-key path is working"*. It is
not working — it cannot work in the shape described. Deleting
`OPENROUTER_KEY` and `AICREDITS_KEY` right now would:

- **remove the only two paths that serve vision at all**, breaking the food
  scanner for every user, and
- risk **Asha's brain**, which the owner says runs on these keys.

So I have removed **nothing**. The order says do not; the condition is unmet.

## 4. The key removal from the repo — that part was already clean

Order 1 of the previous message ("saari key hatao") turned out to need no
edits. A scan of every line mentioning a provider name found only: secret
**names** (`env.AICREDITS_KEY`), **upstream URLs**
(`https://aicredits.in/...`), and coincidental bytes inside PNGs. `.env` exists,
is gitignored and is untracked. `test/no_provider_keys_test.dart` now guards it
so it cannot regress.

## 5. What I did NOT do, and why

- Did not delete any Worker secret. The condition is unmet, and one of them is
  currently the only thing serving vision.
- Did not guess a price for a scan on a model I cannot reach. The owner said
  measure, not guess; I cannot reach these models on the one key, so there is no
  honest per-scan number to report yet.
- Did not touch `ZEN_KEY` (402, out of funds) — that is a money decision and
  therefore the owner's.

## 6. The one-line proof the owner asked for

> **On `OPENCODE_KEY`, every Gemini and Claude id the owner listed returns
> `400 Model is unavailable` — Go's catalogue is open coding models and does not
> carry them — while the models Go does carry return
> `429 GoUsageLimitError (monthly limit exceeded)`. Vision is currently served
> only by `OPENROUTER_KEY` and `AICREDITS_KEY`, so the single-key path is not
> merely unproven, it is impossible in the shape described, and the three
> secrets stay until the owner decides otherwise.**

## 7. What would actually make a single key work

Not a code change — a plan change, which is money and therefore the owner's:

1. **If Go's monthly allowance is topped up / the Zen "use balance" option is
   enabled**, then `mimo-v2.5` becomes available on the one key — but it is
   still **not a vision model**, so the scanner would need a different approach
   entirely.
2. **If a vision-capable model is added to the Go plan**, the order works as
   written and I can measure cost per scan immediately.
3. Otherwise the honest single-key architecture is: **one key, but a model on
   that key which can see** — and today that key has none available to us.

I have not chosen between these and have changed nothing.
