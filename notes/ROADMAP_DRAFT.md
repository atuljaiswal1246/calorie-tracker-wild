# ROADMAP — DRAFT ONLY, NOT LANDED

**Status: DRAFT for owner approval. No milestone below is active.** Per `ceo.md`
§1, the aim and the roadmap belong to the owner. I drafted this; I cannot land it.

Drafted 2026-09-27 by the CEO session.
**Aim it serves:** the best health app in the world, Android **and** iOS.
**My definition of best:** RIGHT, FAST, QUIET — Indian, home-cooked food, no
dietitian. See `notes/THE_AIM.md`.

---

## Ordering logic (I sorted deliberately)

**Money / blockage first.** M0 is the only thing that turns this app into
revenue; it is the owner's one click. M1–M2 make the core trustworthy, which is
the whole product. M3–M4 protect the daily habit. M5 stops money leaking and
stops people losing their data. M6 is growth. M7 is the aim's second platform.

**What looks handsome and earns nothing — do NOT spend the developer here:**
more gamification polish, red-dot badges, fancier charts, more quests, more
league tiers, more emoji, confetti. Every hour here is an hour not on M1/M2,
where the app's only real claim to being different actually lives.

---

## M0 — Get to production · **OWNER-GATED (money/irreversible)**

**Bar:** the app is live in the Play **production** track and at least **one
real payment** has landed.
**Proof:** Play Console screenshot of the production release + the first Play
purchase visible in the dashboard.
**Approve:** owner only (a declaration under their name). **Direction change:** no — it is the stated plan.
**Why first:** until this happens every other milestone earns ₹0. 12 testers
have been opted in for 14+ days; nobody has pulled the trigger.

## M1 — Trust the core: accuracy harness + measured baseline · **MINE, start now**

**Bar:** a **repeatable command** scores **20 measured real Indian meals** and
prints one table, run twice — old prompt vs new prompt, side by side — with the
baseline committed to the repo.
**Proof:** `tools/ai_accuracy.py` output pasted into `AUDIT_REPORT.md` §5, plus
the committed baseline table. Re-running gives the same numbers.
**Approve:** none to build. **Direction change:** no.

## M2 — RIGHT: hit a real accuracy bar · **NEEDS OWNER APPROVAL**

**Bar (proposed):** on those 20 meals — **0 invented dishes**; **median calorie
error ≤ 25%**; calories agree with macros (Atwater) **within 15%**.
**Proof:** the harness run, committed, showing each number.
**Approve:** **owner** — this sets a product quality bar. **Direction change:** yes-ish; it says what "right" is allowed to cost in effort.
**Note:** M1 tells us the honest number first. If today's number is already
good, M2 becomes "hold it" and I will say so instead of inventing work.

## M3 — FAST: log a meal in under 30 seconds · **NEEDS OWNER APPROVAL**

**Bar:** median **≤ 30 s** and p90 **≤ 45 s** from opening the app to a saved
meal, **10 runs on the owner's real Android phone**.
**Proof:** a per-run timing log committed, plus a screenshot of the finished log.
**Approve:** **owner** (needs the phone + a real decision on how much friction
the AI accuracy is worth). **Direction change:** yes — it trades accuracy against speed, and that is a product trade, not mine.
**Depends:** needs a device; blocked until the owner can run it.

## M4 — QUIET: the reason people stay past day 30 · **MINE**

**Bar:** **zero** shame/guilt strings in the app (auditable list); notification
opt-out is **one tap**; the **≤ 2/day** cap and quiet hours hold under test.
**Proof:** the string audit list committed + a passing engine test.
**Approve:** none. **Direction change:** no.

## M5 — Stop the money and the data leaking · **NEEDS OWNER APPROVAL**

**Bars (two):** (a) a **second account on the same phone cannot get a fresh
7-day trial**; (b) a user's data **survives a phone switch** (sign in on a new
device, everything is there).
**Proof:** device test of both, captured; (b) is the churn reason #5 in `THE_AIM.md`.
**Approve:** **owner** — a device ledger + Cloud Function is new infra and a
cost decision. **Direction change:** yes — it introduces a device-level identity we do not currently have.

## M6 — Growth, and one honest cut · **NEEDS OWNER APPROVAL**

**Bars:** a **share card is generated from a real milestone** (PNG proof), and
**leagues are made real or removed** — a written decision either way. Today the
peers are **simulated locally**, which is a trust bug, not a feature.
**Proof:** the share-card image + the written league decision.
**Approve:** **owner** (cutting a shipped feature is a product decision). **Direction change:** yes for the league cut.

## M7 — iOS + Hindi · **OWNER-GATED (money: the $99 Apple program)**

**Bars:** app **builds and installs on the owner's iPhone** and runs the same
core loop; **Hindi string coverage reported as a %** (and a decision, not an
assumption, on shipping it).
**Proof:** device install screenshot + the coverage report.
**Approve:** **owner** — money and an irreversible Apple enrolment. **Direction change:** no, but it is explicitly half the aim.
**Reality check, stated plainly:** until the Apple program is bought, iOS is an
empty slot. I will not pretend otherwise, and I will not start it.

---

## What I am NOT doing without a decision from you

1. Activating any milestone above (including the ones marked "MINE").
2. Purging the PII from git history — you have authorised it, and I will do it
   as a separate, verified step, but I will not bundle it with roadmap work.
3. Spending money: AICredits top-up, the $99 Apple program.
4. Cutting a shipped feature (leagues) or trading accuracy for speed (M3).

## Immediate next step

**M1 — the accuracy harness**, given to the developer, because it is the one
thing that makes M2 and every later judgement provable instead of guessed. It
needs no approval, no money, and no device.
