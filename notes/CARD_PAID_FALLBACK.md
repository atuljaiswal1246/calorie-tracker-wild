# CARD — paid fallback needed, or not? · **CLOSED**

**Status: CLOSED — answer: YES, the paid vision fallback is needed.**

**Decided by the owner at 21:1x IST on 2026-09-27, on their own initiative.**
For the record, and because it matters how the record reads: earlier the same
evening the owner had said *"free pe chalwa do abhi ke liye"*. I did not ask
for money at any point, and I did not re-ask when the evidence came in — the
owner reversed the earlier decision themselves. The reversal was theirs, not a
request of mine.

**What I am NOT doing with this answer, per the same instruction:** the
Worker's existing per-user usage budget is **untouched** (I have not edited the
quota or circuit-breaker code today), and **I have not created any plan, tier or
price.** Pricing is the owner's decision, not mine.

---

## 1. The key never reaches the app — verified, not assumed

Checked 2026-09-27 across the whole tree: **no provider key literal exists in
the shipped app.** The only near-matches are two upstream *URLs* inside
`cloudflare_worker/worker.js`. The app puts exactly one custom header on the
wire:

```dart
headers: { 'Content-Type': 'application/json', 'x-device-id': _deviceId }
```

The provider key stays a Cloudflare secret and the Worker is the only thing that
touches the model. Unchanged, and now checked rather than believed.

**One correction to a premise I was given:** the instruction referred to
`DEEPSEEK_API_KEY` being on the Worker "as now". **There is no such secret.**
`wrangler secret list` returns exactly four:

```
AICREDITS_KEY   OPENCODE_KEY   OPENROUTER_KEY   ZEN_KEY
```

I did not add one and did not change the architecture. Flagging it so nobody
builds on a secret that is not there.

## 2. What a scan actually costs — the number that was missing

5 paid scans, 2026-09-27, producer `tools/ai_accuracy.py --cost`
(`cost_5paid_2026-09-27.json`). Model `gpt-4o-mini-2024-07-18` via AICredits.

| case | prompt tokens | output tokens | cost |
|---|---|---|---|
| thali_ma08 | 26,181 | 326 | $0.004123 |
| dal_makhani_bowl | 26,181 | 124 | $0.004002 |
| kadhi_bowl | 26,181 | 124 | $0.004002 |
| urad_dal_two_roti | 37,515 | 223 | $0.005761 |
| north_indian_dinner | 37,515 | 324 | $0.005822 |

| | |
|---|---|
| **cost per scan** | **mean $0.0047, median $0.0041** |
| text-only call, no photo | $0.000003 |
| **cost per photo** | **$0.0047 — the photo is 99.94% of the cost** |
| 1 scan/day | **$0.14 / person / month** |
| 3 scans/day | **$0.43 / person / month** |
| 5 scans/day | **$0.71 / person / month** |

Priced at gpt-4o-mini list ($0.15/1M in, $0.60/1M out). **Not a quote — the
invoice is the truth.**

**The one lever I found, which I am NOT pulling:** cost tracks image size
(26,181 tokens at one size vs 37,515 at another — 43% more for 43% more
pixels). The app already compresses to 800px/quality 70. Compressing harder
would cut cost roughly in half, but it trades accuracy, and accuracy is M2's
bar, which is the owner's to set. Recorded, not acted on.

---

## The question, in one line

> **When the OpenCode Go free models are unreachable from the app, do we keep
> paying AICredits per scan — or do we stop paying and accept a scanner that
> cannot see?**

## What I measured, naming the producer of every number

Both runs: `tools/ai_accuracy.py`, 7 cases, 2026-09-27.

| | **production path** (`--provider proxy`) | **free path** (`--provider free`) |
|---|---|---|
| model that answered | `gpt-4o-mini-2024-07-18` (AICredits, **paid**) | `opencode-go/space-bunny-free` (free) |
| transport | base64 image → vision model, the shipped request shape | **opencode CLI; the agent reads the file off disk** |
| scans answered | 14 / 14 | 7 / 7 |
| 429 rate-limited | 0 | **0** |
| median calorie error | 19.1% | 21.3% |
| invented dishes | 4 | 8 |
| missed dishes | 6 | 2 |
| median latency | 4.5s | **10.1s** |

**These two columns must never be averaged together.** They are different
systems, not two prices for one system. The harness prints that warning on every
run.

## The finding that decides it

**The free models cannot run the product.** A coding model has no vision input
channel. The free path only "sees" a photo because the opencode CLI agent opens
the file and describes it. Inside the app there is no agent — there is a JSON
request to a model — so `mimo-v2.5` / `space-bunny-free` **cannot be the
scanner**, at any price.

Evidence that the free path is not merely cheaper but *different*: asked about
`food_palak_paneer.jpg` with no image attached, `space-bunny-free` answered
"Palak paneer" — the filename gave it away — then described "two butter naan" and
a "raita in a small terracotta bowl". The bread in that photo is a roti and
there is no raita bowl. It inferred from the filename and embellished.

## So the honest position

- **For measuring our own work:** the free model is **good enough** (21.3% vs
  19.1% median error) and costs nothing. I am measuring on it from now on, and
  the app's cost while I develop falls to zero. **This is already decided and
  needs nothing from the owner.**
- **For the scanner our users touch:** only a paid **vision** model works today.
  That is the part this card is about.

## What I am NOT doing while the card is open

- Not spending, and not asking for a top-up, because the owner said free for now.
- Not claiming the app is accurate on the strength of the free numbers.
- Not building a second vision path "just in case" — that is the handsome work.

## Triggers that bring this card to the owner — one line, then

1. M1 reaches its 20-meal bar and the accuracy number is still **not good enough
   to ship**, i.e. the paid model cannot get us to a number we are willing to
   put in front of users.
2. AICredits needs a top-up **and** the free path is still unreachable from the
   app — i.e. the choice becomes "pay, or the scanner degrades".
3. OpenCode Go starts answering from a Worker IP again (I measure it unblocked) —
   that would make the cheap path viable for production and should be re-tested
   before paying anyone.

## The cheapest thing that would probably settle it

A free **vision** model with an API — Gemini's free tier was rejected for
*production* back in August (10 RPM / 1500 RPD, no SLA), but those limits are
irrelevant for a **test harness** that runs a few dozen scans a day. If the
owner ever wants the measurement to run at zero cost forever, that is the
route, and it needs one free API key — which is a credential only the owner can
create, not a purchase.

**Until then: free model for our measurement, paid vision model for the app, and
I do not spend anything.**
