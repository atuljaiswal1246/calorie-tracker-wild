# UI Guidelines — Calorie Tracker

This document is the **source of truth** for UI decisions. Follow it on every new screen.
The **first two onboarding screens (Choose your goal, Choose your sex)** are the
reference / gold standard. When in doubt, match them.

---

## 1. Theme & Colors

| Token | Value | Use |
|---|---|---|
| Background (main) | `#FFFFFF` (white) | Screens, cards, bottom bar |
| Section background | `#F7F7F7` (very light grey) | Question/content area above the boundary |
| Primary (buttons, accents) | `#000000` (black) | Buttons, slider thumb, selected borders |
| Muted text | `Colors.black54` / `black38` | Secondary text, icons |
| Border (default) | `Colors.black12` (very subtle) | Card outlines, dividers |
| Warning box bg | `#FFF7E6` | Info/transparency notices |
| Warning box border | `#E6C567` | Info/transparency notices |

**Rule:** mostly **white**, black for emphasis. Never use the old orange/deep-purple theme.

---

## 2. Layout (the two-section rule)

Every onboarding screen has **two clearly separated sections**:

```
┌─────────────────────────────────┐
│ GREY SECTION (#F7F7F7)          │  ← Top bar, heading, question content
│                                 │
├─ 2px divider (Colors.black12) ──┤  ← the boundary
│ WHITE SECTION                   │  ← Continue button area
└─────────────────────────────────┘
```

- The **grey section** holds: progress bar + back button (top), heading, and the
  question content (centered in remaining space).
- The **white section** holds only the Continue button, and extends to the very
  bottom of the screen (the safe-area strip is white too).
- Elements that should feel "separate" from the question (e.g. "I don't have a
  target") are pinned **just above the 2px boundary**, inside the grey section.

### Top bar
- **Back button:** circular, very subtle — `Colors.black.withValues(alpha: 0.05)`
  circle, icon `black54`, small (36×36, iconSize 20).
- **Progress bar:** THIN — 3px (`minHeight: 3`), `Colors.black12` background,
  black fill. Step counter `X/10` on the right (13px, black54).
- Gap between progress bar and heading must be **small** (heading sits just below).

### Heading
- Big (28–30px), `FontWeight.w700`, black, `letterSpacing: -0.5`.
- Placed **near the progress bar** (not centered mid-screen).
- Only the title on some screens; a short supporting line (15px, black54,
  `letterSpacing: -0.3`) may follow — only if it adds value.

### Content
- Vertically centered in the space between heading and boundary.
- Start items at the top when content is short; center when it fills space.

---

## 3. Typography

- **Font:** Inter (bundled asset — the ONLY font). No SF Pro / Roboto mixing.
- **Letter spacing:** headings `-0.5`, body/secondary `-0.3`, big numbers `-1`.
- **Sizes:**
  - Screen title: 28–30px, w700
  - Selectable card label: 17px, w600
  - Primary value (slider/wheel): ~44px max, w800 — **not** 52px
  - Secondary/supporting: 13–15px
- **Weight hierarchy:** bold for the value/selection, normal elsewhere.

---

## 4. Components

### Selectable card (Screens 1 & 2 reference)
- White card, `borderRadius: 8` (small corners — keeps cards looking bigger).
- Default border: `black12`, width 1 (very subtle).
- **Selected:** `black` border, width 2, **+ black check-circle icon** on the right.
  Icon turns black when selected. **DO NOT fill the card black.**
- Padding: `horizontal: 16, vertical: 18`, gap between cards `12px`.
- Icon 26px (black54 → black when selected). Label 17px w600, `letterSpacing: -0.5`.
- Subtle `AnimatedContainer` (150ms) for selection feedback.

### Button (bottom bar)
- **Pill / StadiumBorder** (not rounded-rect 16).
- Black fill, white text, 17px w600, `letterSpacing: -0.5`.
- Height 54, spans nearly full width (16px side padding).
- Label: "Continue", last step "Finish", plan page "Let's get started".

### Slider
- **Thin track: 3px** for progress bars; value sliders match their screen's design
  (weight/age use 6px with a 52px value). Consistency within a screen matters most.
- Black active track, `black12` inactive, black thumb.
- Keep it simple — no tick markers.

### Picker wheel (ft/in, iOS style)
- `ListWheelScrollView` with a **selection highlight bar** behind the center item
  (`black.withValues(alpha: 0.06)`, rounded).
- **Auto-centers** on the current value via `FixedExtentScrollController`.
- Selected item bold black; others fade to `black26`.
- Label under each wheel (13px, black54).

### Unit toggle (kg/lbs, cm/ft-in)
- Pill segmented control: grey track `black12`, active pill **black** with white
  text, inactive transparent with `black54` text. Padding 4, radius 24.

---

## 5. Input philosophy

- **Avoid typing** — phones are for touch. Prefer slider / picker wheel / chips.
- Height: ft/in **by default** (with cm option). Weight: kg by default (with lbs).
- Min age is **10** (the slider range is 10–100).
- If a value is bounded, the control should make bad values **impossible** (slider),
  not require validation.

---

## 6. Transparency & honesty

- If a user's goal/timeline is unrealistic, **tell them on that screen** (amber
  `#FFF7E6` info box) — never silently show nonsense numbers.
- Healthy bounds: max **1 kg/week** loss, **0.5 kg/week** gain. Calorie goal is
  floored at 1200. Never show negative calories/macros.
- When we adjust the plan (extend timeline, cap rate), explain it.

---

## 7. Motion

- Prefer short, subtle animations (150–300ms): selection borders, count-ups,
  progress fills, staggered reveal.
- Ease curves: `Curves.easeOutCubic` for entrances.

---

## 8. Anti-patterns (never do)

- ❌ Yellow/black overflow stripes — always fix layout, don't ship it.
- ❌ Fixed pixel heights that overflow on small screens — use flexible/scrollable.
- ❌ Black-filled selected cards (use border + check).
- ❌ Font size 52+ for values — 44px is the ceiling.
- ❌ Thick sliders / progress bars (6px+) — 3px is the rule.
- ❌ Text inputs for bounded numbers — use sliders/pickers.
- ❌ Different fonts per platform — Inter everywhere.
- ❌ Hiding that we adjusted an unrealistic plan — say it clearly.

---

## 9. Golden screens

Revisit **Choose your goal** and **Choose your sex** (screens 1 & 2) before building
anything new — they are the accepted, polished baseline. Match their spacing,
weights, borders, and restraint.