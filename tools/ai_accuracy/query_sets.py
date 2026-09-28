#!/usr/bin/env python3
"""Every query this corpus has ever sent, and the reasoning that produced each one.

WHY THIS FILE EXISTS: the 800-line rule, twice. `fetch_commons.py` was 786 when the photo
store was cut out of it, 729 after, and 781 again once batches 15 and 16 added their lists.
Sixteen batches of queries is one coherent concern and it is not the client's concern:
`fetch_commons.py` is the API client, the licence filter, the per-query and per-author
caps, and the rate-limit accounting. A query list is a DECISION about what to look for, and
the reasoning that produced it travels with it.

THE MOST IMPORTANT THING IN HERE IS NOT A QUERY. It is the record of three batches that
returned zero for three DIFFERENT reasons, which is why each block says what it was FOR and
not only what it asks for:

    batch 13 ........ zero, because Commons was HTTP 429 on every query
    batch 13 retry . zero, because MY OWN WORDING was over-constrained: `filetype:bitmap`
                      plus a quoted phrase plus two form words finds nothing, and the same
                      dish with the form words removed returns three candidates
    batch 15 ........ zero for khakra, and this one IS a fact about the food being
                      unsearchable rather than unphotographable - the word is a proper noun
                      that an 1784 map, the Khakra Math Palace and the Ghaghara river all
                      match, and its synonyms reach a tea plantation in Java

A zero from this module is not a finding about a dish. It is a question about a query, and
the control query that settles which lives in the batch that needs it.

THE PATTERNS, kept because they are what keeps working: plain wording beats clever wording;
regional and transliterated names beat dictionary names; a DISH word beats a plant name or a
proper noun (`dhingra` returned a brigadier general named Dhingra); and a control query
belongs INSIDE the set rather than run separately, because a control run minutes earlier is
a claim about a moment that has passed.
"""

# Overhead-friendly subjects: a plate or bowl a camera can look straight into.
QUERIES = [
    'filetype:bitmap "Vegetarian Thali"',
    'filetype:bitmap thali overhead',
    'filetype:bitmap "dal makhani"',
    'filetype:bitmap "palak paneer"',
    'filetype:bitmap "chana masala"',
    'filetype:bitmap biryani plate',
    'filetype:bitmap "aloo gobi"',
    'filetype:bitmap "rajma" bowl',
    'filetype:bitmap "chapati" plate',
    'filetype:bitmap "paneer tikka"',
    'filetype:bitmap "masala dosa"',
    'filetype:bitmap "vegetable curry" bowl',
    'filetype:bitmap "dal tadka"',
    'filetype:bitmap "matar paneer"',
]
# A batch-1 lesson: multi-dish thalis are abundant but almost useless here. With
# six or seven bowls in frame I cannot label each dish truthfully, and a
# reference truth I cannot defend poisons the whole measurement. A single katori
# of one dish is both defensible AND closer to what a user actually scans
# (one dish, one log). So the corpus is biased deliberately towards one-dish
# overhead shots.
SINGLE_QUERIES = [
    'filetype:bitmap "dal makhani" bowl',
    'filetype:bitmap "rajma" bowl',
    'filetype:bitmap "chole bhature"',
    'filetype:bitmap "kadhi pakora"',
    'filetype:bitmap "sambar" bowl',
    'filetype:bitmap "rasam" bowl',
    'filetype:bitmap "palak paneer" bowl',
    'filetype:bitmap "matar paneer" bowl',
    'filetype:bitmap "baingan bharta"',
    'filetype:bitmap "lauki ki sabzi"',
    'filetype:bitmap "poha" plate',
    'filetype:bitmap "upma" plate',
    'filetype:bitmap "idli" plate',
    'filetype:bitmap "dosa" plate',
    'filetype:bitmap "curd" bowl',
    'filetype:bitmap "pickle" bowl',
]
# Batch 2: dishes batch 1 does NOT already hold, so the corpus keeps widening
# instead of deepening on whatever the search happens to return most of.
BATCH2_QUERIES = [
    'filetype:bitmap "bhindi masala"',
    'filetype:bitmap "baingan bharta" bowl',
    'filetype:bitmap "lauki" curry',
    'filetype:bitmap "matar paneer"',
    'filetype:bitmap "paneer bhurji"',
    'filetype:bitmap "khichdi"',
    'filetype:bitmap "pulao" plate',
    'filetype:bitmap "jeera rice"',
    'filetype:bitmap "plain rice" bowl',
    'filetype:bitmap "dal fry"',
    'filetype:bitmap "moong dal"',
    'filetype:bitmap "masoor dal" bowl',
    'filetype:bitmap "chana dal" bowl',
    'filetype:bitmap "aloo paratha"',
    'filetype:bitmap "besan chilla"',
    'filetype:bitmap "paneer paratha"',
    'filetype:bitmap "egg curry"',
    'filetype:bitmap "chicken curry" bowl',
    'filetype:bitmap "raita" bowl',
    'filetype:bitmap "bhindi fry"',
]
# BATCH 5 — one query per DISH CLASS that cases.json does not already contain.
#
# The trap, three times now: 8 of 16 candidates were bhindi, 8 of 18 were masala
# dosa, and 4x chole. Each batch fixed it by hand and it came back, because a
# dish-shaped query returns dish-shaped results. So this set is built from the
# corpus's own gap list rather than from what is easy to find, and it takes ONE
# query per missing class: egg, biryani, khichdi, fish curry, sarson da saag,
# aloo gobi, kofta, chicken curry. Eight queries, eight different classes, so a
# duplicate cannot dominate this batch even if every query returns its own dish
# twice.
#
# Deliberately NOT queried: anything mapping to dal, chole, paneer or sambar in
# tools/ai_accuracy.py DISH_CLASS. A tenth photo of dal does not move a 13-class
# corpus to 20, it only makes the median better. That is the trap wearing a
# productive hat.
BATCH5_QUERIES = [
    'filetype:bitmap "omelette" plate',
    'filetype:bitmap biryani plate',
    'filetype:bitmap khichdi bowl',
    'filetype:bitmap "fish curry" bowl',
    'filetype:bitmap "sarson da saag"',
    'filetype:bitmap "aloo gobi"',
    'filetype:bitmap kofta curry',
    'filetype:bitmap "chicken curry" bowl',
]
BATCH6_QUERIES = [
    'filetype:bitmap "egg bhurji"',
    'filetype:bitmap omelette indian',
    'filetype:bitmap "methi sabzi"',
    'filetype:bitmap "cabbage poriyal"',
    'filetype:bitmap "veg pulao" plate',
    'filetype:bitmap kheer bowl',
]
BATCH7_QUERIES = [
    'filetype:bitmap "chicken curry" home plate',
    'filetype:bitmap "fish curry" bowl indian',
    'filetype:bitmap "methi sabzi"',
    'filetype:bitmap "boondi raita" bowl',
    'filetype:bitmap "gajar halwa"',
    'filetype:bitmap "bhindi do pyaz"',
]
# BATCH 8 -- FLATTEN, and the arithmetic is the whole reason this batch exists.
#
# The class bar is met at 22 (bar = 20). The SAMPLE is the problem: the top 4
# classes hold 42% of 31 cases (dal x5, chole x4, paneer x2, sambar x2), and the
# readme names <= 35% as the target. So this batch is sized by that arithmetic,
# not by taste: adding N cases to classes that hold ONE each moves the top-4
# share to 13/(31+N), and 13/37 = 35.1%, 13/38 = 34.2%. So ~7-8 accepted photos
# in the thin classes HIT the target, and not one of them may be dal, chole,
# paneer or sambar.
#
# Concretely: one query per class that currently has exactly ONE case, and none
# of the four concentrated ones appears here. That is the "one query per missing
# class" rule applied to the real gap - the gap is not the class COUNT, it is the
# classes that are one photo deep.
#
# The owner's version of the same instruction: do not knowingly ask for dal,
# chole or sambar again, because those queries are what built the 42%.
BATCH8_QUERIES = [
    'filetype:bitmap "aloo gobi" curry',
    'filetype:bitmap "baingan bharta"',
    'filetype:bitmap "bhindi masala"',
    'filetype:bitmap "dum biryani" plate',
    'filetype:bitmap "masala dosa" plate',
    'filetype:bitmap "egg bhurji" bowl',
    'filetype:bitmap "gajar halwa" bowl',
    'filetype:bitmap "idli" plate south',
    'filetype:bitmap "kadhi" bowl',
    'filetype:bitmap "kheer" bowl',
    'filetype:bitmap "khichdi" plate',
    'filetype:bitmap "kofta curry"',
    'filetype:bitmap "lauki" sabzi',
    'filetype:bitmap "pulao" plate',
    'filetype:bitmap "rajma" bowl',
    'filetype:bitmap "sarson da saag"',
    'filetype:bitmap "medu vada"',
    'filetype:bitmap "uttappam"',
]
# BATCH 9 -- WIDEN, and the keys go in WITH the queries.
#
# Batch 8 flattened (42% -> 34%, target hit). The class count is 23 with a bar of
# 20, so the class COUNT is not the gap any more - the gap is that several very
# common home dishes have NO case at all, and a photo app fails on the dish a
# user actually eats on a Tuesday. Measured from cases.json @ 38 cases: no
# mushroom, capsicum, keema, french beans, sweet corn, jalebi or samosa case
# exists, and STAPLE_SIDES means none of them can be smuggled in as a side.
#
# BATCH9_QUERIES is one query per absent class, and the DISH_CLASS keys are added
# in the same commit, because a key added after the fact is how a bar gets bought
# with synonyms. Seven classes, seven queries.
BATCH9_QUERIES = [
    'filetype:bitmap "mushroom curry" bowl',
    'filetype:bitmap "capsicum masala"',
    'filetype:bitmap keema curry',
    'filetype:bitmap "french beans" curry',
    'filetype:bitmap "sweet corn" curry',
    'filetype:bitmap jalebi bowl',
    'filetype:bitmap samosa plate',
]
# BATCH 10 -- the six keys with no case yet, queried harder.
#
# Batch 9 added the class KEYS (mushroom, capsicum, french beans, jalebi, samosa
# and one more) in the same commit as the photographs, so six of them still have
# no case. Batch 9's own queries proved the failure mode: "mushroom curry bowl"
# returned a Thai green curry, and the french beans query returned a four-item
# plate. So the queries are TIGHTER here - the word "indian" or "home" in every
# one, because Commons is a global library and the unsuffixed term finds the
# wrong cuisine. Same per-query and per-author caps, same dHash near-dup check.
BATCH10_QUERIES = [
    'filetype:bitmap "mushroom curry" indian home',
    'filetype:bitmap "shimla mirch" masala indian',
    'filetype:bitmap "french beans" curry indian',
    'filetype:bitmap jalebi indian sweets',
    'filetype:bitmap samosa indian plate',
    'filetype:bitmap "aloo bhaji"',
]
# BATCH 11 -- the six DECLARED class keys that no case reaches, measured not guessed.
#
# `python3 tools/ai_accuracy/test_the_dish_classes_are_distinct.py` prints this list:
# capsicum, french beans, khakra, mushroom, raitha and uthappam are all in DISH_CLASS
# and none of the 42 cases lands in any of them. A declared key with no case is a
# promise the corpus is not keeping, and it is the cheapest possible win: the class
# already exists as a decision, so a photograph here raises the class count WITHOUT
# inventing a new category, keeps every dish family at one case - so the independence
# figure does not get worse - and pushes the concentration down.
#
# The queries are tight for the reason batch 9 recorded: Commons is a global library
# and an unsuffixed term finds the wrong cuisine. "mushroom curry bowl" returned a
# THAI green curry. So every one carries "indian" or "home" or a regional word.
BATCH11_QUERIES = [
    'filetype:bitmap "mushroom masala" indian home',
    'filetype:bitmap "shimla mirch" masala indian',
    'filetype:bitmap "french beans" sabzi indian',
    'filetype:bitmap uthappam south indian',
    'filetype:bitmap "boondi raitha" indian',
    'filetype:bitmap khakra gujarati',
]
# BATCH 12 -- the five classes batch 11 left empty, queried by REGIONAL SPELLING.
#
# Batch 11 got 1 usable photograph out of 3 downloaded across 6 "indian"-suffixed
# queries. The suffix was the right lesson from batch 9 (an unsuffixed term finds the
# wrong cuisine) but it is evidently not enough to find these five dishes, because
# Commons is thin on them and thin in a particular way: the uploads are usually
# captioned in a REGIONAL or TRANSLITERATED form, not the dictionary form.
#
# So every query here changes the NAME rather than adding another cuisine word:
#   khakra      -> khakro, khakra rotli          (Gujarati spellings)
#   mushroom    -> dhingra masala               (Hindi for mushroom)
#   raitha      -> raita, potato raita           (the short form, and the common dish)
#   uthappam    -> uttapam, neyyappam-adjacent   (Kerala/Malabar transliterations)
#   french beans-> gavar phali, beans poriyal     (Gujarati and South Indian names)
#
# This is the honest response to a thin result: widen the NAMES, not the rules. The
# cuisine constraint stays, because batch 9 proved what relaxing it costs - a Thai
# green curry accepted as a mushroom dish would be worse than an empty class.
BATCH12_QUERIES = [
    'filetype:bitmap khakra gujarati',
    'filetype:bitmap "khakro" gujarati snack',
    'filetype:bitmap "dhingra masala"',
    'filetype:bitmap raita indian',
    'filetype:bitmap "potato raita"',
    'filetype:bitmap uthappam breakfast',
    'filetype:bitmap uttapam kerala',
    'filetype:bitmap "beans curry" indian home',
    'filetype:bitmap gavar phali',
    'filetype:bitmap "beans poriyal" south indian',
]
# BATCH 13 -- the last three empty classes, and the dish FORM rather than the name.
#
# Batch 12 widened the NAMES (khakro, dhingra, gavar phali) and filled uthappam and
# raitha but not khakra, mushroom or french beans. Its own commit named the next move:
# change the dish FORM.
#
# There is a real trade-off here and it is worth writing down before the results, because
# it is the reason this round might fail in a new way. A wider form - "a whole thali" -
# finds the dish more often, but a thali is a COMPOSITE: class_of takes the first
# non-staple item, so on a Gujarati thali the class would be decided by whichever
# vegetable I happened to list first. That is the four-component-plate fault batch 10
# rejected. So this round widens the form WITHOUT going composite: bowl, gravy, curry,
# sabzi and fry words, which are still single dishes but photograph differently from a
# close-up.
#
# And the standing commitment from batch 12 is kept: if this comes back thin, the result
# is that these three stay EMPTY, recorded with the measured reason, rather than a case
# manufactured to fill a key. A class filled with a photograph that does not show the
# class is worse than an empty class, because the empty one is honest.
BATCH13_QUERIES = [
    'filetype:bitmap "mushroom curry" bowl gravy',
    'filetype:bitmap "mushroom masala" gravy',
    'filetype:bitmap "mushroom fry" indian',
    'filetype:bitmap "beans curry" bowl',
    'filetype:bitmap "french beans" masala gravy',
    'filetype:bitmap "beans poriyal" bowl',
    'filetype:bitmap khakra rotli',
    'filetype:bitmap "dal khichdi" gujarati',
    'filetype:bitmap khakra thepla gujarati',
    'filetype:bitmap "gavar phali" sabzi',
]
# BATCH 14 -- the queries were the problem, and a control is what proved it.
#
# Batch 13 also returned 0, but for a THIRD and completely different reason, and the
# control query is the only reason I know which one:
#
#   CONTROL, known-good, worked in batch 12 ....... 1 candidate   <- the API is fine
#   'filetype:bitmap "mushroom curry" bowl gravy'  0 candidates   <- batch 13's wording
#   'filetype:bitmap "mushroom curry"' ........... 3 candidates   <- same dish, fewer words
#   'mushroom curry' (no filetype filter) ........ 3 candidates
#   'khakra gujarati' (no filetype filter) ....... 0 candidates   <- this one really is thin
#
# So the cause was MY query construction, not Commons. `filetype:bitmap` plus a quoted
# phrase plus two form words is over-constrained, and batch 13's whole premise - widen
# the dish FORM - widened the query into uselessness. The dish was there the whole time.
#
# Three batches have now returned zero for three DIFFERENT reasons: a rate limit, an
# over-constrained query, and (for khakra) possibly a genuine absence. Only the third
# is a fact about the food, and separating them took a control every time.
#
# These queries drop the form words and keep the filter that demonstrably works.
BATCH14_QUERIES = [
    'filetype:bitmap "mushroom curry"',
    'filetype:bitmap "mushroom masala"',
    'filetype:bitmap mushroom sabzi',
    'filetype:bitmap "beans curry"',
    'filetype:bitmap "french beans"',
    'filetype:bitmap "green beans" curry',
    'filetype:bitmap khakra',
    'filetype:bitmap khakro',
]
# BATCH 15 -- khakra and mushroom, the last two empty classes, WITH THE CONTROL IN
# THE SAME RUN.
#
# Batch 14 proved the cause of the zeros was my own over-constrained wording, so these
# queries are plain: no quoted phrase plus form words, just the dish. And the control
# query is IN THE SET rather than run separately, because a control run minutes earlier
# is a claim about a moment that has passed - the whole lesson of the three zeros.
#
# If the control comes back empty, the batch refuses itself (exit 3, the mechanism from
# 8a7065a) and nothing may be concluded about khakra. If the control comes back with hits
# and khakra does not, then khakra is genuinely thin on Commons - the first
# negative finding in this line of work that would actually be supported by one.
BATCH15_QUERIES = [
    # the control, first, and named as such: proven in batches 12 and 14
    'filetype:bitmap uthappam breakfast',
    'filetype:bitmap khakra',
    'filetype:bitmap "khakra rotli"',
    'filetype:bitmap "gujarati khichdi"',
    'filetype:bitmap khakro',
    'filetype:bitmap "mushroom curry"',
    'filetype:bitmap "mushroom masala"',
]
# BATCH 16 -- the last two empty classes, attacked by SYNONYM rather than by form.
#
# Batch 15 produced the first control-supported negative finding, and its reading was
# precise: khakra "cannot be SEARCHED with the words available", because "khakra" is a
# proper noun a 1784 map and a palace both match. So the answer is not another spelling
# of khakra - it is a DIFFERENT NAME for the food, and I have never tried one.
#
#   khakra  -> mathari, and the bhakri it is eaten with, and farsi puri from the same
#              Gujarati snack family. A dish is findable by its NEIGHBOURS.
#   mushroom -> dhingra (the Hindi word, so the captions are in Hindi), and the visible
#              FORMS - a mushroom has to be VISIBLE, and a sabzi or a fry shows it where
#              a masala under a dosa does not.
#
# The control is in the set again, first, for the reason batch 15 established: a control
# run separately is a claim about a moment that has passed.
# BATCH 17 -- khakra, the last empty class, by the two things never tried.
#
# Sixteen batches have searched khakra four ways: the dictionary word, the transliteration
# (khakro), the compound ("khakra rotli"), and a neighbour ("gujarati khichdi"). Four
# names, four non-dishes - a 1784 map, the Khakra Math Palace, the Ghaghara river, a tea
# plantation in Java. Batch 15 established that this is a fact about the food being
# UNSEARCHABLE rather than unphotographable, and batch 16 confirmed it with a synonym.
#
# So this round changes the MECHANISM rather than the word, which is the only thing left:
#
#   1. CATEGORY-SCOPED SEARCH. Every query so far has asked the full-text search box, which
#      ranks a 1784 antique map highly for the word khakra because the map is full of
#      place names. `incategory:` asks a different question - not "what text matches" but
#      "what is filed under Gujarati cuisine", which is the question a dish should be
#      asked. This is the same distinction as asking the reader instead of re-deriving
#      what the reader does.
#   2. THE DOUBLE-K SPELLING, khakhra, which no batch has tried.
#
# If both come back empty with the control answered, khakra is exhausted as a SEARCH
# problem by every mechanism this harness has, and the honest next step is not another
# query: it is a photograph from a human hand, or a decision to accept 30 of 33 declared
# classes. That decision is not this role's to take silently.
BATCH17_QUERIES = [
    'filetype:bitmap uthappam breakfast',                       # the control, proven 12/14/15/16
    'filetype:bitmap khakhra',
    'filetype:bitmap "gujarati snack"',
]


# BATCH 18 -- SIZED TO MOVE THE CONCENTRATION, which is the number the note says to watch.
#
# Every class this corpus declares now has a case, so there is nothing left to fill and the
# class count cannot grow honestly. That makes the concentration the only number left worth
# moving, and the note has said so since batch 8: "the number to watch next is the
# concentration, not the class count."
#
# SIZED BY ARITHMETIC, not by taste. 22 of the 33 classes hold exactly one case. The top
# four hold 13 of 49, which is 27%. Adding ONE case to each of EIGHT singleton classes:
#
#     49 + 8 = 57 cases, top 4 still 13  ->  13/57 = 23%
#
# and dal and chole are never touched, because growing the two largest classes is the exact
# regression batches 8 and 10 were built to remove. The trade is stated rather than hidden:
# eight families become repeated, so the independence figure moves the other way - 20 of 49
# becomes 28 of 57. Concentration falls, independence falls, and the sample gets bigger. A
# median over 57 cases in 33 classes is a better instrument than one over 49, and that is
# the trade being made.
#
# The eight are chosen for findability, not for coverage: idli, vada, jalebi, samosa, egg,
# halwa, kheer and pulao are high-frequency Indian dishes with real Commons coverage, unlike
# legume salad, which has stayed empty across every batch. Plain wording, control first, per
# the two patterns that have actually worked.
BATCH18_QUERIES = [
    'filetype:bitmap uthappam breakfast',          # the control, proven 12 and 14-17
    'filetype:bitmap idli',
    'filetype:bitmap "medu vada"',
    'filetype:bitmap jalebi',
    'filetype:bitmap samosa',
    'filetype:bitmap "egg curry"',
    'filetype:bitmap "gajar halwa"',
    'filetype:bitmap kheer',
    'filetype:bitmap pulao',
]


# BATCH 19 -- the three singletons batch 18 named as failures, retried with the mechanism
# that batch 17 proved works.
#
# Batch 18 was sized to move the concentration and yielded four of the eight it planned.
# It named its own failures: gajar halwa, kheer and pulao returned nothing that survived
# the per-query cap, while idli, vada, jalebi and samosa came back immediately. That
# asymmetry is the clue - the four that worked are the four whose NAMES are the dish, and
# the three that failed are names a person is more likely to caption differently.
#
# So this round does not try more spellings of gajar halwa. It changes the INSTRUMENT, the
# way batch 17 did: `incategory:` asks "what is filed under Indian sweets" rather than
# "what text matches these four words", and in batch 17 that is what surfaced Gol dhokla,
# khandvi, muthia and methi muthiya where the text search had been returning an 1784 map.
#
# Four singletons are also added by the mechanism rather than the name, because the
# mechanism is now the better instrument and the class bar is met with thirteen spare, so
# there is nothing to gain from being clever about names.
BATCH19_QUERIES = [
    'filetype:bitmap uthappam breakfast',                                # the control
]


# RETRACTED 2026-09-28: every `incategory:` query in this file was REMOVED, because
# none of the categories it named exists. Verified against the Commons API with
# fetch_commons.category_exists() and recorded in verified_categories.json:
#
#   exist ...... Indian cuisine, Vegetarian cuisine, Sweets
#   DO NOT USE . Gujarati cuisine, Indian sweets, Indian rice dishes, Indian snacks,
#                Indian curries, Indian breads, Indian desserts, Indian sweets and snacks
#
# The one that matters is "Gujarati cuisine", because batch 17 reported it as the
# MECHANISM by which the khakhra was found. It does not exist. So `incategory:` with a
# non-existent category does NOT return zero - it changes the search in a way that was
# never understood - and the Gujarati snacks that query returned came from somewhere I
# cannot now account for.
#
# What actually found the khakhra was the DOUBLE-K SPELLING on its own, with no category
# in the query at all. That finding stands. The "mechanism finding" that sat beside it does
# not, and it is retracted here rather than quietly deleted, because a claim that was
# published and then falsified is worth more in the record than a claim that was never
# made. test_a_search_category_must_exist.py is what makes this class of error visible
# next time: it reads this file, and a category that is not in the verified file - or
# that is recorded as NOT EXISTING - is a red guard rather than a plausible-looking query.

BATCH21_QUERIES = [
    'filetype:bitmap uthappam breakfast',       # the control
    'filetype:bitmap gajar halwa',
    'filetype:bitmap kheer',
    'filetype:bitmap pulao',
    'filetype:bitmap khichdi',
]


BATCH16_QUERIES = [
    'filetype:bitmap uthappam breakfast',            # the control, proven in 12/14/15
    'filetype:bitmap mathari',
    'filetype:bitmap "gujarati bhakri"',
    'filetype:bitmap "farsi puri"',
    'filetype:bitmap dhingra',
    'filetype:bitmap "mushroom sabzi"',
    'filetype:bitmap "mushroom fry"',
]
# Batch 3: dishes batches 1-2 do NOT hold, and regions batch 1-2 under-covered.
# Batch 1-2 leaned North/Northwest (thali, dal makhani, kadhi, chole) and one
# Bengali dish. The stated user eats what their region eats, so a corpus that is
# only "North Indian" would flatter the score for half the country.
BATCH3_QUERIES = [
    'filetype:bitmap "masala dosa"',
    'filetype:bitmap "idli sambar"',
    'filetype:bitmap "uttapam"',
    'filetype:bitmap "medu vada"',
    'filetype:bitmap "bisi bele bathu"',
    'filetype:bitmap "masoor dal" bowl',
    'filetype:bitmap "chana dal" bowl',
    'filetype:bitmap "dal tadka"',
    'filetype:bitmap "tarka dal"',
    'filetype:bitmap "egg curry" bowl',
    'filetype:bitmap "butter chicken" bowl',
    'filetype:bitmap "chicken tikka masala"',
    'filetype:bitmap "rogan josh"',
    'filetype:bitmap "gobi curry"',
    'filetype:bitmap "shahi paneer"',
    'filetype:bitmap "kadai paneer"',
    'filetype:bitmap "palak kofta"',
    'filetype:bitmap "malai kofta"',
    'filetype:bitmap "dhokla"',
    'filetype:bitmap "khandvi"',
    'filetype:bitmap "thepla" plate',
    'filetype:bitmap "khichdi"',
    'filetype:bitmap "halwa" bowl',
    'filetype:bitmap "gulab jamun"',
    'filetype:bitmap "payasam"',
]
# Batch 4: DELIBERATELY NON-BREAKFAST. Batch 3 accepted five South-Indian
# breakfast photos and the corpus score moved for reasons that had nothing to do
# with the app - which is the whole reason the corpus rule exists. Every query
# here is a lunch/dinner dish, plus the region coverage batches 1-3 missed
# (Kashmiri, Awadhi, Bengali, Gujarati, Goan, Hyderabadi, Kerala, Punjabi).
BATCH4_QUERIES = [
    'filetype:bitmap "chana masala"',
    'filetype:bitmap "chole" curry',
    'filetype:bitmap "rajma" curry',
    'filetype:bitmap "butter chicken"',
    'filetype:bitmap "chicken curry" bowl',
    'filetype:bitmap "rogan josh"',
    'filetype:bitmap "egg curry"',
    'filetype:bitmap "shahi paneer"',
    'filetype:bitmap "paneer butter masala"',
    'filetype:bitmap "gobi curry"',
    'filetype:bitmap "dal tadka"',
    'filetype:bitmap "tarka dal"',
    'filetype:bitmap "eggs bhurji"',
    'filetype:bitmap "methi sabzi"',
    'filetype:bitmap "tindora"',
    'filetype:bitmap "kashmiri dum aloo"',
    'filetype:bitmap "awadhi kebab"',
    'filetype:bitmap "bengali fish curry"',
    'filetype:bitmap "gujarati dal"',
    'filetype:bitmap "goan pork"',
    'filetype:bitmap "hyderabadi biryani"',
    'filetype:bitmap "kerala fish curry"',
    'filetype:bitmap "dhaba dal"',
    'filetype:bitmap "punjabi chole"',
    'filetype:bitmap "khichdi"',
    'filetype:bitmap "poha"',
]

# The registry lives in fetch_commons.main(), so a new set is added there too - one place,
# deliberately: a query list that is not reachable by `--set` is a query list nobody runs.
BATCH17_QUERIES_SET_NAME = "batch17"
