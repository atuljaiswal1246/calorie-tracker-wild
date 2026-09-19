# STUDY.md — Cal Matters: a technical study of the codebase

Written 2026-09-17 by Jarvis, from a read of the working tree at commit `9b3112b`
(branch `main`, level with `origin/main`). Repo: `~/Desktop/calorie_tracker`.

This is the **code-level** companion to the project's own docs. Those docs are
written for the owner (plain language, product state, decisions). This one is
written for whoever next opens the editor — architecture, data flow, where the
risk is, and what to read first.

Read order for a new session: **`HANDOFF.md` → `AGENTS.md` → `AUDIT_REPORT.md` →
this file.** This file does not override the others; where they disagree, they win.

---

## 1. What the product is, in one paragraph

Cal Matters is a Flutter calorie-tracking app for the **Indian** market. The core
loop is: the user photographs (or names) a food → an AI vision model returns a
structured breakdown (items, portion, calories, macros, micros) → the entry is
logged against a personal daily calorie goal → the day is visualised as a ring on
Home, in Insights, and on Android home-screen widgets. All nutrition analysis is
delegated to the model; the app owns the goal maths, the logging, the streak and
the payment. Android-first (Google Play), iOS built but second-class.

Version in the tree: `0.9.6+11` (`pubspec.yaml`). Dart SDK `^3.13.1`, Flutter 3.47.1 stable.

---

## 2. Scale and shape

| Measure | Value |
|---|---|
| Dart source in `lib/` | 33,214 lines |
| Screens | 32 files in `lib/screens/` (27 screens + 5 `demo/`) |
| Services | 27 files in `lib/services/` |
| Models | 9 files in `lib/models/` |
| Widgets | 18 files in `lib/widgets/` |
| Test files | 28 (`test/*.dart`) + 51 golden PNGs + a 32-image `test/failures/` folder |
| Docs | `AGENTS.md` (61 KB), `HANDOFF.md`, `AUDIT_PLAN.md`, `AUDIT_REPORT.md`, `GAMIFICATION_*.md`, `UI_GUIDELINES.md`, `PLAY_STORE_LISTING.md`, `PRIVACY_POLICY.md` |

The four biggest files carry most of the product: `home_screen.dart` (3,167),
`onboarding_flow.dart` (3,038), `progress_screen.dart` (2,607),
`capture_screen.dart` (1,745). `storage_service.dart` (1,041) is the single data
layer. That concentration is the main structural fact about this codebase.

---

## 3. Architecture

### 3.1 Entry point and navigation

`lib/main.dart` (292 lines) is the whole app shell.

- `main()` does, in order: `Firebase.initializeApp()` → `StorageService.init()`
  → `AnalyticsService.init` → `SoundService.init` → `ExperimentService.init` →
  `Funnel.appOpen()` → build `GamificationController` and `init()` → push
  `darkMode` and shop `theme` into `AppColors` notifiers → `NotificationService.init()`
  → **chain** a widget-push listener onto the existing `storage.activityListener`
  → `runApp`.
- Anything optional is deliberately `unawaited` (`SoundService.prepareIosNotificationSound`,
  `_registerWidgetCallback`). The comment in the source is explicit: *"an awaited
  plugin call before runApp is exactly how you get a white screen."* This was a
  real bug (`4d5a2fa fix(startup): white screen`). **Do not await plugins in `main()`.**

Navigation is **not** a router. `_CalorieAppState` holds a single `_AppScreen` enum
(`loading`, `welcome`, `signIn`, `onboarding`, `home`) and a `switch` in `build`
picks the root widget. There are no named routes. Screens below the root push
themselves with `Navigator.push`.

Resume logic lives in `_init()` and `_onAuthenticated()`, and it is more subtle
than it looks. Three explicit intent flags exist purely to stop the app guessing:
`_onboardingAtSignup`, `_onboardingAtPricing`, `_onboardingAtStep`. A guest with a
saved profile who has not paid is sent to *sign-up*, not to the questionnaire; a
guest who dropped mid-flow resumes at their saved step; a signed-in user with no
profile must redo the questionnaire. Preserve those flags if you touch onboarding.

### 3.2 State management

There is **no state-management package** — no Provider, Riverpod, Bloc. State is:

- `StorageService` — a `SharedPreferences`-backed store passed down by constructor
  injection. Almost every screen takes `storage`.
- `GamificationController` — a `ChangeNotifier`-ish controller created in `main()`
  and listened to across Home/Progress.
- `AppColors.darkNotifier` / `themeNotifier` — global `ValueNotifier`s that
  `MaterialApp` rebuilds on (`ListenableBuilder` + `Listenable.merge`). Dark mode
  and the shop theme are read globally, not passed down.

Screens are `StatefulWidget`s that read from storage in `initState` and write back
through service methods. Rebuilds after a write are mostly manual.

### 3.3 Data layer — `StorageService`

One class, 1,041 lines, key/value in `SharedPreferences` plus a Firestore mirror.
Local is the source of truth; cloud is continuity.

Local key groups (all in `storage_service.dart`):

| Area | Key(s) |
|---|---|
| Profile / onboarding | `user_profile`, `onboarding_draft` |
| Meals | `food_entries` |
| Water | `water_entries`, `water_goal_ml` |
| Weight | `weight_entries` |
| Steps / activity | per-day step keys, `sensor_step_baseline`, `exercise_logs`, `body_measurements` |
| Payment | `paid_state_version` (schema version 2, with `_migratePaymentState`) |
| Gamification | gamification state + league (see `gamification_*.dart`) |
| Misc | `dark_mode`, `profile_photo_path`, `friends`, weekly summaries |

Cloud shape: `users/{uid}` for profile + paid flag, `users/{uid}/entries/{entryId}`
for meals, `users/{uid}/gamification/state`, and `users/{uid}/{water|weight|exercise|league}/*`.

`firestore.rules` is **default-deny**, with the only grant being
`request.auth.uid == uid` on the user's own subtree and its subcollections. This
rule is what killed the friends/leaderboard feature (it read other users'
entries) — see §9.

Two write paths are deliberately different and worth knowing:
- `addEntry()` — normal logging; emits a logging activity, so it can advance quests.
- `restoreEntry()` — the undo path; **deliberately does not** emit an activity, so
  undoing a delete cannot farm Cal Points or double-advance a quest
  (`test/storage_entries_test.dart` guards this).

`syncUserDataFromCloud()` restores water/weight/exercise/league/gamification **only
into empty local stores**, so a device switch doesn't look like data loss and a
re-install doesn't clobber live data.

### 3.4 The AI pipeline

`lib/services/openai_service.dart` is the client; `cloudflare_worker/worker.js` is
the proxy. The app **never holds an API key**.

- Endpoint: `https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev`
  (name is historical — the Gemini era). Model string sent by the client: `mimo-v2.5`.
- `analyzeImage(path)` base64-encodes the photo and posts it as an OpenAI-style
  `image_url` data URL; `analyzeText(foodName)` posts text only. Both return
  `({List<FoodItem> items, String? mealType})`.
- `_maxRetries = 3`.
- The worker tries **three upstreams in order**, first success wins:
  1. OpenCode Go (secret `OPENCODE_KEY`) — `mimo-v2.5`
  2. AICredits (`AICREDITS_KEY`) — `gpt-4o-mini`
  3. OpenRouter (`OPENROUTER_KEY`) — `gpt-4o-mini`
- **Circuit breaker** in Cloudflare KV: 5 consecutive failures suspends a provider
  for 30 minutes, then auto-resumes; one success resets the counter. Keys
  `cb_<provider>`. Optional Telegram alert on suspension (throttled 1/hour).
- Optional per-device daily quota via the `QUOTA` KV binding.
- Missing secrets degrade gracefully; all three missing → 500.

Images are compressed before upload (`flutter_image_compress`), which matters
because these are photos off a phone camera.

### 3.5 The data model

- `FoodItem` (`models/food_entry.dart`) — the interesting one. It stores calories
  and macros privately, applies `quantity` as a multiplier in the getters, and —
  critically — **recomputes calories from macros when they exist**:
  `calories = protein*4 + carbs*4 + fat*9` (Atwater), falling back to the stored
  `calories` value when macros are all zero. So a model that returns calories
  inconsistent with its macros will be silently overridden by the macros. It also
  carries a parallel set of `db*` fields (`dbMatchedName`, `dbCaloriesPer100g`, …)
  for comparing the AI's answer against the local Indian food database.
- `Profile` (`models/profile.dart`) — Mifflin-St Jeor BMR, TDEE from activity
  level, goal/pace → a weekly rate → a daily calorie target
  (`weeklyRateKg * 1102.5` kcal/day), and a macro split derived from the goal.
  Age is recomputed from `dob` on load rather than trusted. Overrides exist for
  all four targets (`calorieGoalOverride`, `proteinOverride`, …).
- Others: `exercise_entry`, `body_measurement_entry`, `gamification_state`,
  `league`, `notification_state`, `quest`, `shop`.

### 3.6 Local food database

`assets/merged_foods.json` is the shipped asset, built from `food_data/` (Indian
Food Nutrition API CSV, INDB recipes, plus category JSONs: cereals/millets, pulses
and legumes, green leafy vegetables, milk, eggs, meat, freshwater/marine fish and
shellfish, oils, condiments). `lib/data/prebuilt_plans.dart` and
`assets/quick_picks.json` sit on top for the meal-plan and quick-pick screens.
`barcode_service.dart` + `mobile_scanner` handle packaged food.

---

## 4. Feature inventory

**Core loop:** `capture_screen` (camera/gallery) → AI → confirm/edit → `addEntry` →
Home ring + macro cards + Insights.

**Screens of note:** `home_screen` (bento layout, both tabs, plus first-run state),
`onboarding_flow` (6 steps + goal/body/activity/pacing, the largest file),
`progress_screen` (charts, weight, body measurements), `insights_screen`,
`manual_entry_screen`, `meal_plan_screen`, `quick_picks_screen`,
`high_protein_meals_screen`, `meal_detail_screen`, `all_entries_screen`,
`history_screen`, `macro_breakdown_screen`, `pricing_screen`, `settings_screen`,
`achievements_screen`, `challenges_screen`, `league_screen`, `shop_screen`,
`gamification_hub_screen`, `nutrition_tips_screen`, `discover_screen` (dormant),
`asha_screen` (dormant), and a `demo/` set used for the in-app walkthrough.

**Services of note:** `storage_service`, `auth_service` (Firebase Auth: Google,
Apple-flagged-off, email), `analytics_service` + `funnel` (onboarding funnel),
`billing_service` (Play Billing), `notification_service` + `notification_engine` +
`notification_coordinator` (scheduling vs. deciding vs. coordinating — keep the
split), `gamification_service` / `quest_service` / `league_service` /
`achievements_service` / `shop_service`, `widget_service` + `widget_state`,
`sound_service`, `celebration_service`, `experiment_service`, `weekly_summary_service`,
`activity_service`, `food_search_service`, `barcode_service`, `openai_service`.

**Gamification:** Cal Points, quests, streaks, achievements, leagues, a shop with
a currency ("NutriCoins") and themes. The design intent is in
`GAMIFICATION_DESIGN.md` and `GAMIFICATION_PLAN_ASHA.md`.

**Monetisation:** `in_app_purchase` (Android + StoreKit). Products
`cal_matters_monthly` / `cal_matters_yearly`, each with a 3-day free trial. There is
a `paid_state_version` migration and an `isPaidOrSandbox(authEmail:)` check — the
sandbox escape hatch is why a dev build can reach Home without paying.

**Android home-screen widgets:** three separate widgets, intentionally not merged
(`ring`, `meal`/"trigger", `water`), sharing one data layer via `WidgetService` +
`widget_state.dart` + native layouts. The strategy — "give users the option to add
which they like", and treat adds/taps per widget as product research — is written
up in `AGENTS.md`. The ring and meal widgets shipped in 0.9.6; the water widget was
**pulled** because its one-tap background worker never fires on a real device (see §9).

---

## 5. Tests

Two kinds, and they are both load-bearing:

1. **Unit/widget tests** — 28 files covering storage (local + cloud), gamification,
   quests, league, shop, achievements, notifications, onboarding flow, funnels,
   experiments, target pacing, food-entry calorie maths, widget state, theme.
2. **Golden/preview tests** — `test/screen_preview_test.dart` and
   `test/app_screens_preview_test.dart` render real screens at iPhone and Android
   widths with real fonts, real emoji and seeded data, writing PNGs into
   `test/goldens/`. Any RenderFlex overflow fails the test.

The golden harness is the project's best asset. Per `HANDOFF.md`, six layout bugs
(Home header overflow on 360dp, the calorie total wrapping, MealCard overflow,
Achievements grid overflow, Shop subtitle overlap, the manual-entry dropdown losing
Inter) were all found by rendering screens and looking at them — not by reading code.
`AGENTS.md`'s rule is blunt: *never claim "done" without seeing pixels.*
Run with `flutter test --update-goldens test/screen_preview_test.dart`, then open
the PNGs. `test/failures/` holds diff images from a past failing run; it is
diagnostic output, not a baseline.

Last recorded full run: **180 passing** at commit `67ae271` (`HANDOFF.md`).
`flutter analyze`: clean of errors, ~156 pre-existing infos/warnings.

---

## 6. Environment, build and release

- Flutter 3.47.1 stable at `/opt/homebrew/bin/flutter`; JDK Temurin 21 at
  `~/devtools/jdk-21.0.12.1+1/Contents/Home`.
- Signing secrets are read from a gitignored `key.properties` (`0f3b4f8`). The
  release keystore `android/app/release-key.jks` is gitignored and is the single
  most dangerous thing to lose — no keystore, no more updates to the same listing.
- Play needs the **AAB**, not the APK. `~/Desktop/CalMatters-0.9.6+11.aab` is the
  current signed artifact (and the `+10` one before it).
- `adb` at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`.
- iOS device: devicectl id `6C0FE134-9424-5153-9BD9-6FB6D916666B`, bundle
  `com.neharohilla.calorietracker`. The phone must be unlocked or the install fails.
- Firebase project `calorie-tracker-80a0b`; store pages on Firebase Hosting at
  `https://calorie-tracker-80a0b.web.app`.
- macOS has no `timeout` — use `perl -e 'alarm N; exec @ARGV'`.

---

## 7. Feature flags and parked work

`lib/config/features.dart` is the single switchboard. Dormant code is **kept, not
deleted**, so re-enabling is one line.

- `Features.asha = false` — the in-app AI chat, her quest/points/shop voices and
  the "Asha's words" copy. The weekly summary is unaffected, and food scanning is
  not affected. (Visible "Asha" strings were removed from the UI; the class names
  remain.)
- `Features.appleSignIn = false` — code complete and dormant. Blocked by Apple:
  personal development teams cannot use the Sign In with Apple capability. Needs the
  $99/yr program; the file documents the three-step re-enable. Required for App
  Store review (4.8).

Also parked: friends/leaderboard (removed, `discover_screen.dart` and
`social_service.dart` left dormant and unreferenced — do not re-wire without a
public-aggregate design that the security rules permit), Hindi/localisation,
DPDP compliance (mandatory Nov 2026), iOS StoreKit products, the water widget,
haptics toggles, and an O(n) rewrite of the prefs write path.

---

## 8. Hard-won rules in this codebase

These each cost a real bug. They are in `AGENTS.md` too; they are repeated here
because they are the things a new session breaks first.

1. **Never await optional plugins before `runApp`** — that is the white-screen bug.
2. **Widget provider names derive from the real `applicationId`**
   (`com.neharohilla.calorietracker`). The original scaffold package
   (`com.calorietracker.calorie_tracker.*`) silently updated a provider that did not
   exist, so every widget showed its placeholder — and the launcher's preview
   images are static drawables, so it *looked* correct. Never hardcode the package.
3. **Widget colours must be resource-based** (`@color/widget_text` +
   `values-night/colors.xml`). Hardcoded light-card colours made the water widget's
   "1.2 L" invisible in dark mode.
4. **A widget is views on the launcher — it cannot play sound.** Sound comes from
   the app when the tap opens it.
5. **Android notification channels are immutable.** Changing a channel's sound
   requires a new channel id, or existing installs keep the system default.
6. **Widget background taps are unreliable on OEM Android** (Vivo/iQOO style
   restrictions kill the background isolate). The chosen fix is a deep link that
   opens the app and logs on open.
7. **Do not emit a logging activity from `restoreEntry`** — undo must not pay out
   points.
8. **Match the theme when styling a dropdown.** A bare `DropdownButton.style`
   replaces the theme style and loses the Inter font family.
9. **`FoodItem.calories` prefers the macro-derived value** when macros exist. If you
   are debugging a "wrong calorie" report, check macros before the calorie field.
10. **The security rules are default-deny.** Any feature that reads another user's
    data will fail in production even if it works locally.

---

## 9. Risk register and known debt

| # | Risk | Where | Severity |
|---|---|---|---|
| 1 | ~~**The release keystore is gitignored and not backed up**~~ — **backed up, confirmed by the user 2026-09-17** | `android/app/release-key.jks` | Closed — keep it that way |
| 2 | **Ring/meal widget live numbers were never confirmed on a device** before upload; the tester note asks for exactly that | `AGENTS.md` | High — a shipped widget may show wrong data |
| 3 | **Water widget's one-tap is dead on real hardware**; pulled from 0.9.6, deep-link fix not yet built | `AGENTS.md` | High for the next release |
| 4 | **No human has used the current build yet** — device test is the next real gate | `HANDOFF.md` | High |
| 5 | **Macro split is computed by mass, not calories** (grams/total grams). Internally consistent, but most apps show the calorie split; needs a product call | `HANDOFF.md` §2b | Medium — a one-line change, but a user-visible one |
| 6 | **Giant screen files** — Home 3,167 / onboarding 3,038 / Progress 2,607 lines. High merge and regression risk; every UI fix lands in a very large file | `lib/screens/` | Medium |
| 7 | **Manual `setState` refresh everywhere** — no reactive store, so a missed rebuild is a silent stale-UI bug | app-wide | Medium |
| 8 | **Prefs writes are O(n)** — the audit flagged a tidy-up; deliberately deferred as too risky to do unattended | `storage_service.dart` | Low–Medium |
| 9 | **~156 analyzer infos/warnings** — noise that hides a new real warning | app-wide | Low |
| 10 | **Dormant but referenced code** (`social_service.dart`, `discover_screen.dart`, `asha_screen.dart`) — dead weight that lints and confuses | `lib/` | Low |
| 11 | **`_totalDaysInPeriod` is dead code** in `progress_screen.dart` (pre-existing) | `progress_screen.dart` | Trivial |
| 12 | **AI quality is entirely upstream-dependent** — three rotating providers, one of which is the paid primary. A silent quality change would look like an app bug | `cloudflare_worker/worker.js` | Medium |
| 13 | **iOS is second-class** — no StoreKit products, no Apple sign-in, no iOS widget. It builds and installs, and that is all | `ios/` | Expected |

---

## 10. Open decisions owned by the user

1. **Macro split basis** — weight (current) or calories (mainstream). One-line change.
2. **Hindi support** and **DPDP compliance** (mandatory Nov 2026) — deliberately
   deferred until after launch.
3. **Play Console listing copy** — the repo doc is corrected; the Console text is a
   separate manual edit nobody has made yet.
4. ~~**Back up the release keystore** somewhere safe.~~ Done — confirmed by the user 2026-09-17.
5. Water widget tap behaviour — single 250 ml per tap, or a +250/+500 choice.

---

## 11. How to work on this safely

1. Read `HANDOFF.md` first; it is the current snapshot and the plan.
2. Read `AGENTS.md` before touching any screen — it lists the **LOCKED** screens
   (onboarding 1–6, welcome, auth, paywall) and the environment detail.
3. Follow `UI_GUIDELINES.md` for any new UI; the first two onboarding screens are
   the gold standard. Mock and get visual approval **before** coding a screen.
4. Change one thing. Render it, look at it, `flutter analyze`, `flutter test`.
5. Config, env and scripts need explicit user OK before changing.
6. The owner **does not read code** — report in plain language: what changed, what it
   costs, what needs their decision. Surface only decisions, money, and things only
   they can do. Never hand them a technical task without step-by-step UI instructions.

---

## 12. Where the product stands (as of this study)

- Live on Google Play **closed testing** with 12+ testers, past the 14-day mark;
  plan is closed → open testing → production.
- Play Billing live; a real tester purchase verified. Firestore rules deployed and
  deny-by-default. Play Data safety questionnaire submitted for review.
- 0.9.6+11 is the current build (`9b3112b`, "release: 0.9.6 (11) live on closed
  testing + the tooling that shipped it"). Local `main` is level with `origin/main`.
- Uncommitted in the tree: a modified `AGENTS.md` plus four untracked scratch PNGs
  (`exp_test*.png`, `tapped3*.png`) from device experiments.
- Shipping in 0.9.6: ring + meal widgets, undo-delete, the UI pass, the sound
  identity, the widget-package and dark-mode fixes. **Not** shipping: the water
  widget, the nudge.
- The next real gate is not code: it is a human walkthrough of the build on a device.

---

## 13. Quick reference

```bash
# from ~/Desktop/calorie_tracker
flutter analyze                                     # expect no errors
flutter test                                        # 28 files; 180 passing last recorded
flutter test --update-goldens test/screen_preview_test.dart   # then open test/goldens/*.png
flutter build appbundle --release                   # Play needs the AAB
git log --oneline -15
```

Files worth reading, in order, if you have an hour:
`HANDOFF.md` → `lib/main.dart` → `lib/services/storage_service.dart` →
`lib/services/openai_service.dart` → `cloudflare_worker/worker.js` →
`lib/models/food_entry.dart` + `lib/models/profile.dart` →
`lib/screens/home_screen.dart` → `test/app_screens_preview_test.dart`.
