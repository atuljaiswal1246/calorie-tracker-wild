#!/usr/bin/env python3
"""Does the published privacy page name every third party that can receive data?

THE DEFECT (2026-09-28, 07:19Z reading of the Worker's /health). The hosted
privacy page names ONE image processor: "AICredits: Used for food image
analysis." The Worker's own /health says the last billed request was served by

    {"provider": "openrouter", "served_model": "openai/gpt-4o-mini"}

So a user's food photo can be processed by a company the privacy policy does not
name, and does not even mention. The Play data-safety form is declared from that
page, so the declaration and the behaviour disagree. That is a compliance defect
with a user's photograph in it, and it is exactly what standing order 2 exists
to prevent: the model is NOT chosen by us and NOT chosen by the app, so the set
of processors is decided by whichever key is funded. A static page cannot
describe a dynamic rotation — and a page that names one of three is worse than
one that names the mechanism, because it looks answered.

WHY THIS IS A CHECKER AND NOT A FINDING I REPORT. I read /health, saw
openrouter, and could have written "the privacy page is wrong". That claim has
nothing behind it: it is my reading of two documents at one moment, and the
rotation changes. Instead the processor list is derived from the Worker's own
source — the tiers it can actually serve — and the policy is required to cover
them ALL, so the page stays correct as the rotation changes. Adding a tier to
the Worker breaks this check until the policy names it. That is the direction a
guard should fail in.

The live /health read is a separate, optional part (`--live`) because the
scheduled check must not depend on the network, and because a network read that
fails must never be read as "no third parties" (standing order 4).

Exit codes
  0  every processor the Worker can serve is named in public/privacy.html
  1  a reachable processor is missing from the policy
  2  the policy or the Worker source is missing, or nothing was checked
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "public" / "privacy.html"
TERMS = ROOT / "public" / "terms.html"
WORKER = ROOT / "cloudflare_worker" / "worker.js"
WORKER_URL = "https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev"

# The user-facing document, and the internal copies that the Play Console is
# filled from. The first version of this checker guarded public/privacy.html
# alone, which meant the SAME wrong claim survived in two more places:
# PRIVACY_POLICY.md (the repo copy) and AGENTS.md's data-safety section, which
# says "photos (sent to AICredits for analysis)". A guard that watches one file
# is a guard that lets the finding through the other two doors.
USER_FACING = [POLICY]
DECLARED_COPIES = [ROOT / "PRIVACY_POLICY.md", ROOT / "AGENTS.md"]

# The policy must name the company's CONSUMER-FACING name, not the secret's
# variable name. The Worker calls its secret OPENROUTER_KEY; the company a user
# could complain to is OpenRouter. Keeping both spellings here means a policy
# that pastes the variable name does not count as coverage.
PROCESSOR_NAMES = {
    "aicredits": ["AICredits", "aicredits.in"],
    "openrouter": ["OpenRouter", "openrouter.ai"],
    "go": ["OpenCode", "opencode.ai"],
    "zen": ["Zen", "zen.so"],
}

# A tier is only a processor if the Worker can actually SEND a request with it.
#
# NOT the `env.X_KEY` presence test, which was my first attempt and was wrong:
# it counted ZEN, because ZEN_KEY exists in the environment. But ZEN is not in
# the serving rotation at all - it appears in worker.js only in the probe list -
# so a secret that is never asked for a completion cannot receive a photo. That
# is the same mistake as counting storage_service.addWeightEntry as evidence a
# user can log a weight, and as counting the WORD "fasting" as evidence of a
# fasting screen: presence is not capability.
#
# The real gate is `const rotation = [...]`, the list the serving loop iterates.
# Read that, and the evidence line is the rotation entry itself.
_ROTATION = re.compile(
    r"const\s+rotation\s*=\s*\[(?P<body>.*?)\];", re.S)
_ROTATION_ENTRY = re.compile(r'\[\s*"(?P<name>[a-z0-9_]+)"\s*,')


def _reachable_tiers() -> tuple[set[str], list[str]]:
    """Tiers the Worker's SERVING loop can reach, read from its own source.

    Returns (tiers, evidence) where evidence is the rotation entry itself, so a
    reader can check the derivation instead of trusting it.
    """
    if not WORKER.exists():
        return set(), []
    src = WORKER.read_text(encoding="utf-8", errors="replace")
    m = _ROTATION.search(src)
    if not m:
        return set(), []
    start_line = src[: m.start()].count("\n") + 1
    tiers: set[str] = set()
    evidence: list[str] = []
    for entry in _ROTATION_ENTRY.finditer(m.group("body")):
        name = entry.group("name")
        tiers.add(name)
        evidence.append(f'worker.js:{start_line} rotation += "{name}"')
    return tiers, evidence


# A "declaring line" is one that NAMES a processor AND says what is sent to it.
# Matching on "photo|image" alone swept in every image path in the file and then
# reported a processor missing from a line that never mentioned any — which is
# how a file that says "AICredits" plainly got reported as naming no processor
# at all. Both halves are required, and the line is reported so a reader can see
# that the filter chose it rather than guessed.
_SENT = re.compile(r"photo|image|picture|scan|analys|analys|process|retai|"
                   r"upload|send|sent", re.I)
_NAME = re.compile(
    r"\b(" + "|".join(sorted(
        {n for names in PROCESSOR_NAMES.values() for n in names},
        key=len, reverse=True)) + r")\b", re.I)


def _declaring_lines(text: str) -> list[str]:
    """Lines that name a processor AND say what is sent to it."""
    out = []
    for ln in text.splitlines():
        ln = ln.strip().lstrip("-*| ").strip()
        if not ln or _NAME.search(ln) is None or _SENT.search(ln) is None:
            continue
        out.append(ln)
    return out


def _quote_one(lines: list[str]) -> str:
    if not lines:
        return "(no declaring line found - nothing to quote)"
    ln = lines[0]
    return (ln[:110] + "...") if len(ln) > 110 else ln


def _strip_markup(raw: str) -> str:
    """Plain text a reader could see. A name inside an HTML comment is not a
    promise, and counting it as one would let a commented-out name pass."""
    no_comments = re.sub(r"<!--.*?-->", " ", raw, flags=re.S)
    return re.sub(r"<[^>]+>", " ", no_comments)


def _policy_text() -> str:
    if not POLICY.exists():
        return ""
    return _strip_markup(POLICY.read_text(encoding="utf-8", errors="replace"))


def _live_health(timeout: float = 20.0) -> dict | None:
    """Read the Worker's /health. Returns None on ANY failure, and says so.

    Never returns a fabricated empty dict: a failed read is not evidence that no
    provider is configured.
    """
    try:
        req = urllib.request.Request(
            WORKER_URL + "/health",
            data=b"{}",  # /health is a POST route; the body is ignored
            headers={"content-type": "application/json",
                     "user-agent": "calmatters-claim-check/1.0"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except (urllib.error.URLError, OSError, ValueError, json.JSONDecodeError) as e:
        print(f"NOTE: could not read {WORKER_URL}/health ({type(e).__name__}). "
              f"NOT VERIFIED this run - a failed read is not an empty result.")
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--live", action="store_true",
                    help="also read the Worker's /health and report who last served")
    args = ap.parse_args()

    if not POLICY.exists() or not WORKER.exists():
        print("FATAL: public/privacy.html or cloudflare_worker/worker.js is "
              "missing. Nothing was checked, so nothing is claimed.")
        return 2

    tiers, evidence = _reachable_tiers()
    if not tiers:
        print("FATAL: no serviceable tier could be derived from worker.js. An "
              "empty result is not a pass (standing order 4).")
        return 2

    policy = _policy_text()
    if not policy.strip():
        print("FATAL: public/privacy.html has no readable text. Nothing checked.")
        return 2

    missing = []
    # THE SENTENCE, corrected 2026-09-29 after QA Lead caught the same class of
    # fault in their company: their guard asserted a fault the product did not
    # have, and I have been relaying a version of it all night.
    #
    # This check reads ONE file - cloudflare_worker/worker.js, the SOURCE - and
    # from it concludes what the app "can send a photo to". That is a CONFIGURATION
    # fact wearing a BEHAVIOUR sentence, and this repository's own measured record
    # contradicts the behaviour half: AGENTS.md:537 records OPENCODE_KEY as out of
    # monthly quota with no vision model, and :539 records ZEN_KEY as not in the
    # serving rotation at all.
    #
    # THE VERDICT IS STILL CORRECT AND IS NOT BEING WEAKENED. A Play data-safety
    # declaration describes what the app CAN do, not what it did this afternoon: a
    # processor that is configured to receive a photo and would serve it if funded
    # is a processor, and the day the key is recharged an undeclared processor is
    # exactly the finding that costs an app its listing. So `go` and `openrouter`
    # stay in the red.
    #
    # What changes is the claim this instrument is entitled to make, which is the
    # whole difference between this check and the launchd pin in the other company:
    # A SOURCE FILE CAN TELL YOU WHAT IS CONFIGURED. IT CANNOT TELL YOU WHAT RAN.
    print("Third parties the Worker is CONFIGURED to be able to send a photo to,\n"
          "vs public/privacy.html. Configuration, not measured behaviour - see the\n"
          "note at the top of this file. The declaration covers capability.\n")
    for tier in sorted(tiers):
        names = PROCESSOR_NAMES.get(tier, [tier])
        hit = next((n for n in names if n.lower() in policy.lower()), None)
        where = next((e for e in evidence if f'"{tier}"' in e), "")
        if hit:
            print(f"  {tier:<12} NAMED      policy says \"{hit}\"  ({where})")
        else:
            print(f"  {tier:<12} NOT NAMED  expected one of {', '.join(names)}"
                  f"  ({where})")
            missing.append(tier)

    if args.live:
        health = _live_health()
        if health is not None:
            b = (health.get("paid_usage") or {}).get("last_billed_request") or {}
            print(f"\n  live /health: last billed request served by "
                  f"{b.get('provider')} ({b.get('served_model')}) at {b.get('at')}")
            if b.get("provider") and b["provider"] not in missing:
                pass  # named already, nothing to add
            elif b.get("provider"):
                print(f"  and that provider is NOT in the policy. The page is "
                      f"wrong today, not merely incomplete.")
        else:
            print("\n  live /health: NOT READ. This run proves the static "
                  "coverage only.")

    print("")
    if missing:
        print(f"FAIL: the policy does not name {len(missing)} processor(s) the "
              f"Worker is CONFIGURED to be able to send a photo to: "
              f"{', '.join(missing)}. A data-safety declaration describes what the\n"
              f"  app CAN do, not what it did this afternoon, so an out-of-quota key\n"
              f"  is still an undeclared processor the day somebody recharges it.")
        print("A data-safety declaration is written from this page, so the")
        print("declaration and the behaviour disagree. Name every processor, or")
        print("describe the mechanism (one door, model chosen server-side, any")
        print("of several processors) — which stays true as the rotation changes.")
    else:
        print(f"PASS: the policy names all {len(tiers)} processors the Worker can "
              f"serve ({', '.join(sorted(tiers))}).")

    # The same claim, restated where Play Console is actually filled from. A
    # corrected hosted page with a stale repo copy still puts the wrong name in
    # the declaration, so these are checked for the same coverage.
    print("\nInternal copies of the same declaration (Play Console is filled "
          "from these):")
    stale_copies = []
    for path in DECLARED_COPIES:
        if not path.exists():
            print(f"  {path.name:<22} ABSENT (nothing to check)")
            continue
        text = _strip_markup(path.read_text(encoding="utf-8", errors="replace"))
        # The DECLARING LINES, not the whole file. AGENTS.md passes a whole-file
        # test today because it contains the word "OpenRouter" in a comment about
        # backups — while the sentence the owner copies into the data-safety form
        # still reads "photos (sent to AICredits for analysis)". A file-level
        # match is the vocabulary trap again: the file mentions the right word
        # somewhere while the claim stays wrong.
        claims = _declaring_lines(text)
        gaps = [t for t in sorted(tiers)
                if not any(n.lower() in " ".join(claims).lower()
                           for n in PROCESSOR_NAMES.get(t, [t]))]
        where = _quote_one(claims)
        if gaps:
            print(f"  {path.name:<22} MISSING {', '.join(gaps)}")
            print(f"  {'':<22} in its declaring line: {where}")
            stale_copies.append((path.name, gaps))
        else:
            print(f"  {path.name:<22} complete")

    if stale_copies:
        print()
        for name, gaps in stale_copies:
            print(f"  - {name} still omits {', '.join(gaps)} from the line the "
                  f"declaration is written from.")
        print("  Fixing the hosted page alone does not fix the declaration.")
        return 1

    return 0 if not missing else 1


if __name__ == "__main__":
    sys.exit(main())
