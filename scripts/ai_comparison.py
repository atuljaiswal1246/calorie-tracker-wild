#!/usr/bin/env python3
"""
AI vs Database Comparison Script
Sends each food from merged_foods.json to Gemini API,
compares AI estimate with database values, saves results.
"""

import json
import time
import os
import sys
import re
from datetime import datetime
from pathlib import Path

from google import genai

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
FOOD_DB = PROJECT_ROOT / "assets" / "merged_foods.json"
RESULTS_FILE = PROJECT_ROOT / "ai_comparison_results.json"
PROGRESS_FILE = PROJECT_ROOT / "ai_comparison_progress.json"

# Config
MODEL_NAME = "gemini-3.6-flash"
DELAY_BETWEEN_CALLS = 900  # 15 minutes (free tier safety)
MAX_RETRIES = 3
BACKOFF_BASE = 60  # seconds for exponential backoff on 429


def load_foods():
    with open(FOOD_DB) as f:
        return json.load(f)


def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {"processed": [], "failed": []}


def save_progress(progress):
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)


def load_results():
    if RESULTS_FILE.exists():
        with open(RESULTS_FILE) as f:
            return json.load(f)
    return []


def save_results(results):
    with open(RESULTS_FILE, "w") as f:
        json.dump(results, f, indent=2)


def query_gemini(client, food_name):
    prompt = f"""Estimate nutrition for: {food_name}

Return ONLY valid JSON, no other text:
{{"servingSizeGrams":100,"calories":250,"protein":12.0,"carbs":30.0,"fat":8.0,"fiber":5.0,"sugar":3.0,"sodium":450.0}}

Rules:
- Estimate for a typical Indian household serving (approximately 100g)
- calories = integer kcal
- protein/carbs/fat/fiber/sugar = grams
- sodium = mg
- Return ONLY the JSON object, nothing else"""

    for attempt in range(MAX_RETRIES):
        try:
            response = client.models.generate_content(
                model=MODEL_NAME,
                contents=prompt,
            )
            text = response.text.strip()

            json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
            if json_match:
                return json.loads(json_match.group())
            return None

        except Exception as e:
            err_str = str(e)
            if "429" in err_str or "quota" in err_str.lower() or "rate" in err_str.lower():
                wait = BACKOFF_BASE * (2 ** attempt)
                print(f"(rate limited, waiting {wait}s)...", end=" ", flush=True)
                time.sleep(wait)
                continue
            raise

    return None


def compare(food_db, ai_estimate):
    serving = ai_estimate.get("servingSizeGrams", 100)
    scale = 100.0 / serving if serving > 0 else 1.0

    ai_cal = ai_estimate.get("calories", 0) * scale
    ai_protein = ai_estimate.get("protein", 0) * scale
    ai_carbs = ai_estimate.get("carbs", 0) * scale
    ai_fat = ai_estimate.get("fat", 0) * scale
    ai_fiber = ai_estimate.get("fiber", 0) * scale
    ai_sugar = ai_estimate.get("sugar", 0) * scale
    ai_sodium = ai_estimate.get("sodium", 0) * scale

    db_cal = food_db.get("calories", 0)
    db_protein = food_db.get("protein", 0)
    db_carbs = food_db.get("carbs", 0)
    db_fat = food_db.get("fat", 0)
    db_fiber = food_db.get("fiber", 0)
    db_sugar = food_db.get("sugar", 0)
    db_sodium = food_db.get("sodium", 0)

    def pct_diff(ai_val, db_val):
        if db_val == 0:
            return None if ai_val == 0 else 999.9
        return round(((ai_val - db_val) / db_val) * 100, 1)

    return {
        "ai": {
            "servingSizeGrams": serving,
            "calories": round(ai_cal),
            "protein": round(ai_protein, 1),
            "carbs": round(ai_carbs, 1),
            "fat": round(ai_fat, 1),
            "fiber": round(ai_fiber, 1),
            "sugar": round(ai_sugar, 1),
            "sodium": round(ai_sodium, 1),
        },
        "db": {
            "calories": db_cal,
            "protein": db_protein,
            "carbs": db_carbs,
            "fat": db_fat,
            "fiber": db_fiber,
            "sugar": db_sugar,
            "sodium": db_sodium,
            "source": food_db.get("source", ""),
        },
        "diff_pct": {
            "calories": pct_diff(ai_cal, db_cal),
            "protein": pct_diff(ai_protein, db_protein),
            "carbs": pct_diff(ai_carbs, db_carbs),
            "fat": pct_diff(ai_fat, db_fat),
            "fiber": pct_diff(ai_fiber, db_fiber),
            "sugar": pct_diff(ai_sugar, db_sugar),
            "sodium": pct_diff(ai_sodium, db_sodium),
        },
    }


def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        api_key = input("Enter Gemini API key: ").strip()
    if not api_key:
        print("No API key provided. Exiting.")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    foods = load_foods()
    progress = load_progress()
    results = load_results()

    processed_set = set(progress["processed"])
    remaining = [f for f in foods if f["name"] not in processed_set]

    print(f"Total foods: {len(foods)}")
    print(f"Already processed: {len(processed_set)}")
    print(f"Remaining: {len(remaining)}")
    print(f"Results so far: {len(results)}")
    hours = (len(remaining) * DELAY_BETWEEN_CALLS) / 3600
    print(f"Estimated time: {hours:.1f} hours ({hours/24:.1f} days)")
    print()

    for i, food in enumerate(remaining):
        name = food["name"]
        print(f"[{len(processed_set) + i + 1}/{len(foods)}] {name}...", end=" ", flush=True)

        try:
            ai_estimate = query_gemini(client, name)
            if ai_estimate is None:
                print("FAILED (bad response)")
                progress["failed"].append({"name": name, "reason": "bad_response", "time": datetime.now().isoformat()})
                save_progress(progress)
                time.sleep(DELAY_BETWEEN_CALLS)
                continue

            comparison = compare(food, ai_estimate)
            result = {
                "name": name,
                "nameHindi": food.get("nameHindi", ""),
                "category": food.get("category", ""),
                "timestamp": datetime.now().isoformat(),
                **comparison,
            }
            results.append(result)
            progress["processed"].append(name)

            if len(results) % 10 == 0:
                save_results(results)
                save_progress(progress)

            cal_diff = comparison["diff_pct"]["calories"]
            print(f"OK (AI: {comparison['ai']['calories']}kcal, DB: {comparison['db']['calories']}kcal, diff: {cal_diff}%)")

        except Exception as e:
            print(f"ERROR: {e}")
            progress["failed"].append({"name": name, "reason": str(e), "time": datetime.now().isoformat()})

        save_progress(progress)
        time.sleep(DELAY_BETWEEN_CALLS)

    save_results(results)
    save_progress(progress)

    print()
    print("=" * 60)
    print(f"Done! Processed {len(progress['processed'])} foods, {len(progress['failed'])} failed")
    print(f"Results saved to: {RESULTS_FILE}")

    if results:
        valid = [r for r in results if r["diff_pct"]["calories"] is not None and abs(r["diff_pct"]["calories"]) < 999]
        if valid:
            avg_cal_diff = sum(r["diff_pct"]["calories"] for r in valid) / len(valid)
            print(f"Average calorie diff: {avg_cal_diff:+.1f}%")


if __name__ == "__main__":
    main()
