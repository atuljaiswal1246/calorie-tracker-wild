# HANDOFF — Cal Matters (start here)

Written 2026-09-15 23:55 IST at commit `67ae271` (branch `main`).
Repo: `/Users/neharohilla/Desktop/calorie_tracker` · Firebase project `calorie-tracker-80a0b`
Owner: Atul (does not read code — speak in plain language, see "Working agreement").

Read order for a new session: **this file → `AGENTS.md` → `AUDIT_REPORT.md`**.
`AGENTS.md` is the long-lived memory (locked screens, environment, hard-won rules);
this file is the current snapshot and the plan.

---

## 1. Where the product stands

**Live / done**
- Android app in **Google Play closed testing** (day ~13 of the mandatory 14), 12+ testers.
  Plan from the user: closed → **open testing** → **production**, not immediately.
- Store pages hosted on Firebase Hosting: `https://calorie-tracker-80a0b.web.app`
  (index, privacy, terms, delete-account). Privacy discloses Firebase Analytics.
- Payments: **Play Billing live**, products `cal_matters_monthly` / `cal_matters_yearly`,
  each with a **3-day free trial**. A real tester purchase has been verified.
- **Firestore security rules deployed 2026-09-15** (deny-all default, user can touch only
  their own `users/{uid}/**`). Cloud mirror + restore-on-sign-in for profile, meals,
  water, weight, exercise, league, gamification (restores only into empty local stores).
- Firebase Analytics forwarding the onboarding funnel (`analytics_service.dart`).
- **Play Data safety questionnaire updated and submitted for review** (added
  App activity → App interactions, and Device or other IDs; both Analytics, required).
- Paywall, onboarding 1–6, first screen, sign-up and sign-in are **locked** (see AGENTS.md).

**Parked / not shipped**
- **Friends & leaderboard: hidden** (2026-09-15, user call). It read other users'
  entries, which the new rules deny. The Discover tab and home strip are gone;
  `discover_screen.dart` + `social_service.dart` remain dormant and unreferenced —
  do not re-wire without a public-aggregate design. "Groups" promises were removed
  from the repo listing copy.
- **Sign in with Apple: parked** — Apple blocks personal development teams. Code is
  written and dormant behind `Features.appleSignIn = false`; needs the $99 program.
- **In-app Asha chat**: parked behind `Features.asha = false` (food scan is NOT affected).

**iOS**
- Builds and installs on the user's iPhone; Apple sign-in blocked as above. StoreKit
  products don't exist yet, so iOS shows "Purchases open at launch on the App Store."

## 2. What the last session changed

Commits `f65de1e`, `50de4cf`, `5779f5b`, `67ae271` (plus `a7ec977`, `4d306d0`, `92b36dd`,
`f97a860`, `beaf325` earlier the same day):
1. `firebase.json` was **missing a `firestore` target**, so `firebase deploy --only
   firestore:rules` had never been able to run — that is why the rules committed in
   `929af42` were not live. Added the target and deployed; confirmed released.
2. Friends surfaces removed (nav is now Home · Progress · Scan · Profile).
3. Settings: added the medical disclaimer, corrected the version label (said v0.9.5).
4. Docs: Play listing copy corrected (no more "your data stays on your device", no
   Groups), `AGENTS.md` stale pointers fixed, `AUDIT_REPORT.md` E2E-001 signed off.

`flutter analyze`: no errors (165 pre-existing infos/warnings). `flutter test`: **169 pass**.

## 3. Plan forward (in order)

| # | Step | Owner | Notes |
|---|------|-------|-------|
| 1 | Update the **Play Console listing text** to match `PLAY_STORE_LISTING.md` (drop the Groups line, fix the "data stays on your device" claim) | **user** | The repo doc is fixed; the Console copy is a separate edit nobody has done yet |
| 2 | Watch the **Data safety review** result (Publishing overview / Inbox) | user | Submitted 2026-09-15 |
| 3 | Finish closed testing (day 14), request **production access**, then move to open testing | user | Google decides; keep testers opted in |
| 4 | Cut the next release **0.9.6+10**: verify the locked flow on a real device, then `flutter build appbundle --release` (Play needs an **AAB**, not the profile APK) | assistant | ~3 days out, per the user. Release signing is already configured via gitignored `android/app/release-key.jks` |
| 5 | Back up `android/app/release-key.jks` somewhere safe (password manager / encrypted drive) | **user** | It is gitignored, so it is NOT on GitHub. Losing it means no more updates to the same Play listing |
| 6 | `git push` the ~10 unpushed commits to `github.com/atuljaiswal1246/calmatters-app` | assistant (on request) | Local `main` is ahead of `origin/main` |
| 7 | After launch: Hindi/localisation, DPDP compliance (Nov 2026), iOS ($99 program → Apple sign-in → StoreKit with the same product IDs), friends public-aggregate design, performance profiling, prefs O(n) write tidy-up | both | See `AUDIT_REPORT.md` §7–8 for the full gap list |

## 4. Open decisions for the user

- Nothing blocking. The two real post-launch decisions are **Hindi support** and
  **DPDP compliance** (mandatory Nov 2026) — deliberately deferred until after launch.

## 5. Working agreement (do not drift from this)

- **The user does not read code.** Report in plain language: what changed, what it costs,
  what needs their decision. Never hand them a technical task without step-by-step UI
  instructions (the Play Console walkthroughs in the last session are the model).
- Surface only: **decisions, money, and things only they can do** (Play Console, their
  Apple account, purchases on their side). Everything technical is ours to handle.
- **Mock/visual approval before coding a screen**; screens marked LOCKED in `AGENTS.md`
  must not be touched without an explicit new request. Never claim "done" without seeing
  pixels (`test/screen_preview_test.dart` → `test/goldens/`, plus the Android-size sweep).
- **Config, env and scripts need explicit user OK** before changing (the `firebase.json`
  rules target was one such OK).
- Check in early and often — verify in the working tree, not from a self-report.
- Session = one client; app close ≠ stack close. Never commit secrets (`.env` is gitignored).

## 6. Environment quick reference

- Harness: `flutter test --update-goldens test/screen_preview_test.dart`, then open the PNGs.
- No `timeout` on macOS — use `perl -e 'alarm N; exec @ARGV'`.
- Android: `adb` at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`
  (no device attached last session). APK: `~/Desktop/CalMatters-0.9.6-profile.apk`.
- iOS device: devicectl id `6C0FE134-9424-5153-9BD9-6FB6D916666B`, bundle
  `com.neharohilla.calorietracker`. **The iPhone must be unlocked/awake** or the install
  fails; kill stale `Runner` processes first.
- Firebase CLI is installed and authenticated; `firebase deploy --only hosting` works.
- AI calls go through the Cloudflare worker proxy — no API key ships in the app.
- Full detail (fonts for goldens, Leonardo helper, sandbox email, etc.): `AGENTS.md`.
