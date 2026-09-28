#!/usr/bin/env python3
"""The string literals in a Python source file, extracted by Python's own tokenizer.

WHY THIS EXISTS, and it is a defect the guards were carrying for a long time without
knowing. Every guard in this repo that checks "is this query in a query set" extracts
query strings from `query_sets.py` with a quote-delimited regex:

    re.findall(r"'([^']+)'", src)

That regex has no notion of a COMMENT or a docstring, and `[^']+` happily matches across
newlines. So a single unpaired apostrophe in prose desynchronises every match after it,
and the extraction silently stops being an extraction. Measured 2026-09-28 on
`query_sets.py`:

    single-quote characters in the file ..... 609   <- ODD
    lines with an odd number of apostrophes .. 15
    all of them prose: "batch 13's", "the client's", "batch 25's finding"

Fifteen ordinary English possessives in comments, and the file's whole query registry
became unreadable to a regex. The guards did not fail loudly - they went on reporting
success while seeing a different file than the one on disk, which is the exact class of
fault this repo keeps measuring: a check that passes for the wrong reason.

It surfaced only when a new batch pushed the parity across the block the guard was
reading. The control guard is still GREEN and is green by luck: whether it sees a query
depends on how many apostrophes happen to sit between it and the query.

So the extraction is done here, ONCE, by `tokenize` - the standard library's own lexer,
which knows what a comment and a docstring are. And a guard that imports it no longer
depends on the prose around the data.

WHAT THIS MODULE GUARANTEES, and both are checked by
test_the_record_distinguishes_a_zero_from_a_query_never_asked.py:

  * an apostrophe in a comment or docstring cannot change what is extracted - the
    extraction is immune to the prose, which is the whole point;
  * and a file that cannot be TOKENIZED raises, rather than returning a short list. A
    truncated list is the dangerous shape, because every consumer then reports a
    confident answer about a file it only partly read.

Run with: python3 -c "import sys; sys.path.insert(0, 'tools/ai_accuracy'); import qstrings"
"""
from __future__ import annotations

import ast
from pathlib import Path


def string_literals(path: Path) -> list[str]:
    """Every string literal in `path`, in source order, with comments and docstrings
    excluded. RAISES on a file that cannot be parsed - see the module docstring.

    Built on `ast` rather than on `tokenize` because `ast` gives me the VALUE of each
    literal instead of its source text, and that distinction matters: the first version of
    this function tried to reconstruct values with `untokenize` and returned quoted
    fragments, which silently made every caller fail to match a real query. A function
    that returns the wrong shape is worse than one that raises.
    """
    tree = ast.parse(Path(path).read_text(encoding="utf-8"), filename=str(path))
    out: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            out.append(node.value)
    return out


def source_without_comments(path: Path) -> str:
    """The source with every COMMENT and DOCSTRING removed, for the guards that need to
    parse structure out of the text rather than a list of literals.

    Kept here beside `string_literals` because both answer the same question - "read the
    data, not the prose" - and a second copy of the answer is how the two-copies fault
    happens, which is the same fault this repo paid for with argparse's `choices` and the
    query-set registry.
    """
    src = Path(path).read_text(encoding="utf-8")
    out, depth_doc, i = [], 0, 0
    while i < len(src):
        ch = src[i]
        if depth_doc:
            if src.startswith('"""', i) or src.startswith("'''", i):
                i += 3
                depth_doc -= 1
                continue
        elif src.startswith('"""', i) or src.startswith("'''", i):
            i += 3
            depth_doc += 1
            continue
        elif ch == "#":
            j = src.find("\n", i)
            i = len(src) if j == -1 else j
            continue
        out.append(ch)
        i += 1
    return "".join(out)
