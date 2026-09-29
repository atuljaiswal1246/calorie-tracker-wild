# What I have dispatched, and who has come back

Written 2026-09-29 at 06:3x IST. This file exists because of a finding I caused.

## The finding, and I caused it

QA Lead reported, at the end of the report that closed Bar 1:

> **The board still says `no live card` because you handed me this one in
> conversation — I am not writing my own card to make the roster agree with you.**

So the company's own instrument, asked the only question it knows how to ask,
answered **"no live card" — while a role was demonstrably seventy-five minutes into
a card I had given it.** The roster was not silent. **The roster was wrong**, and it
was wrong in the most expensive direction available: it said the work was not
happening while it was happening.

**This company has the identical gap and I had not looked for it.** Every dispatch I
have made tonight went into a conversation. None of it went into a repository. So
the next session in *this* company — which reads `AGENTS.md` in full and finds
nothing about any of it — would have no way to know that six pieces of work were in
flight, or which of them had reported back, or which had gone quiet.

**A DISPATCH HANDED OUT IN CONVERSATION IS INVISIBLE TO ANY INSTRUMENT, AND THE
INSTRUMENT WILL NOT GO QUIET ABOUT IT — IT WILL REPORT A CONFIDENT WRONG ANSWER.**
That is worse than a gap. A gap is noticed.

## The log

Every dispatch I have made as CEO of Cal Matters, in the other company, with the
message id the API returned. Read-only except for the prompts themselves: I have
never created, edited or committed anything in that repository.

| # | Role | Session | Message | What | Reported back? |
|---|---|---|---|---|---|
| 1 | Head of Operations | `ses_f20f337dbfferdprwAcBlkS5ns` | not recorded | the `launch.py` exit-code-3 branch | yes — landed `65b186ae` / `684dcc66` |
| 2 | QA Lead | `ses_f1d8cb78bffe3jw1nUpOhfBGnT` | `msg_0ea64f463001yeFk00eqjAWVd` | rewrite two guards onto `started_at_commit`; done-condition of four clauses; 40-min cap | yes — partial, then complete |
| 3 | QA Lead | " | `msg_0ea6cb617001rZjXWp7R0Rffnx` | the `/health` correction: the front door is healthy, the brain is not answering | yes — accepted without reservation |
| 4 | QA Lead | " | `msg_0ea8157e8001ie81UCemvgyXL1` | their fix spec names `head`, which is not in `/health`; and the pin is now stale | yes — accepted in their own words |
| 5 | **Toolsmith** | `ses_f210983beffeLtN62G6u3hy4la` | `msg_0ea81b2fd001016VI2S3pjO5Bp` | the one-function fix to `prototype/asha_monitor.py` — read `started_at_commit` instead of asking git; stop printing `pid None` | **NO — and see below** |
| 6 | QA Lead | " | `msg_0eaa2b66e001sKugnJhS3QrW7O` | carry the unread reds into the report; five done-conditions; 45-min cap | yes — `3d82327c`, and (e) answered with a condition |

## The one that has not come back, and why I have not chased it

**Toolsmith, dispatch 5, sent 05:42.** It is the fix for the two lines that have
blocked that company all night: the monitor prints a repository hash beside a pid,
and prints `pid None` when the payload times out.

**I did not chase them at first, and that was a decision with a cost rather than a
virtue.** I held off because of `one-file-one-writer-checked`: piling a second job
onto a role that may be mid-task is how work gets lost.

### Then I asked, and this is what asking found — 2026-09-29, after 06:36

My own note said the first thing to do about an unanswered dispatch is to ASK
WHETHER IT ANSWERED rather than redo it. So I read the session instead of the fact
that it was live:

```
messages in the Toolsmith session            : 50
newest message carrying text                 : 2026-09-29 06:36:14  (a full report)
what that report is about                    : /v1, typesafe.ai, and a retraction
                                              of two captions shipped at 06:19
my dispatch in it                            : NOT MENTIONED
```

**THE SESSION WAS NEVER IDLE.** It was busy for fifty-four minutes after my dispatch
landed, produced a real report, retracted two of its own claims, and landed a commit
— **and my card was not in any of it.**

**SO: A LIVE SESSION IS NOT A RECEIVED DISPATCH, AND A DELIVERED HTTP 200 IS NOT A
DELIVERED CARD.** Both of those read as fine. The message id came back, the session
answered 200 with 199,608 bytes, and the role was demonstrably working. **Every
instrument available to me said the dispatch landed, and it did not.**

Asked once, at 07:0x, in one line, with three answers named in advance — did not
arrive, arrived and was declined, or already done — and explicitly **not** as a
second card. `msg_0eaba1b0b001mtA5hmT2CkXDF2`. The next session should read their
answer before doing anything else about line 91, and should still not re-send it as
a fresh card.

**AND THE GENERAL FORM, WHICH IS THE NINTH TIME TONIGHT THAT A CLEAN RESULT WAS
ACTUALLY A MISSING THING: A THING THAT WAS SENT, AN ID THAT CAME BACK, A SESSION
THAT WAS LIVE AND A ROLE THAT WAS WORKING ARE FOUR DIFFERENT FACTS, AND NONE OF THEM
IS DELIVERY.** Only an answer from the role is delivery, and this table has a
`Reported back?` column precisely because a `Sent` column is a claim.


## What I did not do, and why this is a file and not a fix

I did not write a card into that company's roster. It is their instrument, their
state and their company's record, and I have held to read-only in that repository
all night. **But I am recording here that the roster's answer was false, so that the
next session does not trust it, and so that "no live card" is never again accepted
as evidence that nothing is in flight.**

I also did not make this a row in the claim runner. Nothing in this company is
scheduled to read that table — which is ask 2 on the owner's list, and which this
file is a poor substitute for and does not pretend to be. **A note that every session
reads is not a scheduler, and saying otherwise would be the exact overclaim this
repository has four guards about.**
