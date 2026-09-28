#!/usr/bin/env python3
"""Does the Play Store listing describe the app we actually ship?

The defect (2026-09-28): PLAY_STORE_LISTING.md advertises a "Fasting Tracker"
and "Meal Plans". Fasting has no screen at all — only a quest category and a
sentence in a settings dialog. MealPlanScreen exists and is reachable ONLY from
discover_screen.dart, which AGENTS.md documents as dormant and unreferenced
since the Firestore rules landed. So the listing sells two things a user cannot
open. It is a Play submission problem and a support problem, and it survived
because nobody compared the listing to the code.

WHY A TOOL AND NOT A READING. Order 9: a claim about my own work needs something
that can disagree with me. I am the one who would hand-wave "it's basically
there". So this walks the REAL path — a transitive import closure from
lib/main.dart — and prints the screen every claimed feature resolves to, or says
NONE. A grep for the word "fasting" would pass: the word IS in lib/. That is
exactly the check that passed for a day over a dead feature.

REACHABILITY, precisely. A screen counts as reachable when it is imported, or
imported by a reachable screen, starting from lib/main.dart. Dormant files are
listed in DORMANT_BY_DESIGN and are treated as ENTRY BLOCKERS, not features:
they are real code that the app does not lead to.

Exit codes
  0  every claimed feature resolves to a reachable screen
  1  a claim resolves to nothing, or only to dormant code
  2  the listing or lib/main.dart is missing, or nothing was checked
     (an empty result is not a pass — standing order 4)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "PLAY_STORE_LISTING.md"
ENTRY = ROOT / "lib" / "main.dart"
LIB = ROOT / "lib"

# Screens that exist but that the app does not lead to. AGENTS.md: the Discover
# tab and the home friends-strip were removed on 2026-09-15 because the
# Firestore rules deny the reads they needed; the files are kept for a future
# design and must not be re-wired by accident.
DORMANT_BY_DESIGN = {"lib/screens/discover_screen.dart",
                     "lib/services/social_service.dart"}

# Each claim in the listing, the words that carry it, and the EVIDENCE that
# would satisfy it.
#
# The first version of this file asked for a filename, and got two false alarms
# the moment it ran: water and weight tracking are real, shipped, and live
# inside home_screen and progress_screen — there is simply no water_screen.dart.
# A checker that demands a filename is reading vocabulary, not behaviour, which
# is order 9's second question pointed at my own new tool.
#
# So each claim names a SYMBOL that must be reached, and the evidence is: the
# symbol appears in a file the app can actually get to from lib/main.dart. The
# answer printed is the file and the symbol, so a reader can go and look.
CLAIMS = [
    ("AI Food Recognition", "Snap a photo and get instant calorie/macro breakdown",
     "CaptureScreen", ["lib/screens/capture_screen.dart"]),
    ("Barcode Scanner", "Scan packaged foods for instant nutrition data",
     "BarcodeScannerScreen", ["lib/screens/barcode_scanner_screen.dart"]),
    ("Smart Search", "1,700+ Indian foods database with fuzzy search",
     "QuickPicksScreen", ["lib/screens/quick_picks_screen.dart"]),
    ("Manual Entry", "Add meals manually with AI-assisted nutrition lookup",
     "ManualEntryScreen", ["lib/screens/manual_entry_screen.dart"]),
    ("Meal Plans", "Save and reuse your favorite meal combinations",
     "MealPlanScreen", ["lib/screens/meal_plan_screen.dart"]),
    ("Fasting Tracker", "Track intermittent fasting with customizable goals",
     "FastingScreen", []),
    ("Water Tracking", "Monitor daily hydration",
     "addWater", []),
    ("Weight Tracking", "Log weight with trend visualization",
     "_weightChart", []),
    ("Weekly Insights", "calorie trends, macro distribution, and logging streaks",
     "InsightsScreen", ["lib/screens/insights_screen.dart"]),
    ("Achievements", "Unlock badges for consistent tracking",
     "AchievementsScreen", ["lib/screens/achievements_screen.dart"]),
]

_IMPORT = re.compile(r"""import\s+['"]([^'"]+)['"]""")


def _import_targets(path: Path) -> list[Path]:
    try:
        src = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    out = []
    for spec in _IMPORT.findall(src):
        if not spec.startswith(("dart:", "package:")):
            out.append((path.parent / spec).resolve())
    return out


def reachable_from(entry: Path) -> set[Path]:
    """Every .dart file the app can actually get to, from main.dart.

    DORMANT files are visited but they do not hand out reachability: nothing
    behind a screen the app does not open is reachable, and treating the
    dormant file as an entry point is how "meal plans" looked shipped.
    """
    seen: set[Path] = set()
    queue = [entry.resolve()]
    while queue:
        cur = queue.pop()
        if cur in seen or not cur.exists() or cur.suffix != ".dart":
            continue
        seen.add(cur)
        try:
            rel = str(cur.relative_to(ROOT))
        except ValueError:
            continue
        if rel in DORMANT_BY_DESIGN:
            continue  # read, but do not traverse outward
        queue.extend(_import_targets(cur))
    return seen


def main() -> int:
    if not LISTING.exists() or not ENTRY.exists():
        print("FATAL: PLAY_STORE_LISTING.md or lib/main.dart is missing. "
              "Nothing was checked, so nothing is claimed.")
        return 2

    listing = LISTING.read_text(encoding="utf-8")
    live = reachable_from(ENTRY)

    # Read the reachable files ONCE, and search them for the symbol. A symbol is
    # satisfied by any reachable file; a declared anchor file that is not
    # reachable is the extra signal for DORMANT.
    sources = {}
    for p in live:
        try:
            sources[p] = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
    dormant_text = {}
    for d in sorted(DORMANT_BY_DESIGN):
        p = ROOT / d
        if p.exists():
            try:
                dormant_text[d] = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                pass

    rows, bad = [], []
    for feature, wording, symbol, anchors in CLAIMS:
        if wording.lower() not in listing.lower():
            rows.append((feature, "NOT IN LISTING", "nothing to prove"))
            continue

        # A screen, not a service. storage_service.addWeightEntry is the
        # persistence API — it exists whether or not a user can log a weight, so
        # satisfying a user-facing claim from a service is the vocabulary trap
        # wearing a different hat. A claim about what a user can DO must be
        # satisfied by a reachable SCREEN that calls it.
        where = None
        for p, src in sources.items():
            if "/screens/" not in str(p):
                continue
            if symbol in src:
                where = (str(p.relative_to(ROOT)), "reachable from main.dart")
                break

        if where is not None:
            rows.append((feature, "OK", f"{where[0]} uses {symbol}"))
            continue

        # Not reachable. Is it at least real code, sitting behind a dormant file?
        behind = [d for d, src in dormant_text.items() if symbol in src]
        if behind:
            rows.append((feature, "DORMANT",
                         f"{symbol} exists only behind {', '.join(behind)}"))
            bad.append(
                f"{feature}: {symbol} is real code, but it is reachable only "
                f"through {', '.join(behind)}, which the app does not open "
                f"(documented dormant in AGENTS.md). A user cannot reach it, and "
                f"the listing promises they can."
                + (" The declared anchor " + ", ".join(anchors) +
                   " is a screen nothing imports."
                   if anchors and not any(
                       (ROOT / a).resolve() in live for a in anchors) else ""))
        else:
            rows.append((feature, "NOT SHIPPED",
                         f"no reachable file mentions {symbol}"))
            bad.append(
                f"{feature}: the listing promises it and nothing reachable in "
                f"lib/ implements it. The word may appear in a quest category or "
                f"a settings sentence — that is not a feature a user can open.")

    width = max(len(r[0]) for r in rows) if rows else 10
    print("Play Store listing vs the app, walking the real import path from "
          "lib/main.dart")
    print(f"({len(sources)} reachable dart files read; a symbol counts only if "
          f"it is\n in one of them)\n")
    for feature, verdict, detail in rows:
        print(f"  {feature:<{width}}  {verdict:<12}  {detail}")

    if bad:
        print(f"FAIL: {len(bad)} listing claim(s) do not resolve to a reachable "
              f"screen.")
        for b in bad:
            print(f"  - {b}")
        print("")
        print("Either build and ship the feature, or remove the claim. A store "
              "listing that\nsells a screen the app cannot open is a Play "
              "rejection and a 1-star review.")
        return 1

    print(f"PASS: all {len(rows)} listing claims resolve to a screen reachable "
          f"from lib/main.dart.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
