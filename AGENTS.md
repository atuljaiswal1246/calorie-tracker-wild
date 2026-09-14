# AGENTS.md — Project Memory & Handoff

Read this first before doing any work in this project. It records everything done in the
previous session so a fresh chat can continue seamlessly.

## Project Overview
- **Product:** Calorie-tracking mobile app, AI-powered, targeting the **Indian audience**.
- **Core mechanic:** User takes/upload a food photo -> AI vision model returns a breakdown
  (items, calories, macros, portion size) -> logged into a daily calorie tracker.
- **No manual nutrition logic:** all food analysis is delegated to an AI vision model.
- **Platform:** Android-first (Google Play). iOS later (App Store). Built with **Flutter**.
- **Launch target:** get to Google Play as fast as possible; API cost is NOT a blocker.

## Decisions Already Made (do not relitigate)
1. **Framework: Flutter** (chosen over React Native) — strong typing, single codebase,
   reliable image plugins, straightforward release APK.
2. **AI vision API:** user has a paid **OpenAI subscription + API key**. Gemini free tier
   is a fallback if needed. Cost is not a constraint.
3. **Free-tools constraint:** avoid paid tools *unless the idea is proven*. The only
   unavoidable cost is Google Play's one-time $25 developer registration.
4. **Launch plan:** Google Play first (cheaper + faster), App Store after validation.
5. **Budget:** do not spend money beyond the Play Store fee until the idea is validated.

## Environment Setup (already installed & verified on this Mac)
- **Flutter SDK:** 3.47.1 stable, installed via Homebrew cask. Binary at `/opt/homebrew/bin/flutter`.
- **JDK:** Temurin 21 extracted at `~/devtools/jdk-21.0.12.1+1/Contents/Home`
  (installed manually as a tarball because `brew install --cask temurin` requires sudo).
- **Android SDK:** `/opt/homebrew/share/android-commandlinetools` (ANDROID_HOME), SDK 36,
  Build-Tools 36.0.0, platform-tools, NDK r28c. Licenses accepted.
- **iOS/Xcode:** NOW FULLY WORKING (set up this session). Xcode 26.6 at
  `/Applications/Xcode.app`; iOS 26.5 platform downloaded; CocoaPods installed via brew
  (1.17.0, though this Flutter uses Swift Package Manager so no Podfile needed).
  **IMPORTANT: Xcode needs `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`**
  exported because `xcode-select` still points at CommandLineTools.
- **iPhone:** User's iPhone 15 ("Atul's iPhone") is registered for dev on team
  `US3QA872WA` (Apple ID atuljaiswal1246@gmail.com, free personal team). Developer Mode
  is ON on the device. iOS bundle ID = `com.neharohilla.calorietracker`.

### Required env vars for every Flutter/Android command:
```sh
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=~/devtools/jdk-21.0.12.1+1/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # for iOS builds
```

### iOS device commands (worked this session):
- Build: `flutter build ios --profile` (uses automatic signing, team US3QA872WA; ALWAYS profile, NOT debug — debug builds can't launch from home screen)
- Install: `xcrun devicectl device install app --device <UDID> build/ios/iphoneos/Runner.app`
- Launch: `xcrun devicectl device process launch --device <UDID> com.neharohilla.calorietracker`
- List device: `xcrun devicectl list devices` (UDID may change; check each time)
- Device must be unlocked/awake and Developer Mode on for installs.

### Verified working commands (run from project root):
- `flutter analyze` -> "No issues found!"
- `flutter test` -> 2 unit tests pass
- `flutter build apk --debug` -> builds successfully
  (`build/app/outputs/flutter-apk/app-debug.apk`)

## Project State
- Scaffolded with `flutter create --org com.calorietracker --project-name calorie_tracker
  --platforms android,ios .` at `~/Desktop/calorie_tracker`.
- **Flow (2026-08-23 restructure):** Welcome (Get started / Sign in only — NO sign-up
  screen) -> Guest fills the 8-question onboarding -> 3-sec "Setting your goal" ->
  Plan/goal summary -> "Get started" opens SIGN-UP screen (new users) -> Pricing ->
  "Payment approved" -> Home. Signed-in users without a profile must fill the
  questionnaire (cannot bypass). Returning users: profile + paid -> Home directly;
  profile + unpaid -> pricing directly (onboarding `startAtPricing`).
  Payment state persisted via `StorageService.isPaid/savePaid/loadPaidFromCloud`
  (local prefs + Firestore user doc `paid` flag).
- **MVP app built** (this session). `lib/main.dart` no longer the counter demo.
- Android package name is `com.calorietracker.calorie_tracker` (default).
- Dependencies added: `image_picker`, `shared_preferences`, `http`, `intl`.
- `flutter analyze` -> "No issues found!"
- `flutter test` -> 2 unit tests pass (Profile BMR/TDEE + JSON round-trip).
- `flutter build apk --debug` -> succeeds
  (`build/app/outputs/flutter-apk/app-debug.apk`).

### Code structure (`lib/`)
- `main.dart` — app entry; loads `StorageService`, routes to Onboarding or Home based on
  whether a profile exists.
- `models/profile.dart` — Profile model + Mifflin-St Jeor BMR/TDEE/calorie goal.
- `models/food_entry.dart` — FoodItem + FoodEntry models with totals + JSON.
- `services/storage_service.dart` — `shared_preferences` persistence (profile, entries,
  OpenAI API key).
- `services/openai_service.dart` — calls OpenAI vision (`gpt-4o-mini`), base64 image,
  JSON-schema prompt, robust JSON extraction (fenced-code + `{...}` fallback).
- `screens/onboarding_screen.dart` — 8 questions + plan summary + pricing flow.
- `screens/home_screen.dart` — **REDESIGNED (2026-08-23): premium Cal-AI-style home**:
  warm-white bg (`#FAF9F7`), header w/ black app-icon + streak pill (🔥, real streak
  from entries), Sun–Sat week selector (selected=black ring, logged=green, missed=red,
  future=gray), big calories card w/ black progress ring + flame, 3 macro cards
  (protein coral/red, carbs orange, fat blue) w/ mini rings, pagination dots,
  "Recently uploaded" meal cards (thumbnail, 🔥 cal, macro pills, timestamp), floating
  pill nav with scanner in center + gallery icon next to "Recently uploaded".
  Tabs: Progress & Groups = placeholders; Profile = details + AI settings + sign out.
  Calories/macros reflect the SELECTED day.
- `screens/capture_screen.dart` — camera/gallery picker -> AI analyze -> results -> log.
  Accepts `initialImage` param for direct camera/gallery flow. Auto-analyzes when
  image is pre-loaded. Shows fiber, sugar, sodium in results. Meal type auto-detected
  by time of day + AI cross-check. "No food detected" for empty cups/plates.
- `screens/history_screen.dart` — list of past meals, long-press to delete.

### API key handling
- NOT hardcoded. User enters their OpenAI key at runtime in Home > Settings (gear icon),
  stored in `shared_preferences`. The app currently uses `gpt-4o-mini` (cheap). Cost is
  not a blocker per decisions.

### AI provider fallback (IMPORTANT — Gemini is the working provider)
- **User's card could not be charged**, so the paid OpenAI quota is unavailable (429).
- Added **Gemini free-tier support** (`lib/services/gemini_service.dart`) as the working
  provider. Settings (gear icon) now has an **OpenAI / Gemini toggle** + separate key
  fields. Provider and Gemini key are persisted via `StorageService`.
- **Gemini model in use: `gemini-3.6-flash`** (default in `gemini_service.dart`). Note:
  `gemini-1.5-flash` and `gemini-2.5-flash` return **404** (deprecated/not available in
  the user's region). Do NOT switch back to them.
- **MVP validated end-to-end on a real device (2026-08-21):** onboarding → home →
  gallery photo → AI analysis (detected "Besan Sev", 185 kcal) → log → dashboard totals
  updated → history shows the entry. All working.
- The app is installed on the user's device (Android, USB debugging). The user must
  reconnect the phone via USB when a rebuild/install is needed.

## LOCKED — Calculation Logic & Onboarding Options (do not change)
- **Weekly rate is FIXED per pace (matches mainstream apps):** slow = 0.1,
  moderate = 0.5, fast = 0.9 kg/week. Timeline = kg to lose / rate
  (calendar months, ~30.5 days/month: 100wk=23mo, 50wk=11mo, 20wk=5mo).
- **Calorie goal = floor(burn -/+ round(rate x 1102.5) - 0.25), floored at
  1200 kcal/day women / 1500 men.** Verified exact vs other apps on 6
  profiles: 68kg woman 0-2x/wk -> 1508/1200/1200 (lose 10kg); 62kg man
  3-5x/wk -> 2442/2883/3324 (gain 5kg); 52kg 25F 6+x/wk -> 1996/1555/1200
  (lose 6kg); 88kg 40M 0-2x/wk -> 2046/1605/1500 (lose 12kg); 70kg 35F
  0-2x/wk -> 1784/2225/2666 (gain 4kg). Maintain = floor(TDEE) — confirmed
  by user (75kg 30M 3-5x/wk maintain = 2710; earlier 1500 was a misread).
- **Multiplier from workout frequency ONLY (no lifestyle question):**
  0-2/wk = 1.2, 3-5/wk = 1.55, 6+/wk = 1.725 (classic TDEE values).
- **Macros are % of calories:** lose+slow = 28.5% protein / 40.5% fat /
  31% carbs (107P/68F/117C @1508). All other pace+goal = 29% / 39% / 32%
  (87P/52F/96C @1200; 177P/106F/195C @2442; 241P/144F/266C @3324).
  Carbs = remainder after protein & fat. NOTE: gain-moderate in other apps
  showed 207/127/228 vs our 209/125/230 (±2g) — unresolved, treat as noise.
  Other macro noise (±1-5g): P1-slow, P2-slow, P4-slow/fast, 1500-sets.
- **Onboarding options (8 screens):** goal (4), sex (4), age, height
  (ft/in -> cm ROUNDED to whole cm, or cm), weight (kg/lbs), workouts per
  week (3: 0-2 / 3-5 / 6+), target weight (full range, no ±5 limit), pace
  (3 options with realistic time labels). NO lifestyle/routine question.
- From now on: **NO changes to logic or options** — only visual/UI improvements.

## Next Steps (in order)
1. **User tests the MVP on a real Android device** (`flutter run` or install the debug APK):
   - Enter OpenAI API key in Settings.
   - Test onboarding -> home -> log a meal (camera + gallery) -> AI breakdown -> history.
2. Verify AI parsing quality with real food photos; tune the prompt in `openai_service.dart`
   if needed (Indian dishes, portion estimates).
3. Consider hardening: retry on parse failure (currently single attempt), error states,
   offline handling, calorie goal edit.
4. Set proper app name/icon/package metadata; build a **release** APK (sign with a
   keystore for Play Store).
5. Prepare Play Store assets (screenshots, privacy policy, store listing) and submit.

## Key Constraints & Notes for Future Sessions
- Keep responses/builds working with the env vars above.
- User self-tests on real Android devices; build `flutter build apk --debug` or
  `flutter run` for device testing.
- Timeline goal from original plan: MVP in ~1 week, submit to Google Play mid-next-week.

## AI Provider Setup (2026-08-29) — AICredits via Cloudflare proxy
- OpenAI/Gemini paid keys CANNOT be used: OpenAI's Stripe checkout rejects most Indian
  cards; user's OpenAI 429 (no usable quota). Gemini free tier exists but is NOT viable
  for production (10 RPM / 1500 RPD, trains on data, no SLA). GEMINI_KEY removed.
- **Production path: AICredits** (aicredits.in) — OpenAI-compatible API, pay in INR via
  UPI, min top-up ₹50 (balance: ₹50 as of 2026-08-29). API key = secret `AICREDITS_KEY`
  on Cloudflare Worker `cal-matters-gemini-proxy` (https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev).
- Proxy worker (`cloudflare_worker/worker.js`): forwards to `https://aicredits.in/v1/chat/completions`,
  adds Bearer AICREDITS_KEY, per-device daily quota via KV binding `QUOTA` = **100/day**.
  On app restarts the device id regenerates (stored in systemTemp), so quota is per-session-ish.
- App never ships a key: `OpenAIService` (lib/services/openai_service.dart) POSTs OpenAI
  format to the proxy with header `x-device-id`. Model: gpt-4o-mini (default).
- Deploy: `cd cloudflare_worker && wrangler deploy` (secrets must be re-added via
  `wrangler secret put AICREDITS_KEY` or dashboard if the worker is re-created).
- Note: curl/python CLI calls to the worker may hit Cloudflare bot-fight 403 — use a
  browser-like User-Agent or test via the app itself.

## Play Store Launch Plan (verified 2026-08-29)
- **MANDATORY: 12-testers-for-14-days closed testing** — applies to ALL apps from personal
  Play Console accounts created after Nov 13, 2023. This is the #1 launch blocker.
  - Run a **closed test** with ≥12 testers opted in continuously for 14 days BEFORE
    requesting production access. Testers must actually install/use the app; quitting
    via the testing web link de-opts them (uninstall does NOT opt out).
  - Organization accounts are exempt but need a D-U-N-S number (days–weeks + financial/
    health app restrictions) — plan is to stay PERSONAL.
  - User's friends volunteering to test: use them to fill the 12-testing slots via a
    closed-testing email/group link in Play Console.
- **App category — be careful:** Health apps (Medical/Human Subjects Research) MUST use
  an Organization account and need the Health apps declaration form. Our app is a
  nutrition/calorie tracker — NOT a medical app — but Google Play category is
  "Health & Fitness". Safe path: keep it consumer nutrition (no medical claims/advice
  in listing or app), it does NOT need the Health apps declaration as long as we don't
  claim medical/clinical/weight-loss-treatment benefits. Avoid words like "treatment",
  "diagnose", "clinical" in the store listing. Use "Health & Fitness" category but
  write the listing around food/calories/logging, not health-advice.
- **Data safety form** (Play Console > App content): must declare — health/fitness data
  (calories/macros/weight), photos (sent to AICredits for analysis; NOT stored),
  email+display name if Google sign-in. Data is not shared/sold; encrypted in transit.
  **Privacy policy LIVE on Firebase Hosting**: https://calorie-tracker-80a0b.web.app/privacy.html
  (Firebase project `calorie-tracker-80a0b`; hosting config in `firebase.json` serving the
  `public/` dir — privacy.html, terms.html, index.html; deploy with `firebase deploy --only hosting`
  from project root). Also a data-safety README copy at `PRIVACY_POLICY.md`.
  NOTE: policy updated 2026-08-29 (AICredits + atuljaiswal1246@gmail.com, Last updated
  2026-08-29) and deployed to Firebase — verified live.
- **Store listing must match app** — screenshots/text must show current features only
  (no unshipped "AI magic"). App name "Cal Matters" is FINAL. Contact email shown in
  Play listing: atuljaiswal1246@gmail.com.
- **App access declaration:** provide Google sign-in (reviewable login may require listing
  sign-in instructions/credentials). NOTE: NO guest mode once live — users must sign up and
  pay (trial/payment) to reach Home. Mention the required login path in the declaration.
  - **PAYMENT/MONETIZE SETUP — REQUIRED, NOT YET DONE (sequenced after store listing):**
    1. In Play Console under **Monetize with Play**: create the subscription/one-time
       product (Play Billing) with INR price point.
    2. Wire `lib/services/billing_service.dart` (in_app_purchase scaffold exists, NOT hooked;
       onboarding `_PaymentApprovedScreen` is a test stub calling `savePaid(true)` directly).
    3. Flip **Financial features** to **Yes** (via Google Play Billing) and complete the
       financial features declarations in the Dashboard checklist.
    Doing the checklist now with the stub build: Financial features = No (nothing real yet).
  **TEST ACCOUNT (created 2026-08-29 via Firebase Auth REST API, user
  localId 2q8X6tImtlMc5fcwzBQ7Gknuqh32):** email `playtest@calmatters.app`,
  password `CalPass#2026` (email/password sign-in; email NOT verified — fine, sign-in works).
- **Future requirements (not launch blockers, do NOT break launch):**
  - Feb 2027: memory/bitmap/DEX-optimization thresholds (R8/minify already enabled
    in build.gradle.kts; keep `isMinifyEnabled = true` + proguard rules).
  - Apr 2027: Zero-Tap Sign-In via Android Restore Credentials API for apps with sign-in.

## Release Build & Sharing
- Version currently `0.9.0+3` (pubspec.yaml). Bump versionCode above installed builds
  before `adb install -r` (downgrade errors otherwise); signature of release differs
  from debug so a debug build must be fully uninstalled first.
- Signing: `android/app/release-key.jks` (storePassword/keyPassword calorietracker123,
  alias calorie_tracker) — DO NOT commit these credentials anywhere public.
- Release APK to share with testers: `build/app/outputs/flutter-apk/app-release.apk`
  (~77MB); Play upload format = AAB: `build/app/outputs/bundle/release/app-release.aab`
  (~66MB). Copy to ~/Desktop as CalMatters-<ver>.apk/.aab for sharing.
- iOS test install: `flutter build ios --profile` then devicectl (see env section).
  UDID 6C0FE134-9424-5153-9BD9-6FB6D916666B — changes; check `xcrun devicectl list devices`.

## QA Process (pairing mode — ongoing)
- USER drives visual QA screen-by-screen on Android and iPhone; assistant does the driving/
  code fixes. Instructions flow from user; wait for user's guidance.
- Android QA via adb: device 10BDCK24A0000LS (1080x2400). Use `uiautomator dump` for exact
  tap points (nav pill coords: Home(183,2158) Progress(361,2158) Discover(718,2158)
  Profile(897,2158), center Scan(540,2158); insights icon (758,290)).
- Insights screen now has streak+achievements pills (matching Progress screen).
- Known minor issues to fix later: emoji vs Material-icon inconsistency on some screens
  (progress stats), y-axis "105" label position in progress chart.
- AI scan verdict "No food detected" can occur spuriously (bad model response) — consider
  auto-retry before showing the verdict (NOT yet implemented).
- Verify changes with `flutter analyze` after edits.
## Gamification — Phase 1 (implemented 2026-09-14)
Implements `GAMIFICATION_PLAN_ASHA.md` (the committed design spec) one module at a
time. Health guardrail enforced: points reward *logging behaviour* only — nothing
reads calories, and there are no weight-loss/deficit rewards.

**Done (engine → quests → wiring → Home UI), all tested:**
- `lib/models/gamification_state.dart` — `GamificationState` + `StreakState` (JSON,
  mirrors the plan §7.1 schema).
- `lib/models/quest.dart` — `QuestTemplate`, `ActiveQuest`, `QuestMetric`.
- `lib/services/gamification_service.dart` — Cal Points table + per-action daily
  limits, 200/day point cap, 60s rapid-repeat cooldown (logging actions only),
  level thresholds/titles (§4.2), multi-action streak with automatic freeze
  forgiveness + milestones (§4.3), NutriCoins, daily-login + quest bonuses.
- `lib/services/quest_service.dart` — 12-template pool, daily generation honouring
  the four selection rules (exclude yesterday, ≥1 easy, ≤1 nutrition-quality,
  weighted to weak areas), progress reporting, `claim`/`claimAll`.
- `lib/services/gamification_controller.dart` — app singleton
  (`GamificationController.instance`), initialised in `main.dart`. Registers
  `StorageService.activityListener`; `apply()` runs the engine, advances quests,
  auto-claims, queues celebrations and bumps a `ValueNotifier`.
- `lib/services/storage_service.dart` — emits `StorageActivity` for meal/scan/
  water-goal/weight/exercise (so every logging path earns without screen edits);
  persists gamification state + quest board (prefs + `users/{uid}/gamification/state`).
- `lib/screens/home_screen.dart` — Today's-quests card, live streak pill (multi-
  action), level sheet, floating reward toasts. `asha_screen.dart` — Asha-chat reward.

**Tests:** `test/gamification_test.dart` (22), `test/quest_test.dart` (13),
`test/gamification_controller_test.dart` (9). `flutter analyze` clean, `flutter test`
84 pass, `flutter build apk --debug` succeeds.

**Also done:** dynamic achievements (plan §4.7) — `achievements_service.dart`
rewritten to ~40 achievements across 10 categories with live progress, secret
badges and category-grouped UI; the existing `getAll()/unlockedCount/
checkAndUpdate()` API is unchanged so all callers keep working.

**Also done (Phase 2 start):** NutriCoins shop — `models/shop.dart`,
`services/shop_service.dart` (12-item catalog, freeze purchases apply through the
engine, cosmetics/personalities/features recorded in `shop_inventory`),
`screens/shop_screen.dart`, reachable from the hub's 🛍️ action.

**Not yet built (Phase 2+):** leagues, notification engine, full-screen
celebrations; shop effects beyond freezes (frames/themes/voices) are recorded but
not yet applied in UI.
