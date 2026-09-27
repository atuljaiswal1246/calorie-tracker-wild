#!/usr/bin/env python3
"""Food-scan accuracy harness for Cal Matters.

The core claim of this app is that it knows what is on your plate. Until this
existed, every prompt change was a guess. This scores the LIVE path: it takes
the prompt **straight out of the Dart source** (so we test what actually ships,
not a copy that can drift), sends the real photo to the real proxy, and scores
the answer against a labelled truth.

    # score the prompt that currently ships
    python3 tools/ai_accuracy.py

    # A/B the fix: score the pre-fix prompt from git, side by side
    python3 tools/ai_accuracy.py --compare ba7d8d6

    # save a baseline for the record
    python3 tools/ai_accuracy.py --json out.json

Scores, per meal:
  recall      truth dishes the model actually named
  invented    dishes the model claimed that are not in the photo  <- the
              failure that made a user log a "Naan" that never existed
  kcal error  |predicted - reference| / reference
  atwater     calories vs 4P+4C+9F, i.e. are the numbers self-consistent
  generic     penalised dish names ("Vegetable Curry", "Curry", "Sabzi")

Truth calories are IFCT-style **reference** values, not laboratory measures.
So `kcal error` is error against a reference band, and should be read as a
trend between runs, not as ground truth to the calorie.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DART = "lib/services/openai_service.dart"
CASES = os.path.join(ROOT, "tools", "ai_accuracy", "cases.json")
ENDPOINT = "https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev"

# Names too vague to be useful in a food log.
GENERIC = {
    "curry", "vegetable curry", "veg sabzi", "sabzi", "vegetables",
    "side dish", "mixed vegetables", "gravy", "indian food", "food",
    "salad", "bowl of food", "cooked food",
}

# Words that carry the dish identity. Matching is on these, not on the whole
# string, so "Palak Paneer" matches a prediction of "Palak Paneer (home style)".
def identity_tokens(name: str) -> set[str]:
    junk = {"with", "and", "the", "a", "of", "in", "style", "home", "bowl",
            "plate", "served", "masala", "curry", "sabzi", "fry", "cooked"}
    return {t for t in re.split(r"[^a-z]+", (name or "").lower()) if t and t not in junk}


def same_dish(a: str, b: str) -> bool:
    ta, tb = identity_tokens(a), identity_tokens(b)
    if not ta or not tb:
        return False
    # A prediction counts as the same dish if it shares the distinctive words,
    # or if it is a strict subset ("Paneer Curry" ~ "Palak Paneer").
    return len(ta & tb) >= 1 and (ta <= tb or tb <= ta or len(ta & tb) >= min(len(ta), len(tb)))


# ---------------------------------------------------------------- prompt source
PROMPT_RE = re.compile(r"final prompt = '''\n(.*?)'''", re.S)


def dart_text(ref: str | None) -> str:
    if ref:
        return subprocess.run(["git", "show", f"{ref}:{DART}"], cwd=ROOT,
                              capture_output=True, text=True, check=True).stdout
    with open(os.path.join(ROOT, DART), encoding="utf-8") as fh:
        return fh.read()


def image_prompt(ref: str | None = None) -> str:
    """Pull the image-analysis prompt out of the Dart source."""
    src = dart_text(ref)
    for block in PROMPT_RE.findall(src):
        if "Analyze this food photo" in block:
            return block
    raise SystemExit("could not find the image prompt in " + (ref or "the working tree"))


# ---------------------------------------------------------------- live call
def ask_proxy(prompt: str, image_path: str, device_id: str) -> dict:
    with open(image_path, "rb") as fh:
        b64 = base64.b64encode(fh.read()).decode()
    payload = {
        "model": "mimo-v2.5",
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url",
             "image_url": {"url": "data:image/jpeg;base64," + b64}},
        ]}],
        "temperature": 0.2,
        "max_tokens": 1000,
    }
    req = urllib.request.Request(
        ENDPOINT, data=json.dumps(payload).encode(), method="POST",
        headers={"Content-Type": "application/json",
                 "x-device-id": device_id,
                 "User-Agent": "Mozilla/5.0 Chrome/120.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        served = resp.headers.get("x-cm-served-model", "?")
        provider = resp.headers.get("x-cm-provider", "?")
        raw_body = resp.read().decode()
    body = json.loads(raw_body)
    text = body["choices"][0]["message"]["content"]
    raw = text.replace("```json", "").replace("```", "").strip()
    return json.loads(raw), served, provider


# ---------------------------------------------------------------- scoring
def score_case(case: dict, result: dict) -> dict:
    truth = case["truth"]
    items = result.get("items", []) or []

    matched, invented = [], []
    for pred in items:
        hit = next((t for t in truth if same_dish(pred.get("name", ""), t["name"])), None)
        (matched if hit else invented).append(pred.get("name", "?"))

    recalled = [t["name"] for t in truth
                if any(same_dish(t["name"], p.get("name", "")) for p in items)]

    truth_kcal = sum(t["kcal"] for t in truth)
    pred_kcal = sum(float(p.get("calories", 0) or 0) for p in items)
    kcal_err = abs(pred_kcal - truth_kcal) / truth_kcal if truth_kcal else None

    atw = sum(4 * float(p.get("protein", 0) or 0) + 4 * float(p.get("carbs", 0) or 0)
              + 9 * float(p.get("fat", 0) or 0) for p in items)
    atwater = abs(pred_kcal - atw) / pred_kcal if pred_kcal else None

    generic = [p.get("name", "?") for p in items
               if (p.get("name", "").strip().lower() in GENERIC)
               or len(identity_tokens(p.get("name", ""))) == 0]

    return {
        "id": case["id"],
        "truth_kcal": truth_kcal,
        "pred_kcal": round(pred_kcal),
        "recalled": recalled,
        "missed": [t["name"] for t in truth if t["name"] not in recalled],
        "invented": invented,
        "generic": generic,
        "n_pred": len(items),
        "n_truth": len(truth),
        "kcal_error_pct": None if kcal_err is None else round(kcal_err * 100, 1),
        "atwater_pct": None if atwater is None else round(atwater * 100, 1),
        "latency_s": None,
    }


def summarise(rows: list[dict]) -> dict:
    if not rows:
        return {}
    inv = sum(len(r["invented"]) for r in rows)
    miss = sum(len(r["missed"]) for r in rows)
    gen = sum(len(r["generic"]) for r in rows)
    errs = [r["kcal_error_pct"] for r in rows if r["kcal_error_pct"] is not None]
    atws = [r["atwater_pct"] for r in rows if r["atwater_pct"] is not None]
    lat = [r["latency_s"] for r in rows if r["latency_s"]]
    med = lambda xs: sorted(xs)[len(xs) // 2] if xs else None
    return {
        "meals": len(rows),
        "invented_total": inv,
        "missed_total": miss,
        "generic_total": gen,
        "median_kcal_error_pct": med(errs),
        "median_atwater_pct": med(atws),
        "median_latency_s": round(med(lat), 1) if med(lat) else None,
    }


def run(label: str, prompt: str, cases: list[dict], device_id: str,
        repeat: int = 1) -> dict:
    rows, served = [], set()
    for case in cases:
        path = os.path.join(ROOT, case["image"])
        if not os.path.exists(path):
            print(f"  ! missing image {case['image']}", file=sys.stderr)
            continue
        for attempt in range(repeat):
            t0 = time.time()
            try:
                result, served_model, _prov = ask_proxy(prompt, path, device_id)
            except Exception as exc:                  # noqa: BLE001
                print(f"  ! {case['id']} run{attempt + 1}: {exc}", file=sys.stderr)
                continue
            row = score_case(case, result)
            row["latency_s"] = round(time.time() - t0, 1)
            row["served_model"] = served_model
            row["run"] = attempt + 1
            rows.append(row)
            served.add(served_model)
            print(f"  {case['id']:<26} run{attempt + 1} kcal {row['pred_kcal']:>5}"
                  f" (ref {row['truth_kcal']:>5})  err {row['kcal_error_pct']:>5}%"
                  f"  invented={len(row['invented'])} missed={len(row['missed'])}"
                  f"  atwater={row['atwater_pct']}%"
                  f"  {row['latency_s']}s")
            if row["invented"]:
                print(f"      INVENTED: {', '.join(row['invented'])}")
    return {"label": label, "rows": rows, "summary": summarise(rows),
            "served_models": sorted(served)}


def print_block(res: dict) -> None:
    print(f"\n--- {res['label']} ---")
    for r in res["rows"]:
        print(f"  {r['id']:<26} kcal {r['pred_kcal']:>5} (ref {r['truth_kcal']:>5})"
              f"  err {r['kcal_error_pct']:>5}%"
              f"  invented={len(r['invented'])} missed={len(r['missed'])}"
              f"  atwater={r['atwater_pct']}%"
              f"  {r['latency_s']}s")
        if r["invented"]:
            print(f"      INVENTED: {', '.join(r['invented'])}")
        if r["missed"]:
            print(f"      MISSED:   {', '.join(r['missed'])}")
        if r["generic"]:
            print(f"      GENERIC:  {', '.join(r['generic'])}")
    s = res["summary"]
    print(f"  SUMMARY {json.dumps(s)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--compare", metavar="GIT_REF",
                    help="also score the image prompt as of this git ref, side by side")
    ap.add_argument("--json", help="write the full result here")
    ap.add_argument("--repeat", type=int, default=1,
                    help="runs per case; the upstream is NOT deterministic, so a "
                         "single run cannot distinguish a fix from luck")
    ap.add_argument("--device-id", default=None)
    args = ap.parse_args()

    with open(CASES, encoding="utf-8") as fh:
        cases = json.load(fh)["cases"]
    device = args.device_id or f"ceo-acc-{int(time.time())}"

    print(f"cases: {len(cases)}  x{args.repeat} run(s)   "
          f"(bar in ROADMAP M1 is 20 meals - the set is short, see cases.json)")
    current = run("shipped (working tree)", image_prompt(), cases, device, args.repeat)
    out = {"shipped": current}
    if args.compare:
        out["compare"] = run(f"pre-fix @{args.compare}",
                             image_prompt(args.compare), cases, device, args.repeat)

    print_block(current)
    if "compare" in out:
        print_block(out["compare"])
        a, b = current["summary"], out["compare"]["summary"]
        print("\n=== A/B: shipped vs pre-fix ===")
        for key in ("invented_total", "missed_total", "median_kcal_error_pct",
                    "median_atwater_pct", "median_latency_s"):
            print(f"  {key:<26} {b.get(key)}  ->  {a.get(key)}")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(out, fh, indent=2)
        print(f"\nwrote {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
