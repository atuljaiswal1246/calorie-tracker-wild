# Cal Matters — Gamification & Notification Design

**Status:** proposal for review (no code until approved)
**Author:** supervisor (brain) with Asha
**Date:** 2026-09-13
**Scope:** end-to-end gamification, then the notification engine.

This document specifies *mechanics and behavior*, mapped onto Cal Matters' real
actions (meal logging, AI scan, water, weight, steps, fasting, exercise, Asha).
It is written to be implemented in **our own Flutter code**.

---

## 0. Ground rules

- **We do not copy code.** Duolingo is closed-source; Habitica / LibreLingo /
  wger / Loop Habit Tracker are **AGPL/GPL (copyleft)**. We study them for
  *mechanics* and implement our own. No file, snippet, or asset is lifted.
- **Health-first, not guilt-first.** This is a nutrition app, not a game about
  weight. We never rank calories/weight against other people, never reward
  undereating or over-exercising, and we make "slack" (freezes) the default so a
  bad day never becomes churn.
- **Everything is measured.** Each mechanic ships with its event + metric, and
  we A/B where we can.
- **Build envelope:** `flutter analyze` clean, `flutter test` green; the locked
  BMR/TDEE/macro math and onboarding options are untouched.

### Sources behind the design (public; no code taken)
- Duolingo: streak/habit blog + help center; Deconstructor of Fun teardowns
  (streaks, leagues, notifications); Growth.Design retention case study;
  Lenny's Newsletter (Duolingo streaks PM).
- Habitica: habitica.com/static/features + `HabitRPG/habitica` (AGPL) — loop,
  XP/Gold/Gems, Dailies, Perfect Day, quests.

Key evidence we lean on:
- Separating **streak** from **daily goal** → +3.3% D14 retention.
- **Streak Freeze** ("slack") → +0.38% DAU; reduced churn ~21% for at-risk users.
- **Milestone celebrations** with real rewards → +1.7% D7 for new users.
- **Behavior-triggered** notifications, two slots (routine/save), **cap 2/day**.

---

## 1. The Cal Matters core loop

```
  ACTION            REWARD                     PROGRESS                RETURN TRIGGER
  log a meal   →   +XP, +Coins, streak day  →  level, quests, league  →  notification engine
  drink water      (+gems at milestones)         bar, badges, avatar      (habit-window / save)
  weigh in                                                                      │
  scan / fast                                                                   ▼
        ▲──────────────────────── next session ◀───────────────────────────────┘
```

The loop is **logging-consistency first**. Calories are *information*, not the
score. The score is showing up.

---

## 2. Systems

### 2.1 XP & Levels
**XP** is the universal currency of engagement (Duolingo's lesson → XP; Habitica's
task → XP). Earned per action, capped daily to prevent farming.

| Action | XP | Daily cap |
|---|---|---|
| Log a meal (manual / quick-pick / barcode) | 10 | first 3 → 10, then 5 |
| AI photo scan (our signature) | +15 | 5 scans |
| Log water (per glass) | 2 | 8 |
| Weigh-in | 20 | 1 |
| Log exercise | 15 | 3 |
| Hit step goal | 20 | 1 |
| Complete a fast | 25 | 1 |
| Chat with Asha | 5 | 1 |
| Read weekly summary | 5 | 1 |
| **Hit daily calorie target ("goal day")** | **30** | 1 |

- **Level curve:** `xpToNext(n) = round(50 * n^1.35)` (tunable). Level is derived
  from lifetime XP; never resets.
- **Level-up moment:** full-screen celebration, haptic, new title, and a reward
  (coins + occasionally a gem/freeze).
- **XP boosts:** 2× XP for 15 min (shop item, earned not bought).

### 2.2 Streak system (the daily habit)
- **Streak = log at least ONE thing today** (a meal; water alone does not count —
  a meal is the "one lesson"). *Daily calorie goal is separate* — this is the
  single highest-leverage Duolingo learning.
- Displayed prominently (flame) on Home, Progress, widget, and share cards.
- **Streak Freeze:** silently protects one missed day. Capacity **2** to start
  (→5 via milestones). **Auto-applied with no dialog** — a user who misses a day
  is, by definition, not in the app to confirm anything.
- **Streak Repair:** if the streak broke and was **≥ 7 days**, offer repair for
  Gems within **48 h** (Duolingo's 2026 pattern: repair by completing 3 logs).
- **Weekend Amulet** (optional later): equip to protect Fri–Sun.
- **Milestones & Streak Society tiers:** 3, 7, 14, 30, 50, 100, 365+.
  Each milestone opens a **chest** with *real* value (freeze refill, coins/gems,
  badge, app-icon, share card) — not symbolic confetti.
- **At-risk state:** derived from the user's learned logging window; drives the
  "save" notification (§3).

### 2.3 Currency & Reward Shop
- **Coins** (soft): earned from logging/quests; buy custom rewards & cosmetics.
- **Gems** (premium-ish but **earned, not sold** at launch): from quests,
  milestones, league promotions. Spend on:
  - Streak Freeze — 200 · Streak Repair — 200 · XP Boost (2× 15 min) — 50
  - League Demotion Protection — 200 · Cosmetics (avatar frames, app icons) — 100–500
- **No real-money purchase** in v1 (Play Billing is a later, separate decision).
- Shop is *aspirational but honest*: no fake countdowns, no artificial scarcity.

### 2.4 Daily & Weekly Quests
- **3 Daily Quests** drawn from a rotating pool, tuned to real behavior:
  - "Log 2 meals", "Drink 6 glasses", "Hit your protein target", "Scan a meal",
  - "Log breakfast", "Stay under goal", "Complete a fast", "Walk 5,000 steps".
- Completing all 3 → **reward chest** (coins + XP; gems occasionally). Daily
  quests are the **primary Gem source** (per Duolingo).
- **Weekly Quest:** one larger goal (e.g., "Log 5 days") with a bigger chest.
- Variety matters: never the same 3 two days running; adapt to user goals
  (veg/non-veg, fasting on/off, gain/lose/maintain).

### 2.5 Leagues & Friends
- **Weekly league:** ~30 users grouped by XP earned that week. Tiers
  **Bronze → Silver → Gold → Sapphire → Ruby → Emerald → Amethyst → Pearl →
  Obsidian → Diamond**. Top X% promote, bottom Y% demote; **promotion % shrinks
  as you climb** (fast early wins, scarce late) and **no double-promotion**.
- **We rank XP / logging consistency — never calories or weight.**
- Resets weekly (Sunday evening, local tz) with a countdown.
- **Friends:** replace today's kcal leaderboard with a **consistency
  leaderboard** (days logged / XP). **Friend Streaks** (up to 5): you and a
  friend each log daily to keep a shared streak; a "nudge" button pushes *from
  you*, not the brand.
- Opt-in; private profiles are excluded (and get a solo experience).

### 2.6 Achievements & Badges (upgrade of existing 12)
- Keep `AchievementsService`; add **rarity** (common/rare/epic/legendary),
  **celebration on unlock**, and **share cards**.
- Categories: streaks, meals, water, steps, weight, fasting, scans, quests,
  leagues, friends, "comeback" (returned after a break).

### 2.7 Celebrations & "juice"
- Count-ups, ring fills, flame tick-up, confetti at milestones, haptic on log.
- **Share cards** at milestones/streak/level (Instagram/Twitter aspect ratios) —
  Duolingo's single biggest organic-growth lever.
- Respect reduced-motion settings.

### 2.8 Home widget
- Android widget (already scoped via `home_widget`): show **streak + today's
  XP/goal ring + "log now" deep link**. This is the "watch face" that keeps the
  streak present without a notification.

---

## 3. Notification engine (behavior-triggered)

Replace the current fixed-clock schedule with a **behavioral engine**.

**Two slots, hard cap 2/day:**
- **Routine** (gentle, on-cadence): fires around the user's **learned logging
  window** (e.g., logged at 6pm yesterday → nudge ~5:30pm today). Asha's voice.
- **Save** (urgent, last-chance): **streak-at-risk** near the user's day-end or
  ~21:45 — "Your 84-day streak ends soon." Reserved for genuine risk.

**Triggers (all behavioral; no scheduled broadcasts):**
- habit-window routine nudge · streak-at-risk save · meal-time gaps (only if the
  user usually logs that meal and hasn't) · league ending / overtaken ·
  friend-quest progress · milestone congrats · comeback (D1/D3/D7 win-back with a
  small welcome-back reward) · weekly summary ready · water gaps.

**Engine rules**
- Learn each user's log times; schedule relative to *their* behavior, not a
  global clock.
- **Frequency cap 2/day**, quiet hours (22:00–07:00), and never >1 "save"/day.
- Copy testing is cheap and huge (Duolingo: "continue" → "commit to my goal"):
  maintain variant sets, measure CTR, rotate the winner.
- **Persona:** notifications come from **Asha** (our assistant) — voice/tone
  consistent with the in-app concierge.
- **Settings screen:** per-category toggles, custom time, pause, and a one-tap
  "fewer notifications". Respect opt-out permanently.
- **Deep links:** every notification opens the exact action (scan, water, quest,
  streak).
- **Anti-shame:** encouraging, never "you failed"; no manipulative/confirm-shaming.

---

## 4. Event taxonomy & instrumentation

Every action emits one event into `GamificationService.onEvent()`:

`meal_logged`, `scan_used`, `water_logged`, `weigh_in`, `exercise_logged`,
`steps_goal_hit`, `fast_completed`, `asha_chat`, `goal_day_hit`,
`quest_progress`, `quest_completed`, `level_up`, `streak_extended`,
`streak_broken`, `streak_frozen`, `streak_repaired`, `milestone_hit`,
`league_joined`, `league_promoted`, `notif_scheduled`, `notif_opened`.

The engine fans each event out to: XP/level, streak, quests, currency,
achievements, and the notification scheduler. **One event in → all systems
updated.** Analytics mirror the same events.

---

## 5. Data model & code map (Flutter + Firebase)

**State (local + Firestore `users/{uid}/gamification/state`):**
```
xp, level, coins, gems,
streakCount, lastLogDate, freezes, streakSocietyTier,
dailyGoalDate, dailyProgress, logTimesHistogram,
quests: { date, items[], completed }, league: { tier, cohortId, weekXp },
achievementsUnlocked: { id: iso }, notif: { lastSentAt, slotsToday, prefs }
```

**New code (all ours):**
- `lib/services/gamification/gamification_service.dart` — facade + `onEvent`.
- `lib/services/gamification/streak_service.dart`
- `lib/services/gamification/quest_service.dart`
- `lib/services/gamification/league_service.dart`
- `lib/services/gamification/shop_service.dart`
- `lib/services/gamification/gamification_events.dart`
- `lib/services/notification_engine.dart` (replaces/augments `notification_service.dart`)
- `lib/models/gamification/*.dart`
- `lib/screens/gamification/` — `league_screen`, `quests_screen`, `shop_screen`,
  `level_up_screen`, `streak_celebration`, `streak_repair_sheet`, `notif_settings`
- `lib/widgets/gamification/` — `xp_bar`, `level_badge`, `streak_flame`,
  `quest_card`, `league_row`, `reward_chest`, `share_card`
- **Storage:** extend `StorageService` (local) + a `gamification` Firestore
  subcollection; leagues in `leagues/{tier}/weeks/{isoWeek}/cohorts/{id}`.

**Touchpoints (existing code, additive only):** where a meal/scan/water/weight/
exercise/fast is logged today, fire the matching event. No changes to the locked
calculation logic.

---

## 6. Health & ethics guardrails (non-negotiable)

- Never rank or compare **calories, weight, or body metrics** between users.
- Never reward **undereating, skipped meals, or excessive exercise**.
- Streaks reward **showing up**, not restriction.
- Forgiving by default (freezes auto-apply); a return is celebrated, not punished.
- No "you failed"/shame copy; no manipulative or confirm-shaming patterns.
- No medical/nutrition-therapy claims (Play "Health & Fitness" safe path).
- Easy, honored opt-out of every notification category.

---

## 7. Phased rollout (one at a time, end-to-end)

| Phase | Deliverable | Acceptance |
|---|---|---|
| **G0 Data layer** | `GamificationService` + events wired to existing logging; persisted XP/streak/coins | Logging a meal updates XP + streak; unit tests; analyze clean |
| **G1 XP & levels** | XP display on Home + level-up celebration | Level-up fires once; no double XP per action |
| **G2 Streaks** | Daily streak, auto-freeze, repair, milestones, celebration, at-risk computation | Freeze protects a missed day; repair window works |
| **G3 Quests & shop** | 3 daily + weekly quests, reward chest, coins/gems, shop | Quest completion pays out once; shop spends correctly |
| **G4 Leagues & friends** | Weekly XP leagues, promotion/demotion, friend streaks (consistency board) | Cohort assignment + weekly reset correct |
| **G5 Notifications** | Behavioral engine, 2/day cap, settings, deep links, widget | Triggers fire on behavior; cap + quiet hours hold |
| **G6 Polish** | Share cards, celebrations, animations, dark mode, accessibility | Visual QA on device; reduced-motion respected |

Each phase: `flutter analyze` + `flutter test` green, then **you** QA on device.

---

## 8. How we prove it works (metrics)

- **Retention:** D1 / D7 / D30 (first 7 days are most fragile — Duolingo).
- **% of DAU with a ≥7-day streak** (target: ≥50%, Duolingo's benchmark).
- **Logs/user/day**, sessions/day, quest completion rate.
- Notification **opt-in rate, CTR, and 24h uninstall rate** (guardrail).
- **Comeback rate** for D3/D7 win-backs.
- Guardrail: **no increase** in streak-break → uninstall.

---

## 9. Open questions for you

1. Currency naming — keep **Coins/Gems**, or Indian-flavored names?
2. Leagues **opt-in** (solo default) vs on by default?
3. Should notifications be voiced by **Asha** (our assistant) as the persona?
4. XP values/goal-day bonus — happy with the table, or tune for Cal Matters?
5. Any monetization intent for Gems now, or keep them earned-only?
6. Hindi/regional copy at launch, or English first?

Once you answer (or say "use your judgment"), I'll have Asha implement **G0**
first and we go down the list.
