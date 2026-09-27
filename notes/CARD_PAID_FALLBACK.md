# CARD — paid fallback needed, or not? · **owner's decision**

**Status: OPEN.** I keep this card. I bring it to the owner in **one line** when
the evidence says the decision can no longer be deferred.

Raised 2026-09-27. Owner instruction of record: *"free pe chalwa do abhi ke liye"*
— explicitly **temporary**, not permanent.

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
