# The stop-list - queries measured to find nothing, with a positive control alongside

**Written 2026-09-28 from `tools/ai_accuracy/query_results.json`, the first real product of
the per-query record that began at batch 25.** Every entry below was measured at **zero
pages returned** in a run in which the batch's control query **returned hits**, so none of
these is a rate limit, none is a throttle, and none is my instrument returning nothing for
a reason it could have told me about.

| Query | Measured zero | Batch and run | Control that run |
|---|---|---|---|
| `filetype:bitmap "amla murabba"` | pages=0 | batch27 @ 2026-09-28T15:46:44 | uthappam breakfast, pages>0 |
| `filetype:bitmap "amla murabba"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "bell pepper curry"` | pages=0 | batch26 @ 2026-09-28T15:36:38 | uthappam breakfast, pages>0 |
| `filetype:bitmap "bell pepper curry"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "green bean curry"` | pages=0 | batch26 @ 2026-09-28T15:36:38 | uthappam breakfast, pages>0 |
| `filetype:bitmap "green bean curry"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "gwar curry"` | pages=0 | batch27 @ 2026-09-28T15:46:44 | uthappam breakfast, pages>0 |
| `filetype:bitmap "gwar curry"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "kacche kele curry"` | pages=0 | batch27 @ 2026-09-28T15:46:44 | uthappam breakfast, pages>0 |
| `filetype:bitmap "kacche kele curry"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "lauki sabzi"` | pages=0 | batch25 @ 2026-09-28T15:28:17 | uthappam breakfast, pages>0 |
| `filetype:bitmap "lauki sabzi"` | pages=0 | batch26 @ 2026-09-28T15:36:38 | uthappam breakfast, pages>0 |
| `filetype:bitmap "lauki sabzi"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "makai curry"` | pages=0 | batch26 @ 2026-09-28T15:36:38 | uthappam breakfast, pages>0 |
| `filetype:bitmap "makai curry"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "ratan jot salad"` | pages=0 | batch25 @ 2026-09-28T15:28:17 | uthappam breakfast, pages>0 |
| `filetype:bitmap "ratan jot salad"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |
| `filetype:bitmap "tinda curry"` | pages=0 | batch27 @ 2026-09-28T15:46:44 | uthappam breakfast, pages>0 |
| `filetype:bitmap "tinda curry"` | pages=0 | batch28 @ 2026-09-28T15:52:12 | uthappam breakfast, pages>0 |

**WHAT A STOP-LIST IS FOR, and what it is not.** It says the QUERY found nothing. It does
not say the DISH has no photograph, and conflating those two is how this corpus produced
four false findings - lauki is on this list and lauki now has a case, because
`"bottle gourd curry"` found it in the same run the stop-list query missed it.

**THE TWO ENGLISH NAMES ARE THE INTERESTING ENTRY.** `"bell pepper curry"` and
`"green bean curry"` both returned zero in the batch 26 pairs, where their transliterated
counterparts returned 7 and 8. Two runs, a positive control, and no hit either time: those
two names are not in this archive at all, so no future batch should spend a query on them.
That is a fact about Commons, not about the vegetables.

**NOT DELETED, LISTED.** A stop-list nobody can read is a comment. Re-running an entry is
allowed - it is a reproduction, and if one of these ever returns pages the list is wrong and
should say so.
