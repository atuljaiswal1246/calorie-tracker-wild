#!/usr/bin/env python3
"""Did a role's hash LAND, or did the role only say a hash?

THE DEFECT (2026-09-28 13:47). I ordered two drifting roles to end their reply
with a commit hash. Both did:

    Research Lead      replied 13:46:53, hash 581620f
    Engineering Lead   replied 13:47:36, hash 37d4f3c

Then I ran `git log -1 581620f` in the repo they work in, and:

    fatal: ambiguous argument '581620f': unknown revision or path not in the
    working tree.
    $ git cat-file -t 581620f
    fatal: Not a valid object name

So one of the two hashes is not a commit. Not a commit that is unpushed, not a
commit on another branch - not an object in that repository at all. A role said a
hash that does not exist, and the doorbell would have counted it as a landing,
because a doorbell that reads the MESSAGE cannot tell a hash from a string that
looks like one.

That is the whole class this repo keeps meeting, wearing a new hat: a claim
nothing can disagree with. The order said "end your reply with the short hash",
and the reply ended with a short hash, and the instruction was satisfied while
the work was not done. Satisfying the SHAPE of a done-condition is not
satisfying it.

WHAT THIS DOES. Reads the roles' own last assistant message, extracts hex tokens
that look like hashes, and asks GIT whether each one is an object in the repo.
Reports LANDED / NOT A COMMIT / NO HASH. Exits 1 when a role that answered has
no real commit behind its claim.

BOUNDARY. Read-only on the other company's repo: `git log`/`git cat-file` only,
never a write. It reads their sessions and their history; it changes nothing.

Exit codes
  0  every answering role's hash resolves to a real commit
  1  a role answered with a hash that is not a commit, or with none at all
  2  a role's session could not be read. NOT VERIFIED, which is not a pass.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

API = "http://127.0.0.1:49374"
OTHER_REPO = Path.home() / "Desktop" / "Jarvis"
STATE = Path(__file__).resolve().parent.parent / ".agent-logs" / "drift_orders.json"
# A git short hash is 7-40 hex. Anchored on a word boundary so a word that merely
# starts with hex letters ("facade", "decade") is not read as a hash.
HASH = re.compile(r"(?<![0-9a-zA-Z])([0-9a-f]{7,40})(?![0-9a-zA-Z])")


def _pw() -> str:
    return json.loads(
        (Path.home() / ".config" / "opencode" / "service.json")
        .read_text(encoding="utf-8"))["password"]


def last_reply(sid: str, timeout: float = 20.0) -> tuple[str | None, int | None, str]:
    """The role's most recent assistant message THAT HAS TEXT, its time, model.

    Two bugs were here, both pointing the same way - reporting a WORKING role as
    broken, which for a drift instrument is the expensive direction:

      1. The field names are `type` and `content` on this service. My first
         reader looked for `info.role` / `parts` and reported "no reply" for a
         role that had replied three minutes earlier with a real commit.
      2. `data` is newest-first and MOST TURNS HAVE NO TEXT - a tool call, a
         read, a plan step. Grading the newest message grades an empty string.
         At 14:08 it reported BOTH roles as hashless while their repo took eight
         commits after 13:45.

    So: skip textless turns and take the most recent one that actually said
    something. A tool call is not a statement, and grading silence as a verdict
    is how a monitor starts crying wolf at a role that is working.
    """
    auth = "Basic " + base64.b64encode(
        ("opencode:" + _pw()).encode()).decode()
    req = urllib.request.Request(f"{API}/api/session/{sid}/message",
                                 headers={"authorization": auth})
    d = json.loads(urllib.request.urlopen(req, timeout=timeout).read())
    msgs = d.get("data", []) if isinstance(d, dict) else []
    asst = [m for m in msgs if isinstance(m, dict) and m.get("type") == "assistant"]
    if not asst:
        return None, None, ""
    for m in asst:  # newest first
        txt = " ".join(c.get("text", "") for c in m.get("content", [])
                       if isinstance(c, dict) and c.get("type") == "text").strip()
        if txt:
            return txt, m.get("time", {}).get("created"), \
                (m.get("model") or {}).get("id", "")
    return None, None, ""


# ONE REPO IS AN ASSUMPTION, AND I MADE IT TWICE.
# That company has several git repos under it and five registered worktrees, and
# a role can legitimately commit in any of them. My checker looked only at the
# parent repo, so "not a valid object name" meant "not in THAT repo" while I
# reported it as "this role did not commit" - which is a bigger claim, and
# possibly false. The honest verdict for a hash that is in none of the known
# repos is NOT FOUND ANYWHERE, not NOT A COMMIT, and the difference matters: one
# is a fact about the world, the other is an accusation about a person.
def candidate_repos(extra: list[str] | None = None) -> list[Path]:
    """Every git repo we can legitimately look in, parent first."""
    out: list[Path] = []
    base = OTHER_REPO
    if base.exists():
        out.append(base)
        for d in sorted(base.rglob(".git")):
            if "/node_modules/" in str(d):
                continue
            p = d.parent
            if p not in out and p != base:
                out.append(p)
    for e in extra or []:
        p = Path(e).expanduser()
        if p.exists():
            out.append(p)
    return out


def is_commit(repo: Path, h: str) -> bool:
    p = subprocess.run(["git", "cat-file", "-t", h], cwd=str(repo),
                       capture_output=True, text=True)
    return p.returncode == 0 and p.stdout.strip() == "commit"


def subject_of(repo: Path, h: str) -> str:
    p = subprocess.run(["git", "log", "-1", "--format=%ad %s", "--date=format:%H:%M", h],
                       cwd=str(repo), capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else ""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--role", help="check one role by name")
    args = ap.parse_args()

    if not STATE.exists():
        print("NOT VERIFIED: no drift_orders.json - nobody has been ordered yet, "
              "so there is nothing to hold to a commit.")
        return 2
    orders = json.loads(STATE.read_text(encoding="utf-8"))

    rows, unreadable, bad, waiting = [], 0, [], []
    for role, rec in orders.items():
        if args.role and role != args.role:
            continue
        sid = rec.get("session")
        if not sid:
            unreadable += 1
            continue
        try:
            txt, ms, model = last_reply(sid)
        except Exception as e:  # noqa: BLE001
            print(f"  {role:<20} SESSION UNREADABLE ({type(e).__name__}) - "
                  f"NOT VERIFIED, not a pass")
            unreadable += 1
            continue
        if txt is None:
            # A role that has not spoken yet has NOT been cleared. It used to
            # print "waiting, not failing" and then fall through to a summary
            # line reading PASS - so a silent role was quietly counted as a good
            # one. Exactly the empty-result-is-a-pass trap, about a person.
            print(f"  {role:<20} ordered, no spoken reply yet - WAITING")
            waiting.append(role)
            continue
        at = time.strftime("%H:%M:%S",
                           time.localtime(ms / 1000)) if ms else "?"
        # WHY GIT'S LOG IS NOT THE GROUND TRUTH HERE, and I was wrong to try.
        # Every role in that company commits into ONE repo on ONE branch, so
        # `git log --since` counts the whole company's work, not the role's: it
        # returned 1808 commits and attributed the same Toolsmith commit to two
        # different roles. A shared history cannot attribute a commit to an
        # author unless the author says so.
        #
        # So the only attribution signal is the role naming its own hash, and my
        # job is to check that the named thing is real. That is what caught
        # 581620f, and it is the whole value of this file. The known cost: a role
        # that lands and then spends twenty minutes explaining the landing has no
        # hash in its newest sentence and reads as NO HASH. That is a FALSE
        # ALARM, and it is why the order now demands the hash be in the FINAL
        # message - not to be polite, but so the check has something to check.
        claimed = HASH.findall(txt)
        repos = candidate_repos()
        found = None
        for h in claimed:
            for r in repos:
                if is_commit(r, h):
                    found = (h, r)
                    break
            if found:
                break
        if found:
            h, r = found
            where = "" if r == OTHER_REPO else f"  [{r.name}]"
            print(f"  {role:<20} LANDED  {at}  {h}  {subject_of(r, h)[:46]}{where}")
            rows.append((role, "LANDED", h))
        elif claimed:
            print(f"  {role:<20} NOT FOUND ANYWHERE  {at}  it said "
                  f"{claimed[0]}; searched {len(repos)} repo(s), including every "
                  f"worktree parent - so this is a fact about the hash, not an "
                  f"accusation about the role")
            rows.append((role, "NOT FOUND", claimed[0]))
            bad.append(role)
        else:
            print(f"  {role:<20} NO HASH  {at}  no hash in its last spoken turn. "
                  f"Cannot attribute: this repo is shared, so a commit proves "
                  f"nothing about WHO landed it.")
            rows.append((role, "NO HASH", "-"))
            bad.append(role)

    print("")
    if bad:
        print(f"FAIL: {len(bad)} role(s) answered without a real commit behind "
              f"it: {', '.join(bad)}.")
        print("A doorbell that reads the MESSAGE counts a string shaped like a")
        print("hash as a landing. A shape is not a landing.")
        return 1
    if unreadable or waiting:
        who = ", ".join(waiting + ["<unreadable>"] * unreadable)
        print(f"NOT VERIFIED: {len(waiting) + unreadable} role(s) are not "
              f"cleared ({who}).")
        print("Not failed, not passed. A role that has not answered is not one")
        print("that has landed, and it is not one that has gone quiet either.")
        return 2
    print(f"PASS: every ordered role has a real commit in {OTHER_REPO} after the order.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
