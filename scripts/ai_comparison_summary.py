#!/usr/bin/env python3
"""
Summarize AI vs Database comparison results.
Run after ai_comparison.py has collected data.
"""

import json
from pathlib import Path
from collections import defaultdict

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
RESULTS_FILE = PROJECT_ROOT / "ai_comparison_results.json"


def main():
    if not RESULTS_FILE.exists():
        print("No results file found. Run ai_comparison.py first.")
        return

    with open(RESULTS_FILE) as f:
        results = json.load(f)

    print(f"Total comparisons: {len(results)}")
    print()

    # Filter valid results
    valid = [r for r in results if r["diff_pct"]["calories"] is not None and abs(r["diff_pct"]["calories"]) < 999]

    if not valid:
        print("No valid comparisons with both AI and DB values.")
        return

    # Overall stats
    metrics = ["calories", "protein", "carbs", "fat", "fiber", "sugar", "sodium"]
    print(f"{'Metric':<12} {'Avg Diff':>10} {'Median':>10} {'Min':>10} {'Max':>10} {'Within 20%':>12}")
    print("-" * 70)

    for metric in metrics:
        diffs = [r["diff_pct"][metric] for r in valid if r["diff_pct"][metric] is not None and abs(r["diff_pct"][metric]) < 999]
        if not diffs:
            continue
        diffs.sort()
        avg = sum(diffs) / len(diffs)
        median = diffs[len(diffs) // 2]
        within_20 = sum(1 for d in diffs if abs(d) <= 20) / len(diffs) * 100
        print(f"{metric:<12} {avg:>+9.1f}% {median:>+9.1f}% {min(diffs):>+9.1f}% {max(diffs):>+9.1f}% {within_20:>10.1f}%")

    # By source
    print()
    print("By database source:")
    print("-" * 50)
    by_source = defaultdict(list)
    for r in valid:
        src = r["db"]["source"]
        by_source[src].append(r)

    for src, items in sorted(by_source.items(), key=lambda x: -len(x[1])):
        cal_diffs = [r["diff_pct"]["calories"] for r in items if r["diff_pct"]["calories"] is not None]
        avg = sum(cal_diffs) / len(cal_diffs) if cal_diffs else 0
        print(f"  {src}: {len(items)} items, avg calorie diff: {avg:+.1f}%")

    # Worst estimates
    print()
    print("10 biggest calorie overestimates:")
    overestimates = sorted(valid, key=lambda r: -(r["diff_pct"]["calories"] or 0))
    for r in overestimates[:10]:
        ai = r["ai"]["calories"]
        db = r["db"]["calories"]
        diff = r["diff_pct"]["calories"]
        print(f"  {r['name']}: AI={ai}kcal, DB={db}kcal ({diff:+.1f}%)")

    print()
    print("10 biggest calorie underestimates:")
    underestimates = sorted(valid, key=lambda r: (r["diff_pct"]["calories"] or 0))
    for r in underestimates[:10]:
        ai = r["ai"]["calories"]
        db = r["db"]["calories"]
        diff = r["diff_pct"]["calories"]
        print(f"  {r['name']}: AI={ai}kcal, DB={db}kcal ({diff:+.1f}%)")


if __name__ == "__main__":
    main()
