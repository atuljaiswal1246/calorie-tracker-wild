# Two decisions waiting on the owner — drafted, NOT applied

Written 2026-09-28 by the Cal Matters CEO. **Nothing in this file has been
applied.** Both items are legal or product copy, and I have declined three times to
write either on my own initiative. What I can do is make each one a single word to
approve, with the exact text, the exact reason, and what breaks if we do nothing.

Each of the two is guarded by a checker that is currently **FAILING** in the claim
runner. That is deliberate: a red row for a decision the owner has not made is
honest, and I would rather ship two reds than a green that means nothing.

---

## 1. The privacy page names one processor; the Worker can use three

**The finding, with its producer.**
`python3 tools/check_privacy_processors.py` derives the processor set from the
Worker's own `const rotation = [...]` — the list the serving loop actually iterates
— and compares it against `public/privacy.html`. At 17:07 that read:

```
  aicredits    NAMED      policy says "AICredits"
  go           NOT NAMED  expected one of OpenCode, opencode.ai
  openrouter   NOT NAMED  expected one of OpenRouter, openrouter.ai
  searched 121 repos … (that count is the other checker)
```

and `POST /health` at 11:32:29Z independently said the last billed request was
served by **`openrouter`** (`openai/gpt-4o-mini`). So a user's food photograph can
be processed by a company the published page does not name. The Play data-safety
declaration is written *from* that page, so the declaration and the behaviour
disagree.

**Three places carry the claim, not one.** The hosted page is the one users read,
but the two the owner actually fills Play Console from are internal:
`public/privacy.html`, `PRIVACY_POLICY.md`, and `AGENTS.md`'s data-safety line,
which reads verbatim:

> photos (sent to AICredits for analysis; NOT stored)

**Option A — name all three processors.** Smallest change, most literal, and it
rots: the next time a key is funded or a tier is added, the page is wrong again
and `check_privacy_processors.py` goes red until someone remembers.

**Option B — describe the mechanism.** One door, model chosen server-side, and any
of three processors may serve a scan. This stays true as the rotation changes, and
the checker keeps enforcing that whatever the rotation contains is named or
covered.

My recommendation is **B**, because a static page cannot describe a dynamic
rotation, and a page that names one of three is worse than one that names the
mechanism — it looks answered.

**DONE-CONDITION for either:** `python3 tools/check_privacy_processors.py` exits 0.
It is the only proof; a re-read by me is not.

---

## 2. The Play listing sells two features the app cannot open

**The finding, with its producer.**
`python3 tools/check_store_listing.py` walks the real import closure from
`lib/main.dart` (76 reachable files at 19:00) and asks, per listing claim, whether
a reachable **screen** implements it.

```
  Meal Plans           DORMANT       MealPlanScreen exists only behind
                                  lib/screens/discover_screen.dart
  Fasting Tracker      NOT SHIPPED   no reachable file mentions FastingScreen
  Water Tracking       OK            home_screen uses addWater
  Weight Tracking      OK            progress_screen uses _weightChart
```

- **Meal Plans** — a real, finished ~700-line screen, reachable only from
  `discover_screen.dart`, which AGENTS.md has documented as **dormant and
  unreferenced** since the Firestore rules denied the reads it needed (2026-09-15).
  A real screen with no way in.
- **Fasting Tracker** — no screen exists at all. The word survives in
  `models/quest.dart` (a quest category) and one sentence in
  `settings_screen.dart`. A grep for "fasting" **passes**; a user tapping the
  listing's promise finds nothing.

**Option A — cut both from the listing.** One edit, honest, costs the roadmap
nothing that is not already unfunded. Fastest route to a submission that survives
review.

**Option B — build Fasting, wire Meal Plans.** Fasting is a new screen plus a
model; wiring Meal Plans means re-homing a screen that works, behind a tab the
Firestore rules may still deny. Both are real work and neither is tonight's.

**DONE-CONDITION for either:** `python3 tools/check_store_listing.py` exits 0.

My recommendation is **A for the submission, B afterwards** — but the listing is
the owner's document and the two features may already be promised to someone.

---

## What is NOT waiting on the owner

- The M1 run is **MONEY BLOCKED** on all three tiers, measured 17:07, exit 3:
  aicredits 402, openrouter 402, go 429. Not a decision about text; a decision
  about money, and until it is funded no run happens.
- The corpus is at **71 cases over 50 dish families** (it was 43 earlier the same
  evening, so it is being fed). The M1 bar of 21 distinct classes is met several
  times over. What is missing is the run, not the corpus.
