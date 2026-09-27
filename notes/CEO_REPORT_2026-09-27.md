# CEO session — 2026-09-27

**Read this first, then `HANDOFF.md`, then `AGENTS.md`.**
Written by the Cal Matters CEO session. Commit at the end: `ba7d8d6`.
Proof sheet: `design/ceo/ai-scan-before-after.png`.

---

## 1. Ground truth measured today (not read from docs)

| Check | Result |
|---|---|
| `flutter analyze` | **164 issues, 0 errors** (baseline unchanged) |
| `flutter test` | **219 / 219 pass** |
| Google Play tracks (API) | **only `alpha` exists** — `completed`, versionCode `15` (0.9.10) |
| AI proxy, live probe | HTTP 200, served by **`gpt-4o-mini`**, not the intended `mimo-v2.5` |
| Worker secrets present | `AICREDITS_KEY`, `OPENCODE_KEY`, `OPENROUTER_KEY`, `ZEN_KEY` |
| Telegram alerting | **inert** — no `TELEGRAM_BOT_TOKEN` set |
| Signing material | `release-key.jks` + `key.properties` present, both gitignored, none tracked |
| `firestore.rules` | deny-all default, per-user subtree — deployed and correct |

---

## 2. THE BLOCKER — found, fixed, landed

**The app's headline feature was returning the prompt's own example numbers
instead of reading the photo.**

`lib/services/openai_service.dart` asked the model to "return ONLY valid JSON"
and then showed a realistic sample: `Dal Makhani, 200g, 250 kcal, P12 C30 F8`.
Measured on a real photo through the live proxy, same model both runs:

| | items | calories | macros |
|---|---|---|---|
| before | 2 — one **invented "Naan"** | 500 | 12/30/8 = the template's own numbers |
| after | 2 — both real (paneer + the roti in frame) | 470 | 18/20/25 and 3/25/1, Atwater-consistent |

This is the documented `AUDIT_REPORT.md` §5 failure ("60% within 20%",
"paneer misidentified", "collapsed thali into 1-2 items") — the cause was never
the model, it was our own prompt. Both prompts (image + `analyzeText`) are now
schema-only with no realistic values and an explicit "estimate from THIS photo".

**Second defect, same pass: the proxy was silently downgrading.** OpenCode Go
was failing on every request and falling through to the **paid** AICredits
fallback, invisibly — no log, no alert, no error surfaced to anyone.

Root cause, measured not guessed: `wrangler kv key get --binding QUOTA err_go`
held the real reply —

```
go:400 {"type":"error","error":{"type":"MissingSessionID",
  "message":"Request is missing x-opencode-session ..."}}
```

The Worker never sent `x-opencode-session`. Adding it (plus an identifying
`User-Agent`, both required by <https://opencode.ai/docs/go/#where-can-i-use-it>)
moved the failure **400 → 429**. So Go is unreachable from a Cloudflare Worker
IP — precisely what our own rule **KB-06** says happens. Conclusion: Go is
structurally unusable from the Worker, not misconfigured.

---

## 3. Hard-won rules from this session — read before touching the AI again

1. **Never put a realistic example in a food-analysis prompt.** With a weak
   model the example *is* the answer. Schema + types only.
2. **Go (`zen/go`) cannot be called from a Cloudflare Worker.** It 429s. The
   sanctioned client is the `opencode` CLI. If Go is ever wanted for scans, it
   needs a different architecture, not a header tweak.
3. **A circuit breaker nobody can see is not a circuit breaker.** The Worker
   now returns `x-cm-provider`, `x-cm-served-model`, `x-cm-tiers`, `x-cm-keys`
   and writes `err_<provider>` to KV. Always probe the real upstream status
   before believing a fallback is "working".
4. **KV is eventually consistent.** After writing a breaker key, wait ~60s
   before probing, or you will read a stale value and draw the wrong
   conclusion. This cost me two wrong hypotheses.
5. **A secret that exists by NAME is not proof it is set.** Hence `x-cm-keys`.
6. **Test the hypothesis before the fix.** I assumed the Go key was blank;
   `x-cm-keys` disproved it. Measure, then act.

---

## 4. What the app does today

Android, Play **closed testing**, 12+ testers, 0.9.10 live.
Photo → AI breakdown → log; manual search + quick picks; barcode; water,
weight, exercise, steps; 7-day full trial then a soft lock (manual logging,
Home, habits, history stay free); Cal Points, quests, streaks, achievements,
NutriCoins shop, weekly leagues, notifications; Home-screen widgets
(ring + meal); Google Play Billing monthly/yearly with a real verified
purchase; Firebase Auth + Firestore mirror + sign-in restore; dark mode.

## 5. What is stuck

| # | Stuck | Whose call |
|---|---|---|
| 1 | **The 14-day closed-testing gate is long done and production access was never requested.** No `production` and no open-testing track exists. This is the whole reason the app earns nothing. | **OWNER** — Play Console form, I cannot submit a declaration for them |
| 2 | **Play Console listing text** was never updated to match `PLAY_STORE_LISTING.md` (still has the old "your data stays on your device" claim + the removed Groups line). | OWNER — Console edit |
| 3 | **AICredits balance** pays every scan while Go is unreachable. It was ₹50 on 2026-08-29. | **OWNER** — money |
| 4 | Telegram alerting on the Worker is a no-op without a bot token. | OWNER — one secret |
| 5 | Trial is account-level only: a second Gmail on the same phone gets a fresh 7 days. Needs a device ledger + Cloud Function. | ours, post-launch |
| 6 | `~/Desktop/CalMatters-0.9.9.apk` is one version behind (0.9.10 is the live one). | cosmetic |

## 6. Not shipping / parked (unchanged)

Water widget (one-tap background action never ran on a real device), Asha
chat (`Features.asha = false`), Apple sign-in (needs the $99 program),
friends/leaderboard (denied by our own Firestore rules), Hindi, DPDP, iOS.

## 7. Next session — do in this order

1. **Ship 0.9.11** (this prompt fix is in it) via `tools/publish.py <aab> alpha`.
2. Owner: apply for production access. Everything else is downstream of it.
3. Owner: top up AICredits, or accept gpt-4o-mini quality.
4. Re-measure AI accuracy properly — 10 real Indian photos, old vs new prompt,
   recorded in `AUDIT_REPORT.md` §5. The one-photo proof is not an accuracy study.
5. Only then: barcode/packaged-food depth, Hindi.

## 8. Housekeeping noticed, not done

Untracked junk in the repo root: `tapped3.png` (2.8 MB), `tapped3_crop.png`,
`hello.txt`, `.freebuff/`. Harmless; delete when convenient.
