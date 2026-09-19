# UI Guidelines — Cal Matters (what ships)

Source of truth for new screens: `lib/theme/app_colors.dart` (colours) and
`lib/theme/app_tokens.dart` (type / spacing / radii). This document describes
only what is shipped in the signed-off screens. Every claim below is checkable
against those files and the app.

## 1. Palette

Rule: **cream background, near-black ink, ONE accent (orange).** Macro colours
are the only other hues allowed. Dark mode is handled by the same
`AppColors` tokens (each getter returns a light value and a dark value).

| Token (`AppColors`) | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FAF9F7` | `#0E0F11` | Screen background |
| `card` | `#FFFFFF` | `#1B1C1E` | Cards |
| `ink` | `#1C1C1E` | `#F2F2F4` | Primary text; primary CTA fill in light mode |
| `muted` | `#6E6E73` | `#9A9AA2` | Secondary text |
| `faint` | `#8A8A85` | `#6D6D75` | Tertiary text |
| `accentOrange` | `#FF9500` | `#FF9500` (same) | THE accent: selection borders, rings, highlights |
| `protein` | `#E53935` | same | Macro |
| `carbs` | `#FF9500` | same | Macro |
| `fat` | `#007AFF` | same | Macro |
| `green` | `#34C759` | same | Success / logged day |
| `missedRed` | `#FF3B30` | same | Missed day / error state |
| `warningOrange` | `#FFA726` | same | Warnings |

Notes: `water` (`#007AFF`), `fiber` (`#8D6E63`), `sugar` (`#E91E63`),
`sodium` (`#78909C`) are macro-detail colours used inside breakdowns only.
Do not introduce any hue outside this table.

## 2. Type scale

Rule: pick from these seven; do not invent a new size.

| Token (`AppType`) | Size | Use |
|---|---|---|
| `micro` | 10 | Pills, labels |
| `small` | 11.5 | Captions |
| `body` | 13 | Body (default) |
| `bodyStrong` | 15 | Body emphasis |
| `title` | 17 | Card titles |
| `headline` | 22 | Screen titles |
| `hero` | 28 | Big numbers |

Font: Inter everywhere. Headings carry negative letter spacing.

## 3. Spacing

Rule: gaps come from this set.

| Token (`AppSpace`) | Value |
|---|---|
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |

## 4. Radii

Rule: no new radii.

| Token (`AppRadius`) | Value | Use |
|---|---|---|
| `pill` | 10 | Pills / chips |
| `card` | 16 | Cards |
| `sheet` | 24 | Sheets / major cards |
| `full` | 999 | Pill (stadium) |

## 5. House rules

- One dominant idea per screen.
- Big, left-aligned type with negative letter spacing.
- One primary CTA, full width, black (white in dark mode).
- Real illustrations, never emoji-as-art.
- No filler copy.
- On stat tiles put the label first, then the value.
- Material Symbols for functional icons.

## 6. What is locked

Do not change without an explicit new request: the welcome / get-started
screen, onboarding screens 1–6, the sign-up screen, and the paywall.
