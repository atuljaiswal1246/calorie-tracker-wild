# Cal Matters — Duolingo-Level Gamification & Notification System

**Design Document v1.0**
**Author:** Asha (AI Agent)
**Date:** September 2026
**Status:** Design only — no code changes

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Research Foundation](#2-research-foundation)
3. [Design Principles & Health Ethics Guardrails](#3-design-principles--health-ethics-guardrails)
4. [Gamification System Architecture](#4-gamification-system-architecture)
   - 4.1 Cal Points (XP Equivalent)
   - 4.2 Levels & Progression
   - 4.3 Streaks
   - 4.4 Currency & Shop
   - 4.5 Daily Quests
   - 4.6 Leagues (Social Competitive Layer)
   - 4.7 Achievements & Badges
   - 4.8 Celebrations & Micro-Rewards
5. [Notification Engine](#5-notification-engine)
   - 5.1 User State Model
   - 5.2 Message Catalogue
   - 5.3 Timing Intelligence
   - 5.4 Cadence & Fatigue Guardrails
   - 5.5 Technical Architecture
6. [Action-to-Reward Mapping](#6-action-to-reward-mapping)
7. [Data Model](#7-data-model)
8. [Flutter Code Architecture](#8-flutter-code-architecture)
9. [Phased Rollout Plan](#9-phased-rollout-plan)
10. [Open-Source References & Licenses](#10-open-source-references--licenses)
11. [Metrics & Success Criteria](#11-metrics--success-criteria)
12. [Assumptions & Risks](#12-assumptions--risks)

---

## 1. Executive Summary

Cal Matters today has **basic gamification**: 10 hard-coded achievements in `achievements_service.dart`, a static weekly challenges screen, and a simple Firestore-based leaderboard via `social_service.dart`. Notifications are fixed daily time-slot reminders (water + meal nudges) with zero personalization.

This document designs a **Duolingo-grade engagement system** that makes Cal Matters the most habit-forming calorie tracker in India. The design is adapted from Duolingo's proven mechanics (streaks, XP, leagues, quests, push intelligence) but **re-mapped onto health actions** — not language learning — with strict ethical guardrails appropriate for a health app.

**Key design decisions:**

| Decision | Rationale |
|----------|-----------|
| Cal Points instead of XP | "Cal" = calorie, ties branding to the mechanic |
| Streak freezes, not streak repair | Health apps should encourage rest days as valid, not guilt-trip |
| Leagues measure consistency, not calorie restriction | Never reward eating less — only reward the *habit* of tracking |
| No "lose weight to earn" mechanics | Gamifying weight loss triggers disordered eating |
| Notification engine uses state-based messaging | Copy Duolingo's proven approach: tone adapts to user engagement state |
| Behavior-based notifications, not time-based | Replaces fixed-schedule reminders with context-aware nudges |

---

## 2. Research Foundation

### 2.1 Duolingo Mechanics Studied

| Mechanic | How Duolingo Uses It | Cal Matters Adaptation |
|----------|---------------------|----------------------|
| **Streak** | Daily lesson = streak day. 32M users have 7+ day streak. Streak Freeze for forgiveness. Streak milestones at 7/30/100/365. | Daily meal log = streak day. Streak Freeze (purchasable). Milestones at 7/30/100/365. Rest days count if water + weight logged. |
| **XP (Experience Points)** | Earned per lesson. Bonus XP for speed, perfect score, new words. XP is the universal score. | Cal Points earned per health action. Bonus for AI photo scans, hitting water goal, logging all 3 meals. |
| **Levels** | XP accumulation → level up. Profile badge shows level. No gameplay impact — pure status. | Same: Cal Level from accumulated Cal Points. Pure prestige + unlocks. |
| **Leagues** | 30-person weekly leaderboard. 10 tiers (Bronze→Diamond). Top N% promote, bottom N% demote. Drives +25% lesson completion. | 30-person weekly league. 10 tiers (Seedling→Evergreen). Ranked by Cal Points earned that week. Promotion/demotion. |
| **Gems (Currency)** | Earned from chests, league podium, quests. Spent in shop for streak freezes, outfit items, bonus XP. | "NutriCoins" earned from quests, league placement, streaks. Spent in shop for streak freezes, profile cosmetics, meal plan unlocks. |
| **Daily Quests** | 3 quests per day, refresh daily. Earn XP + gems. Monthly challenge accumulates quest completions. | 3 quests per day. Example: "Log a photo scan", "Hit your water goal", "Stay within 200 kcal of target". |
| **Notifications** | AI-selected from pool based on user state (streak length, last activity, time of day). Sleeping Bandit algorithm. State-aware tone (playful/supportive/gentle). | Same architecture: state-based push with behaviour detection, adaptive tone, fatigue guardrails. |

### 2.2 Duolingo's Notification AI (Published Research)

Duolingo published a **Sleeping, Recovering Bandit Algorithm** (KDD 2020, Yancey & Settles) for notification optimization:

- Pool of ~200 pre-written notification templates
- Personalized by: user language, streak length, last activity time, notification history
- Bandit algorithm learns which templates drive lesson completion per user
- "Sleeping" variant handles users who disappear (novelty effects decay)
- "Recovering" variant resets exploration when templates change

Cal Matters will use a **simplified version**: rule-based state detection + template pool + Firebase Analytics for CTR tracking. Full bandit ML can be added in Phase 3.

### 2.3 Open-Source References

| Project | License | What We Learn |
|---------|---------|--------------|
| **FitQuest** (`NickiMash17/fitquest-app`) | MIT | Flutter + Firebase gamified wellness app with plant companion, XP, streaks. Direct architectural reference. |
| **Momentum** (`vawcom-technologies/momentum`) | MIT | Flutter RPG-style life tracker with XP, daily quests, leveling. Quest system design reference. |
| **Valence** (`deepan-alve/valence`) | MIT | Group-first habit tracker with friend streaks, leaderboards, nudges. Social accountability mechanics. |
| **WellNudge** (`ShazzedShajal/WellNudge`) | MIT | Ambient health companion. Minimal nudge-based approach to contrast against heavy gamification. |

**Note:** We study these for *architectural patterns and mechanics*, not for code. Cal Matters has its own design language (see `UI_GUIDELINES.md`) and codebase.

### 2.4 Health Gamification Ethics (Academic)

From Arora & Razavian (2021), "Ethics of Gamification in Health and Fitness-Tracking" (MDPI, IJERPH):

- **Risk of normalizing disordered eating** when gamification rewards calorie restriction
- **Risk of shame spirals** when streaks/achievements tie to body metrics
- **Autonomy erosion** when notifications become compulsive rather than supportive
- **Inequity** when gamification assumes able-bodied, neurotypical engagement patterns

These inform our guardrails in Section 3.

---

## 3. Design Principles & Health Ethics Guardrails

### 3.1 Core Principles

1. **Gamify the behaviour, not the outcome.** Reward *logging meals*, *drinking water*, *tracking weight* — never reward *losing weight* or *eating less*.
2. **Streaks should feel forgiving.** A health app must accommodate rest days, illness, travel. Rest is not failure.
3. **No calorie-restriction rewards.** Never award points/bonuses for staying under a calorie limit. The app tracks nutrition; it does not police it.
4. **Celebrations are about consistency.** "You logged 7 days in a row!" not "You lost 2 kg!"
5. **Notifications are helpful, not nagging.** Every notification must pass the "would a good friend send this?" test.
6. **Accessibility first.** All gamification must work with screen readers, colour-blind palettes, and reduced-motion settings.

### 3.2 Hard Guardrails (Non-Negotiable)

| Guardrail | Implementation |
|-----------|---------------|
| **No points for calorie deficit** | Cal Points are earned for *logging*, not for *what* is logged. Logging a 2000 kcal day earns the same as a 1200 kcal day. |
| **No weight-loss leaderboards** | Leagues rank by Cal Points (engagement), never by weight change. Weight is private. |
| **No "under-eating" bonuses** | If a user logs significantly under BMR, the app shows a health note, not a reward. |
| **No body-shaming language** | All notification templates and achievement copy reviewed for fatphobic/diet-culture language. |
| **Rest-day legitimacy** | Streak Freeze is freely available (earnable via quests). Water + weight logging counts as a "light streak day". |
| **Notification opt-out is easy** | One-tap to reduce notification frequency. Two-tap to disable all. No guilt-tripping copy on the opt-out screen. |
| **Age-appropriate mode** | For users under 18, leagues are opt-in, calorie numbers are hidden behind "on track / needs attention" indicators. |
| **Eating-disorder sensitivity** | If the app detects patterns suggesting disordered eating (severely low intake, obsessive logging at 3am), it surfaces a compassionate message and suggests professional resources. |

---

## 4. Gamification System Architecture

### 4.1 Cal Points (XP Equivalent)

Cal Points are the universal engagement currency. They are earned for **health actions** — the things we want users to do daily.

| Action | Cal Points | Cooldown / Limit | Notes |
|--------|-----------|-----------------|-------|
| Log a meal (any method) | 10 pts | 3 meals/day max earn points | Prevents spam-logging |
| AI Photo Scan meal | 15 pts | 3/day | Higher reward for our core feature |
| Log water (hit daily goal) | 10 pts | 1/day | Earned at goal, not per glass |
| Log weight | 5 pts | 1/day | Encourages consistent tracking |
| Log exercise | 10 pts | 1/day | Any exercise type |
| Complete a daily quest | 15 pts | 3 quests/day | See Quests section |
| Complete all 3 daily quests | 25 pts bonus | 1/day | Completionist bonus |
| Full streak day (any action) | 5 pts | 1/day | Streak maintenance bonus |
| Weekly league podium (top 3) | 50/30/20 pts | 1/week | League rewards |
| Asha chat interaction | 5 pts | 2/day max | Encourage AI coach use |
| Log a fasting window | 5 pts | 1/day | If fasting feature enabled |

**Daily earning cap:** 200 Cal Points (prevents unhealthy obsessive logging patterns).

**Anti-exploit:** Meal logging deduplication (same photo hash → no double points). Rapid successive logs within 60 seconds → cooldown.

### 4.2 Levels & Progression

Levels are **prestige only** — they don't gate features or affect gameplay. They give users a sense of long-term progression.

| Level | Cal Points Required | Title | Unlock |
|-------|-------------------|-------|--------|
| 1 | 0 | Sprout 🌱 | Default |
| 2 | 100 | Seedling 🌿 | — |
| 3 | 300 | Grower 🌾 | — |
| 4 | 600 | Green Thumb 🪴 | Profile frame |
| 5 | 1,000 | Bloomer 🌸 | — |
| 6 | 1,500 | Harvester 🌻 | — |
| 7 | 2,200 | Cultivator 🧑‍🌾 | — |
| 8 | 3,200 | Garden Master 🏡 | Profile frame |
| 9 | 4,500 | Green Guardian 🌳 | — |
| 10 | 6,000 | Nutrition Sage 🧘 | Special badge |
| 11–20 | 6K → 20K (escalating) | Elite tiers | Progressive frames |
| 21+ | 20K+ | Legends (infinite) | Seasonal frames |

**Level-up animation:** Full-screen plant-grow animation (matching our Seed→Sage nature theme). Haptic burst. Congratulatory Asha message.

**Level-down:** Never. Levels are cumulative and permanent.

### 4.3 Streaks

The streak is the **single most important retention mechanic** (Duolingo credits it as their #1 lever). Ours is adapted for health:

#### Core Streak
- **What counts:** At least one qualifying action per day: log a meal, log water, log weight, or log exercise.
- **Why multiple actions:** Health apps must accommodate days where users don't eat at home (travel, social meals). Requiring meal logging alone would break streaks unfairly.

#### Streak Freeze
- Users start with **1 Streak Freeze** (banked).
- Earn additional freezes: every 7-day streak milestone awards 1 freeze. League podium awards 1 freeze. Quest completion occasionally drops a freeze (random reward).
- Freeze is **consumed automatically** when a day is missed.
- **Max bank:** 3 freezes. This is generous but not infinite — streaks should still feel meaningful.

#### Streak Milestones (Celebration Moments)

| Milestone | Celebration | Reward |
|-----------|------------|--------|
| 7 days | 🎉 Full-screen fire animation + "Week Warrior!" | 25 Cal Points + 50 NutriCoins |
| 14 days | 🔥 Phoenix animation + "Fortnight Champion!" | 50 Cal Points + 75 NutriCoins |
| 30 days | 👑 Crown animation + "Monthly Master!" | 100 Cal Points + 150 NutriCoins + badge |
| 50 days | ⚡ Lightning animation + "Unstoppable!" | 150 Cal Points + 200 NutriCoins |
| 100 days | 💎 Diamond animation + "Century Legend!" | 300 Cal Points + 500 NutriCoins + exclusive badge |
| 365 days | 🏆 Full-screen celebration + "Year of Growth!" | 1000 Cal Points + 2000 NutriCoins + legendary badge |

#### Friend Streaks
- When two friends both log on the same day, a shared streak counter increments.
- Displayed on the friend list and in notifications ("Your streak with Priya is at 12 days! 🔥").
- **Limit:** Max 5 active friend streaks (prevents social overload).

#### Rest-Day Policy
- Logging water + weight counts as a "light streak day" — streak continues, but no Cal Points for meal logging (because no meals were logged).
- This is deliberate: users who are sick, fasting, or traveling can maintain their streak with minimal effort.

### 4.4 Currency & Shop

#### NutriCoins (Premium Currency)

NutriCoins are the spendable currency. They are earned more slowly than Cal Points and spent in the Shop.

**Earning NutriCoins:**

| Source | Amount |
|--------|--------|
| Daily login (first open of the day) | 5 |
| Complete daily quests (per quest) | 10 |
| Complete all 3 daily quests (bonus) | 20 |
| League podium (1st/2nd/3rd) | 100/60/30 |
| Streak milestones (see above) | Varies |
| Weekly challenge completion | 25 |
| Random quest reward (10% chance) | 5–15 |

**Shop Items:**

| Item | Cost | Type |
|------|------|------|
| Streak Freeze | 100 NutriCoins | Consumable |
| Profile Frame — Bronze | 200 | Cosmetic |
| Profile Frame — Silver | 400 | Cosmetic |
| Profile Frame — Gold | 800 | Cosmetic |
| Profile Frame — Seasonal (rotating) | 500 | Cosmetic (limited) |
| "Double Points" boost (1 day) | 150 | Consumable |
| Custom App Theme — Midnight | 300 | Cosmetic |
| Custom App Theme — Forest | 300 | Cosmetic |
| Asha Personality — Encouraging | 0 (default) | Chat style |
| Asha Personality — Coach | 200 | Chat style |
| Asha Personality — Friend | 200 | Chat style |
| Meal Plan Unlock (1 week premium plan) | 500 | Feature access |
| Custom Macro Targets (1 month) | 300 | Feature access |
| Badge Showcase Slot (extra) | 250 | Cosmetic |

**Economy balance target:** Average user earns ~150 NutriCoins/week. A Streak Freeze costs ~1 week of saving. Cosmetics are aspirational (3–5 weeks of saving).

### 4.5 Daily Quests

Each day, the user is presented with **3 quests** that refresh at midnight local time.

**Quest Pool (randomly selected based on user history):**

| Quest Template | Category | Cal Points |
|----------------|----------|-----------|
| Log a meal using AI Photo Scan | Core Feature | 15 |
| Log all 3 meals today (breakfast, lunch, dinner) | Consistency | 15 |
| Hit your daily water goal | Hydration | 10 |
| Log your morning weight | Tracking | 5 |
| Stay within 200 kcal of your daily target | Mindfulness | 15 |
| Try a new food (first-time scan) | Exploration | 15 |
| Chat with Asha about your nutrition | AI Coach | 5 |
| Log 30 minutes of exercise | Activity | 10 |
| Log a meal within 30 minutes of eating | Timeliness | 10 |
| Hit your protein target today | Nutrition Quality | 15 |
| Complete a fasting window of 12+ hours | Fasting | 5 |
| Scan a home-cooked meal (AI detects) | Indian Focus | 15 |

**Quest Selection Algorithm:**
1. Exclude quests the user completed yesterday (variety).
2. Weight quests toward the user's weakest engagement area (if they haven't scanned photos in 3 days, prioritize a scan quest).
3. Always include at least one "easy" quest (>80% completion probability based on history).
4. Never include more than one nutrition-quality quest (to avoid calorie-obsessive patterns).

#### Monthly Challenge
- Each completed daily quest contributes 1 Quest Point toward a monthly challenge.
- Monthly challenge has 3 tiers: Bronze (15 points), Silver (25 points), Gold (35 points).
- Rewards: Large NutriCoin bonuses + exclusive monthly badge.

### 4.6 Leagues (Social Competitive Layer)

Directly adapted from Duolingo's proven 10-tier weekly league system.

#### Structure

| Tier | Name | # Users | Promote | Demote | Theme |
|------|------|---------|---------|--------|-------|
| 1 | Seedling 🌱 | 30 | Top 20 (67%) | Bottom 5 | Beginner |
| 2 | Sprout 🌿 | 30 | Top 15 (50%) | Bottom 5 | Growing |
| 3 | Sapling 🌳 | 30 | Top 10 (33%) | Bottom 5 | Building |
| 4 | Canopy 🍃 | 30 | Top 7 (23%) | Bottom 3 | Established |
| 5 | Blossom 🌸 | 30 | Top 7 (23%) | Bottom 3 | Blooming |
| 6 | Harvest 🌾 | 30 | Top 5 (17%) | Bottom 3 | Producing |
| 7 | Evergreen 🌲 | 30 | Top 5 (17%) | Bottom 2 | Sustaining |
| 8 | Ancient 🌳 | 30 | Top 3 (10%) | Bottom 2 | Enduring |
| 9 | Sacred Grove 🕊️ | 30 | Top 2 (7%) | Bottom 1 | Elite |
| 10 | World Tree 🌍 | 30 | Top 1 (3%) | None | Legendary |

#### How Leagues Score Cal Points

Leagues rank users by **Cal Points earned during the Mon–Sun week**. This measures *engagement consistency*, not calorie restriction.

**Key design choices:**
- **30 users per league:** Small enough that top-5 feels achievable for anyone who shows up.
- **Skill-based matchmaking:** New users (Levels 1–3) are grouped together. Higher levels face stiffer competition. This prevents new users from being crushed.
- **Weekly reset:** Every Monday at 00:00 local time, leagues reassign. Top finishers promote, bottom finishers demote.
- **Sunday night deadline:** The league ends Sunday at midnight. This leverages the same "last chance" psychology Duolingo uses to combat weekend drop-off.

#### League Rewards

| Finish Position | NutriCoins | Cal Points | Bonus |
|----------------|-----------|-----------|-------|
| 1st place | 100 | 50 | "League Champion" badge for the week |
| 2nd place | 60 | 30 | — |
| 3rd place | 30 | 20 | — |
| Promotion (any) | — | — | Tier-up animation |
| Demotion | — | — | "You'll bounce back!" encouragement (no shame) |

#### Social Features Within Leagues

- **League chat:** Optional, 280-char messages. Pre-moderated for toxicity.
- **Reaction emojis:** 👏🔥💪 on league members' profile pics.
- **Friend within league:** Highlighted at the top of the leaderboard with a special border.

### 4.7 Achievements & Badges

Replaces the current 10 hard-coded achievements in `achievements_service.dart` with a **dynamic achievement system**.

#### Achievement Categories

| Category | Example Achievements | Count |
|----------|---------------------|-------|
| **Streaks** | 3-day, 7-day, 14-day, 30-day, 50-day, 100-day, 365-day | 7 |
| **Meal Logging** | First meal, 10 meals, 50, 100, 500, 1000 | 6 |
| **AI Explorer** | First scan, 10 scans, scan 10 different cuisines, scan a home-cooked meal | 6 |
| **Hydration** | Hit water goal 1 day, 7 days, 30 days, 100 days | 4 |
| **Weight Tracking** | Log weight 7 days, 30 days, 90 days, record first change | 4 |
| **Activity** | Log exercise first time, 10 times, 50 times, every day for a week | 4 |
| **Social** | Add first friend, join a league, win a league, 5 friend streaks | 4 |
| **Nutrition** | Hit protein goal 5 days, try 20 unique foods, log a balanced macro day | 4 |
| **Asha** | First chat, 10 chats, ask about macros, get a weekly summary | 4 |
| **Milestones** | Reach Level 5, Level 10, Level 20, earn 1000 NutriCoins | 4 |
| **Seasonal** | Monthly rotating achievements (e.g., "Monsoon Warrior" for July logging) | 4/season |
| **Secret** | Hidden achievements revealed on unlock (e.g., "Night Owl" for 3am logging) | 5 |

**Total: ~56 achievements** (expandable with seasons).

#### Badge Display
- User can showcase **5 badges** on their profile.
- Badge cases are unlockable via NutriCoins shop.
- Friends see showcased badges on the leaderboard.

### 4.8 Celebrations & Micro-Rewards

Every positive action gets a small visual reward. This is critical for the dopamine loop.

| Trigger | Micro-Celebration |
|---------|-------------------|
| Log a meal | Checkmark animation + "+10 Cal Points" toast + subtle haptic |
| Complete a quest | Quest card flips to reveal reward + confetti burst |
| Level up | Full-screen plant-grow animation + haptic burst |
| Streak day | Flame icon pulses + streak counter increments |
| Hit water goal | Water splash animation + droplet particles |
| Win a league | Trophy animation + "Champion!" overlay |
| Unlock a badge | Badge card reveal with shimmer effect |
| Daily login | Greeting card with today's quest preview |

**Design constraint:** All celebrations use the existing `UI_GUIDELINES.md` theme (black + white, Inter font, subtle motion). No garish game-ui. Celebrations should feel **premium and calm**, not slot-machine.

---

## 5. Notification Engine

### 5.1 User State Model

Every user is classified into one of 4 states. The state determines notification frequency, tone, and content.

| State | Definition | Notification Cadence | Tone |
|-------|-----------|---------------------|------|
| **Active** | Logged an action today, streak intact | 0–1/day (only quest reminders) | Playful, reinforcing |
| **Wobbling** | Missed 1 day, streak at risk | 2/day max (primary + backup) | Supportive, low-pressure |
| **At-Risk** | Missed 2–3 days | 1/day max | Empathetic, gentle |
| **Dormant** | No action for 7+ days | 1–2/week max | Value-reminding, zero guilt |

**State transitions:**
- Active → Wobbling: 24h since last action
- Wobbling → At-Risk: 48h since last action
- At-Risk → Dormant: 168h (7 days) since last action
- Any → Active: User performs any qualifying action
- Active → Dormant: 7+ days missed (skip Wobbling/At-Risk for users who uninstall-reinstall)

### 5.2 Message Catalogue

Each state has a pool of notification templates. The engine selects based on: (a) user state, (b) time of day, (c) notification history (avoid repeats within 48h), (d) streak length.

#### Active State Messages

| Template | Trigger | Time |
|----------|---------|------|
| "Your streak is at {streak} days! One scan keeps it alive 🔥" | Before streak risk window | User's typical session time |
| "You've earned {points} Cal Points today. Keep going! 💪" | After completing an action | +30min delay |
| "Your league ends tomorrow — you're in #{position}. Can you clinch top 3?" | Saturday evening | 18:00–20:00 |
| "Quest update: {quest_name} is still waiting. Quick and easy! 📋" | Incomplete quests, evening | 19:00–20:00 |
| "You and {friend} are on a {streak}-day streak together! Don't let {friend} down 🔥" | Friend streak at risk | 17:00–19:00 |

#### Wobbling State Messages

| Template | Trigger | Time |
|----------|---------|------|
| "Missed yesterday? No worries — one quick log gets you back on track today ✨" | Morning | 08:00–10:00 |
| "Your streak can still be saved! Log any meal or water before midnight 🌙" | Afternoon | 15:00–17:00 |
| "Hey {name}, just a gentle nudge — your {streak}-day streak is waiting for you 💚" | Evening | 19:00–20:00 |

#### At-Risk State Messages

| Template | Trigger | Time |
|----------|---------|------|
| "It's been a few days. Even logging water counts — every bit helps 💧" | Morning | 09:00–11:00 |
| "No pressure, but we miss you! Open Cal Matters when you're ready 🌱" | Every 2 days | 10:00–12:00 |

#### Dormant State Messages

| Template | Trigger | Time |
|----------|---------|------|
| "It's been a while! Your Cal Points and streaks are waiting 🌿" | Once per week | User's historical peak hour |
| "New this week: {feature/quest update}. Come check it out!" | When new content ships | Mid-week |
| "{name}'s weekly summary is ready! See your nutrition insights 📊" | Weekly summary day | User's preferred time |

### 5.3 Timing Intelligence

Duolingo's research shows that **personalized send times** outperform fixed schedules by 30–40% on open rates.

#### Time Optimization

1. **Record user's active hours:** Every app open, log the timestamp. After 7 days, compute the user's modal session hour.
2. **Primary notification:** Send 30–60 minutes *before* the user's typical session time (catch them before they naturally open the app).
3. **Backup notification (Wobbling state only):** Send 90–120 minutes before end-of-day cutoff (23:00 local).
4. **Never send between 22:00–07:00** unless the user has explicitly opted into late-night reminders.
5. **Weekend adjustment:** If the user's Saturday/Sunday pattern differs from weekdays, track separately.

#### Contextual Triggers

| Trigger | Notification |
|---------|-------------|
| User opens app but doesn't log anything | "Ready to log? I'll make it quick 📸" (after 30 seconds of idle) |
| User takes a photo but doesn't confirm | "Your scan is ready — tap to see the breakdown 👀" (after 5 minutes) |
| It's meal time + no log today | "Lunch time! Got something delicious? Scan it 🍛" |
| Water goal 50%+ missed by evening | "Still {glasses} glasses to go — you've got this 💧" |
| Weekly summary generated | "Your week in review is ready! See how you did 📊" |

### 5.4 Cadence & Fatigue Guardrails

These prevent notification fatigue — the #1 killer of push engagement.

| Rule | Implementation |
|------|---------------|
| **Daily cap** | Max 3 push notifications per day, regardless of state |
| **Weekly cap** | Max 15 push notifications per week |
| **Ignore cooldown** | If user dismisses 3 consecutive notifications without opening, reduce to 1/day for 7 days |
| **Opt-out respect** | Disabling notifications is 2 taps, no guilt copy |
| **Silent hours** | 22:00–07:00 local, always |
| **Duplicate prevention** | No identical template within 48 hours |
| **Weekly review** | Every Monday, check: ignore rate > 40% → reduce frequency; unsubscribe rate > 5% → pause all non-essential notifications |
| **Re-engagement cap** | Dormant users get max 2 re-engagement notifications total before being left alone permanently |

### 5.5 Technical Architecture

```
┌─────────────────────────────────────────────────┐
│                 NOTIFICATION ENGINE               │
│                                                   │
│  ┌──────────────┐    ┌──────────────────────┐    │
│  │ State Engine  │───▶│  Template Selector    │    │
│  │ (daily eval)  │    │  (state + context)    │    │
│  └──────────────┘    └──────────┬───────────┘    │
│                                  │                 │
│  ┌──────────────┐    ┌──────────▼───────────┐    │
│  │ Timing Engine │───▶│  Fatigue Guardrail    │    │
│  │ (per-user     │    │  (cap + cooldown)     │    │
│  │  session log) │    └──────────┬───────────┘    │
│  └──────────────┘               │                 │
│                                  ▼                 │
│                      ┌──────────────────────┐     │
│                      │  Firebase Cloud       │     │
│                      │  Messaging (FCM)      │     │
│                      └──────────────────────┘     │
└─────────────────────────────────────────────────┘
```

**Why FCM:** Cal Matters already uses Firebase. FCM is free, reliable on Android, and supports iOS via APNs bridge. No additional service needed.

**State evaluation:** Runs as a daily background task (using `workmanager` package) + on every app open. Stores user state in Firestore user doc.

---

## 6. Action-to-Reward Mapping

This table shows the complete user action → reward chain for every tracked behaviour:

| User Action | Cal Points | NutriCoins | Streak | Quest Progress | Achievement Progress | League XP |
|-------------|-----------|-----------|--------|---------------|---------------------|----------|
| Log meal (manual) | 10 | — | ✅ | ✅ | ✅ | ✅ |
| Log meal (AI scan) | 15 | — | ✅ | ✅ | ✅ | ✅ |
| Hit water goal | 10 | — | ✅ | ✅ | ✅ | ✅ |
| Log weight | 5 | — | ✅ | — | ✅ | ✅ |
| Log exercise | 10 | — | ✅ | — | ✅ | ✅ |
| Complete daily quest | 15 | 10 | — | — | — | ✅ |
| Complete all 3 quests | 25 bonus | 20 bonus | — | — | — | ✅ |
| Daily login | — | 5 | — | — | — | — |
| First-time action | — | — | — | — | ✅ | — |
| Win league (1st) | 50 | 100 | — | — | ✅ | — |
| Promote league tier | — | — | — | — | ✅ | — |
| Streak milestone (7) | 25 | 50 | — | — | ✅ | — |
| Streak milestone (30) | 100 | 150 | — | — | ✅ | — |
| Streak milestone (100) | 300 | 500 | — | — | ✅ | — |

---

## 7. Data Model

### 7.1 Firestore Schema

```
users/{uid}/
  gamification/
    calPoints: int           // lifetime Cal Points earned
    level: int               // current level (1-21+)
    nutriCoins: int          // spendable currency balance
    streak: {
      current: int           // current streak days
      longest: int           // all-time longest streak
      lastActionDate: Timestamp
      freezeCount: int       // streak freezes in bank
      maxFreezeBank: int     // always 3
    }
    league: {
      tier: int              // 1-10 (Seedling to World Tree)
      weeklyPoints: int      // current Mon-Sun Cal Points
      leagueId: string       // assigned league group ID
      lastWeekPosition: int
      promotionHistory: [Timestamp]  // when promoted
    }
    quests: {
      date: Timestamp        // current quest date
      active: [
        {
          id: string         // quest template ID
          title: string
          target: int
          current: int
          reward: { calPoints: int, nutriCoins: int }
          completed: bool
        }
      ]
      monthlyPoints: int     // quest completions this month
      monthlyTier: string    // "bronze" | "silver" | "gold"
    }
    dailyLog: {
      date: string           // "2026-09-05"
      actions: [string]      // ["meal_manual", "meal_scan", "water", ...]
      calPointsEarned: int
      questsCompleted: int
    }
    notifications: {
      state: string          // "active" | "wobbling" | "at_risk" | "dormant"
      lastStateChange: Timestamp
      lastNotificationSent: Timestamp
      consecutiveDismisses: int
      suppressUntil: Timestamp  // fatigue cooldown
      preferredHour: int     // 0-23, learned from session data
      sessionHours: [int]    // last 20 session open hours
    }
    achievements: {
      unlocked: { [achievementId]: Timestamp }
      showcase: [string]     // 5 badge IDs shown on profile
    }
    friendStreaks: {
      [friendUid]: {
        streak: int
        lastSharedDay: Timestamp
      }
    }
    shop: {
      streakFreezes: int     // purchased (separate from earned)
      cosmetics: [string]    // owned cosmetic item IDs
      activeCosmetics: {
        profileFrame: string?
        theme: string?
        ashaPersonality: string?
      }
    }
```

### 7.2 Local Storage (SharedPreferences)

For offline-first operations and reducing Firestore reads:

| Key | Type | Purpose |
|-----|------|---------|
| `gamification_state` | JSON | Cached gamification state for instant UI |
| `daily_quests_cache` | JSON | Today's quests (avoids re-fetch) |
| `notification_hours` | List<int> | Session hours for timing optimization |
| `last_celebration` | String | Prevents duplicate celebration animations |
| `shop_inventory` | JSON | Owned items for offline shop browsing |

### 7.3 Firebase Cloud Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `evaluateUserState` | Daily cron (00:05 local) | Updates user state (active/wobbling/at_risk/dormant) |
| `assignLeagues` | Weekly cron (Monday 00:00 UTC) | Assigns users to league groups, promotes/demotes |
| `selectNotification` | FCM scheduled topic | Selects and sends personalized notifications |
| `processQuestRewards` | Firestore write to quests | Awards Cal Points + NutriCoins on quest completion |
| `antiCheatCheck` | On gamification write | Detects exploit patterns (spam logging, etc.) |

---

## 8. Flutter Code Architecture

### 8.1 New Files (to be created)

```
lib/
  models/
    gamification_state.dart      # GamificationState, Streak, League, Quest models
    quest.dart                   # Quest template + active quest model
    league.dart                  # League tier, group, standings models
    notification_state.dart      # User notification state model
    achievement_v2.dart          # Dynamic achievement model (replaces current)

  services/
    gamification_service.dart    # Core engine: points, levels, streaks, currency
    quest_service.dart           # Quest generation, tracking, rewards
    league_service.dart          # League assignment, scoring, promotion/demotion
    shop_service.dart            # NutriCoin spending, inventory management
    notification_engine.dart     # State detection, template selection, scheduling
    celebration_service.dart     # Triggers animations, haptics, confetti
    anti_cheat_service.dart      # Spam detection, duplicate prevention

  screens/
    gamification_hub_screen.dart # Main gamification dashboard (replaces challenges_screen)
    quest_screen.dart            # Daily quests display
    league_screen.dart           # League leaderboard + tier info
    shop_screen.dart             # NutriCoin shop
    achievements_v2_screen.dart  # Dynamic achievements grid

  widgets/
    cal_points_badge.dart        # Animated "+10 Cal Points" toast
    streak_flame_widget.dart     # Animated streak flame
    quest_card.dart              # Quest display card with progress
    league_card.dart             # League position card
    level_progress_widget.dart   # Level-up progress bar
    celebration_overlay.dart     # Full-screen celebration animations
```

### 8.2 Existing Files to Modify (Phase 1 only)

| File | Change |
|------|--------|
| `lib/services/storage_service.dart` | Add gamification read/write methods |
| `lib/services/notification_service.dart` | Replace fixed schedule with engine-driven |
| `lib/screens/home_screen.dart` | Add Cal Points badge, streak widget, quest preview |
| `lib/screens/achievements_screen.dart` | Migrate to dynamic achievement system |
| `lib/screens/challenges_screen.dart` | Redirect to new gamification hub |
| `lib/services/social_service.dart` | Integrate league scoring into leaderboard |
| `lib/widgets/floating_nav.dart` | Add gamification hub to navigation |

### 8.3 Dependencies to Add

| Package | Purpose |
|---------|---------|
| `confetti_widget` | Celebration animations |
| `lottie` | Level-up and milestone animations |
| `workmanager` | Background state evaluation |
| `firebase_messaging` | Push notification delivery (if not already present) |

### 8.4 Service Initialization Order

```
main.dart → StorageService → GamificationService → QuestService
         → LeagueService → NotificationEngine → CelebrationService
```

All gamification services depend on `StorageService` (consistent with existing architecture).

---

## 9. Phased Rollout Plan

### Phase 1: Core Engagement Loop (Weeks 1–3)

**Goal:** Establish the Cal Points + Streak + Daily Quests system. This is the foundation.

| Task | Effort | Impact |
|------|--------|--------|
| GamificationState model + Firestore schema | 2 days | Foundation |
| GamificationService (points, levels, streaks) | 3 days | Core engine |
| QuestService (daily quest generation) | 2 days | Daily engagement |
| CelebrationService (micro-rewards) | 2 days | Dopamine loop |
| AntiCheatService (spam detection) | 1 day | Integrity |
| Update home_screen with Cal Points + streak | 1 day | Visibility |
| GamificationHub screen (replaces challenges) | 2 days | UX |
| Quest screen | 1 day | UX |
| Migrate achievements to dynamic system | 2 days | Feature parity |

**Phase 1 Exit Criteria:** Users earn Cal Points for every action, see streaks on home screen, have 3 daily quests, and get celebration animations. `flutter analyze` clean, all existing tests pass.

### Phase 2: Social + Currency (Weeks 4–6)

**Goal:** Add leagues, shop, and friend streaks for social engagement.

| Task | Effort | Impact |
|------|--------|--------|
| NutriCoins economy + ShopService | 2 days | Currency |
| ShopScreen (items, purchase flow) | 2 days | Monetization hook |
| LeagueService (assignment, scoring, promotion) | 3 days | Social competition |
| LeagueScreen (leaderboard, tier display) | 2 days | UX |
| Friend streaks integration | 1 day | Social accountability |
| Update SocialService with league data | 1 day | Integration |
| League assignment Cloud Function | 1 day | Backend |

**Phase 2 Exit Criteria:** Leagues run weekly with promotion/demotion. Shop is functional. Friend streaks display.

### Phase 3: Notification Engine (Weeks 7–9)

**Goal:** Replace fixed notifications with state-based intelligent nudges.

| Task | Effort | Impact |
|------|--------|--------|
| NotificationEngine (state detection) | 2 days | Intelligence |
| Template catalogue (50+ messages) | 2 days | Content |
| Timing optimization (session hour learning) | 1 day | Personalization |
| Fatigue guardrails (cooldowns, caps) | 1 day | Trust |
| Update NotificationService to use engine | 1 day | Integration |
| Firebase Cloud Function for daily state eval | 1 day | Backend |
| A/B testing framework for notification variants | 2 days | Optimization |

**Phase 3 Exit Criteria:** Notifications are state-aware, personalized by time, and respect fatigue rules.

### Phase 4: Polish + Analytics (Weeks 10–12)

**Goal:** Refine, measure, and iterate.

| Task | Effort | Impact |
|------|--------|--------|
| Firebase Analytics events for all gamification actions | 1 day | Measurement |
| A/B test: streak display variants | 2 days | Optimization |
| A/B test: notification tone variants | 2 days | Optimization |
| Monthly seasonal achievement system | 1 day | Content refresh |
| Seasonal cosmetics in shop | 1 day | Content refresh |
| Performance profiling (gamification doesn't slow app) | 1 day | Quality |
| Accessibility audit (screen readers, reduced motion) | 1 day | Inclusivity |
| Polish animations and haptics | 2 days | Feel |

**Phase 4 Exit Criteria:** Analytics dashboard shows D7/D30 retention improvement. Notification open rate > 15%. No performance regression.

---

## 10. Open-Source References & Licenses

| Project | License | URL | What We Reference |
|---------|---------|-----|-------------------|
| FitQuest | MIT | github.com/NickiMash17/fitquest-app | Flutter + Firebase gamification architecture with plant companion, XP system, streaks. MIT allows commercial use and modification. |
| Momentum | MIT (inferred from Dart/Flutter) | github.com/vawcom-technologies/momentum | RPG-style life tracker with XP, daily quests, leveling. Quest system design patterns. |
| Valence | MIT (inferred) | github.com/deepan-alve/valence | Group-first habit tracker with friend streaks, leaderboards, nudges. Social accountability mechanics. |
| WellNudge | MIT | github.com/ShazzedShajal/WellNudge | Minimal nudge-based health companion. Contrast reference for notification restraint. |

**All referenced projects use MIT or permissive licenses.** We study architectural patterns only — no code is copied. Cal Matters has its own codebase, design system (`UI_GUIDELINES.md`), and product identity.

**Duolingo research sources (public, not code):**
- Yancey & Settles (2020), "A Sleeping, Recovering Bandit Algorithm for Optimizing Recurring Notifications" — KDD 2020 paper, published publicly
- Duolingo Engineering Blog: "Hi, it's Duo" (2020) — public blog post about notification AI
- Deconstructor of Fun: Duolingo gamification teardowns (2025) — public analysis
- Vmobify: "How Duolingo Grew" gamification teardown (2026) — public analysis

---

## 11. Metrics & Success Criteria

### Primary Metrics (North Star)

| Metric | Current (Est.) | Phase 1 Target | Phase 4 Target |
|--------|---------------|----------------|----------------|
| D1 Retention | ~40% | 50% | 60% |
| D7 Retention | ~15% | 25% | 35% |
| D30 Retention | ~5% | 12% | 20% |
| DAU/MAU Ratio | ~0.15 | 0.25 | 0.35 |

### Engagement Metrics

| Metric | Target |
|--------|--------|
| % users with 7+ day streak | 40% of active users |
| % users completing daily quests | 60% of DAU |
| % users in leagues | 50% of users Level 3+ |
| Avg Cal Points earned/day | 80 pts |
| Avg NutriCoins earned/week | 150 coins |

### Notification Metrics

| Metric | Target |
|--------|--------|
| Push notification open rate | > 15% |
| Notification dismiss rate | < 30% |
| Unsubscribe rate | < 2% |
| % users on silent hours | Track only |

### Health Metrics (Guardrail)

| Metric | Guardrail |
|--------|-----------|
| % users logging severely low calories | < 2% (flag for health note) |
| % users logging at 2–4am | < 1% (flag for intervention) |
| Opt-out rate from leagues | < 5% |
| Support tickets about gamification guilt | 0 |

---

## 12. Assumptions & Risks

### Assumptions

1. **Firebase is the backend.** All Firestore, FCM, and Cloud Functions infrastructure is already available.
2. **The existing `StorageService` pattern continues.** All new services follow the same `StorageService` dependency injection pattern.
3. **Users care about social features.** India's app market is highly social (WhatsApp, Instagram). Leaderboards and friend streaks should resonate.
4. **The plant/nature theme for levels fits.** The current app uses warm whites and flame icons. A nature progression (Seedling→World Tree) extends this without clashing.
5. **FCM is sufficient for notifications.** No need for OneSignal, Braze, or other notification services at current scale.
6. **Cal Points daily cap of 200 is appropriate.** This can be tuned based on Phase 1 data.
7. **Indian users will engage with NutriCoins shop.** Currency + cosmetics work well in Indian market (see BGMI, Dream11).

### Risks

| Risk | Mitigation |
|------|-----------|
| Gamification feels "gamey" for a health app | Guardrails Section 3. Test with real users. Nature-themed progression feels organic, not arcade-like. |
| Leagues cause anxiety in competitive users | Leagues are opt-in until Level 3. Demotion messages are encouraging, not shaming. Easy opt-out. |
| Notification fatigue | Fatigue guardrails are strict (max 3/day, 15/week). Ignore-based cooldown. Weekly automated review. |
| Firestore costs increase with gamification data | Gamification data is write-light (daily aggregates, not per-action). Use local cache aggressively. Monitor Firestore reads/writes in Phase 1. |
| Streak freezes devalue streaks | Max 3 in bank. Earnable through engagement, not purchasable with real money. Streaks still feel meaningful. |
| Anti-cheat is insufficient | Phase 1 uses photo-hash dedup + rate limiting. Phase 4 adds pattern analysis. Full ML anti-cheat is out of scope. |
| Seasonal content requires ongoing effort | Monthly achievements and cosmetics can be pre-built 3 months ahead. Automate rotation. |

---

## Appendix A: Comparison with Current System

| Aspect | Current | Proposed |
|--------|---------|----------|
| Achievements | 10 hard-coded, no persistence of progress | 56 dynamic, with progress tracking and Firestore persistence |
| Challenges | Static screen, pre-computed on load | Daily quest system with rewards and monthly challenge |
| Streak | Basic count from food entries only | Multi-action streak (meals + water + weight + exercise) with freezes and milestones |
| Leaderboard | Weekly kcal totals from friends | 10-tier league system with promotion/demotion |
| Currency | None | NutriCoins (earn + spend) |
| Shop | None | Cosmetic items, streak freezes, feature access |
| Notifications | Fixed daily time slots | State-based, timing-optimized, fatigue-aware |
| Celebrations | None | Micro-rewards on every action, full-screen for milestones |
| Levels | None | 21+ level progression with titles and unlocks |
| Social | Friends list + basic leaderboard | Friend streaks, league chat, reactions, profile badges |

---

## Appendix B: Detailed Notification Template Bank (Phase 3)

### Water Notifications (6 templates)
1. "💧 Glass #5 of 8 — you're past halfway!"
2. "Your plants would be jealous of how well you're hydrating 🌱"
3. "Quick water break? Your body will thank you 💧"
4. "Hydration check: {current}/{goal} glasses. Keep it up!"
5. "Water is the simplest health hack. One glass at a time 💧"
6. "You're {pct}% toward your water goal. Finish strong! 🌊"

### Meal Logging Notifications (6 templates)
1. "Delicious meal? Don't forget to log it! 📸"
2. "What's on the plate today? Quick scan takes 15 seconds ⚡"
3. "Lunch logged? If not, your Cal Points are waiting 🍛"
4. "Asha wants to know: what did you eat? 🤔"
5. "Your nutrition story for today is incomplete — add your next meal 📝"
6. "Missed logging? It's not too late — even a late entry counts ✨"

### Streak Notifications (6 templates)
1. "🔥 {streak} days strong! One more day and you hit {milestone}."
2. "Your streak survived another day. You're building something real 💪"
3. "Day {streak} of your streak. That's not just a number — that's discipline 🔥"
4. "Streak at risk! A quick water log saves it 💧"
5. "Your {streak}-day streak puts you ahead of 80% of users 👏"
6. "Almost {milestone} days! Don't stop now 🔥"

### Quest Notifications (4 templates)
1. "📋 Your daily quests are ready — 3 quick challenges await!"
2. "Quest update: {completed}/3 done. One more for the bonus! 🎯"
3. "You've got {points} Cal Points to earn from today's quests 💪"
4. "Missing out on quest rewards — they reset at midnight ⏰"

### Social Notifications (4 templates)
1. "{friend} just passed you on the leaderboard! Are you going to take that? 😏"
2. "Your league ends in 24 hours. You're #{position} — top 3 is close! 🏆"
3. "You and {friend} are on a {streak}-day streak! 🔥 Don't break it!"
4. "New week, new league! Your Seedling rivals are ready 🌱"

---

*End of document. This is a design-only specification. No application code has been modified.*
