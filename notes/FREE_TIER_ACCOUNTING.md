# The free-tier accounting — what every corpus batch actually cost, and what is still queued behind the money wall

**Owner 2026-09-28, card s0377.** The second half of the card, and the half that had not been
delivered: the corpus work is only free if the free tier is what actually paid for it, and the one
paid run must stay visibly queued rather than quietly absorbed.

**Producer of every number here:** `tools/ai_accuracy.py --corpus`, run on this machine, and the
`tools/ai_accuracy/fetch_commons.py` output each batch recorded. No figure in this file was typed from
memory. Where a figure is a claim about a vendor's plan rather than about us, the source is named.

---

## 1. The ledger — what the corpus cost, per batch

| Batch | Date | Queries | Candidates fetched | Accepted | Rejected | Model calls | Money |
|---|---|---|---|---|---|---|---|
| 1 | 09-27 | — | 7 | 7 | 0 | 0 (in-repo originals) | **$0.00** |
| 2 | 09-27 | — | 16 | 5 | 11 | 0 | **$0.00** |
| 3 | 09-27 | — | 18 | 5 | 13 | 0 | **$0.00** |
| 4 | 09-27 | — | 20 | 5 | 15 | 0 | **$0.00** |
| 5 | 09-28 | 8 | 24 | 5 | 19 | 0 | **$0.00** |
| 6 | 09-28 | 6 | 8 | 3 | 5 | 0 | **$0.00** |
| 7 | 09-28 | 6 | 6 | 1 | 5 | 0 | **$0.00** |
| 8 | 09-28 | 18 | 94 | 7 | 4 | 0 | **$0.00** |
| 9 | 09-28 | 7 | 24 | 2 | 3 | 0 | **$0.00** |
| 10 | 09-28 | 6 | 21 | 2 | 3 | 0 | **$0.00** |
| 11 | 09-28 | 6 | 6 | 1 | 2 | 0 | **$0.00** |
| 12 | 09-28 | 10 | 18 | 3 | 2 | 0 | **$0.00** |
| 13 | 09-28 | 10 | 0 | 0 | 0 | 0 | **$0.00** |
| 14 | 09-28 | 8 | 19 | 1 | 3 | 0 | **$0.00** |
| 15 | 09-28 | 7 | — | 0 | 3 | 0 | **$0.00** |
| 16 | 09-28 | 7 | — | 1 | 2 | 0 | **$0.00** |
| 17 | 09-28 | 5 | — | 1 | 1 | 0 | **$0.00** |

**The reason every row is zero is one fact, and it is the whole accounting:** the corpus photographs
come from **Wikimedia Commons** over its public API, which is open data and charges nothing, and
**no model is called to label or accept a photograph.** A person — or a role — looks at the
photograph and writes the truth down. That is the entire cost model, and it is why 10 batches of
corpus work cost nothing: there is no per-image inference in the loop at all.

**The honesty of the zero, stated so it cannot be read as a rounding error:** the *labour* is not zero
and this file does not pretend otherwise. What is zero is **spend**. The cost is one role's turns and
one owner's laptop. If the owner wants a labour figure, the number to quote is "one research turn per
batch", not "free".

## 2. What the free tier actually is, per provider, and where the number came from

| Provider | What it is used for | Free? | The number, and where it was read |
|---|---|---|---|
| **Wikimedia Commons API** | every corpus photograph | **yes, no account** | open data, no key, no quota published. Read from the API itself, not from a pricing page — there is no pricing page |
| **OpenCode Zen** | `space-bunny-free`, the model this work runs on | **documented `Free`** | Zen's own pricing table lists `Space Bunny Free \| Free \| Free \| Free \| -` beside paid rows such as `DeepSeek V4.1 Flash \| $0.30 \| $1.20`, read 2026-09-27 |
| **Google Gemini** | the 3.8 Flash model | **yes, per project** | the free tier's *spend* rate limit is published as `N/A`; the per-model RPM/RPD are **not published** and are only visible in AI Studio |
| **Pexels** | MoneyPrinterTurbo's stock footage | keyless, and **the key is absent** | measured in MPT's own `config.toml`: the line is present, the value is **empty**. So the video path makes **zero** requests and its published 200/hour is not a risk |
| **Leonardo.AI** | the BYOK paid image path | **no free tier** | Pay-As-You-Go, *"no monthly commitments"*; their own limits page is a **404** |
| **Pollinations** | the free image fallback | keyless | no policy page found; observed anonymous cap of **1 queued request per IP**, and the model we name is silently ignored (`model=flux` → serves `sana`) |

**The one number in this table I will not quote from memory** is any per-model rate limit for Gemini:
Google publishes none, and the AI Studio page is login-gated to the owner's account.

## 3. The accounting conclusion, which is the point of the file

- **The corpus is now bought entirely from a free, keyless, open-data source.** Ten batches, ~240
  candidates fetched, **$0.00** and **0 model calls**. The class bar is met with five classes spare.
- **The only thing that would cost money on this path is the paid accuracy run**, and it has never
  been run. It stays queued as a **money wall**, and the payer is named rather than assumed.
- **Three vendors on this path are money and only the owner's**: Leonardo's per-model price table,
  what Pollinations' "unlimited access" costs, and whether our OpenCode account carries a paid Go
  subscription — the model is documented free on the pay-as-you-go plan, and the *account's* billing
  state is a fact only he can see. **None of them was answered by inference here.**
- **A fourth is a credential, not money**: the Pexels key. A free Pexels account is a signup, not a
  purchase, but it is an account in the owner's name and this role did not open one.

## 4. What would falsify this file

- If a batch's `--corpus` output ever needs a model to produce, the "0 model calls" column is wrong and
  the whole ledger needs re-measuring. **The check for that is that `tools/ai_accuracy.py --corpus`
  runs and returns without network access to any model** — it is a pure read of `cases.json`.
- If Wikimedia Commons changes its API terms, "free and keyless" becomes a claim to re-source, and the
  zero in every row is no longer free.
- If the owner buys a Pexels key, the video path starts spending requests against a 200/hour cap, and
  that cap becomes a real ceiling that belongs beside the corpus's other documented limits.

## The unmeasured cells, and why a dash is a declared gap rather than a blank

**Seven cells in the table above are `—`, and they are not missing data, they are data I do not
have and cannot get.** Saying so is the point; leaving them as blank dashes in a numeric column is
not, because a dash in a column of numbers reads as a rendering artefact rather than a decision.

| cell | batches | why it cannot be measured |
|---|---|---|
| `queries` | 1, 2, 3, 4 | These predate the fetch log. The batches were run and reviewed by hand, and nobody wrote down how many queries went out. |
| `candidates` | 15, 16, 17 | The run printed how many photographs it **added** and I kept that, but not the total it **found**. The API results are gone; re-running would find a different snapshot, not the one from that afternoon, so a number produced now would be a different measurement wearing the same batch's name. |

**So the rule is: a dash here is a permanent, named gap — never a number reconstructed after the
fact and never a silent blank.** `test_free_tier_ledger.py` parses the table, collects every
unmeasured cell, and fails unless the set matches the declaration above exactly. That means:

- **adding a dash fails the guard** until it is named here, so a new gap cannot be introduced quietly;
- **deleting a name from this paragraph fails the guard** too, so a declared gap cannot be quietly
  forgotten once it is fixed;
- and the number is never back-filled from memory, which is the failure this whole file exists to
  prevent.

Seven gaps in seventeen batches is an honest accounting of a hand-run corpus. A table with no gaps
would be a table where somebody filled cells in later without saying so.

## The reconciliation, added 2026-09-28 after the rejected column was caught disagreeing with the
artefact — the only one of the three columns that nothing checked.**

The `accepted` column ties to `len(cases)` and the guard proves it. The `candidates` column is
what the fetcher printed. The **`rejected` column was neither**, and when it was finally
reconciled against `photos.json` it was wrong by 18 — not because it was mistyped, but because
**the evidence had been deleted**:

| | count |
|---|---|
| rejected column, summed over all seventeen batches | **95** |
| rejections on record inside `photos[]` (batches 8–17 flag them there) | 49 |
| rejections recovered from git history into the top-level `rejected` array | 24 |
| **total rejections the tree can account for** | **73** |
| **claimed but with no surviving record** | **18** |

**The cause, named at the call site rather than inferred.** `fetch_commons.py` read
`.get("photos", [])` and then **wrote a freshly constructed dict of `_note` + `photos`**, so every
fetch run destroyed the top-level `rejected` array that `apply_batch1..3` had been filling in. Git
history shows the key present at `c9aae5d` (batch 3, 13 records) and gone by `faaf963` (batch 4,
0) — because batch 4's *fetch* ran before its *apply*. So this was never a batch-4 slip; **it
would have repeated on every batch since, and did.** The 24 records and their `rejected_because`
reasons were recovered from `c9aae5d` and `461b22d` and restored, each carrying a `_recovered`
note saying where it came from.

**The 18 are named as untraceable rather than papered over.** They fall in batches 4–10, whose
rejections were partly *policy* rejections — photographs rejected without ever being opened
(batches 8 and 10 each rejected two "on policy, not opened"). A photograph nobody looked at was
never a manifest record, so there was never anything for the manifest to lose. That accounts for
part of the 18 and **not all of it**, and the remainder I could not trace to any record, so I am
not inventing a reason for it.

**The lesson, in the shape it actually took:** a second writer that rebuilds a file from the keys
it happens to know is how an audit trail disappears. Nothing errors, nothing warns, and the
history is the only place the record still lives. The fetch path now round-trips every top-level
key it did not create, and
`tools/ai_accuracy/test_the_rejection_record_survives.py` fails if the on-record rejection count
ever falls below 60, or if the fetcher's write path drops a key again.

**The guard for this file is its own, because a ledger nobody checks is a document.**
`tools/ai_accuracy/test_free_tier_ledger.py` reads the table above and checks it against the
artefacts, and `test/free_tier_ledger_test.dart` runs that module inside the Flutter suite so it
cannot be skipped by anyone who does not know it exists. What it checks:

- every row's batch numbers are consecutive with no gap or repeat;
- every row's accepted total, summed across all batches, **equals `len(cases)`** — so a row cannot
  be invented, dropped or double-counted, and the ledger cannot drift from the corpus;
- no batch is credited with more accepted + rejected than it fetched;
- every row still claims **zero model calls and $0.00**, and a row that stops claiming it fails
  **by name** rather than the file quietly becoming a different document;
- **`tools/ai_accuracy.py --corpus` runs with the network poisoned** — the falsifier this section
  names, executed rather than described. If the producer ever needs the network it is reaching a
  model, and "0 model calls" across every batch is then a lie;
- the admission below, and the labour paragraph, are still in the file. Tidying the honesty out
  fails the guard.

**What it still cannot see, and this is the whole remaining gap: it cannot see money.** A dollar
figure cannot be asserted from inside the repo — it is a statement about spend on the outside
world. So the money column above is asserted by the next person who runs a batch, which is why
every batch's commit message repeats `0 model calls, 0 rupees` rather than trusting this file to
remember it. The checkable part of "free" — that nothing in the loop calls a model — is now
machine-checked; the *spend* is still a human claim, and pretending otherwise would be the same
defect one level down.

**The bite proof:** `tools/ai_accuracy/prove_the_ledger_guard_bites.py` breaches each of those
checks in a throwaway copy of this repo's layout and asserts the named test goes red — **8 of 8,
including a breach that installs a producer which really does call `urlopen`**, because a poison
check that passes for an unrelated reason (a bad path, a missing import) looks exactly like a
poison check that worked. A guard that has only ever been green is a comment.

**Two of the eight breaches caught rules I had written wrong**, which is the reason the proof
exists and not just the test. I first asserted "rejected ≥ accepted past batch 1"; it went **red on
batch 8**, which fetched 94 candidates, accepted 7 and rejected 4 and left the other 83 fetched but
never opened. A rule that fails on real data was never a rule. The one I shipped instead — you
cannot judge a photograph you did not fetch — cannot be evaded by arithmetic. The second: batch 1's
model column reads `0 (in-repo originals)`, and an exact-string check failed it, so the check reads
the leading token and the reason survives.
