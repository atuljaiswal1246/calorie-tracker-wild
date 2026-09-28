# Owner decisions, and the evidence behind each

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


| decision | decided by | evidence | kind | known gap |
|---|---|---|---|---|
| **ABSTAIN: a wrong number is worse than no number** | owner, 2026-09-28 | `test/abstain_state_machine_test.dart` | function | The DECISION is tested on all three branches. Whether the model actually abstains rather than invents is a different question and it is UNMEASURED on the app's own route - the only canary we have was flaky, with kadhi_bowl abstaining on run 1 and inventing Chana Masala on run 2. The product can now honour an abstention; nothing yet says it happens often. |
| **ABSTAIN: the card the user actually sees** | owner, 2026-09-28 | `test/abstain_card_render_test.dart` | widget | The card is rendered and looked at; the whole analyse path is not driven in a test, so the wiring from a scan to this card rests on the state machine test. |
| **TRIAL LOCKS: six surfaces paywalled when the trial ends** | owner, 2026-09-21 | `test/trial_gate_routes_test.dart` | function | The decision and the wiring are proven. Whether a limited user can reach a locked screen by a route nobody has found is unknowable by construction - so the structural test is the answer, and it has no exceptions left. |
| **MONEY GATE: /health before any scan, ceiling in money** | CEO, 2026-09-28 (order 8) | `test/money_gate_test.dart` | process | The gate is proven with zero provider calls. Whether a real run WOULD have been blocked is untested, because testing it means spending. |
| **ABSTENTION IS SCORED AS AN ABSTENTION, not as 0 kcal** | owner, 2026-09-28 | `test/abstain_scoring_test.dart` | process | Arithmetic is proven: an abstention is counted, is excluded from the median, and is not an invention or a miss. The RATE is unknown - it has never been measured on the app's own route, so the first real run will be the first number anyone has for it. |
| **THE A/B RUNS: side-by-side mechanism, no silent no-op** | ROADMAP M1 | `test/compare_path_test.dart` | process | The mechanism runs with a synthetic response. It has still never run with a real model, so obligation 2 of M1 is not yet satisfied - only its failure modes are known. |
| **REPORT TIMES ARE MACHINE-READ, never typed** | CEO, 2026-09-28 | `test/report_clock_test.dart` | process | tools/now.py is checked against the shell's own date, and a drifted stamp is refused. A wrong system clock would be invisible to both, because they read the same clock. |
| **CORPUS HONESTY: a case count is not a fact count** | CEO, 2026-09-28 | `test/corpus_independence_test.dart` | process | The counts are computed and declared, and the declared numbers must match the corpus. Whether the corpus represents Indian home cooking is a judgement no test can make. |
| **A CLOUD FAILURE NEVER COSTS A USER A LOGGED MEAL** | the core promise, 2026-09-14 foundation audit | `test/logging_survives_cloud_failure_test.dart` | function | The helper holds, is awaited, and runs after the local save. A real Firestore failure is untested - no mock in dev_dependencies. |
| **LOCKED SCREENS: eight screens the owner said not to change** | owner, 2026-09-15 (AGENTS.md) | `test/locked_screens_golden_digests_test.dart` | data | The bytes are pinned, so an ACCIDENTAL change fails the build. A deliberate one is still possible by pasting new digests - which is a human decision recorded in a commit, and that is the whole design: the lock makes the change visible, it does not make it impossible. |
| **CORPUS INTEGRITY: every case has its photo on disk** | CEO, 2026-09-28 | `test/corpus_photos_present_test.dart` | data | Every case is checked for a file, provenance and a reason. Whether each truth label is CORRECT is not machine-checkable; it rests on having looked at each photograph, which is a human judgement and stays one. |

## Every row, in full

### ABSTAIN: a wrong number is worse than no number
- decided by: owner, 2026-09-28
- implemented in: `lib/screens/capture_screen.dart`
- evidence: `test/abstain_state_machine_test.dart`, which must exercise `scanOutcome(` or the build fails
- known gap: The DECISION is tested on all three branches. Whether the model actually abstains rather than invents is a different question and it is UNMEASURED on the app's own route - the only canary we have was flaky, with kadhi_bowl abstaining on run 1 and inventing Chana Masala on run 2. The product can now honour an abstention; nothing yet says it happens often.

### ABSTAIN: the card the user actually sees
- decided by: owner, 2026-09-28
- implemented in: `lib/widgets/abstain_card.dart`
- evidence: `test/abstain_card_render_test.dart`, which must exercise `AbstainCard(` or the build fails
- known gap: The card is rendered and looked at; the whole analyse path is not driven in a test, so the wiring from a scan to this card rests on the state machine test.

### TRIAL LOCKS: six surfaces paywalled when the trial ends
- decided by: owner, 2026-09-21
- implemented in: `lib/screens/home_screen.dart`
- evidence: `test/trial_gate_routes_test.dart`, which must exercise `gateDecision(` or the build fails
- known gap: The decision and the wiring are proven. Whether a limited user can reach a locked screen by a route nobody has found is unknowable by construction - so the structural test is the answer, and it has no exceptions left.

### MONEY GATE: /health before any scan, ceiling in money
- decided by: CEO, 2026-09-28 (order 8)
- implemented in: `tools/ai_accuracy.py`
- evidence: `test/money_gate_test.dart`, which must exercise `--self-test` or the build fails
- known gap: The gate is proven with zero provider calls. Whether a real run WOULD have been blocked is untested, because testing it means spending.

### ABSTENTION IS SCORED AS AN ABSTENTION, not as 0 kcal
- decided by: owner, 2026-09-28
- implemented in: `tools/ai_accuracy.py`
- evidence: `test/abstain_scoring_test.dart`, which must exercise `unrecognised` or the build fails
- known gap: Arithmetic is proven: an abstention is counted, is excluded from the median, and is not an invention or a miss. The RATE is unknown - it has never been measured on the app's own route, so the first real run will be the first number anyone has for it.

### THE A/B RUNS: side-by-side mechanism, no silent no-op
- decided by: ROADMAP M1
- implemented in: `tools/ai_accuracy.py`
- evidence: `test/compare_path_test.dart`, which must exercise `--compare` or the build fails
- known gap: The mechanism runs with a synthetic response. It has still never run with a real model, so obligation 2 of M1 is not yet satisfied - only its failure modes are known.

### REPORT TIMES ARE MACHINE-READ, never typed
- decided by: CEO, 2026-09-28
- implemented in: `tools/report_to_jarvis.py`
- evidence: `test/report_clock_test.dart`, which must exercise `tools/now.py` or the build fails
- known gap: tools/now.py is checked against the shell's own date, and a drifted stamp is refused. A wrong system clock would be invisible to both, because they read the same clock.

### CORPUS HONESTY: a case count is not a fact count
- decided by: CEO, 2026-09-28
- implemented in: `tools/ai_accuracy.py`
- evidence: `test/corpus_independence_test.dart`, which must exercise `--corpus` or the build fails
- known gap: The counts are computed and declared, and the declared numbers must match the corpus. Whether the corpus represents Indian home cooking is a judgement no test can make.

### A CLOUD FAILURE NEVER COSTS A USER A LOGGED MEAL
- decided by: the core promise, 2026-09-14 foundation audit
- implemented in: `lib/services/storage_service.dart`
- evidence: `test/logging_survives_cloud_failure_test.dart`, which must exercise `runBestEffortCloud(` or the build fails
- known gap: The helper holds, is awaited, and runs after the local save. A real Firestore failure is untested - no mock in dev_dependencies.

### LOCKED SCREENS: eight screens the owner said not to change
- decided by: owner, 2026-09-15 (AGENTS.md)
- implemented in: `test/goldens/paywall.png`
- evidence: `test/locked_screens_golden_digests_test.dart`, which must exercise `lockedGoldenDigests` or the build fails
- known gap: The bytes are pinned, so an ACCIDENTAL change fails the build. A deliberate one is still possible by pasting new digests - which is a human decision recorded in a commit, and that is the whole design: the lock makes the change visible, it does not make it impossible.

### CORPUS INTEGRITY: every case has its photo on disk
- decided by: CEO, 2026-09-28
- implemented in: `tools/ai_accuracy.py`
- evidence: `test/corpus_photos_present_test.dart`, which must exercise `cases.json` or the build fails
- known gap: Every case is checked for a file, provenance and a reason. Whether each truth label is CORRECT is not machine-checkable; it rests on having looked at each photograph, which is a human judgement and stays one.


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
