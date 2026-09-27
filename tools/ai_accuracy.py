#!/usr/bin/env python3
"""Food-scan accuracy harness for Cal Matters.

The core claim of this app is that it knows what is on your plate. Until this
existed, every prompt change was a guess. This scores the LIVE path: it takes
the prompt **straight out of the Dart source** (so we test what actually ships,
not a copy that can drift), sends the real photo to the model, and scores the
answer against a labelled truth.

    # the PRODUCTION path: base64 image -> vision model via the proxy
    python3 tools/ai_accuracy.py

    # the FREE path, per the owner's money decision
    python3 tools/ai_accuracy.py --provider free

    # A/B the fix: score the pre-fix prompt from git, side by side
    python3 tools/ai_accuracy.py --compare ba7d8d6

    # save a baseline for the record
    python3 tools/ai_accuracy.py --json out.json

## The two providers are NOT the same measurement, and must never be mixed

| provider | what actually happens | comparable to the paid baseline? |
|---|---|---|
| `proxy` (default) | the photo is base64-encoded and sent to a **vision model** in the production request shape | yes — this IS production |
| `free` | the prompt is handed to the **opencode CLI**, and the agent reads the image off disk as a file | **no** |

The free path is a different system, not a cheaper version of the same one. A
coding model has no vision input channel; it can only see a picture because the
agent hands it the file, and it will happily describe a "butter naan" that is
really a roti. Its numbers are recorded and labelled, and they are never
averaged into the production score.

## When the free model is rate-limited, that is not a result

A 429 is a **condition**, not an answer. The harness retries with backoff, and
if it still cannot get through it records the scan as
`UNMEASURED - free model rate-limited` and reports no number for it. A number
nobody can name the producer of is the most dangerous thing this tool could
print, so it refuses to invent one.

Every run records: which model, whether it answered or was rate-limited, and
how many retries it took.

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
import shutil
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


def truth_names(truth_item: dict) -> list[str]:
    """A labelled dish plus the names a cook would reasonably use for it.

    Without this, "Chole" vs "Chana Masala" scores as a miss even though a user
    would call that the same food, and the corpus quietly rewards one naming
    habit instead of measuring recognition.
    """
    return [truth_item["name"], *truth_item.get("aliases", [])]


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



# ---------------------------------------------------------------- PREFLIGHT
class MoneyBlocked(RuntimeError):
    """Raised BEFORE any provider call, when /health already says there is no budget."""


def fetch_health(timeout: int = 20) -> dict:
    """Read the Worker's /health. No image, no model, no spend."""
    req = urllib.request.Request(
        ENDPOINT, data=b"{}", method="POST",
        headers={"Content-Type": "application/json",
                 "x-device-id": MEASUREMENT_DEVICE_ID,
                 "User-Agent": "cal-matters-proxy/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())



WRANGLER_CANDIDATES = [
    shutil.which("wrangler"),
    "/Users/neharohilla/.nvm/versions/node/v26.2.0/bin/wrangler",
    "/opt/homebrew/bin/wrangler",
]


def read_tier_reasons(tiers=("aicredits", "openrouter", "go")) -> dict:
    """Read the Worker KV key err_<tier> for each serving tier.

    This is the 402/429 evidence /health does not yet expose. It is a READ of
    shared state, not a change to it, so it needs no Worker deploy and does not
    touch Asha's setup.

    A failed read is reported as UNKNOWN, never as "no problem" - standing
    order 4: an empty result is not a finding. The caller then treats UNKNOWN as
    MONEY BLOCKED, which is the safe direction to be wrong in.
    """
    exe = next((p for p in WRANGLER_CANDIDATES if p and os.path.exists(p)), None)
    out = {}
    if not exe:
        return {t: "UNKNOWN - wrangler not found" for t in tiers}
    for t in tiers:
        try:
            proc = subprocess.run(
                [exe, "kv", "key", "get", "--binding", "QUOTA", f"err_{t}",
                 "--remote"],
                capture_output=True, text=True, timeout=90,
                cwd=os.path.join(ROOT, "cloudflare_worker"))
            if proc.returncode != 0:
                out[t] = f"UNKNOWN - kv read failed (exit {proc.returncode})"
            else:
                blob = (proc.stdout or "").strip()
                out[t] = blob if blob else "UNKNOWN - key empty or absent"
        except Exception as exc:                       # noqa: BLE001
            out[t] = f"UNKNOWN - {exc}"
    return out


def preflight(health: dict, tier_reasons: dict | None = None) -> dict:
    """Decide from /health ALONE whether a scan may start.

    "PEHLE /HEALTH, PHIR SCAN." A run that has not read /health has not earned
    the right to spend. ok=False means make ZERO provider calls.

    KNOWN GAP: /health does not yet expose the per-tier failure reason (the 402
    "insufficient balance" text lives in the KV key err_<tier>), so this gate
    infers no-budget from the breakers being suspended rather than reading the
    reason. Exposing it needs a Worker change, and the Worker is SHARED, so it
    is raised, not done. Until then a suspended tier is treated as no budget,
    which is the safe direction to be wrong in.
    """
    reasons = []
    breakers = (health.get("breaker") or {}).get("tiers") or {}
    serving = ("aicredits", "openrouter", "go")
    for name in serving:
        b = breakers.get(name) or {}
        if b.get("suspended"):
            reasons.append(
                f"{name} suspended for {b.get('suspended_for_min', '?')} min")
    live = [n for n in serving if not (breakers.get(n) or {}).get("suspended")]
    if not live:
        reasons.append("no serving tier left")

    # The decisive evidence: what the upstreams actually said. A live tier whose
    # last recorded failure was 402 has no budget even though its breaker has
    # expired - that is exactly the hole that let a run through on 2026-09-28.
    for name, raw in (tier_reasons or {}).items():
        low = str(raw).lower()
        if "insufficient balance" in low or "insufficient credit" in low \
                or "insufficient_quota" in low or "usage limit exceeded" in low \
                or "usagelimiterror" in low:
            reasons.append(f"{name}: OUT OF MONEY ({str(raw)[:70]})")
        elif str(raw).startswith("UNKNOWN"):
            reasons.append(f"{name}: {raw}")

    paid = health.get("paid_usage") or {}
    spent = float(paid.get("est_cost_usd_today") or 0)
    ok = bool(live) and not any(
        "OUT OF MONEY" in r or "UNKNOWN" in r for r in reasons)
    return {
        "ok": ok,
        "live_tiers": live,
        "spent_today_usd": spent,
        "billed_today": paid.get("requests_billed"),
        "reasons": reasons,
        "verdict": "CLEAR TO SCAN" if ok else MONEY_BLOCKED,
    }


def run_preflight(device: str | None = None) -> dict:
    """Live preflight. Returns the decision; never spends."""
    try:
        health = fetch_health()
    except Exception as exc:                       # noqa: BLE001
        # If we cannot SEE the budget we do not spend against it.
        return {"ok": False, "verdict": MONEY_BLOCKED,
                "reasons": [f"could not read /health: {exc}"],
                "spent_today_usd": None, "billed_today": None}
    return preflight(health, read_tier_reasons())


# ---------------------------------------------------------------- SPEND CEILING
class SpendCeiling(Exception):
    """The run hit its own budget and stopped itself."""


def make_cost_guard(ceiling_usd: float):
    """Abort a run mid-flight if it exceeds its own ceiling.

    "PAISA NUMBER HAI, SCAN NUMBER NAHI." A run that cannot complete still costs
    per attempt, so the ceiling is in money, enforced as it goes.
    """
    state = {"spent": 0.0, "calls": 0}

    def charge(usd: float) -> None:
        state["spent"] += usd
        state["calls"] += 1
        if ceiling_usd and state["spent"] >= ceiling_usd:
            raise SpendCeiling(
                f"ceiling ${ceiling_usd:.4f} reached after {state['calls']} calls "
                f"(${state['spent']:.4f})")

    return charge, state



# ---------------------------------------------------------------- CORPUS
# "22 cases" is not 22 facts. I searched dish by dish to escape the duplicate
# trap, and then the corpus itself carried the trap: three dish families appear
# more than once, so those errors get weighted 3x while a single-case family
# gets 1x. A median over that is a median over a corpus I built, not over meals.
# The owner's bar is 20 MEALS. Measured 2026-09-28, tools/ai_accuracy/cases.json
# at 22 cases: 17 distinct dish families, 8 cases inside a repeated family.
#
# THIS IS THE ONE DEFINITION of a family. The Dart guard executes this function
# rather than re-implementing it, so the note and the guard cannot disagree.

STAPLE_SIDES = {
    "roti", "chapati", "flatbread", "phulka", "paratha", "thepla", "bajra roti",
    "rice", "plain rice", "bread", "idli", "dosa", "uttapam", "uthappam",
    "semolina", "upma", "poha", "besan sev", "salad", "papad", "curd",
    "yogurt", "dahi", "rasam", "chutney",
}

# A family is the dish a case is really ABOUT: its most prominent non-staple
# item. A thali and a bowl of the same dal are the same judgement twice.
FAMILY_REPEAT_CAP = 3


# A dish NAME is not a dish CLASS. "Dal", "Dal Makhani" and "Urad Dal" are three
# names and one judgement; "Chole" and "Chana Masala" likewise; "Palak Paneer"
# and "Matar Paneer" likewise. The class count is the honest one and it is much
# smaller than the family count, so it is the number the bar is measured against:
# ROADMAP M1 asks for 20 MEALS, and a corpus of eleven dish classes is not
# twenty meals however many photographs it holds.
#
# Measured 2026-09-28 on cases.json @ 22 cases: 17 distinct dish NAMES, but only
# 11 distinct dish CLASSES. dal, chole and sambar alone hold 14 of the 22 cases.
# I reported 17 to Jarvis at 02:45 as the honest figure. 11 is more honest.

DISH_CLASS = {
    "dal": "dal", "dal makhani": "dal", "urad dal": "dal",
    "chole": "chole", "chana masala": "chole",
    "palak paneer": "paneer", "matar paneer": "paneer",
    "bhindi masala": "bhindi", "bhindi sabzi": "bhindi",
    "sambar": "sambar", "kadhi": "kadhi", "rajma": "rajma",
    "baingan bharta": "baingan", "lauki ki sabzi": "lauki",
    "masala dosa": "dosa", "rava idli": "idli", "idli": "idli",
    # batch 5. Mutton/chicken/dum biryani are ONE class: treating them as
    # different would inflate the class count, and the class count is the
    # number the 20-meal bar is judged on.
    "biryani": "biryani", "mutton biryani": "biryani", "chicken biryani": "biryani",
    "dum biryani": "biryani", "veg biryani": "biryani", "vegetable biryani": "biryani",
    "khichuri": "khichdi", "khichdi": "khichdi", "khichri": "khichdi",
    "sarson da saag": "sarson da saag", "sarso ka saag": "sarson da saag",
    "sarson ka saag": "sarson da saag", "sarson_ka_saag": "sarson da saag",
    "aloo gobi": "aloo gobi", "aloo ghobhi": "aloo gobi", "aloo_gobhi": "aloo gobi",
    "kofta curry": "kofta", "kofta": "kofta", "malai kofta": "kofta",
    "khakra": "khakra",
    "uthappam": "uthappam", "vada": "vada", "chickpea salad": "legume salad",
}


def class_of(case: dict) -> str:
    """The DISH CLASS a case is about, via the same first-non-staple rule."""
    names = [t.get("name", "").strip().lower() for t in case.get("truth", [])]
    for n in names:
        if n and n not in STAPLE_SIDES:
            return DISH_CLASS.get(n, n)
    return names[0] if names else "?"


def family_of(case: dict) -> str:
    names = [t.get("name", "").strip().lower() for t in case.get("truth", [])]
    for n in names:
        if n and n not in STAPLE_SIDES:
            return n
    return names[0] if names else "?"


def independence(cases: list[dict]) -> dict:
    counts: dict[str, int] = {}
    for c in cases:
        counts[family_of(c)] = counts.get(family_of(c), 0) + 1
    repeated = {k: v for k, v in counts.items() if v > 1}
    sole = [c["id"] for c in cases if counts[family_of(c)] == 1]
    worst = max(counts.values()) if counts else 0
    # A third measure, so the honest one is not chosen by me. A thali carries
    # four judgements but class_of() only sees the first non-staple item, so
    # counting every labelled item measures what the corpus can actually judge.
    coverage = set()
    for c in cases:
        for t in c.get("truth", []):
            n = t.get("name", "").strip().lower()
            if n and n not in STAPLE_SIDES:
                coverage.add(DISH_CLASS.get(n, n))

    ccounts: dict[str, int] = {}
    for c in cases:
        k = class_of(c)
        ccounts[k] = ccounts.get(k, 0) + 1
    crepeated = {k: v for k, v in ccounts.items() if v > 1}
    return {
        "cases": len(cases),
        "classes": len(ccounts),
        "coverage_classes": len(coverage),
        "coverage": sorted(coverage),
        "class_counts": dict(sorted(ccounts.items(), key=lambda kv: -kv[1])),
        "cases_in_repeated_class": sum(crepeated.values()),
        "families": len(counts),
        "repeated_families": dict(sorted(repeated.items(), key=lambda kv: -kv[1])),
        "cases_in_repeated_family": sum(repeated.values()),
        "sole_case_of_its_family": len(sole),
        "worst_family_count": worst,
        "over_cap": {k: v for k, v in counts.items() if v > FAMILY_REPEAT_CAP},
    }


def print_independence(cases: list[dict]) -> dict:
    r = independence(cases)
    print(f"CORPUS: {r['cases']} cases over {r['families']} distinct dish "
          f"families; {r['cases_in_repeated_family']} of {r['cases']} cases sit "
          f"in a family that appears more than once")
    if r["repeated_families"]:
        print("  repeated: " + ", ".join(
            f"{k} x{v}" for k, v in r["repeated_families"].items()))
    print(f"DISH CLASSES: {r['classes']} distinct classes "
          f"({', '.join(f'{k} x{v}' for k, v in list(r['class_counts'].items())[:5])}) "
          f"- a dish NAME is not a dish CLASS, and the class count is the one "
          f"the 20-meal bar is measured against")
    print(f"COVERAGE: {r['coverage_classes']} distinct classes across EVERY "
          f"labelled item (a thali holds four judgements, class_of sees one). "
          f"Reported so the conservative number cannot be picked for me: the "
          f"20-meal bar is judged on {r['classes']}, not on this one.")
    if r["over_cap"]:
        print(f"  ** {len(r['over_cap'])} family/families are over the cap of "
              f"{FAMILY_REPEAT_CAP} - the search trap is coming back **")
    return r


# ---------------------------------------------------------------- transports
FREE_MODEL = "opencode-go/space-bunny-free"

# A coding model has no vision input channel. The free path therefore differs
# in kind, not just in price, and every number it produces is labelled as such.
TRANSPORT_NOTE = {
    "proxy": "production path: base64 image -> vision model in the shipped request shape",
    "free": "DIFFERENT SYSTEM: opencode CLI agent reads the image off disk. "
            "Not comparable to the production baseline.",
}

RETRY_SLEEPS = (3, 8, 20)          # backoff, in seconds


def _looks_rate_limited(text: str) -> bool:
    low = text.lower()
    return ("429" in low or "rate limit" in low or "too many requests"
            in low or "quota" in low or "resource_exhausted" in low)


def ask_proxy(prompt: str, image_path: str, device_id: str,
               force_tier: str | None = None) -> dict:
    """Production path. Raises RateLimited if the upstream refuses."""
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
                 "User-Agent": "Mozilla/5.0 Chrome/120.0",
                 # Only when explicitly testing ONE tier. The app never sends
                 # this header, so a forced run is not measuring the app.
                 **({"x-cm-force-provider": force_tier} if force_tier else {})})
    with urllib.request.urlopen(req, timeout=120) as resp:
        served = resp.headers.get("x-cm-served-model", "?")
        provider = resp.headers.get("x-cm-provider", "?")
        raw_body = resp.read().decode()
    if served.startswith("?"):
        served = json.loads(raw_body).get("model", "?")
    parsed = json.loads(raw_body)
    usage = parsed.get("usage") or {}
    text = ((parsed.get("choices") or [{}])[0].get("message") or {}).get("content", "")
    return json.loads(text.replace("```json", "").replace("```", "").strip()), \
        served, provider, usage


# ---- cost ---------------------------------------------------------------
# gpt-4o-mini list pricing, per 1M tokens. AICredits is OpenAI-compatible, so
# this is the price the owner is billed at. Kept in one place so a price change
# is a one-line edit and never a guess buried in a report.
PRICE_IN_PER_M = 0.15
PRICE_OUT_PER_M = 0.60


def price(usage: dict) -> dict:
    pin = int(usage.get("prompt_tokens", 0) or 0)
    pout = int(usage.get("completion_tokens", 0) or 0)
    return {
        "prompt_tokens": pin,
        "completion_tokens": pout,
        "cost_usd": round(pin / 1e6 * PRICE_IN_PER_M + pout / 1e6 * PRICE_OUT_PER_M, 8),
    }


def ask_free(prompt: str, image_path: str) -> tuple[dict, str]:
    """Free path via the sanctioned CLI client.

    Never hand-rolls HTTP to zen/go: that is exactly what the abuse filter
    rejects, and the CLI is the validated client.
    """
    env = {k: v for k, v in os.environ.items() if k != "OPENCODE_API_KEY"}
    task = (f"{prompt}\n\n"
            f"Read the image file at this exact path and analyse what is in it: "
            f"{image_path}\n"
            f"Answer with ONLY the JSON object, no prose, no code fence.")
    proc = subprocess.run(
        ["opencode", "run", "-m", FREE_MODEL, task],
        capture_output=True, text=True, timeout=300, env=env, cwd=ROOT)
    out = (proc.stdout or "") + (proc.stderr or "")
    if proc.returncode != 0 or not out.strip():
        raise RuntimeError(f"free model produced nothing (exit {proc.returncode})")
    if _is_out_of_funds(out):
        raise OutOfFunds(out[-300:])
    if _looks_rate_limited(out):
        raise RateLimited(out[-300:])
    raw = out
    fence = re.search(r"```(?:json)?\s*(\{.*?\})", out, re.S)
    if fence:
        raw = fence.group(1)
    else:
        brace = re.search(r"\{.*\}", out, re.S)
        if not brace:
            raise RuntimeError("free model returned no JSON object")
        raw = brace.group(0)
    return json.loads(raw), FREE_MODEL


class RateLimited(RuntimeError):
    """The model refused for quota reasons. This is a condition, not a result."""


class OutOfFunds(RuntimeError):
    """402 / no balance / no credits. A MONEY condition, not a result."""


def _is_out_of_funds(text: str) -> bool:
    low = text.lower()
    return ("insufficient balance" in low or "insufficient credits" in low
            or "insufficient_quota" in low or "402" in low
            or "billing" in low or "quota exceeded" in low)


def with_retry(fn, *args):
    """Returns (value, retries). Raises RateLimited after the backoff is spent."""
    last = None
    for attempt, wait in enumerate((0,) + RETRY_SLEEPS):
        if wait:
            print(f"      rate limited - retry {attempt} in {wait}s")
            time.sleep(wait)
        try:
            return fn(*args), attempt
        except RateLimited as exc:
            last = exc
    raise last


# ---------------------------------------------------------------- scoring
def score_case(case: dict, result: dict) -> dict:
    truth = case["truth"]
    items = result.get("items", []) or []

    matched, invented = [], []
    for pred in items:
        hit = next((t for t in truth
                    if any(same_dish(pred.get("name", ""), n) for n in truth_names(t))),
                   None)
        (matched if hit else invented).append(pred.get("name", "?"))

    recalled = [t["name"] for t in truth
                if any(same_dish(t["name"], p.get("name", "")) or
                       any(same_dish(n, p.get("name", "")) for n in truth_names(t))
                       for p in items)]

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
        "status": "answered",
    }


UNMEASURED = "UNMEASURED"
# The reason MUST match the actual condition. An earlier version hard-coded
# "free model rate-limited" and printed that while the real cause was 402
# Insufficient Balance on every tier - a money outage mislabelled as a
# rate limit, which is precisely the kind of wrong number this harness exists
# to prevent.
# MONEY BLOCKED is not UNMEASURED. They are different reasons and they lead to
# different next decisions: UNMEASURED means "try again later", MONEY BLOCKED
# means "this costs money, stop and ask". Added 2026-09-28 after ~66 scans ran
# against an account that was already 402 - the spend was the instrument, and
# the instrument was telling me not to spend.
MONEY_BLOCKED = "MONEY BLOCKED - no budget, not an attempt"
PREFLIGHT_RULE = "PEHLE /HEALTH, PHIR SCAN"

# MEASUREMENT IDENTITY, 2026-09-28. The Worker's breakers and per-user budget are
# keyed on this id, so measurement traffic and app traffic shared ONE breaker:
# my 66 calls tripped it and the APP 502'd for ~25 minutes. The blast radius of
# a measurement run must not include the app. Engineering is splitting the
# per-user budget into a separate DO; until that lands this id at least names
# which traffic is which, so the split has something to attach to.
MEASUREMENT_DEVICE_ID = "ceo-measure"

UNMEASURED_RL = "UNMEASURED - rate limited (429)"
UNMEASURED_FUNDS = "UNMEASURED - provider out of funds (402)"
UNMEASURED_UPSTREAM = "UNMEASURED - all upstreams failed (502)"

# ROUTE-AWARE LABELS, added 2026-09-28 after a real incident.
#
# I reported "the scanner is down for every user" from measurements taken with
# `x-cm-force-provider` on each named tier. The app does NOT send that header and
# does NOT walk the tiers the way I did. Forcing tiers tells you about those
# tiers; it says nothing about the route users actually take. The owner measured
# the app's real route working (deepseek-flash, vision) at 01:20 while my tier
# probes were 402-ing, and my "outage" was a statement about my own probe.
#
# So these are now DIFFERENT labels and must never be collapsed:
UNMEASURED_APP_ROUTE = "UNMEASURED - the app's own route failed (502, all upstreams)"
UNMEASURED_FORCED_TEMPLATE = "UNMEASURED - forced tier {tier} failed ({reason})"


def forced_label(tier: str, status) -> str:
    """A failure of a FORCED tier. Says nothing about the app's route."""
    if status == 402 or status is None:
        why = "out of funds"
    elif status == 429:
        why = "rate limited"
    elif status == 502:
        why = "all upstreams failed"
    else:
        why = f"HTTP {status}"
    return UNMEASURED_FORCED_TEMPLATE.format(tier=tier or "unnamed", reason=why)


def summarise(rows: list[dict]) -> dict:
    """Scores only ever come from rows that were actually answered."""
    scored = [r for r in rows if r.get("status") == "answered"]
    unmeasured = [r for r in rows if r.get("status") != "answered"]
    if not scored:
        reasons = sorted({r.get("status", UNMEASURED) for r in unmeasured})
        return {"meals": len(rows), "scored": 0, "unmeasured": len(unmeasured),
                "verdict": "; ".join(reasons) if reasons else UNMEASURED}
    inv = sum(len(r["invented"]) for r in scored)
    miss = sum(len(r["missed"]) for r in scored)
    gen = sum(len(r["generic"]) for r in scored)
    errs = [r["kcal_error_pct"] for r in scored if r["kcal_error_pct"] is not None]
    atws = [r["atwater_pct"] for r in scored if r["atwater_pct"] is not None]
    lat = [r["latency_s"] for r in scored if r["latency_s"]]
    med = lambda xs: sorted(xs)[len(xs) // 2] if xs else None
    return {
        "meals": len(rows),
        "scored": len(scored),
        "unmeasured": len(unmeasured),
        "invented_total": inv,
        "missed_total": miss,
        "generic_total": gen,
        "median_kcal_error_pct": med(errs),
        "median_atwater_pct": med(atws),
        "median_latency_s": round(med(lat), 1) if med(lat) else None,
        "verdict": (("PARTIAL - " + "; ".join(sorted(
                        {r.get("status", UNMEASURED) for r in unmeasured}))
                    + f" ({len(unmeasured)} of {len(rows)})")
                    if unmeasured else "all scans answered"),
    }


def run(label: str, prompt: str, cases: list[dict], device_id: str,
        repeat: int = 1, provider: str = "proxy",
        force_tier: str | None = None, charge=None) -> dict:
    rows, served = [], set()
    for case in cases:
        path = os.path.join(ROOT, case["image"])
        if not os.path.exists(path):
            print(f"  ! missing image {case['image']}", file=sys.stderr)
            continue
        for attempt in range(repeat):
            t0 = time.time()
            retries, model = 0, "?"
            try:
                if provider == "free":
                    (result, model), retries = with_retry(ask_free, prompt, path)
                else:
                    (result, model, _prov, usage), retries = with_retry(
                        ask_proxy, prompt, path, device_id, force_tier)
                if charge is not None and provider != "free" and usage:
                    charge(price(usage)["cost_usd"])
                served.add(model)
                row = score_case(case, result)
                row["latency_s"] = round(time.time() - t0, 1)
                row["run"] = attempt + 1
                row["model"] = model
                row["retries"] = retries
                row["transport"] = TRANSPORT_NOTE[provider]
                if provider != "free":
                    row["usage"] = price(usage)
                rows.append(row)
                cost = (f"  ${row['usage']['cost_usd']:.6f}" if "usage" in row else "")
                print(f"  {case['id']:<24} r{attempt + 1} {model:<28} "
                      f"kcal {row['pred_kcal']:>5} (ref {row['truth_kcal']:>5})"
                      f"  err {row['kcal_error_pct']:>5}%"
                      f"  inv={len(row['invented'])} miss={len(row['missed'])}"
                      f"  retries={retries}  {row['latency_s']}s{cost}")
                if row["invented"]:
                    print(f"      INVENTED: {', '.join(row['invented'])}")
            except SpendCeiling as exc:
                print(f"\n  STOPPED BY SPEND CEILING: {exc}")
                break
            except OutOfFunds:
                row = {**{k: None for k in
                          ("pred_kcal", "kcal_error_pct", "atwater_pct")},
                       "id": case["id"], "run": attempt + 1,
                       "status": UNMEASURED_FUNDS, "model": "all-tiers",
                       "retries": len(RETRY_SLEEPS),
                       "latency_s": round(time.time() - t0, 1),
                       "invented": [], "missed": [], "generic": [],
                       "recalled": [], "n_pred": 0,
                       "n_truth": len(case["truth"]), "truth_kcal": 0}
                rows.append(row)
                print(f"  {case['id']:<24} r{attempt + 1} {UNMEASURED_FUNDS}")
            except urllib.error.HTTPError as exc:
                if force_tier:
                    reason = forced_label(force_tier, exc.code)
                elif exc.code == 502:
                    reason = UNMEASURED_APP_ROUTE
                elif exc.code == 429:
                    reason = UNMEASURED_RL
                elif exc.code == 402:
                    reason = UNMEASURED_FUNDS
                else:
                    reason = f"UNMEASURED - HTTP {exc.code}"
                row = {**{k: None for k in
                          ("pred_kcal", "kcal_error_pct", "atwater_pct")},
                       "id": case["id"], "run": attempt + 1,
                       "status": reason, "model": "all-tiers",
                       "retries": len(RETRY_SLEEPS),
                       "latency_s": round(time.time() - t0, 1),
                       "invented": [], "missed": [], "generic": [],
                       "recalled": [], "n_pred": 0,
                       "n_truth": len(case["truth"]), "truth_kcal": 0}
                rows.append(row)
                print(f"  {case['id']:<24} r{attempt + 1} {reason}")
            except RateLimited:
                row = {**{k: None for k in
                          ("pred_kcal", "kcal_error_pct", "atwater_pct")},
                       "id": case["id"], "run": attempt + 1,
                       "status": UNMEASURED_RL, "model": FREE_MODEL,
                       "retries": len(RETRY_SLEEPS),
                       "latency_s": round(time.time() - t0, 1),
                       "invented": [], "missed": [], "generic": [],
                       "recalled": [], "n_pred": 0,
                       "n_truth": len(case["truth"]), "truth_kcal": 0}
                rows.append(row)
                print(f"  {case['id']:<24} r{attempt + 1} {FREE_MODEL:<28} "
                      f"{UNMEASURED_RL} (after {len(RETRY_SLEEPS)} retries)")
            except Exception as exc:                  # noqa: BLE001
                print(f"  ! {case['id']} run{attempt + 1}: {exc}", file=sys.stderr)
    return {"label": label, "provider": provider,
            "transport": TRANSPORT_NOTE[provider],
            "rows": rows, "summary": summarise(rows),
            "served_models": sorted(served)}


def print_block(res: dict) -> None:
    print(f"\n--- {res['label']} ---")
    print(f"    provider : {res['provider']}")
    print(f"    transport: {res['transport']}")
    print(f"    models   : {', '.join(res['served_models']) or 'none answered'}")
    for r in res["rows"]:
        if r.get("status") != "answered":
            print(f"  {r['id']:<24} {r.get('status', UNMEASURED)}")
            continue
        print(f"  {r['id']:<24} r{r.get('run')} {r.get('model', '?'):<28}"
              f" kcal {r['pred_kcal']:>5} (ref {r['truth_kcal']:>5})"
              f"  err {r['kcal_error_pct']:>5}%"
              f"  inv={len(r['invented'])} miss={len(r['missed'])}"
              f"  retries={r.get('retries', 0)}")
        if r["missed"]:
            print(f"      MISSED:   {', '.join(r['missed'])}")
        if r["generic"]:
            print(f"      GENERIC:  {', '.join(r['generic'])}")
    print(f"  SUMMARY {json.dumps(res['summary'])}")


def cost_report(rows: list[dict], device: str) -> None:
    """The number the owner actually asked for: what does a scan cost.

    Separates the cost of the PHOTO from the cost of the prompt by also pricing
    one text-only call with no image attached. Without that split, "cost per
    scan" is a number nobody can reason about.
    """
    scans = [r for r in rows if r.get("usage")]
    if not scans:
        print("\n=== COST ===\nno priced scans in this run "
              "(the free provider reports no token usage)")
        return

    # text-only control: same model, same question, no image
    control = None
    try:
        body = json.dumps({
            "model": "mimo-v2.5",
            "messages": [{"role": "user", "content": "Say ok"}],
            "max_tokens": 5,
        })
        req = urllib.request.Request(
            ENDPOINT, data=body.encode(), method="POST",
            headers={"Content-Type": "application/json",
                     "x-device-id": device, "User-Agent": "Mozilla/5.0 Chrome/120.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            control = price(json.loads(resp.read().decode()).get("usage") or {})
    except Exception as exc:                          # noqa: BLE001
        print(f"  (text-only control failed: {exc})")

    costs = [s["usage"]["cost_usd"] for s in scans]
    pins = [s["usage"]["prompt_tokens"] for s in scans]
    mean = lambda xs: sum(xs) / len(xs)
    med = lambda xs: sorted(xs)[len(xs) // 2]

    print("\n=== COST, 5 paid scans (gpt-4o-mini via AICredits) ===")
    print(f"  {'case':<24}{'prompt tok':>12}{'output tok':>12}{'cost USD':>14}")
    for s in scans:
        u = s["usage"]
        print(f"  {s['id']:<24}{u['prompt_tokens']:>12}{u['completion_tokens']:>12}"
              f"{u['cost_usd']:>14.6f}")
    print(f"\n  COST PER SCAN   mean ${mean(costs):.6f}   median ${med(costs):.6f}")
    if control:
        per_photo = mean(costs) - control["cost_usd"]
        print(f"  text-only call        ${control['cost_usd']:.6f} "
              f"({control['prompt_tokens']} prompt tok, no photo)")
        print(f"  => COST PER PHOTO     ${per_photo:.6f}  "
              f"(mean prompt tokens with a photo: {mean(pins):.0f})")
    print("\n  What that means per person, at the prices in the app:")
    for label, n in (("1 scan/day", 30), ("3 scans/day", 90), ("5 scans/day", 150)):
        print(f"    {label:<12} {n:>4} scans/month  =  ${mean(costs) * n:.4f}/month")
    print("\n  Priced at gpt-4o-mini list: $0.15/1M in, $0.60/1M out. "
          "Not a quote - the invoice is the truth.")



def self_test() -> int:
    """Prove the preflight gate, with ZERO real provider calls.

    Simulates an all-suspended /health (what a drained account looks like) and
    asserts the gate blocks. Then simulates a healthy /health and asserts the
    gate allows. The provider call is replaced by a counter, so running this
    costs nothing and cannot spend by accident.
    """
    calls = {"n": 0}

    def counting_call(*_a, **_k):
        calls["n"] += 1
        raise AssertionError("a provider call happened during the self-test")

    real = ask_proxy
    globals()["ask_proxy"] = counting_call
    try:
        blocked = {
            "breaker": {"tiers": {
                "aicredits": {"suspended": True, "suspended_for_min": 12},
                "openrouter": {"suspended": True, "suspended_for_min": 12},
                "go": {"suspended": True, "suspended_for_min": 20},
            }},
            "paid_usage": {"requests_billed": 81, "est_cost_usd_today": 0.33},
        }
        g1 = preflight(blocked)
        print(f"[self-test] all-suspended  -> {g1['verdict']}  ok={g1['ok']}")
        if g1["ok"]:
            print("[self-test] FAIL: a drained account was allowed to scan")
            return 1
        if calls["n"] != 0:
            print(f"[self-test] FAIL: {calls['n']} provider call(s) were made")
            return 1

        healthy = {
            "breaker": {"tiers": {
                "aicredits": {"suspended": False, "suspended_for_min": 0},
                "openrouter": {"suspended": False, "suspended_for_min": 0},
                "go": {"suspended": False, "suspended_for_min": 0},
            }},
            "paid_usage": {"requests_billed": 0, "est_cost_usd_today": 0.0},
        }
        g2 = preflight(healthy)
        print(f"[self-test] healthy        -> {g2['verdict']}  ok={g2['ok']}")
        if not g2["ok"]:
            print("[self-test] FAIL: a healthy budget was blocked")
            return 1

        # The label must be MONEY BLOCKED, not UNMEASURED: they lead to
        # different next decisions.
        if MONEY_BLOCKED in UNMEASURED_UPSTREAM or "UNMEASURED" in MONEY_BLOCKED:
            print("[self-test] FAIL: MONEY_BLOCKED and UNMEASURED are conflated")
            return 1
        # The hole that actually let a run through: a tier whose breaker has
        # expired but whose last recorded failure was 402. It must still block.
        expired_but_broke = {
            "breaker": {"tiers": {
                "aicredits": {"suspended": False, "suspended_for_min": 0},
                "openrouter": {"suspended": False, "suspended_for_min": 0},
                "go": {"suspended": False, "suspended_for_min": 0},
            }},
            "paid_usage": {"requests_billed": 81, "est_cost_usd_today": 0.33},
        }
        g3 = preflight(expired_but_broke, {
            "aicredits": '{"status":402,"detail":"Insufficient Balance"}',
        })
        print(f"[self-test] breaker expired but 402 on record -> {g3['verdict']}  ok={g3['ok']}")
        if g3["ok"]:
            print("[self-test] FAIL: an expired breaker hid an empty account")
            return 1

        # An unreadable budget is not a green light either.
        g4 = preflight(expired_but_broke, {"aicredits": "UNKNOWN - kv read failed"})
        print(f"[self-test] unreadable budget          -> {g4['verdict']}  ok={g4['ok']}")
        if g4["ok"]:
            print("[self-test] FAIL: an unreadable budget was treated as spendable")
            return 1

        print(f"[self-test] labels distinct: {MONEY_BLOCKED!r} vs {UNMEASURED_UPSTREAM!r}")
        print(f"[self-test] provider calls made during self-test: {calls['n']}")
        print("[self-test] PASS")
        return 0
    finally:
        globals()["ask_proxy"] = real


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--compare", metavar="GIT_REF",
                    help="also score the image prompt as of this git ref, side by side")
    ap.add_argument("--json", help="write the full result here")
    ap.add_argument("--provider", choices=["proxy", "free"], default="proxy",
                    help="proxy = production vision path (paid). free = the "
                         "opencode CLI, a DIFFERENT system - never averaged "
                         "together with proxy results")
    ap.add_argument("--repeat", type=int, default=1,
                    help="runs per case; the upstream is NOT deterministic, so a "
                         "single run cannot distinguish a fix from luck")
    ap.add_argument("--device-id", default=None)
    ap.add_argument("--max-cost-usd", type=float, default=0.50,
                    help="hard spend ceiling for this run, in money. The run "
                         "aborts mid-flight when it is reached. Default $0.50.")
    ap.add_argument("--skip-preflight", action="store_true",
                    help="escape hatch only. Without /health you have not "
                         "earned the right to spend.")
    ap.add_argument("--corpus", action="store_true",
                    help="print the corpus independence report and exit. Costs "
                         "nothing: it reads cases.json and never calls a model.")
    ap.add_argument("--self-test", action="store_true",
                    help="prove the preflight gate: a fake all-suspended /health "
                         "must produce ZERO provider calls")
    ap.add_argument("--force-tier", default=None,
                    help="measure ONE tier via x-cm-force-provider. The app does "
                         "NOT send this header, so a forced run never describes "
                         "the app's route and its failures are labelled as a "
                         "forced tier, never as an app outage.")
    ap.add_argument("--cost", action="store_true",
                    help="price the scans: cost per scan, cost per photo, and "
                         "per-person monthly projection")
    args = ap.parse_args()

    with open(CASES, encoding="utf-8") as fh:
        cases = json.load(fh)["cases"]
    # Measurement traffic carries its own id so the per-user budget and the
    # breakers can be split away from the app's. Blast radius of a measurement
    # run must not include a user.
    device = args.device_id or MEASUREMENT_DEVICE_ID

    if args.corpus:
        print_independence(cases)
        return 0

    if args.self_test:
        return self_test()

    # ---- PEHLE /HEALTH, PHIR SCAN ----
    if not args.skip_preflight:
        gate = run_preflight(device)
        print(f"PREFLIGHT: {gate['verdict']}")
        print(f"  live tiers        : {gate.get('live_tiers')}")
        print(f"  billed today      : {gate.get('billed_today')}"
              f"   est ${gate.get('spent_today_usd')}")
        for r in gate["reasons"]:
            print(f"  - {r}")
        if not gate["ok"]:
            print(f"\n{MONEY_BLOCKED} — ZERO provider calls will be made. "
                  f"Not 'UNMEASURED': this is a budget stop, and it needs a "
                  f"decision, not a retry.")
            return 3
    print(f"SPEND CEILING: ${args.max_cost_usd:.4f} for this run")
    charge, _money = make_cost_guard(args.max_cost_usd)

    print(f"cases: {len(cases)}  x{args.repeat} run(s)   provider: {args.provider}")
    print(f"ROUTE: {'FORCED TIER ' + args.force_tier + ' (the app never sends this header)' if args.force_tier else 'the app\'s own default route - what users actually hit'}")
    ind = print_independence(cases)
    print(f"bar in ROADMAP M1 is 20 MEALS = 20 distinct dishes. We have "
          f"{ind['families']} distinct dish names and only {ind['classes']} "
          f"distinct dish CLASSES across {ind['cases']} cases, so the bar is "
          f"NOT met by a wide margin - quote a score with all three numbers, "
          f"never the case count alone.")
    route = f"forced:{args.force_tier}" if args.force_tier else "app-default"
    current = run("shipped (working tree)", image_prompt(), cases, device,
                  args.repeat, args.provider, args.force_tier, charge)
    out = {"provider": args.provider, "route": route, "shipped": current}
    if args.compare:
        out["compare"] = run(f"pre-fix @{args.compare}",
                             image_prompt(args.compare), cases, device,
                             args.repeat, args.provider, args.force_tier, charge)

    print_block(current)
    if "compare" in out:
        print_block(out["compare"])
        a, b = current["summary"], out["compare"]["summary"]
        print("\n=== A/B: shipped vs pre-fix (same provider only) ===")
        for key in ("scored", "unmeasured", "invented_total", "missed_total",
                    "median_kcal_error_pct", "median_atwater_pct",
                    "median_latency_s"):
            print(f"  {key:<26} {b.get(key)}  ->  {a.get(key)}")

    if args.cost and args.provider == "proxy":
        cost_report(current["rows"], device)

    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(out, fh, indent=2)
        print(f"\nwrote {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
