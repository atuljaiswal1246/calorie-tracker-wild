# AGENTS.md — Project Memory & Handoff

## ⚠️ ONE THING (locked 2026-09-16) — do not start a second
**In progress: WIDGETS — device-tested 2026-09-16, two bugs fixed, water pulled.**
`8034675` on top of `e05b13c`. Tested on the user's iQOO (Android 15). The
device found three things that no test or golden could:

1. **Widget updates went nowhere (FIXED).** `WidgetService` pushed to
   `com.calorietracker.calorie_tracker.*` — the old scaffold package — while the
   applicationId is `com.neharohilla.calorietracker`. `HomeWidget.updateWidget`
   silently updated a non-existent provider, so **no widget ever received real
   data**; they showed their placeholder layouts. Names now derive from the real
   applicationId. (The preview images in the launcher are static drawables, so
   they looked correct while the live widgets were empty — that is what hid it.)
2. **Dark mode (FIXED).** The water widget's text colours were hardcoded for a
   light card; on a phone in dark mode the card flipped dark and "1.2 L" became
   invisible. Colours moved to `@color/widget_text` + `values-night/colors.xml`.
3. **The water widget's one-tap does not work on a real device (PULLED).** The
   background worker never runs and no water is logged, even when the broadcast
   is sent straight to the receiver. It is removed from the manifest for 0.9.6
   rather than shipping a dead button. NEXT ATTEMPT: the tap opens the app via
   deep link and logs on open — reliable everywhere, still one tap, and it drops
   the background isolate/WorkManager entirely (Vivo-style OEM restrictions
   make that path unreliable).

**Shipping in 0.9.6:** ring widget + meal widget (interaction verified: tap opens
the app; data path now correct), undo-delete, the UI pass. **Not shipping:** the
water widget, and the nudge.

**Unverified:** the ring/meal widgets' live NUMBERS on a device were not
confirmed before upload — the tester note asks specifically for that.

**DONE 2026-09-16: Home revert.** `1b28a84` restored the bento Home the user
prefers (`87dcf45`), keeping the Profile inline calorie-goal edit and the
dark-mode inverted CTA.

**WIDGET GALLERY — the user's stated strategy (2026-09-16).** They are building
several widgets on purpose: *"I want to give option to users to add which they
like."* So there are THREE separate widgets, never merged — each with one job:
| Widget | Job | Mock |
|---|---|---|
| **Ring** | Status at a glance: calories taken, progress in the ring, colour by state (black on track / amber halfway / green on target / red over). Nothing else, no logging prompt. | `mock_21_ring_widget.png` |
| **Trigger** | Bring them in: the meal + one tap to log. BUILT (`a6ac903`). | `mock_18_widget_as_trigger.png` |
| **Water** | One tap logs a glass (250 ml), no app open. | `mock_19_water_widget.png` |
The chooser itself matters: `mock_22_widget_gallery.png`. **The choice is the
research** — adds-per-widget and taps-per-widget become free product data; the
winner becomes the default and the losers get cut by data, not opinion. They must
share ONE data layer (same water rules, same streak, same state engine) so a new
widget is a layout, not a new system.

**SOUND — approved 2026-09-16 (all three candidates chosen).** Files are in the
repo (unwired, so 0.9.6 is untouched):
| File | Use |
|---|---|
| `android/app/src/main/res/raw/cal_notify.wav` | the notification sound (0.9s warm chime) |
| `assets/sounds/cal_pip.wav` | in-app confirmation: meal logged, water added (0.18s) |
| `assets/sounds/cal_success.wav` | streak milestone / goal reached (0.72s, two rising notes) |
They were synthesised with Python (no licence, nothing to pay). Mechanics to
remember:
- **Android notification channels are immutable.** The current channel is
  `reminders`; changing its sound requires a NEW channel id, or existing installs
  keep the system default. Do it with the sound change, in one go.
- **Widgets cannot play sound** — a widget is views on the launcher. The sound
  comes from the app when the tap opens it (that is what Duolingo does).
- iOS needs its own copy in the runner bundle (aiff/wav/caf) — later.
- Pair it with a "sounds" toggle in Settings: sound is the fastest way to feel
  alive and the fastest way to annoy.

**Parking Lot (do NOT start while something above is open):**
- **WATER WIDGET (mock approved 2026-09-16, `mock_19_water_widget.png`).**
  Separate from the calorie widget — do not merge them. Pure action: tap = +1 glass
  (250 ml) with no app open, via a background interactivity callback that writes the
  entry and redraws. Drawn **natively** (fill + bar), so unlike the calorie widget it
  is instant and never stale. Sizes: small 2x2 and wide 4x1; goal-reached goes quiet;
  resets at midnight; long-press opens the water card. MUST reuse the same water rules
  as the in-app card (daily reset, goal, undo). Needs the Android device to verify the
  background callback. Open question for the user: single 250 ml per tap vs +250/+500.
- Haptics: widget tap vibration (needs the Android device) and a "vibrate on actions"
  setting — the app already uses haptics widely but has no toggle.
- Settings / achievements / meal-detail / manual-entry-empty polish passes.
- Small widget size; background redraw (WorkManager).
- iOS widget (needs a WidgetKit target; check App Groups on the free team).
- Hindi, iOS, pref O(n) rewrite, any new gamification.

**Rules of the ledger:** one item in progress, ever. An item leaves the list only
when it survives: rendered and looked at, `flutter analyze` clean, `flutter test`
green, and installed on the user's phone. Everything else is parked, however
good it sounds.


## Free trial + soft lock (2026-09-21) — REPLACES the post-signup paywall
**The funnel no longer asks for payment.** Sign-up → Home; every account gets a
**7-day full-access trial**; day 8 it soft-locks.
`Features.bypassPaywall = false` (reverted 2026-09-21 — the funnel no longer needs
it, and the Settings "TEST BUILD" banner is gone as a result).

- `StorageService` is the gate: `AccessLevel {trial, limited, full}`,
  `accessLevel()`, `isLimited()`, `trialDaysLeft`, `ensureTrialStarted()`,
  `loadTrialFromCloud()` (earliest of local vs cloud wins, so a reinstall or a
  sign-in on another device cannot restart the 7 days).
- **Limited** keeps manual logging + Home + habits + history free; **locks**
  AI scan, Gallery, Quick picks, Barcode, Progress, Trophy, and turns Profile
  into an account-only page (upgrade, Restore, Sign out).
- Home shows a quiet countdown in the last 3 days, then "Your 7-day trial has
  ended".
- **`Features.trialControls = true`** adds Settings → "Trial (test build)"
  (force ended / active / clear) so the lock can be exercised without waiting a
  week. **MUST be false before production.**
- **KNOWN GAP:** account-level only. A different Gmail on the same phone still
  gets a fresh trial — that needs the device ledger (stable device id +
  Cloud Function). The trial date is already cloud-synced so that layer is a
  small follow-up.
- Unblock a tester without code: `tools/mark_paid.py <email>`.


## Agent delegation — brain + muscles (locked 2026-09-19)
The user's method, learned from their `Jarvis` project and used here from now on.
**The brain (this session) plans, briefs, verifies and owns the outcome. It does
not do the implementable work itself when a muscle can.** Muscles execute exactly
what the brief says and report; they never decide.

**Dispatch:**
```
TMPDIR="$PWD/.agent-logs" ~/Desktop/Jarvis/scripts/agent_run.sh \
  --dir "$PWD/.worktrees/<task>" --model opencode-go/muse-spark-1.3-contributor \
  --auto --task "@notes/agent-briefs/<task>.txt"
```
- **Abuse rule (KB-06):** NEVER hand-roll HTTP to `opencode.ai/zen|go` — that is
  what triggers the abuse filter's 429s. The CLI/serve is the validated client
  (the harness also unsets `OPENCODE_API_KEY` so it cannot shadow `auth.json`).
- **One agent per directory.** Work in an isolated worktree under `.worktrees/`;
  never point two agents at the same tree. Logs land in `.agent-logs/` (gitignored).
- **Probe first:** `opencode run -m <model> "reply with three words"` before a real
  run. Paid `opencode-go/muse-spark-1.3-contributor` buys quota, not quality.
- **Briefs live in `notes/agent-briefs/`** (versioned): goal, exact files, exact
  values, what is FORBIDDEN (locked screens, tests, deps), and the verification
  command. A vague brief is the brain's failure, not the muscle's.

**Verification (the brain's job, never optional):**
1. Read `git -C <worktree> status/diff` yourself. Never trust a self-report.
2. `flutter analyze` — expect 0 errors and no change to the 160-item baseline.
3. `flutter test` — the WHOLE suite, not one harness. A change to a shared
   widget or a token moves goldens owned by several test files (the type snap
   moved `ring_widget_*`, `cal_widget_*`, `demo_*` and `dob_picker` as well as
   the app screens); scoping regeneration to one file left `main` red. When a
   change can alter rendering, regenerate ALL goldens and confirm the changed
   set is exactly the expected one — and that no locked-screen golden moved.
   For a refactor that claims to be invisible, prove it:
   **A/B the goldens at the same fixed clock** (stash the change, regenerate,
   restore, regenerate, compare bytes). Note: the harness is clock-pinned now
   (`withClock(Clock.fixed(2026-09-16 10:00))`), so a plain golden run is
   trustworthy again.
4. Merge only the intended files (e.g. never the clock-shifted goldens) and
   commit with `Worker-written (<model>), brain-verified`.

**Files stay in the Cal Matters folder.** Briefs in `notes/agent-briefs/`, release
artefacts and notes in `notes/releases/`, mocks and review sheets in `design/`,
throwaway agent trees in `.worktrees/`, logs in `.agent-logs/`. Nothing of ours
goes on the Desktop or in system temp. (Exception, by design: the keystore backup
must stay OUT of the repo — it is a secret.)



> **START HERE (2026-09-15):** read **`HANDOFF.md`** first — it holds the current
> snapshot (what is live, what is parked, the ordered plan and who owns each step).
> This file is the long-lived memory: locked screens, environment, and hard-won rules.

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
- `screens/onboarding_flow.dart` — the 6 onboarding question screens + plan summary.
- `screens/pricing_screen.dart` — the paywall (`PricingScreen`).
- `screens/welcome_screen.dart` — first screen (carousel + Try demos).
- `screens/auth_screen.dart` — sign-up / sign-in (Google, email; Apple parked).
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
> **Stale — superseded 2026-09-15.** The live plan is in `HANDOFF.md` §3 ("Plan
> forward"), with an owner and a status for every step. Kept only as history.
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
- Signing: `android/app/release-key.jks`, with its passwords/alias in the
  gitignored `android/key.properties`. `app/build.gradle.kts` reads that file —
  no credentials are hardcoded in the repo, and none should ever be added back.
  The keystore itself is gitignored too. Back it up somewhere safe: losing it
  means this Play listing can never be updated again.
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

**Also done (Phase 2):** weekly leagues — `models/league.dart`,
`services/league_service.dart` (10 tiers from §4.6, Mon–Sun Cal Points scoring,
deterministic simulated peers, promotion/demotion, podium rewards via
`GamificationService.awardBonus`), `screens/league_screen.dart` from the hub's 🏆.

**Also done (Phase 3 start):** notification engine — `models/notification_state.dart`
(4 engagement states), `services/notification_engine.dart` (state detection,
16-template catalogue, time-window selection, 48h dedup, 3/day + 15/week caps,
silent hours 22-07, ignore-cooldown, dormant re-engagement cap, session-hour
learning), `services/notification_coordinator.dart` (runs on app open, schedules
one nudge via `NotificationService.scheduleEngineNudge`).

**Also done (Phase 4):** full-screen celebrations with reduce-motion support
(`celebration_service.dart` + `widgets/celebration_overlay.dart`), a rotating
monthly seasonal achievement and Seasonal Frame, and a local analytics seam
(`analytics_service.dart`, bounded ring buffer; logs gameplay_action, level_up,
shop_purchase, league_result — swap the `log()` body for Firebase Analytics later).

**Also done (Phase 4 cont.):** equipped shop frames render as a ring on the home
profile avatar (bronze/silver/gold/seasonal); a stable per-user A/B variant uses
`experiment_service.dart` to label the streak pill and logs exposure; the
Midnight/Forest themes now re-tint the app accent + primary buttons
(`AppColors.themeNotifier`, set in main and on shop equip).

**Also done (Phase 4 finish):** screen-reader semantics on quests/league rows/
celebrations; notification-tone A/B (templates tagged playful/supportive/gentle,
chosen per user via `experiment_service.dart` with exposure logged).

**Still open:** performance profiling; leagues simulate peers locally (no Cloud
Function); no Firebase Cloud Function for daily state evaluation.

## Foundation audit (2026-09-14) — schedule before scale/launch
Feature work can continue on top (the service seams are sound), but these three
base-layer gaps are the only ones worth scheduling. Ranked, with evidence.
Status re-checked 2026-09-15.

1. ~~**No Firestore security rules.**~~ **CLOSED (2026-09-15).** `firestore.rules`
   (deny-all default; a signed-in user may touch only their own `users/{uid}/**`
   subtree) is deployed. `firebase.json` had **no `firestore` target**, so
   `firebase deploy --only firestore:rules` could not run at all until a
   `"firestore": { "rules": "firestore.rules" }` block was added — worth
   remembering if the rules are ever edited again. Deployed and confirmed:
   `✔ firestore: released rules firestore.rules to cloud.firestore`.
   Known consequence — **resolved 2026-09-15 (user call: hide it)**: the friends /
   leaderboard feature read **other** users' `users/{uid}/entries`, which these
   rules deny, so it was inert. The Discover tab and the home friends-strip were
   removed (nav is now Home · Progress · Scan · Profile; `_navIndex` 2 = profile)
   and the "Groups" promises were dropped from `PLAY_STORE_LISTING.md`.
   `lib/screens/discover_screen.dart` and `lib/services/social_service.dart` are
   kept **dormant and unreferenced** — do NOT re-wire them without a real design
   (a public weekly-total doc per user is the intended shape). Revisit after launch.
2. ~~**Cloud writes unguarded + offline persistence off.**~~ **CLOSED
   (2026-09-15):** all Firestore writes now go through the guarded `_cloud()`
   helper (local stays the source of truth), and offline persistence was never
   actually missing — on Android/iOS Firestore persistence is **on by default**
   (`Settings.persistenceEnabled` is nullable = platform default; the
   `enablePersistence()` API that IS required is web-only, and we don't ship
   web). The earlier audit note was wrong on that point. `storage_service.dart`
   awaits Firestore with no try/catch in `addEntry` (:338), `deleteEntry` (:351),
   `updateEntry` (:361), `loadEntriesFromCloud` (:368) and `saveGamification`
   (:560) — only `resetProfile` (:150) guards. There are ~10
   `await storage.addEntry(...)` call sites (e.g. `capture_screen.dart:134`,
   `manual_entry_screen.dart:180`), so one offline error can throw into the
   logging path even though the local save succeeded. Firestore offline
   persistence is never enabled. FIX: make the cloud mirror best-effort
   (try/catch; local stays source of truth) and enable offline persistence.
3. **Whole-list SharedPreferences blobs.** Every meal/water/weight/exercise
   mutation re-encodes the *entire* list and every read re-parses it
   (`_saveEntries`, `addWater`, `addWeightEntry`, `addExercise`). O(n) per write,
   O(n) startup. FIX when volume grows: sqflite/drift or per-day keys.

Minor / not blocking:
- ~~Cloud restore covers only profile/entries/paid; water/weight/exercise/league
  state are never read back on a new device.~~ **FIXED (2026-09-15):** water,
  weight, exercise and league are now mirrored to `users/{uid}/<collection>` on
  every write/delete, and `StorageService.syncUserDataFromCloud()` restores
  them (plus gamification) on sign-in. It only fills stores that are EMPTY
  locally, so a device with real data is never clobbered by an older cloud
  copy; failures are swallowed, never thrown. Covered by
  `test/storage_cloud_test.dart`.
- Very large screens (home 3046, onboarding 3481, progress 2542 lines) with no
  state-management layer; services are constructed per screen;
  `GamificationController.instance` is a process-global.
- No Firestore-rules tests and no CI.


## Asha parked (2026-09-14)
The in-app Asha AI chat is temporarily disconnected via `lib/config/features.dart`
(`Features.asha = false`): the Home concierge card is hidden, `asha_chat` quests
are never generated, and the shop's Asha voices are hidden. The chat screen,
prompts, gamification action and personality code are all retained dormant — flip
`Features.asha` to `true` to reconnect. The food analysis (`OpenAIService.
analyzeImage/analyzeText`) and the weekly summary are **not** affected.


## Onboarding funnel instrumentation (2026-09-14)
Baseline for "time-to-first-log" (the current focus). All events go through
`lib/services/funnel.dart` → `AnalyticsService` (local ring buffer) and carry
`since_open_ms`.
Events: `app_open` (main), `onboarding_start`, `onboarding_step` {step,name,ms},
`onboarding_questions_complete`, `signup` {method}, `paywall_view`,
`purchase_complete`, `home_reached`, `first_log` {method}. In a debug
`flutter run` they print as `[analytics] …` to the console.
Baseline procedure: fresh install (delete app) → walk Welcome→questions→plan→
sign-up→pricing→Home→first log (dev bypasses payment via the sandbox email
atuljaiswal1246@gmail.com on iOS), then read the `[analytics]` lines.
Decisions: paywall stays before Home; questionnaire may merge/defer/reorder
(locked BMR/macro math + option sets unchanged).


## Pace projection fix (2026-09-14)
Found during the E2E baseline: Fast and Moderate could both hit the 1500/1200
safety floor (same calorie goal) yet still *display* different kg/week and
timelines, because `weeklyChangeKg`/`weeksToGoal` used the nominal pace constants
instead of the actual goal. Fixed in `models/profile.dart`:
`weeklyChangeKg = (currentBurn − calorieGoal) × 7 ÷ 7700`, timeline divides by
that. When the floor binds, the faster paces now honestly show the same slower
rate, and the pace screen explains why ("… is your safe minimum, so a faster pace
isn't safe"). The locked calorie-goal formula and `weeklyRateKg` constants are
unchanged; `widget_test.dart` expectations updated (mod/fast lose → 27 wks,
slow gain → 51 wks).


## Free-worker delegation log (2026-09-14)
This Cal Matters session offloaded coding to the free zen workers via the Asha
harness (`~/Desktop/Asha/scripts/agent_run.sh --dir <repo> --model opencode/<model>
--auto --task @brief`). Brain = plan + brief + verify the diff (analyze/tests) +
commit; workers = edit. One task per dir at a time. Avoid paid models; **no free
deepseek** — use `opencode/big-pickle` (mechanical/writing) and
`opencode/mimo-v2.5-free` (code/reasoning); `muse-spark` is rate-limited.

| Task | Worker | Commit | Verified |
|------|--------|--------|----------|
| Deny-by-default `firestore.rules` | big-pickle | 929af42 | read diff, correct |
| DOB year-first picker (E2E-002) | mimo-v2.5-free | 9855b25 | analyze + tests |
| First-log CTA on Home (E2E-003) | big-pickle | 3c8fc83 | analyze + tests |
| `plan_view` funnel event | big-pickle | — | analyze + tests |
| Nutrition read-only report | mimo-v2.5-free | (no files) | confirmed no edits |
| kcal-from-macros fix + tests (E2E-004) | mimo-v2.5-free | 8ea5fec | analyze + 144 tests |

Recipe: (1) brain writes a precise brief with exact anchors + constraints +
"run flutter analyze"; (2) `agent_run.sh` runs `opencode run --auto`; (3) brain
reads `git diff` and gates on `flutter analyze` + `flutter test`; (4) commit with
"worker-written (model), brain-verified".

## WORKFLOW RULE (locked 2026-09-15) — mock first, then code
**Never start coding a screen without an approved mock.**
1. **Design first.** Produce a visual mock (image) of the screen — real assets, real
   composition, no placeholders/emoji-as-art.
2. **Show the mock** to the user.
3. **Get explicit approval.**
4. **Only then** write the Flutter code, matching the approved mock.
5. If an asset is missing (photo/illustration), get it first (or ask) — do not
   substitute a placeholder.

Rationale: shipping wireframes/placeholders (e.g. an emoji in a box) is not acceptable;
design judgment must happen BEFORE implementation, not during it. Image generation is
available for mocks — use it, then implement.

## ✅ FINALIZED — Onboarding screen 4 (Activity) — LOCKED
Locked 2026-09-15 (commit `6a98eb4`). **Do not change without an explicit new request.**
`lib/screens/onboarding_flow.dart` (`_ActivityStep` + the shared `_IllustCard`), step
index 3, progress **4/6**.

Locked composition — four illustrated cards in a 2x2 grid (same treatment as screen 1):
- **No workout** → sofa (*Mostly sitting*) — value `none`
- **1–2 times a week** → walking (*Light activity*) — value `1to2`
- **3–5 times a week** → running (*Active*) — value `3to5`
- **6+ times a week** → dumbbells (*Very active*) — value `6plus`
- Selected = orange border + glow + check badge. Default selection `3to5`.
- Assets: `assets/onboarding/act_{none,1to2,3to5,6plus}.jpg`.

**Math note (important):** splitting the old 0–2 bucket into `none` and `1to2` does NOT
change the calculator — both map to the locked **1.2** multiplier via `Profile`'s default
branch. `_workoutSummary` gained labels for both. Don't "fix" this into two multipliers.

Shared component: `_IllustCard` + `_IllustData` are used by screens 1 and 4 (2x2,
image-on-top, label + sub-line, aspect 0.82). Reuse them for any further illustrated
option grid.

## ✅ FINALIZED — Onboarding screen 3 (Height & weight) — LOCKED
Locked 2026-09-15 (commits `352c259`, `79b6b88`, `7231a4e`). **Do not change without an
explicit new request.** `lib/screens/onboarding_flow.dart` (`_BodyStep`, `_BodyCard`,
`_Ruler`, `_BmiChip`), step index 2, progress **3/6**.

Locked composition (Option A — approved from `design/mock_height_weight.html`):
- Two illustrated cards (`assets/onboarding/body_height.jpg` ruler,
  `body_weight.jpg` scale) with **big values** + inline unit pills
  (**ft/in ⇄ cm**, **kg ⇄ lbs**) + a **drag ruler** (36 px tall, ticks scroll under
  the orange centre line) and a chevron that opens the precise wheel sheet.
- **Live BMI chip** below: value + band (`Below range / Healthy / Above range / High`),
  colour dot and a marker on a gradient track. Neutral wording on purpose (Play
  policy — no medical claims); maths uses only the entered height/weight.
- Sub-copy: "Slide or tap — no typing needed."

**Drag must stay smooth (do not regress):**
- The drag updates ONLY the body-step subtree; the flow value is synced with a
  *silent* callback (`onHeightDrag/onWeightDrag` — no `setState` on the flow), else
  the whole onboarding screen rebuilds per tick and janks.
- `_Ruler` keeps a **fractional phase** so ticks scroll continuously; only whole
  values are reported upward. Haptics fire per unit.
- `test/body_step_test.dart` covers the unit pills and the drag — keep it green.

## ✅ FINALIZED — Onboarding screen 2 (You / "First things first.") — LOCKED
Locked 2026-09-15 by the user (commit `ccbbaa0`). **Do not change without an explicit
new request.** Implemented in `lib/screens/onboarding_flow.dart` (`_YouStep`), step index 1,
progress **2/6**.

Locked composition:
- Doodle "///" + left-aligned "First things first." + sub-copy.
- **Name** field (person icon), **Date of birth** tap-field (calendar icon + chevron).
- **Male / Female / Other** avatar cards (Leonardo art in `assets/onboarding/avatar_*.png`);
  selected = orange border + check badge.
- "Better choices. Healthier you." + `bowl_illustration.png` on the right.
- Black **Continue** (disabled until name + DOB + sex are set).
- Screen fits without scrolling.

**DOB picker (locked behaviour)** — `lib/widgets/date_picker_3step.dart`, 3 steps
year → month → day, opened via `showDatePicker3Step`:
- Year step shows **20 years per screen, 4 per row** (starts **1990–2009**), with
  ‹ › chevrons that page by 20 years, clamped to first/last year.
- The sheet **hugs its content** (grid is `shrinkWrap` inside a `Flexible`); the day
  step still scrolls. Never let it sit at 72% with empty space again.
- Do NOT go back to a single long year grid, and do NOT drop to 10-per-screen
  (user found it too small).

Accepted as-is by the user (do NOT "fix" unprompted): the "Other" avatar reads feminine,
there is generous empty space below the illustration, and the bowl illustration carries
its own cream background block.

> NOTE: onboarding **screen 1 (Goal, 1/6) is NOT locked** — the user intends to
> rework it. Don't assume it's frozen.

## ✅ FINALIZED — First screen (locked 2026-09-15, do NOT touch)The user signed off on the first screen. **Do not change it** without an explicit new
request. Commit `f4380c4` (preceded by `4e92a77`, `0e0b227`).

`lib/screens/welcome_screen.dart`:
- **Brand on top** (app icon + "Cal Matters" + "Track · Eat · Feel Better").
- **Framed carousel**, capped at **≤50% of screen height** (`MediaQuery.sizeOf().height * 0.5`),
  white 6px frame + rounded 30 + border + shadow. One unit per slide:
  image + **its title inside the image at the bottom** (white, centred).
- 4 slides, each with its own contextual headline + a **Try** button *below* the image
  (centred in the gap): scan → search → activity → water. Auto-advances every 4s.
- **Get started** (black CTA) + **Sign in** pinned at the bottom; **no scrolling**.
- Removed (per user, do not re-add): separate 4-icon benefit row, the sub-headline
  "Log your meals…", the footer "AI-powered · Terms · Privacy", the corner blobs,
  and the nutrition overlay card on the hero.
- Palette = existing theme tokens (`AppColors`), NOT a new brand system.

**Assets** (Leonardo-generated, in `assets/onboarding/`): `food_scan.jpg`,
`food_palak_paneer.jpg`, `feature_exercise.jpg`, `feature_water.jpg`,
`avatar_male/female/other.png`, `bowl_illustration.png`, `hero_bowl.jpg`.

## Try-before-you-buy demos (locked with the first screen)
Each slide's **Try** button opens a demo (no account, no payment):
- `lib/screens/demo/demo_scan_screen.dart` — **pure simulation**: scan beam →
  "Analysing…" → result card slides up with a count-up + macro bars and a
  "Demo result" badge; refresh cycles 5 sample Indian dishes. **No camera, no AI,
  no cost** (the user explicitly chose a dummy demo over real recognition).
- `demo_search_screen.dart` — **real** search over the offline Indian DB
  (`assets/merged_foods.json`, 1,712 items) + animated macro breakdown.
- `demo_exercise_screen.dart` — live dashboard (steps/ring/week bars grow); "Log a
  demo workout" bumps today's numbers.
- `demo_water_screen.dart` — tap droplets, glass fills, celebrates at the goal.
- Shared shell: `demo/demo_common.dart` (`DemoBadge/Header/Cta/Card`, `MacroBar`,
  `CountUp`, `RingStat`).

## UI improvement loop (locked 2026-09-16) — how to keep improving without the user
The user asked for a continuous improvement loop. Run it per screen, in this
order, and do not skip the "look" step:

1. **Render** — `flutter test --update-goldens test/app_screens_preview_test.dart`
2. **Look** — open the PNG, and **crop with PIL before judging** (low-res
   whole-page views lie; several "bugs" were only downscaling).
3. **List defects** against the house rules below.
4. **Fix** the top one or two — small commits, one idea each.
5. **Verify** — `flutter analyze` (0 errors) + `flutter test` (all pass; the
   goldens must pass *without* `--update-goldens` too).
6. **Commit** with what changed and why.

**House rules distilled from the locked screens** (onboarding, welcome, auth,
paywall — the work the user personally signed off):
- **One dominant idea per screen.** One hero; everything else supports it.
- **Big, left-aligned type.** Titles are 20–26px w800 with negative letter
  spacing, not 12–13px everywhere.
- **One accent colour + near-black.** The palette is cream/near-black plus the
  orange accent; macro red/orange/blue are the only other colours allowed.
  Do not add new hues.
- **One primary CTA**, full width, black (white in dark mode). Everything else
  is a secondary tile or a text link with a Material Symbol.
- **Real illustrations, never emoji-as-art.** Use `EmptyIllustration` +
  `assets/illustrations/*` (Leonardo, cream/sage/coral).
- **No filler.** If a card's label is vague ("What's cooking?", "Start tracking
  your body story") it is filler — delete it or rename it plainly.
- **Label first, then the value** on stat tiles (label / number / unit).
- **Material Symbols** for functional icons; decorative gamification emoji only.

## Main-screen golden harness (2026-09-16) — the eyes for non-locked screens
`test/app_screens_preview_test.dart` renders the **real** Home (all tabs),
Progress, Profile, first-run Home/Progress, dark mode, and Insights, History,
Achievements, the gamification hub, Shop, League, Settings, Quick picks, manual
entry and Capture — at iPhone **and** Android widths, with real Inter /
MaterialIcons / **MaterialSymbols** / Apple-emoji fonts, real asset images,
seeded entries/water/weight and the gamification controller live. Any
RenderFlex overflow fails the test.
```sh
flutter test --update-goldens test/app_screens_preview_test.dart   # regenerate
flutter test                                                       # verify
```
Then open `test/goldens/app_*.png` and look. Notes learned the hard way:
- The golden PNGs are 3× (e.g. 1179×12600 for a "tall" full-page capture);
  crop with PIL before eyeballing details — low-res whole-page views lie
  (several "bugs" I thought I saw were just downscaling).
- Material Symbols are a **package font**: register them as
  `packages/material_symbols_icons/MaterialSymbolsRounded`, and **await** the
  `FontLoader.load()` futures or the icons render as tofu squares.
- Mirror `main.dart`'s theme exactly (family on **every** textTheme entry):
  a bare `DropdownButton.style` otherwise falls back to the test font and
  renders text as solid black boxes — that is a harness artefact, not a bug.
- Plugins must be stubbed (`connectivity_plus` method + event channels) and
  `AuthService` subclassed (`_FakeAuth`) — the screens must tolerate their
  absence; that tolerance is part of what the harness asserts.

**Illustration family (2026-09-16):** `assets/illustrations/*.jpg` are
Leonardo-generated flat art (cream/sage/coral, matched to `assets/onboarding/`),
512px JPEG, used via `widgets/empty_illustration.dart` for empty states. The
Leonardo key is NOT in the repo; the helper lives in the session temp dir and
**must call the API with `curl`** (urllib gets a Cloudflare 403).


`test/screen_preview_test.dart` renders the real screens at 1179×2556 (iPhone class)
with the **real Inter + MaterialIcons fonts and real image assets** and writes PNGs to
`test/goldens/`; any RenderFlex overflow fails the test. Run:
```sh
flutter test --update-goldens test/screen_preview_test.dart   # regenerate
flutter test                                                   # verify (all must pass)
```
Then **open the PNGs and look at them** before reporting. Notes:
- Load the icon font from the Flutter cache:
  `/opt/homebrew/Caskroom/flutter/<ver>/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf`.
- Asset images only paint if `precacheImage` runs inside `tester.runAsync`.
- Set `fontFamily: 'Inter'` in the test theme — the default test font is far wider and
  causes false overflows.
- Widget tests need `AuthService._auth` lazy (done) and, for the scan demo,
  `enableCamera: false` (the demo is simulated now, so no plugin is involved).

## iOS device workflow (current)
- Build: `flutter build ios --profile`; install/launch via `xcrun devicectl` (see env
  section). **The device must be unlocked and awake** or install/launch fails with
  `Locked` / error 4016 / 10002.
- Xcode 27.0: the license must be accepted (`sudo xcodebuild -license accept`), and
  Xcode's "External Agent Access" should be set to **Always** for agent tooling.
- User pushes commits; brain commits locally only when asked.

## Sign in with Apple — PARKED (tried 2026-09-15, blocked by Apple's paywall)
**Verdict: needs the paid Apple Developer Program ($99/yr).** I wired it fully and
Xcode refused to sign:

> Cannot create a iOS App Development provisioning profile for
> "com.neharohilla.calorietracker". **Personal development teams, including
> "Atul Jaiswal", do not support the Sign In with Apple capability.**
> Provisioning profile ... doesn't include the com.apple.developer.applesignin entitlement.

Status of each piece:
- **Firebase**: Apple provider ENABLED. Note the console says "Services ID (not
  required for Apple)" and the OAuth code flow is optional — for the native iOS
  flow **no Services ID and no `.p8` are needed** (that requirement is only for the
  web/Android flow). So the Firebase side is genuinely free.
- **Code (done, dormant)**: `sign_in_with_apple` + `crypto` added; `AuthService
  .signInWithApple()` implemented (nonce + `OAuthProvider('apple.com').credential`);
  the button exists in `auth_screen.dart` (iOS/macOS only); `Features.appleSignIn`
  = **false** to keep it hidden.
- **Entitlement (ready, un-wired)**: `ios/Runner/Runner.entitlements` exists with
  `com.apple.developer.applesignin`. It is deliberately NOT referenced from
  `project.pbxproj`, because signing fails while the team is personal.

**To enable after enrolling** (2 minutes):
1. developer.apple.com → App ID `com.neharohilla.calorietracker` → tick **Sign in
   with Apple** (Xcode can also do this once the team is paid).
2. `project.pbxproj`: add `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`
   to the three Runner (app) build configs.
3. Flip `Features.appleSignIn = true` and rebuild.

**Why it matters**: App Store guideline **4.8** requires it once Google sign-in is
offered, so this belongs on the **App Store submission checklist** (Play does not
need it). Decision: ship Play first with Google + email; add Apple during the iOS pass.

## Paywall redesign (2026-09-15) — approved variant B
`PricingScreen` (lib/screens/pricing_screen.dart). The old hero was a grey
`#F7F7F7` block + a fake phone mock + a **150px black gradient with a 34px
"Cal Matters" wordmark** over it — that combination is what looked washed out
(and it hid the mock's lower half). Replaced with:
- **Hero = a real meal + its macros**: `assets/onboarding/food_palak_paneer.jpg`
  with a floating white macro card (Palak Paneer · 265 kcal · Protein 14g /
  Carbs 9g / Fats 19g, animated bars).
- Headline **"Keep your plan"** + a plan line built from the saved profile
  (`_planLine`: kcal/day · goal · workouts).
- Three benefit rows; **Annual** card with a `BEST VALUE · SAVE 17%` badge and
  `≈ ₹83/month · 3 days free`; **Monthly** `₹100/month · 3 days free`.
- CTA **"Start 3-day free trial"** + "Then ₹1,000/year. Cancel anytime." and a
  legal row: **Terms · Privacy · Restore purchases** (Terms/Privacy open the
  Firebase-hosted pages via `url_launcher`).
- `_PlanOptionCard` now always shows the badge and uses one consistent radio
  (filled black circle + check when selected).

Also hardened `BillingService._init()` (`isAvailable()` .catchError + try/catch)
so a billing/plugin failure can never throw into the paywall — the screen still
renders. `test/screen_preview_test.dart` has a `paywall` golden.

## Store billing: Play NOW, App Store LATER THIS YEAR
- **Billing is configured for Android/Play only** (products created in Play
  Console; `in_app_purchase` is cross-platform, so StoreKit needs the same two
  product IDs created in App Store Connect — `cal_matters_monthly` /
  `cal_matters_yearly` — no code change).
- On iOS today the store returns no products, so the paywall shows
  "Purchases open at launch on the App Store." and the CTA explains instead of
  silently doing nothing.
- **App Store checklist (do before submitting)**:
  1. Enrol in the paid Apple Developer Program ($99/yr) — the current team is a
     personal/free team, which also blocks the capabilities below.
  2. **Sign in with Apple** (guideline 4.8, required since Google sign-in
     exists): flip `Features.appleSignIn = true` + wire the entitlement
     (`ios/Runner/Runner.entitlements` already exists; add
     `CODE_SIGN_ENTITLEMENTS` to the Runner configs).
  3. Create the two subscriptions in App Store Connect with the SAME IDs.
  4. Add the App Store privacy questionnaire (photos are sent for analysis,
     not stored) + the hosted privacy/terms URLs.

## ✅ FINALIZED — Payment screen (paywall) — LOCKED
Locked 2026-09-15 by the user ("that's it, lock it"). Commits: `3bbb413` (redesign),
`fe2f222` (compact), `f056ebe` (filler removed), `00c2a29` (back + bigger hero),
`2ca5d16` (both plans visible), `1c83f4d` (centred dish).
**Do not change without an explicit new request.** `PricingScreen` in
`lib/screens/pricing_screen.dart` (`_PaywallHero`, `_PaywallMacro`, `_BenefitRow`,
`_PlanOptionCard`). (Extracted out of the legacy `onboarding_screen.dart`, which was
deleted 2026-09-15 in `92b36dd`.)

Locked composition, top → bottom:
1. **Back button** (optional `onBack`; shown when provided — the funnel returns to
   the plan step, the Settings dev preview pops).
2. **"Keep your plan"** + a plan line built from the saved profile
   (`_planLine`: kcal/day · goal · workouts).
3. **Hero = a real meal + macros**: `assets/onboarding/food_palak_paneer.jpg`,
   `BoxFit.cover` **centred on both axes**, with a compact white card over the
   bottom (Palak Paneer · 265 kcal · one row of macro chips: Protein 14g /
   Carbs 9g / Fats 19g).
4. Three benefit rows (check icon): photo → calories · 1,800+ Indian foods
   offline · targets/pace/progress.
5. **Annual** (selected) with an inline `SAVE 17%` chip: `₹1,000 / year`,
   *≈ ₹83/month · 3 days free*; **Monthly**: `₹100 / month`, *3 days free*.
6. CTA **"Start 3-day free trial"** + *"Then ₹1,000/year. Cancel anytime."* +
   legal row **Terms · Privacy · Restore purchases** (Terms/Privacy open the
   Firebase-hosted pages via `url_launcher`; Restore stays wired to billing).

Hard-won rules (don't regress):
- **Both plan cards must be visible without scrolling**, so the section is a
  non-scrolling Column and the **hero is `Expanded`** — it takes exactly the
  space left over. Do NOT give the hero a fixed height/percentage again (that
  pushed Monthly below the fold).
- **No filler lines** on this screen. "Purchases open at launch" (a dev-only
  state) and "Secure payment…" were both deleted on request.
- **One design for both stores** — no platform-branching copy: the paywall is
  identical on Google Play and the App Store.
- `test/screen_preview_test.dart` has `paywall` (iPhone) + `paywall_android`
  goldens, and the Android-size sweep fails on any overflow.

## ✅ FINALIZED — Onboarding screen 5 (Target & pace) — LOCKED
Locked 2026-09-15. Commits: `c4d4582` (redesign), `f5dbd27` (label overlap),
`8cb4a38` (hide duplicate Moderate). **Do not change without an explicit new
request.** `lib/screens/onboarding_flow.dart` (`_TargetPaceStep`,
`_ProjectionCard`, `_TrendPainter`, `_PacePill`), step index 4, progress **5/6**.

Locked composition:
1. **Projection card** — a weight-trend curve from *Now X kg* to *Goal Y kg*
   (animated), a dashed goal line, and the numbers it implies: **kcal/day ·
   ~timeline · kg/week**. The labels sit clear of the line (the chart reserves
   26px above and below — otherwise "Now 70 kg" overlaps the curve).
2. **Target weight** card with the same **drag ruler** as screen 3 (plus the
   chevron for the precise wheel), clamped so it can never cross the current
   weight the wrong way (`lose`: 30..weight-1, `gain`: weight+1..200) — that
   keeps the Continue gate from going stale during a silent drag.
3. **Pace pills** showing BOTH rate and timeline (Slow 0.1 kg/wk · Moderate
   0.5 · Fast 0.9). **When the kcal safety floor makes Moderate produce the
   same plan as Fast (or Slow), the duplicate Moderate pill is HIDDEN** and the
   selection moves to the pace it matched, so profile + UI stay in sync.
4. Safety-floor explanation when the floor binds, and the
   "I don't have a target, just tracking" toggle.

Rules: all numbers come from the **locked Profile maths** (`_planStats`) — never
invent a pace the plan can't safely deliver. Drags use the silent-callback
pattern (no whole-screen rebuild). `test/target_pace_test.dart` covers the
live projection and the hidden-Moderate case.

## ✅ FINALIZED — Onboarding screen 6 (Plan ready) — LOCKED
Locked 2026-09-15 (commit `2366aa8`). **Do not change without an explicit new
request.** `_PlanReadyScreen`, `_PlanHero`, `_MacroCol`, `_SummaryRow`,
`_SparkGlyph`, `_BarsGlyph`, step index 6, progress **6/6**.

Locked composition:
1. Orange check badge → **"Your plan is ready"** → *"Hi {name} — here's your
   daily target."*
2. **White hero card mirroring Home's language**: a big **orange calorie ring**
   (animated sweep) with the daily kcal inside, then **Protein / Carbs / Fats**
   columns with brand colours and count-up numbers.
3. **"Your goal"** row with a mini projection sparkline; **"Workouts"** row with
   a mini weekly-bars glyph.
4. *"You can change any of this later in Settings."*
5. CTA **"Start tracking →"**.

Rule: keep it consistent with Home (ring + macros are the app's own language);
don't reintroduce the old dark summary card or plain label/value rows.

## ✅ FINALIZED — Sign-up screen — LOCKED
Locked 2026-09-15 (commit `78e53e7`, approved from `design/mock_signup.html` variant A).
**Do not change without an explicit new request.** `lib/screens/auth_screen.dart`
(`AuthScreen`, `PlanRecap`, `_RecapCard`).

Locked composition (sign-up variant):
1. **Brand mark** at the top (app icon + "Cal Matters") — anchors the screen.
2. **"Save your plan"** + *"Create an account to keep your targets and start
   logging."* — the account reads as saving the work they just did.
3. **Recap card** (`PlanRecap`, cream) echoing the plan back:
   kcal/day · your goal · workouts — filled from the live profile in
   `onboarding_flow.dart`.
4. **Sign up with Google** (black, white mono G) · **Continue with email**
   (white outlined) · **Sign up with Apple** (implemented but hidden — see the
   Apple section; blocked by Apple's paid program).
5. **"Already have an account? Sign in"**, then
   *"By continuing you agree to our Terms of Service and Privacy Policy."*
6. Sign-in variant: "Welcome back" / "Sign in to continue."
7. **Layout**: brand anchored at the TOP, the heading/copy/recap/buttons block
   centred in the middle, and the legal line pinned at the BOTTOM (previously
   everything floated as one block with big voids above and below).
8. **Terms of Service / Privacy Policy are tappable links** (they open the
   Firebase-hosted pages via `url_launcher`), matching the paywall — they were
   plain grey text before.
9. **Background is `AppColors.bg`** (warm #FAF9F7), not pure white, so the flow
   does not seam between onboarding -> auth -> paywall -> Home. The paywall was
   switched to the same background.

Rules:
- **Never say "free"** — the app is paid; the user corrected this explicitly.
- `test/screen_preview_test.dart` has a `signup` golden. The harness must load
  the **FontAwesome brands** font (family `packages/font_awesome_flutter/
  FontAwesomeBrands`) or the Google "G" renders as a box.

## ✅ FINALIZED — Onboarding screen 1 (Goal) — LOCKED
Locked 2026-09-15 (commits `8c4886a` illustrated cards, `6a98eb4` shared card
refactor). **Do not change without an explicit new request.** `_GoalStep` +
the shared `_IllustCard` / `_IllustData` in `lib/screens/onboarding_flow.dart`,
step index 0, progress **1/6**. (This was the screen the user originally wanted
to rework — it is now signed off.)

Locked composition — **four illustrated cards in a 2×2 grid** (the same
treatment as screen 4, via the shared `_IllustCard`):
- **Lose weight** → plate + calorie ring + downward arrow · *Burn more than you eat* — value `lose`
- **Maintain weight** → balanced scale of food · *Stay right where you are* — value `maintain`
- **Gain weight** → protein bowls + board · *Eat more, build up* — value `gain`
- **Just exploring** → compass over a bowl · *See what the app can do* — value `exploring`
- Selected = orange border + soft glow + check badge. Default `lose`.
- Assets: `assets/onboarding/goal_{lose,maintain,gain,explore}.jpg` (Leonardo,
  flat cream/coral/sage — the app's illustration family, same as the avatars,
  the bowl and the activity cards).

Rules:
- The illustrations are the point — do **not** fall back to Material icons on
  signature-colour tiles (an earlier attempt was rejected: "not generic").
- The card values are the locked goal values; the maths for every option lives
  in `Profile` and must not change.
- `_IllustCard` is shared with screen 4 — change it once, for both.
