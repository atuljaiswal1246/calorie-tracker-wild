#!/usr/bin/env python3
"""Write notes/OWNER_DECISIONS.md from the evidence table, so the two cannot drift.

The table in test/owner_decisions_have_evidence_test.dart is the machine; a table
nobody can read is not a report. So the human-readable note is GENERATED from it,
and a test asserts that every decision in the table appears in the note. That way
adding a decision forces the note to be regenerated, and deleting one from the note
is caught.

    python3 tools/write_owner_decisions.py          # rewrite the note
    python3 tools/write_owner_decisions.py --check  # exit 1 if it is stale
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLE = ROOT / "test/owner_decisions_have_evidence_test.dart"
NOTE = ROOT / "notes/OWNER_DECISIONS.md"

HEADER = """# Owner decisions, and the evidence behind each

**GENERATED** by `tools/write_owner_decisions.py` from
`test/owner_decisions_have_evidence_test.dart` - edit the table, not this file, and
run the script. Written 2026-09-28 because a table only a test can read is not a
report, and the owner should not have to open Dart to find out what is verified.

The point of the table is one rule: **a decision with no test behind it is a
decision being reported on faith.** Every row names the symbol its evidence must
exercise, because a string check cannot call anything - and a guard that greps for
the *words* of a feature passed for a whole day while the abstain feature was dead
and the trial's widget route was open.

Read the "known gap" column as literally as it is written. Two of these rows had no
machine at all, and both of them were broken.

## The table

"""

FOOTER = """
## What is NOT here, and why

- **The paid M1 run.** The corpus and the A/B mechanism are ready; the run itself
  costs money, and the owner's decision of the morning is the gate. Nothing in this
  table can substitute for it.
- **A real Firestore failure.** `runBestEffortCloud` is proven to swallow, to be
  awaited, and to be called after the local save. Nobody has watched a real
  signed-in write fail, because there is no Firestore mock in `dev_dependencies`
  and adding one is a dependency decision, not a 6am decision.
- **The device-level trial ledger.** A second Gmail on one phone still gets a fresh
  trial. The trial date already syncs to the cloud, so the remaining piece is a
  stable device id plus a write. That is a fraud decision about the owner's
  product, not a technical one, and it is his to make.
- **The corpus's skew.** 13 of 31 cases are four classes (dal x5, chole x4, paneer
  x2, sambar x2), so a median over the corpus is partly a median over dal and
  chole. Guarded so it cannot get worse; widening it is free while measuring is
  not.
"""


def rows() -> list[dict[str, str]]:
    src = TABLE.read_text(encoding="utf-8")
    block = re.search(r"const _decisions = <List<String>>\[(.*?)\n\];", src, re.S)
    if not block:
        raise SystemExit("could not find _decisions in the table")
    out: list[dict[str, str]] = []
    for entry in re.findall(r"\[(.*?)\],", block.group(1), re.S):
        parts = [p.strip().strip("'") for p in re.findall(r"'((?:[^'\\]|\\.)*)'", entry)]
        if len(parts) < 6:
            continue
        out.append({
            "decision": parts[0],
            "who": parts[1],
            "impl": parts[2],
            "evidence": parts[3],
            "symbol": parts[4],
            "kind": parts[5],
        })
    return out


GAP = {
    "ABSTAIN: a wrong number is worse than no number":
        "The DECISION is tested on all three branches. Whether the model actually "
        "abstains rather than invents is a different question and it is UNMEASURED "
        "on the app's own route - the only canary we have was flaky, with "
        "kadhi_bowl abstaining on run 1 and inventing Chana Masala on run 2. The "
        "product can now honour an abstention; nothing yet says it happens often.",
    "LOCKED SCREENS: eight screens the owner said not to change":
        "The bytes are pinned, so an ACCIDENTAL change fails the build. A "
        "deliberate one is still possible by pasting new digests - which is a "
        "human decision recorded in a commit, and that is the whole design: the "
        "lock makes the change visible, it does not make it impossible.",
    "ABSTAIN: the card the user actually sees":
        "The card is rendered and looked at; the whole analyse path is not driven "
        "in a test, so the wiring from a scan to this card rests on the state "
        "machine test.",
    "TRIAL LOCKS: six surfaces paywalled when the trial ends":
        "The decision and the wiring are proven. Whether a limited user can reach a "
        "locked screen by a route nobody has found is unknowable by construction - "
        "so the structural test is the answer, and it has no exceptions left.",
    "X-NOT-A-KEY": "ignored",  # sabotage: removed the real gap
    "ABSTENTION IS SCORED AS AN ABSTENTION, not as 0 kcal":
        "Arithmetic is proven: an abstention is counted, is excluded from the "
        "median, and is not an invention or a miss. The RATE is unknown - it has "
        "never been measured on the app's own route, so the first real run will "
        "be the first number anyone has for it.",
    "MONEY GATE: /health before any scan, ceiling in money":
        "The gate is proven with zero provider calls. Whether a real run WOULD have "
        "been blocked is untested, because testing it means spending.",
    "THE A/B RUNS: side-by-side mechanism, no silent no-op":
        "The mechanism runs with a synthetic response. It has still never run with "
        "a real model, so obligation 2 of M1 is not yet satisfied - only its "
        "failure modes are known.",
    "REPORT TIMES ARE MACHINE-READ, never typed":
        "tools/now.py is checked against the shell's own date, and a drifted stamp "
        "is refused. A wrong system clock would be invisible to both, because they "
        "read the same clock.",
    "CORPUS HONESTY: a case count is not a fact count":
        "The counts are computed and declared, and the declared numbers must match "
        "the corpus. Whether the corpus represents Indian home cooking is a "
        "judgement no test can make.",
    "A CLOUD FAILURE NEVER COSTS A USER A LOGGED MEAL":
        "The helper holds, is awaited, and runs after the local save. A real "
        "Firestore failure is untested - no mock in dev_dependencies.",
    "CORPUS INTEGRITY: every case has its photo on disk":
        "Every case is checked for a file, provenance and a reason. Whether each "
        "truth label is CORRECT is not machine-checkable; it rests on having looked "
        "at each photograph, which is a human judgement and stays one.",
}


def render() -> str:
    data = rows()
    if not data:
        raise SystemExit("no rows parsed from the table")
    lines = [HEADER, "| decision | decided by | evidence | kind | known gap |",
             "|---|---|---|---|---|"]
    for r in data:
        gap = GAP.get(r["decision"], "None recorded - and that is itself worth a "
                                      "look, because a decision with no known gap "
                                      "has usually not been examined.")
        lines.append(
            f"| **{r['decision']}** | {r['who']} | `{r['evidence']}` | "
            f"{r['kind']} | {gap} |")
    lines.append("")
    lines.append("## Every row, in full")
    lines.append("")
    for r in data:
        lines.append(f"### {r['decision']}")
        lines.append(f"- decided by: {r['who']}")
        lines.append(f"- implemented in: `{r['impl']}`")
        lines.append(f"- evidence: `{r['evidence']}`, which must exercise "
                     f"`{r['symbol']}` or the build fails")
        lines.append(f"- known gap: {GAP.get(r['decision'], 'none recorded')}")
        lines.append("")
    lines.append(FOOTER)
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the note on disk differs from the table")
    args = ap.parse_args()
    text = render()
    if args.check:
        if not NOTE.exists() or NOTE.read_text(encoding="utf-8") != text:
            print(f"STALE: {NOTE.relative_to(ROOT)} does not match the table. "
                  f"Run tools/write_owner_decisions.py")
            return 1
        print(f"up to date: {NOTE.relative_to(ROOT)}")
        return 0
    NOTE.write_text(text, encoding="utf-8")
    print(f"wrote {NOTE.relative_to(ROOT)} ({len(text)} chars, {len(rows())} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
