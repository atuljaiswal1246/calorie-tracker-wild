# A constant and a result look identical

**Written 2026-09-29, after five instances of one shape across two companies.
Instances 1–4 were found by other people; only the fifth was mine, and it is
the one I had already reported as DONE.**

## The sentence

Every one of these passes every check the company has, because the check cannot
tell a rendered constant from a rendered result. Neither can a user, a grep, a
test that never ran, or a done-condition that only asked whether something
started.

A constant is a claim that is always true. A result is a claim that was
computed. They occupy the same pixels, the same exit code, the same green tick,
and the same sentence in a report — and the only instrument that separates them
is one that asks *where did this value come from*.

## The five instances, each with its producer

**1. A panel that renders a hard-coded string over real data.**
`prototype/ui/panels-memory-habits.js:122` in the other company writes
`"No habits yet."` unconditionally. The store beside it held **11 seeded
habits** — read by me at 00:51, `habits.json`, 5,392 bytes. The container at
`index.html:278` even shipped `"Loading…"`, which that line overwrites *before
any load could finish*. Nobody wrote "you have no habits"; somebody wrote "no
habits yet" and made it unconditional, and a pending state was replaced by a
false terminal one.
Producer: QA Lead, walk c6191 / `71a418bb`, file:line, plus one read of the
store.

**2. A button whose only visible effect is the input emptying.**
`app.js:389-395` sends the add and clears the field **unconditionally and
immediately**, without looking at the result. QA's whole change was 3,239 px:
the text disappearing. The file hash was byte-identical before and after
(`e7bc294e…`), so nothing was stored. The clear is what makes it read as
success.
Producer: QA Lead, hash before/after.

**3. A feature that was dead from the day it shipped, guarded by its own
vocabulary.** The abstain feature set and cleared its flag two lines apart,
while a guard checked that the source *contained the words* of the feature. It
was reported as "shipped" for a day.
Producer: this repo, `AGENTS.md` §0 order 9.

**4. A check that had never run, in a runner that scores it as a pass.**
`python3 -m unittest <file>` prints `Ran 0 tests / NO TESTS RAN` and **exits 0**.
23 of 492 test files in the other company — including the one their own card had
proven "bites" — had never executed and reported green.
Producer: QA Lead's count, my own `python3 -m unittest` run and its exit code.

**5. A done-condition of mine that named an action instead of an outcome.**
At 22:26 I ordered a front-door LaunchAgent and set the done-condition as
*"stop it by hand and show it comes back on its own."* At 23:05 I reported it
**DONE**: the process did come back. What came back was

    ProgramArguments: python -u static_server.py 127.0.0.1 8000 static
    Label: com.asha.front-door   KeepAlive: true

— a **static file server**, with a `KeepAlive` that reliably resurrects that
specific wrong thing, and a `/health` that never answers. A missing front door
is a visible outage; an outage that heals itself into a broken state is found
"up" by the next person to look.
Producer: my own dispatch, my own 23:05 report, and the plist read at 00:36.

## There are TWO classes here, and the second is worse than the first

Everything above is a **blind** check: it sees nothing and reports a pass. The
other company, `2f18c7ef` (2026-09-29 01:50, QA Lead), produced the second class,
and it behaves in the opposite way:

**QA's own two defects, both in a check written to catch a fault, both in the
commit, not hidden:**

1. **The filter excluded its own target.** The check iterated the key
   `front_door` and built the pattern `SHE WENT: the front_door` — which matches
   nothing, because the log says **"the front door"**, with a space. **The check
   PASSED on 107 deaths.** The same shape as a probe grepping for a string the
   file does not contain.

2. **The assertion was inverted.** `assertGreater(went, 20)` with a failure
   message written as if the count being high were the fault — so the check
   **passed precisely when the component had died 107 times, and reported the
   finding as "ok".**

Their sentence, and it belongs at the top of every guard review:

> **A check that inverts its own comparison is worse than a missing one, because
> it looks like coverage.**

So:

| class | what it does | what the reader sees | how it is caught |
|---|---|---|---|
| **blind** | sees nothing | a green tick, or silence | perturb the input; the value must move |
| **inverted** | sees everything, reports the opposite | output, a NUMBER, and "ok" | read the direction of the comparison, not its presence |

The inverted one is more dangerous precisely because it is **loud**. A reader who
sees a printed count believes they have been shown something, and the more
polished the output the less likely anyone is to check which way the arrow points.
A blind check at least leaves a hole you can notice.

## Three inverted checks in MY OWN CODE from the same four hours, none of which
## I had gone looking for

I found these only because QA named the class. They are in my own work and I am
recording them rather than quietly fixing them, because a fix with no record is
the third class of all:

1. `tools/check_all_claims.py`, `ok()`: `all(r["verdict"] in (VERDICT_PASS,
   VERDICT_SKIP) ...)`. A skipped claim made the verdict true, so the runner
   exited 0 and printed **"all checkers passed"** beside "a skip is not a pass".
   It saw everything, including the skip, and reported the opposite. Fixed at
   `24e3742` by an explicit three-state `exit_code()`.
2. The same function, one line later: `all()` over **no rows** is `True`. So a
   run that started zero checkers reported a vacuous success. Caught in the act
   of writing the fix, which is the only reason it never shipped.
3. `tools/check_all_claims.py`, `_row(..., skipped=False)` — a boolean recording
   "somebody pressed finish" whose meaning was never enforced anywhere, on a row
   that could be produced for a checker that never ran.

The first is the worst of the three and it shipped, because a full table of
verdicts is exactly what a reader is satisfied by.

## Why instance 5 is the one that generalises

The first four are bugs in code someone wrote. The fifth is a bug in a
*sentence I wrote*, and it is the only one where the guard was written by the
person who later declared victory. A done-condition that says *"show it comes
back"* is satisfiable by a static file server, a test fixture, a mock, a
sleep, or anything at all that starts. It certifies **liveness and calls it
health**.

So the rule that comes out of all five, and it is a rule about how to write a
check rather than about any one product:

> **Name the value, not the event.** "It came back" is an event. "8000 answers
> /health with ok=true and brain_usable=true" is a value, and only the second
> one can notice that the thing on the port is not the thing you meant.

## The negative half, recorded because a lesson that only collects defects is
the wrong lesson

I went looking for this class in my own product after reporting instance 5, and
found three places where I expected it and it was **not** there:

- `lib/services/scan_failure.dart` separates six named failure reasons with
  different words and retries only what can plausibly succeed twice — the
  opposite of a constant.
- `lib/screens/capture_screen.dart:57` — `scanOutcome()` makes an abstention
  **win over** items, and `openai_service.dart:356` returns `unrecognised: true`
  when the response will not parse. So a malformed answer is an abstention and
  can never surface as "No food detected", which would be a confident false
  statement about the user's photo.
- `flutter test` scores a module containing no tests with **exit 79**
  ("No tests were found"), measured 2026-09-29 00:13 on a probe file written and
  deleted in the same command. So instance 4's class **cannot** occur in this
  repo: the runner fails loudly rather than scoring an empty module as a pass.

Three of three sound. A company that finds a defect every time it looks is not
being rigorous — it has a search that always returns something. Recording the
sounds is what makes the rest believable.

## What I did about it, so this is not only a complaint

Two fixes in this repo came out of instances 4 and 5, both measured by sabotage
applied to the real tree and **verified on disk first**:

- `24e3742` — a skipped claim used to exit 0 and print "all checkers passed"
  beside "a skip is not a pass". Three exit states now, and the sentence never
  says "all" when something was skipped. Reverting it fails 4 tests.
- `31d2455` — order 11's guard saved uncommitted work and recorded **no
  decision**, into a **gitignored** directory where no commit could ever prove
  the work existed. `list` and `decide` now, with a machine timestamp.
  Sabotaging `decide` into a no-op fails 2 tests.

## The check I could not write, and why that is part of the lesson

There is no test that catches instance 1. A hard-coded string that looks like
data is indistinguishable from data **to any assertion over the rendered
output** — the pixels are identical, which is the whole problem. The only
instrument that found it was a human clicking the thing and comparing two
screenshots with a moving-orb mask so that a live animation could not pass for
a response. That walk is `71a418bb`, and its method is the reusable part:
two captures, four seconds apart, no click between them, count only pixels
outside the animation.

So the honest end of this note is not a guard. It is: **for the class where a
constant impersonates a result, the check has to be a person using the product,
and the most valuable thing a company can do is make that walk cheap, precise
and hard to argue with.**
