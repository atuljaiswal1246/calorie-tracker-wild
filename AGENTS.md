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
- Build: `flutter build ios --debug` (uses automatic signing, team US3QA872WA)
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
- Verify changes with `flutter analyze` after edits.