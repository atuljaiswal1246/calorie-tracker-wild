# The free tier, tested properly — and why the card stays open

2026-09-27, ~21:2x IST. Owner challenged my conclusion and was **right to**:
I had tested the opencode *CLI agent*, not the request. This is the retest.

> ## ⚠️ CORRECTION, 22:28 IST — the conclusion below about WHY is WRONG
>
> I reported: *"the blocker is the egress IP, not the request, not the model,
> not the prompt."* **That is false, and it came from reading an empty output
> from a command that had failed.**
>
> `err_go` was never empty. Read properly (`tools/kv_get.py err_go`) it holds:
>
> ```
> 429  GoUsageLimitError: "Go usage limit exceeded"
>      limitName: monthly   workspace: wrk_01M1NKGRQ3XPRCHAWEBXKE0EM3
> ```
>
> So the 429 is **the monthly usage limit on the owner's own Go subscription
> being exhausted** — not a datacenter-IP block, and not evidence that Go is
> unreachable from a Worker at all. Re-verified at 22:28: still `go:429`.
>
> **What survives:** the measurement stands (a correct multimodal request,
> `x-cm-force-provider: go`, got HTTP 429). **What does not:** my explanation
> of it, and the structural claim built on it.
>
> **How the mistake happened, because it is the reusable part:** I ran
> `wrangler kv key get` in a shell where `wrangler` was not on PATH. That
> returns exit 127 and empty stdout. I read the empty stdout as "this key holds
> nothing, therefore the provider is never attempted" and built a narrative on
> it. The command had not run at all. `wrangler kv key get` never fails
> silently — a missing key exits 1 with a message, a present key exits 0 with a
> value — so the only way to get "empty" is a broken call.
>
> `tools/kv_get.py` now exists to make that impossible to repeat: it prints
> `VALUE` / `MISSING` / `ERROR` with the exit code, and returns non-zero when
> the read cannot be trusted.

## What I got wrong

I wrote "the free models CANNOT run the product", on the grounds that a coding
model has no vision channel. That was inferred from the agent path, not tested
against the real request. The owner's correction — the fault was in the
**request**, not the model — is the right one to make.

## The three steps, run

Same photo (`photos/vegetarian_thali_ma08_jpg.jpg`), standard multimodal shape:
`messages[0].content` = list of a `text` part and an `image_url` part with a
`data:image/jpeg;base64,…` URL. That is the ordinary OpenAI-compatible
multimodal request; nothing unusual.

**Ground truth, read off the photo myself:** 5 compartments, top-right one
**empty**, bottom-left dal **yellow**, top-middle sabzi **dark green**, meat
**visible**, tray **rectangular**.

### Step 1 — is the request shape right? **Yes.**

The identical body is served by the `aicredits` tier, which answers the
questions about the image correctly. So the shape is valid and the photo is
being read. Confirmed rather than argued.

### Step 2 — questions only a looking model can answer

The **paid** model `gpt-4o-mini-2024-07-18` was the only tier that answered:

```
1. How many compartments?      -> "Four"     WRONG (there are 5)
2. How many empty?             -> "One"      right
3. Colour of the dal?          -> "Yellow"   right
4. Colour, top-middle?         -> "Green"    right
5. Any meat visible?           -> "Yes"      right
6. Tray round or rectangular?  -> "Rectangular" right
```

**5 of 6 — and it miscounted the compartments.** Worth recording: a vision model
that cannot count is a real limit on what we may promise, independent of which
vendor answers.

### Step 3 — the same photo forced through OUR proxy, per provider

This is where the answer is. I added a test-only header
`x-cm-force-provider: <name>` so one tier can be measured alone. It was needed
because I had moved `go` to **last** in the rotation for latency — so a success
earlier in the list returned before `go` was ever tried, and the tier list could
not tell "go is broken" from "go was never tried". My own optimisation was
hiding the very thing I was trying to measure.

With `go` forced to the front, same correct request, same session header, same
identifying User-Agent:

```
x-cm-tiers: go:429 aicredits:ok
x-cm-provider: aicredits
```

**`go:429`.** OpenCode Go — `mimo-v2.5`, the model already covered by the $10
Go subscription — answers **HTTP 429** to a Cloudflare Worker, every time, with
a request that is provably well-formed.

## The finding, in one line for the owner

> **The $10-included model is fine from a normal machine and returns 429 from our
> Cloudflare Worker on a request that is provably correct, so the app — which
> must reach the model through the Worker, because no key may ship in the app —
> cannot use it. Paid vision stays.**

The constraint is the **egress IP**, not the request, not the model, and not the
prompt. I cannot fix that from here, and per condition 1 I will not "fix" it by
putting a key in the app.

## State of play

| | |
|---|---|
| paid vision, per scan | **$0.0047** (photo = 99.94% of it) |
| per person, 3 scans/day | **$0.43 / month** |
| free tier from the Worker | **429, measured 3×** |
| Worker's per-user budget | **untouched** |
| plan / price created by me | **none** |

**Card: stays OPEN**, per the owner's own rule — the three steps did not all
succeed, so it comes back with this proof rather than being closed in my
head. The one route that could close it for real is a free **vision** API that
is not IP-restricted (Gemini's free tier was rejected for *production* on rate
limits, which are irrelevant for a harness). That needs one free key, and I am
not asking for it today.

## Also landed, and it is a real fix

`x-cm-force-provider` in the Worker: test-only, cannot bypass the per-device
quota, exposes no key, and does not change default behaviour. Without it we
cannot tell a broken provider from an untried one — which is exactly how the
silent downgrade survived until today.
