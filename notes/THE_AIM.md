# THE AIM — Cal Matters, as I define it

Written 2026-09-27 by the CEO session. This is my definition; the owner set the
aim ("the best health app in the world, Android and iOS") and asked me to decide
what "best" means and write it down.

---

## 1. The aim, restated

**Cal Matters becomes the health app people open every day and never leave —
on Android and iOS.**

Not "the best calorie counter". A health app earns a daily place in someone's
life. A calorie counter gets used for two weeks and deleted.

## 2. Who it is for

**The primary person:** Indian, home-cooked food, no dietitian, not a gym
athlete, trying to lose or hold weight. They are not "tracking" as a hobby.
They have one question, several times a day:

> *"Can I eat this?"*

Secondary: the same person with a condition or a goal (build muscle, manage
diabetes) — later, once the basics are trustworthy. We do not claim medical
outcomes; Play's Health & Fitness path, not a medical app.

**Who we are NOT building for:** competitive bodybuilders, people who want a
social feed, people optimising macros to the gram. They are served badly by
design and that is a deliberate choice, not an oversight.

## 3. What daily use must look like

| Moment | Time budget | What must happen |
|---|---|---|
| Before/after each meal (3–4×/day) | **< 30 seconds** | Photo → see the food, the calories, the protein. One tap to keep, one tap to fix. |
| Morning weigh-in | **< 10 seconds** | Type the number, see the trend, done. |
| Everything else | **0 seconds** | Streaks/quests/leagues must never *delay* or *interrupt* a log. |

**The whole product must fit inside that budget.** If a feature needs more than
30 seconds to use, we do not have that feature. This is the constraint that
kills most feature ideas, and it is the honest reading of "daily".

## 4. What makes someone DELETE a competitor app — our real bar

These are the five moments a person actually leaves. Ranked by how often I
believe they decide us:

1. **"That number is wrong and I can't tell."** → they go back to a boring
   manual app. *Boring but right beats clever but wrong, every time.*
2. **"I had to do work a photo could have done."** — measure, type, search.
3. **"It nags me."** guilt, streaks at risk, red numbers, confirm-shaming.
4. **"Day 30: no reason to open it."** novelty is not a reason to return.
5. **"I switched phone and lost everything."**

**Therefore: BEST = RIGHT, FAST, QUIET.**
- **RIGHT** — the food truth is the product. Everything else is decoration.
- **FAST** — 30 seconds, or the habit dies.
- **QUIET** — encouraging, never shaming; silent by default.

Competitors lose to us on **RIGHT** (photo → correct Indian dish, no work) and
lose their own users to us on **QUIET** (no guilt). We win nothing on features.

## 5. What the app is today — honest

A well-built, well-tested **Android calorie tracker** with a broad gamification
surface. 219 tests green, 0 analyzer errors, dark mode, a locked and genuinely
good onboarding, Play Billing with a verified purchase, Firebase Auth +
Firestore + restore-on-sign-in, two home-screen widgets, a 7-day trial with a
soft lock, quests/levels/coins/achievements/leagues/notifications.

**Its one real differentiator — knowing what is on the plate — was unmeasured,
and this session proved it was returning the prompt's own example numbers
instead of reading the photo** (`design/ceo/ai-scan-before-after.png`).

So: beautiful shell, untrustworthy core. That is the actual state.

## 6. What is EMPTY (hollow, not built, or built but fake)

| # | Empty | Why it matters to the aim |
|---|---|---|
| 1 | **Food accuracy is unmeasured.** No harness, no test set, no score. | The core is a guess. I found a serious bug by accident; I cannot find the next one. |
| 2 | **The coach is parked** (`Features.asha = false`). | Nobody answers "can I eat this?" — the user's one daily question. |
| 3 | **Leagues are fake** — peers simulated locally. | A health app that invents friends is worse than one with none. Make real or cut. |
| 4 | **Share cards not built** (design §2.7). | The biggest organic lever we wrote down and skipped. |
| 5 | **iOS is a shell** — no Apple sign-in, no StoreKit, no iOS widget. | The aim says **both** platforms. Not a plan, an empty slot. |
| 6 | **No Hindi.** | 40%+ of the stated user. |
| 7 | **Food DB = 1,712 items**; barcode thin. | Competitors claim 100k+. Search and barcode are weak arms. |
| 8 | **No device ledger for the trial** — a 2nd Gmail on the same phone gets 7 fresh days. | Revenue leaks the moment someone shares a phone. |
| 9 | **No wearable/Health Connect depth verified.** | Steps are the one effortless daily input we have not exploited. |
| 10 | **Best polish sits ABOVE the core** — all locked screens are pre-Home. | We polished the door and the room behind it lies. |

## 7. What changes FIRST, and why

**Build the food-accuracy harness. Today. Before any new feature.**

Reasoning, plainly:
- The aim is a daily-use app. Daily use is the food number. Nothing else
  matters if the number is wrong.
- Every prompt/model/portion change I make from here is a guess unless I can
  score it. Today I "fixed" a real bug and I can only prove it on **one
  photo** — that is not proof, it is an anecdote. If I build more on that basis
  I will ship the next regression blind.
- It is the smallest step that makes every later step provable.

**Definition of done for step 1:** a repeatable command that sends N real Indian
meal photos through the live proxy and prints one score — dish recall, invented
dishes, calorie error, macro consistency — with the baseline stored in this
repo. Then every future prompt change is A/B'd, not guessed.

## 8. TODO (ordered; one small step at a time, each with proof)

- [x] **1. Contain the PII in git history** — the owner's driving licence
      (name, DOB, address, photo) is committed in `25af837`, is on the private
      GitHub remote, and was not ignored. Untracked + ignored now; **history
      purge needs the owner** (irreversible force-push).
- [ ] **2. Accuracy harness** (`tools/ai_accuracy.py`) + a labelled test set of
      real Indian meals. Establish the baseline score.
- [ ] **3. A/B the old vs new prompt** on the full set; record both in
      `AUDIT_REPORT.md` §5 so the number stops being folklore.
- [ ] **4. Turn on the coach, or cut it.** Parked features do not count.
- [ ] **5. Decide leagues: real or removed.** Fake social is a trust bug.
- [ ] **6. Share cards** — the growth lever in our own design doc.
- [ ] **7. iOS** — needs the owner's $99 decision; until then iOS is not a target.
- [ ] **8. Hindi**, after the food truth is solid.

**Rule I am holding myself to:** no new feature starts until step 3 is on
record. Right before more.
