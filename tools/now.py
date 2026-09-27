#!/usr/bin/env python3
"""The ONLY source of "now" for anything this company says out loud.

Why this file exists, 2026-09-28: seven consecutive reports to my CEO carried a
hand-typed time. I wrote "~02:20", "~02:45", "~03:05", "~04:50", "~05:15",
"~05:50", "~06:30", "~07:20 IST" - none of them read from a clock. The machine
said 05:13:38 when the seventh landed, and `git log` said that commit was made at
05:12:31. So my reports and my commits carried two different answers to "when",
two hours apart, and a future session deciding "what did he believe at the time
of that commit" would get a different answer from each.

The cause was not a timezone bug, not an offset applied twice, and not utcnow()
mislabelled. grep proved it: NO CODE PRODUCED THAT NUMBER. It had no producer at
all, which is the one thing standing order 6 exists to prevent - and the only way
I found out was that somebody read the clock when I did not.

So the time is now MACHINE-READ, and there is exactly one place that reads it.
Not a default that can be overridden, not a parameter: a report header is either
copied from this or it is a guess, and a guess is a defect.

    python3 tools/now.py            ->  2026-09-28 05:13:38 IST (+0530)
    python3 tools/now.py --stamp    ->  2026-09-28 05:13 IST
"""
from __future__ import annotations

import datetime
import sys


def now() -> datetime.datetime:
    return datetime.datetime.now().astimezone()


def stamp() -> str:
    """The report-header form: date, HH:MM, and the zone as the machine calls it."""
    n = now()
    return f"{n:%Y-%m-%d %H:%M} {n:%Z} (UTC{n:%z})"


def header() -> str:
    """Exactly the string that goes after 'Time:' in a report."""
    n = now()
    return f"~{n:%H:%M} {n:%Z}, {n:%Y-%m-%d}"


if __name__ == "__main__":
    if "--stamp" in sys.argv:
        print(stamp())
    elif "--header" in sys.argv:
        print(header())
    else:
        n = now()
        print(f"{stamp()}   machine: {n:%H:%M:%S}   "
              f"source: datetime.now().astimezone() - no offset is applied by hand")
