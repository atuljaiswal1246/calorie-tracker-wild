# Changelog — Cal Matters

Release log for future sessions. Newest first. Play track: **alpha = closed
testing**; `tools/publish.py <aab> <track> [notes-file]`.

---

## 0.9.10 (15) — 2026-09-23 — closed testing
Three fixes reported from device testing.

**Capture — never stuck with an incomplete meal.**
- "Add item" button under the AI results opens the manual search in picker
  mode and merges the chosen food(s) into the meal. Fixes thali scans where
  the model reports 4 of 5 items.
- The thali prompt now demands EVERY visible item (no merging, no dropped
  sides like sambar/papad/chutney) and realistic home-style portions.
- Any item's portion chip is tappable: preset grams (50-300) or free entry,
  with a live kcal preview; rescales calories/macros proportionally
  (`FoodItem.withPortion`).

**Home — calorie ring direction.**
- The hero ring filled with `remaining/goal` and centred the "left" figure, so
  it shrank as you ate. It now fills `logged/goal` and shows the eaten number
  ("KCAL EATEN"; red "KCAL OVER" past goal). "left" stays in the equation line.

**Verification:** `flutter analyze` 0 errors; `flutter test` 219/219.
Uploaded via `tools/publish.py`; read back `alpha completed ['15'] 0.9.10`.

---

## 0.9.9 (14) — 2026-09-21 — live on closed testing
Two themes: the way in (pricing) and Home.

**Pricing: paywall removed from the funnel; 7-day trial + soft lock.**
- Sign-up → Home directly. Every account gets **7 days full access**; day 8 it
  soft-locks instead of dying.
- Free after the trial: manual logging, Home, habits, history.
- Locked: AI scan, Gallery, Quick picks, Barcode, Progress, Trophy; Profile
  becomes an account page (upgrade, Restore, Sign out).
- Gate lives in `StorageService` (`AccessLevel`, `ensureTrialStarted`,
  `loadTrialFromCloud` — earliest of local/cloud wins). See AGENTS.md
  "Free trial + soft lock".
- `Features.bypassPaywall = false` (was the test-build bypass; the funnel no
  longer needs it, so the Settings "TEST BUILD" banner is gone).
- `Features.trialControls = false` for this build (dev force-state buttons).

**Home rebuilt** (`lib/screens/home_screen.dart`):
- calories-left ring (tap = log, long-press = breakdown) + macro rows
- 7-day calorie sparkline
- next-meal prompt ("It's 10:00 AM — log Breakfast?")
- one-tap "Log again" on recent meals
- habits + quests merged into one "Today" strip + "Log exercise" link
- nav gains a **Trophy** tab (achievements); Insights moved to Progress

**Fixes**
- `league_service`: week key used `DateTime.now()` → `clock.now()` (the League
  golden silently broke whenever the real week rolled over).

**Verification:** `flutter analyze` 160 / 0 errors; `flutter test` 213/213.
Uploaded via `tools/publish.py`; read back `alpha completed ['14'] 0.9.9`.

**Open:** device-level trial ledger (a different Gmail on the same phone still
gets a fresh 7 days).

---

## 0.9.8 (13) — 2026-09-21 — live on closed testing
- Home design-system pass (spacing, Material Symbols, type scale).
- Test build with the paywall bypassed + Settings "TEST BUILD" banner.

## 0.9.7 (12) — 2026-09-19 — live on closed testing
- Widgets (ring + meal), undo-delete, meal nudge, sound test.

## 0.9.6 (11) — 2026-09-16
- Water widget pulled (one-tap background action did not run on a real device).
