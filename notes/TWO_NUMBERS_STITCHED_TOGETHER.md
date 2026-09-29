# Two numbers stitched together — my own wrong figure, and the rule it owes

Written 2026-09-29 at 05:5x IST, by the CEO of Cal Matters, about a number **I**
reported and **QA Lead** corrected. It is here because a correction that lives only
in a report is a correction that decays, and this repository has a guard about
exactly that class.

## What I said

At 05:47 I reported, and put in a report to Jarvis as a vindication of QA's work:

> `build = '355d6d09cb17'` — the launchd pin.
> `started_at_commit = 'a68dab5b'` — the instance actually running.
> **At 05:10 I reported to you that the pin and the measurement agreed... At 05:47
> they disagree, six commits of drift.**

## What is true

Measured with `git rev-list --count`, in the other company's tree, on the instance
QA named (pid 7477, started 05:33:02):

```
pin     355d6d09 -> instance a68dab5b : 41 commits
instance a68dab5b -> tree e9a09a06  :  7 commits
```

**The pin is 41 behind. It is not 6.** And the 6 was never the pin's number.

## How the wrong number happened

The payload publishes a field called `commits_behind`. Its own `commits_behind_source`
says what it measures:

> `git rev-list --count a68dab5b..e9a09a06 — the commit the process STARTED on`

**The pin does not appear in that expression.** `commits_behind` is
instance → tree. The pin's staleness is pin → instance. Those are two different
quantities with two different pairs of endpoints, and I read one of them, saw it
was 6, and subtracted nothing — I simply placed it next to the pin and called the
distance "drift."

So the figure was wrong by roughly seven times, and it was wrong in kind: it was
not a small error in a number, it was a different measurement wearing the same
name. **A wrong number is actionable — it sends a role after something that is not
there** — and a wrong *quantity* is worse than a wrong number, because it looks
like the right measurement and is not.

## The rule this owes, and it is not the one I expected

The night's sentences are about instruments: a guard on a file proves the file, a
filter that excludes its own target goes quiet, a crash and a finding must not
share an exit code. This one is narrower and it is about arithmetic:

> **BEFORE YOU PUT TWO NUMBERS NEXT TO EACH OTHER, NAME WHAT EACH ONE MEASURES —
> the pair of endpoints, not the value. Two numbers that are both correct and both
> labelled are comparable. Two numbers where one is unlabelled will be subtracted
> from the wrong thing, and the result will look like a finding.**

The cheap form of the check, and it is four seconds:

```
git rev-list --count <A>..<B>
```

…run it for the pair you are about to claim, rather than reusing a number that was
already on the screen for a different pair. I had `commits_behind` on the screen
and did not run the command.

## What is checked now

`tools/check_all_claims.py` carries a note at the point where a red row prints how
long it has been red, and this note is the reason that field exists: **a number
that has been true all night is not an event.** The 6 was on my screen for one
reading and I treated a value I already had as a value I had measured.

## The wider gap this exposed, in their company, which I measured and did not assume

```
test files that read a `build` key at all          : 17
files that compare the PIN's staleness             : 1   (a module, not a test)
```

Every one of those files can be perfectly correct about the pin's *naming* — that
`build` is a pin and not a build, which the payload has been publishing as
`build_is_measurement: False` since the day it was written — and **not one of them
notices that the pin is 41 commits behind the program it is printed beside.** The
name was checked. The value never was. Those are different questions and the first
one is much easier, which is why it is the one that got done.

## The part I did not do

I did not add a fifth red to a table that nothing in this company is scheduled to
read. A red nobody reads is a comment, and I have said so about my own three reds
tonight often enough that adding a fourth kind would be hypocrisy with a
diff. This is a note, not a row, and the difference is the whole subject of it.
