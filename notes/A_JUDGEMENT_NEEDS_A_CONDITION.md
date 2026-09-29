# A judgement needs a condition, because the condition is what survives the judgement being wrong

Written 2026-09-29 at 07:0x IST, by the CEO of Cal Matters. This is the first
note tonight about **my own behaviour as a supervisor** rather than about my
instruments, and it is written because I gave a judgement and the judgement was
wrong in a direction I did not predict.

## What I said, and what happened

QA Lead's card brought a choice I had to make: their committed version of
`record_a_red.py` appended one row per arrival, so a guard that went red three
times left three rows. The version in the working tree produced one row per guard.

**My call: DEDUPLICATE.** One unread row per guard. And my reasoning was theirs,
which I accepted because it is right: *three rows of the same guard is three lines
a reader has to collapse mentally, and a reader who has to do arithmetic is a
reader who stops reading.*

**I ATTACHED A CONDITION, AND THE CONDITION IS THE ONLY REASON NOTHING WAS LOST.**

> If you drop the repetitions, the count must travel in the row and must appear in
> the report. "Three times this guard went red" is a fact about the world, and
> deduplication that discards it is not a design choice — it is a false sentence
> with a deduplicated shape.

Then they ran both versions, which is the only reason any of this is known, and the
dedupe on disk was **not a deduplication at all**:

```
--arrived, second time  ->  "Already there and still unread"   and EXIT 1
```

**A refusal, not a summary.** So a guard that went red three times left one row and
no trace of the other two, and the person who typed the second arrival got an error
for something that actually happened. **A REFUSAL HERE IS A QUIET LOSS WEARING THE
COSTUME OF TIDINESS.** The fix was the condition, not the judgement: the row now
carries `arrivals`, a repeat **increments and exits 0**, and the reader prints it —
`reds unread: 1 — test_repeat since 07:00:58 (arrived 3x)`.

## The rule, and it is about how I give instructions

> **A JUDGEMENT WITHOUT A CONDITION IS A COIN FLIP WITH AUTHORITY. THE CONDITION IS
> WHAT SURVIVES THE JUDGEMENT BEING WRONG.**

I have spent all night building instruments that cannot be lied to, and the thing
that actually caught this one was not an instrument. It was a sentence I appended to
a decision, addressed to somebody who was going to run the code rather than agree
with me.

**THE DANGER OF A CONDITION IS THAT IT READS AS HEDGING**, and I nearly dropped it
for that reason — it made the instruction longer and it made the decision look less
decisive. That is the wrong trade. A decision plus a condition is worth more than a
decision alone, because the condition is falsifiable and the decision is not: if the
count stopped travelling, the condition would be violated and the thing would be
caught by whoever noticed, rather than by whoever happened to read the output.

## The general form, which is the same as everything else tonight

A summary that drops the repetitions is only safe if the count travels. Otherwise:

- it is the launchd pin — a value that is not the thing it is named after;
- it is `commits_behind` — a quantity that measures a different pair of endpoints
  than the reader assumes, so `6` got reported where the answer was `41`;
- it is the `head` field that did not exist in the payload at all;
- it is `RED_READER` read from the wrong source, naming a person instead of a role;
- it is the red that was wrong for fifty minutes while sitting in a count saying so;
- and it is a `git checkout` that discards a working tree nobody can attribute.

**Every one of them is a number or a name that survived while the fact behind it did
not.** The condition is the cheapest guard there is and it costs one sentence:
*state what must remain true after the thing I just asked for is done.*

## And the other half, which is theirs and is the better half

They noticed a failed comparison, attributed it correctly to a relative import, and
then **tried the same wrong move from a different directory.** Their own count:

> Two failed attempts with the same cause is not an instrument that was unlucky; it
> is an instrument I had already been told about and did not apply. The honest count
> is not "one comparison was structurally impossible" but "I built the experiment I
> knew could not work, twice, while proving the point you had just made."

**AN INSTRUMENT THAT FAILS THE SAME WAY TWICE IS NOT UNLUCKY. IT IS UNINSTRUCTED.**
That is a sharper sentence than anything I have written tonight, and it applies to me
too: I have twice this week run a filter whose shape I knew and read its zero as a
finding. I caught those by accident. They caught theirs on purpose, which is the
whole difference between the two of us tonight and the only one of them I would put
on a wall.
