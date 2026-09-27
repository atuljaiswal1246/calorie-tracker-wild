# Which key is running the vision scans? — measured

Every number below was produced by a command whose exit code I checked, at the
timestamp shown. No key value was read, printed or stored.

## 1. The direct answer, from `/health` → `last_billed_request`

Read at **2026-09-27T17:31:10Z**:

```json
{
  "at": "2026-09-27T17:21:04.914Z",
  "provider": "aicredits",
  "requested_model": "gpt-4o-mini",
  "served_model": "gpt-4o-mini-2024-07-18",
  "prompt_tokens": 26181,
  "completion_tokens": 324,
  "est_cost_usd": 0.00412155
}
```

**Provider `aicredits`, model `gpt-4o-mini-2024-07-18`, 26,505 tokens,
$0.0041 per scan.** Re-read at **17:34:03Z** after a further scan:
`requests_billed: 16`, `est_cost_usd_today: 0.068987`.

## 2. Which SECRET does `aicredits` use? — forced, one key at a time

One real photo (`dal_makhani_01_jpg.jpg`, the same bytes each time), sent with
`x-cm-force-provider` naming one secret, at **2026-09-27T17:31:38Z**:

| forced | served by | model | tokens in/out | dish it named |
|---|---|---|---|---|
| `aicredits` | **aicredits** | `gpt-4o-mini-2024-07-18` | 25529 / 12 | Dal Makhani ✓ |
| `openrouter` | **openrouter** | `openai/gpt-4o-mini` | 25529 / 16 | Dal Makhani ✓ |
| `go` | `go:429` → fell through to `aicredits` | `gpt-4o-mini-2024-07-18` | 25529 / 16 | Dal Makhani ✓ |

**So the answer to "which key" is `AICREDITS_KEY`.** The `go` row is the proof
that it is not `OPENCODE_KEY`: forcing `go` produced `go:429` and the request was
answered by `aicredits` anyway.

All three named the dish correctly, so all three upstreams are vision-capable
for this task — they differ in price and in availability, not in ability.

## 3. Is each of the three necessary, and what breaks if it goes?

| secret | necessary today? | why | what breaks if removed |
|---|---|---|---|
| **`AICREDITS_KEY`** | **YES — it is the one in use** | it is the only tier currently serving scans, and the only one with quota | **the food scanner stops entirely.** Every user gets "AI service is busy" / a failed scan. There is no vision path left. |
| **`OPENROUTER_KEY`** | **YES, as the live backup** | proven above to serve vision correctly; it is 2nd in the rotation | we lose the safety net. If AICredits runs out of balance or rate-limits, there is no fallback and scans hard-fail instead of degrading. |
| **`OPENCODE_KEY`** | **NO, not today** | out of monthly quota (`429 GoUsageLimitError`) and it carries **no vision model at all** — every Gemini/Claude id returns `400 Model is unavailable` on it | **nothing visible breaks.** It is already being skipped on every request. It would only matter if the Go allowance resets or a vision model is added to that plan. |

**`ZEN_KEY` is a fourth case and I will not guess it:** it is **not in the
serving rotation at all** (verified in code — it appears only in the probe list,
lines 72–75, never in the rotation at 185–187). Live probes return
`402 Insufficient account funds` on every model tried and `429 Rate limit
exceeded` on `space-bunny-free`. Whether Asha's brain needs it is **not something
I can measure from this repo**, and I have not touched it.

## 4. The four-secret table

| secret | what it serves | used today (2026-09-27 UTC) | if removed |
|---|---|---|---|
| **`AICREDITS_KEY`** | the vision scans, right now — `gpt-4o-mini-2024-07-18` | **16 requests, $0.0690** (counter live from 17:33Z; the 12 earlier scans are in the paid total) | **the food scanner stops for every user.** No vision path remains. |
| **`OPENROUTER_KEY`** | vision backup, `openai/gpt-4o-mini` | **0** (available and working, just not needed) | no immediate break; we lose the fallback that protects against AICredits failing. |
| **`OPENCODE_KEY`** | nothing today — `429` quota, and no vision models in its catalogue | **0** | nothing visible. It resumes by itself if the Go allowance resets. |
| **`ZEN_KEY`** | **nothing — not in the serving rotation** | **0** (no count exists, because it is never asked) | nothing from this app. **Asha's brain is the open question and I have not touched it.** |

The per-secret counter is new (`/health → usage_by_secret_today`), so counts
begin when it was deployed at **17:33Z** — not at midnight. The `paid_usage`
totals cover the whole day.

## What I did not do

- Removed no secret. The owner set the condition — remove only once a single-key
  path works — and measurements show no single key can serve vision today.
- Did not touch `ZEN_KEY` despite it serving nothing here, because the owner says
  it runs Asha's brain and that is not mine to risk.
- Did not guess a price for any model I cannot reach.
