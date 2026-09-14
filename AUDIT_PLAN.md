# Cal Matters — Comprehensive Audit Plan

## Purpose
Thoroughly evaluate Cal Matters against industry competitors across 8 dimensions.
No coding until this audit is complete and documented.

---

## Competitors to Benchmark Against

| App | Market | Price | Key Strength |
|-----|--------|-------|-------------|
| **HealthifyMe** | India (leader) | ₹999/mo | Best Indian food DB, AI coach Ria, human nutritionists |
| **MyFitnessPal** | Global (leader) | ₹6,500/yr | 14M+ food entries, barcode scanner, device integrations |
| **FitTrack AI** | India | Free (Pro ₹99/mo) | Free photo logging, Indian food focus |
| **Nutrimate** | India | ₹399/mo | 1L+ Indian foods, WhatsApp logging, family tracking |
| **Cronometer** | Global | Free / ₹2,500/yr | Best micronutrient tracking, verified DB |
| **Lose It!** | Global | Free / ₹3,500/yr | Cleanest UI, simplest UX |
| **YAZIO** | Global | Free / paid | Fasting + tracking, international |
| **PlateLens** | Global | Free | Highest accuracy (±1.0% MAPE) |

---

## Audit Dimensions (8 Total)

### 1. UI AUDIT
**What to evaluate:**
- Visual design quality (colors, typography, spacing, consistency)
- Dark mode implementation quality
- Icon design and consistency
- Animation quality and smoothness
- Empty states (no data yet)
- Loading states
- Error states
- Responsive layout (different screen sizes)
- Platform conventions (iOS vs Android feel)
- Polish level vs competitors

**Method:**
- Screenshot every screen of Cal Matters (light + dark)
- Screenshot equivalent screens in HealthifyMe, MyFitnessPal, Lose It!
- Side-by-side comparison per screen
- Score each screen 1-10

**Deliverable:** UI scorecard with screenshots and ratings

---

### 2. UX AUDIT
**What to evaluate:**
- Onboarding flow (steps to first value)
- Time to log a meal (photo vs manual vs barcode)
- Navigation ease (can user find features?)
- Keyboard behavior (dismiss, focus chaining)
- Pull-to-refresh availability
- Haptic feedback
- Error recovery (what happens when AI fails?)
- Offline behavior
- Settings discoverability
- Data export ease

**Method:**
- Time ourselves logging a meal via each method (photo, manual, barcode, quick-pick)
- Compare to HealthifyMe and MyFitnessPal meal logging time
- Walk through each user flow and note friction points
- Test on both Android and iPhone

**Deliverable:** UX friction map with timings and improvement suggestions

---

### 3. BUG AUDIT
**What to evaluate:**
- App crashes or freeze scenarios
- Edge cases (no internet, rapid tapping, background/foreground)
- Notification reliability
- Data persistence (does data survive app kill?)
- Cloud sync conflicts
- Barcode scanner edge cases
- Camera permission flow
- Dark mode visual glitches
- Keyboard overlay issues
- Navigation stack issues (back button behavior)

**Method:**
- `flutter analyze` (code quality)
- `flutter test` (unit tests)
- Manual testing on real device (Android + iPhone)
- Stress test: rapid actions, network disconnect, background/foreground

**Deliverable:** Bug list with severity (critical/high/medium/low) and reproduction steps

---

### 4. FUNCTIONALITIES AUDIT
**What to evaluate:**
- Feature completeness vs competitors
- What we have that competitors don't
- What competitors have that we don't
- Quality of each feature (not just existence)
- Indian food accuracy
- Barcode scan success rate
- AI food recognition accuracy
- Calorie calculation accuracy (BMR/TDEE)
- Macro tracking completeness
- Micronutrient tracking (fiber, sugar, sodium — do we go beyond?)
- Water tracking
- Step/exercise tracking
- Weight tracking
- Body measurements
- Meal plans quality
- Achievements/gamification

**Method:**
- Feature matrix comparison (us vs each competitor)
- Test AI food recognition with 10 real Indian food photos
- Verify BMR/TDEE calculations against known formulas
- Test barcode scanner with 20 products

**Deliverable:** Feature matrix table + accuracy test results

---

### 5. AI USAGE AUDIT
**What to evaluate:**
- Food recognition accuracy (our AI vs HealthifyMe Ria vs MyFitnessPal)
- Response time per scan
- AI chatbot quality (Asha vs HealthifyMe Ria vs MyFitnessPal assistant)
- Prompt engineering quality
- Error handling (what happens with bad photos?)
- "No food detected" frequency
- JSON parsing reliability
- Cost per AI call
- Model choice appropriateness
- Privacy (what data is sent to AI?)

**Method:**
- Send identical food photos to Cal Matters AI, HealthifyMe, MyFitnessPal
- Compare calorie estimates for same meals
- Test with tricky images (empty plate, mixed thali, street food, dark lighting)
- Measure response times
- Review prompt in `openai_service.dart`

**Deliverable:** AI accuracy report with comparison table

---

### 6. COST EFFECTIVENESS AUDIT
**What to evaluate:**
- App price to user (our pricing vs competitors)
- Free tier quality (what's free vs what's paid)
- AI cost per call (proxy cost breakdown)
- Infrastructure cost estimate (Firebase, Cloudflare)
- Revenue model viability
- Price sensitivity for Indian market
- Price sensitivity for global market

**Method:**
- Pricing comparison table
- Free tier feature comparison
- Calculate cost per user per month (AI + infra)
- Estimate break-even point
- Compare value proposition

**Deliverable:** Cost analysis with pricing recommendations

---

### 7. LAUNCH READINESS — INDIAN MARKET
**What to evaluate:**
- Indian food database coverage (regional cuisines?)
- Hindi/regional language support
- INR pricing
- Payment methods (UPI, cards, netbanking via Play Store)
- Indian dietary patterns (veg/non-veg, fasting, festival foods)
- Indian body type calculations (BMR formulas appropriate?)
- Google Play Store listing (screenshots, description, keywords)
- ASO (App Store Optimization) for Indian search terms
- Privacy policy compliance (India DPDP Act)
- Data storage location
- Customer support plan
- Marketing readiness

**Method:**
- Check if BMR formula works for Indian body types
- Test with regional foods (South Indian, North Indian, Bengali, Gujarati)
- Review Play Store listing
- Check DPDP Act compliance
- Review privacy policy

**Deliverable:** Indian market readiness checklist with gaps

---

### 8. LAUNCH READINESS — GLOBAL MARKET
**What to evaluate:**
- iOS App Store readiness
- International food coverage (not just Indian)
- Multi-language support
- USD/EUR/GBP pricing
- GDPR compliance (EU)
- CCPA compliance (California)
- App Store guidelines compliance
- Accessibility (VoiceOver, TalkBack)
- International payment methods
- Global marketing strategy
- Competitive positioning outside India

**Method:**
- Review App Store guidelines checklist
- Test with non-Indian foods
- Check accessibility features
- Review privacy policy for GDPR/CCPA
- Assess international pricing

**Deliverable:** Global market readiness checklist with gaps

---

## Audit Process

### Phase 1: Preparation (Day 1)
- [ ] Install all competitor apps on test devices
- [ ] Create accounts on each competitor
- [ ] Prepare test food photos (10 Indian dishes)
- [ ] Prepare test barcodes (20 products)
- [ ] Set up screenshot capture workflow

### Phase 2: Data Collection (Days 2-4)
- [ ] Complete UI audit (screenshots + scoring)
- [ ] Complete UX audit (timing + friction map)
- [ ] Complete bug audit (testing + bug list)
- [ ] Complete functionalities audit (feature matrix)
- [ ] Complete AI audit (accuracy tests)
- [ ] Complete cost audit (pricing analysis)
- [ ] Complete Indian market audit (checklist)
- [ ] Complete global market audit (checklist)

### Phase 3: Analysis & Documentation (Days 5-6)
- [ ] Compile all findings into `AUDIT_REPORT.md`
- [ ] Create summary scorecard
- [ ] Prioritize issues (P0 = launch blocker, P1 = important, P2 = nice-to-have)
- [ ] Document recommended fixes

### Phase 4: Review (Day 7)
- [ ] Review audit report with you
- [ ] Finalize action items
- [ ] Only THEN plan coding fixes

---

## Output File
All findings documented in: `AUDIT_REPORT.md`

## Scoring System
Each dimension scored 1-10:
- 1-3: Significant gaps, major work needed
- 4-5: Below average, noticeable issues
- 6-7: Good, minor improvements needed
- 8-9: Excellent, competitive advantage
- 10: Industry-leading

---

# E2E VERIFICATION PLAN (functional) — v0.9.5+ gamification build

**Status:** process documented — not yet executed
**Added:** 2026-09-14
**Scope:** prove every user journey works end-to-end in the current build and catch
regressions. Complements — does not replace — the 8-dimension competitive audit
above. No competitor scoring here.
**Target device:** iPhone 15, iOS 26.6.1 (only device for this pass).
**Automation:** build the `integration_test` harness first, then run it on device.

## 0. Decisions locked
- Scope: E2E functional verification only.
- Documentation: this file (process) + `AUDIT_REPORT.md` (findings).
- Automation: `integration_test` harness first, then the manual pass.
- Device: iPhone 15 only.

## 1. Layers (deterministic → manual)
| # | Layer | Tool | Catches |
|---|-------|------|---------|
| 1 | Static | `flutter analyze` | type/lint regressions |
| 2 | Logic / state | `flutter test` | points, streak+freeze, quests, league, notifications — via injected clocks |
| 3 | Widget | `flutter test` (widget) | each screen renders; key taps work |
| 4 | Device E2E | `flutter test integration_test -d <hw-udid>` | real journeys on the phone |
| 5 | Manual journey | `flutter run --profile -d <hw-udid>` + checklist | visual, UX, edge cases |
| 6 | Backend / data | Firestore console + rules, analytics | data shape, security, privacy |

## 2. Environment & commands
- devicectl id (install/launch): `6C0FE134-9424-5153-9BD9-6FB6D916666B`
- flutter hardware id (logs/E2E): `00008120-000A43DE2605A01E`
- Build: `flutter build ios --profile`
- Install: `xcrun devicectl device install app --device <devicectl-id> build/ios/iphoneos/Runner.app`
- Launch: `xcrun devicectl device process launch --device <devicectl-id> com.neharohilla.calorietracker`
- Live logs: `flutter run --profile -d <hw-id>`
- iOS 26 note: `idevicescreenshot` / `idevicesyslog` / `idevicecrashreport` are
  unreliable (libimobiledevice cannot mount the new DDI). Screen evidence is
  captured by the user; live logs come through `flutter run`.

## 3. Deterministic states, fixtures & reset
- Clocks are injected in `GamificationService` / `NotificationEngine`, so day and
  week rollover, streak gaps/freezes, caps and cooldowns are covered in layer 2.
- Test account: `playtest@calmatters.app` / `CalPass#2026`.
- Fixtures: seed via manual entry / quick picks; vary coin balance and freeze bank
  by direct state edits in tests.
- Reset: sign out (session scope); delete app for a clean first-run. NOTE: there is
  no "wipe all local data" action today.

## 4. Coverage checklists
Each item: expected result in brackets. A finding = any deviation.

### A. Functional journeys
- A1 Onboarding → sign-up → pricing → Home [reaches Home; profile persists]
- A2 Log manual meal [entry saved; +10 Cal Points; meal quest advances; streak day]
- A3 Log AI-scan meal [15 pts; scan quest; handles "no food detected"]
- A4 Barcode scan [found/not-found both handled; entry logged]
- A5 Water to goal [10 pts at goal; hydration quest advances]
- A6 Log weight [5 pts; weight quest]
- A7 Log exercise [10 pts; activity quest]
- A8 Steps opt-in [correct source tier; survives relaunch]
- A9 Asha chat [5 pts, max 2/day; Asha quest; purchased voice changes tone]
- A10 Quests: complete one, then all three [3rd pays +25 pts / +20 coins bonus]
- A11 Hub: level/title, streak, weekly points, coins, freezes, quest list
- A12 Shop: freeze, frame, theme, voice [coins debited; effect applied immediately]
- A13 League: tier, countdown, leaderboard with "You"
- A14 Achievements: categories, progress, secret hidden until earned
- A15 Celebrations: toasts + full-screen for level/milestone; reduce-motion static
- A16 Notifications: permission prompt; a nudge is scheduled; no crash
- A17 Existing: meal plans, fasting, friends, weekly summary
- A18 History / Progress / Insights reflect entries + gamification

### B. State & lifecycle
- B1 Fresh install first-run [correct routing]
- B2 Upgrade-in-place [existing local data survives]
- B3 Force-quit & relaunch [points/streak/quests/coins persist]
- B4 Day rollover [daily points reset; quests regenerate; new streak day]
- B5 Week rollover [league settles; weekly points reset]
- B6 Timezone / locale change
- B7 Cloud restore on a second sign-in
- B8 Sign-out/in [session and data scope correct]

### C. Edge & failure
- C1 Airplane mode logging [local save + points still work]
- C2 AI error / timeout [graceful, retryable]
- C3 "No food detected" [clear message, no dead end]
- C4 Camera/gallery permission denied [graceful]
- C5 Barcode camera denied
- C6 Notification permission denied [no crash]
- C7 Purchase with too few coins [blocked with message]
- C8 Streak-freeze bank full [blocked]
- C9 Quest completion across midnight boundary
- C10 Rapid double-tap logging [60s cooldown; no double award]
- C11 Daily 200-point cap reached
- C12 Back navigation on every screen [correct stack]
- C13 Background/foreground mid-scan

### D. Data integrity
- D1 Add / edit / delete entry → totals correct
- D2 Gamification never double-awards a repeated action
- D3 local ↔ cloud consistency for entries
- D4 water/weight/exercise persistence (local-only today — record the gap)
- D5 `exportJson()` completeness

### E. Non-functional
- E1 Cold-start time
- E2 AI scan round-trip time
- E3 Scroll performance on long lists
- E4 Memory over a session
- E5 Build size

### F. UI / UX & accessibility
- F1 Every screen light + dark
- F2 Reduce Motion [celebrations show static card]
- F3 Dynamic type / large text
- F4 Screen-reader labels (quests, league rows, celebration)
- F5 Colour contrast
- F6 Empty / loading / error states
- F7 No overflow on small widths
- F8 Theme re-tint (Midnight / Forest)

### G. Security & privacy
- G1 Firestore security rules (currently missing — verify/enable)
- G2 No secrets shipped in the app
- G3 Sign-out clears the session
- G4 Sandbox paywall bypass is dev-only (compiled out of release)
- G5 Data-safety claims match behaviour (photos to AI, not stored)

### H. Health-ethics guardrails
- H1 No points for calorie deficit
- H2 Leagues rank engagement, never weight
- H3 Copy is gentle (no body-shaming)
- H4 Rest days are legitimate (freeze works)
- H5 Notification opt-out is easy

### I. Observability
- I1 Analytics events fire (check `AnalyticsService.counts()`)
- I2 Errors surface in logs
- I3 Session is crash-free

### J. Regression vs the Sept-5 report
- J1 Onboarding / pricing / paywall
- J2 Capture / manual entry / barcode
- J3 History / Progress / Insights
- J4 Meal plans / fasting / friends / weekly summary
- J5 Settings (dark mode, keys, sign-out)
- J6 Billing stub

## 5. Evidence per finding
Repro steps → expected vs actual → log line / analytics event → screenshot (user) →
severity. Recorded in the findings table in `AUDIT_REPORT.md`.

## 6. Severity & triage
- **Blocker** — crash, data loss, paywall/auth broken
- **Major** — a feature is broken or wrong
- **Minor** — works but wrong/rough polish
- **Nit** — cosmetic

Fix loop: reproduce → fix → re-run layer 1–4 → re-verify on device → mark resolved.

## 7. Exit criteria
- No Blocker or Major findings open
- Areas A–J exercised (or explicitly marked N/A with reason)
- `flutter analyze` 0 errors; `flutter test` green; `integration_test` suite green
- Findings + evidence recorded in `AUDIT_REPORT.md`
