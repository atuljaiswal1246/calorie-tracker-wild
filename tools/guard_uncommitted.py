#!/usr/bin/env python3
"""Refuse to let uncommitted work be destroyed — a guard, not an order.

The defect (2026-09-28, 11:59): a 15-line `DISH_CLASS` block was sitting
uncommitted in tools/ai_accuracy.py. I ran `git checkout tools/ai_accuracy.py`
because it looked like debris, and destroyed it. It may have been the owner's.
The rule I wrote afterwards ("never checkout a file you did not write") is an
ORDER, and orders are what I write when I forget. This is the machine instead.

WHAT IT DOES
  guard   <path>...   Refuse if <path> has uncommitted changes, unless a patch of
                     them has been taken first. Writes the patch, then refuses.
  allow   <path>...   Take the patch, print where it is, and let the caller
                     proceed. The caller is still responsible for the discard.
  check   <path>...   Exit 0 if safe to discard, 1 if not, 2 if the path is not
                     a tracked file in a git work tree at all.
  --self-test         Exercise the refusal path in a throwaway repo and print
                     what happened. Used by tools/check_all_claims.py so the
                     guard is RUN by the claim runner, not merely present.

WHY A PATCH AND NOT A COPY
  A copy of one file protects one file. A patch also carries the mode, and
  survives the file being renamed or deleted. It is also readable — you can see
  what you are about to throw away instead of trusting a number.

PATCHES LAND IN .agent-logs/discard/ — gitignored, outside the tree's history,
so a rescue never becomes an accidental commit.

Exit codes are the whole point: silence and success must not look alike.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

EXIT_SAFE = 0
EXIT_UNSAFE = 1
EXIT_NOT_A_REPO = 2

# Git subcommands that can throw work away. `git checkout -b` creates a branch
# and is safe; the arg check below is what keeps it out of this set.
DESTRUCTIVE = ("checkout", "restore", "stash", "reset", "clean")


def _git(repo: Path, *args: str) -> tuple[int, str]:
    p = subprocess.run(
        ["git", *args],
        cwd=str(repo),
        capture_output=True,
        text=True,
    )
    return p.returncode, (p.stdout or "") + (p.stderr or "")


def repo_root(start: Path) -> Path | None:
    p = Path(start).resolve()
    for cand in [p, *p.parents]:
        if (cand / ".git").exists():
            return cand
    return None


def is_destructive(argv: list[str]) -> bool:
    """True if this argv is a git command that can destroy uncommitted work."""
    args = [a for a in argv if a]
    if not args or args[0] != "git":
        return False
    rest = args[1:]
    if not rest:
        return False
    if rest[0] == "checkout" and rest[1:2] == ["-b"]:
        return False  # creating a branch
    if rest[0] == "checkout" and "--" in rest:
        return True
    return rest[0] in DESTRUCTIVE


def dirty_paths(repo: Path, paths: list[str]) -> list[str]:
    """Tracked paths with staged or unstaged changes, via porcelain (never a guess)."""
    rc, out = _git(repo, "status", "--porcelain", "--", *paths)
    if rc != 0:
        return []
    dirty = []
    for line in out.splitlines():
        if not line.strip():
            continue
        xy = line[:2]
        if xy == "??":
            continue  # untracked: nothing committed to destroy
        name = line[3:].strip().strip('"')
        if " -> " in name:  # rename form
            name = name.split(" -> ")[-1]
        dirty.append(name)
    return dirty


def take_patch(repo: Path, paths: list[str]) -> tuple[int, str]:
    """Write a patch of the current changes. Returns (exit, path-or-message)."""
    out_dir = repo / ".agent-logs" / "discard"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=str(repo),
        capture_output=True,
        text=True,
    ).stdout.strip() or "norev"
    safe = "_".join(p.replace(os.sep, "-").replace("/", "-") for p in paths)
    dest = out_dir / f"{stamp}-{safe}.patch"
    diff = subprocess.run(
        ["git", "diff", "HEAD", "--", *paths],
        cwd=str(repo),
        capture_output=True,
        text=True,
    )
    if diff.returncode != 0:
        return 1, (diff.stderr or "git diff failed").strip()
    dest.write_text(diff.stdout, encoding="utf-8")
    return 0, str(dest)


def discard_dir(repo: Path) -> Path:
    return repo / ".agent-logs" / "discard"


def decide(repo: Path, patch: Path, verdict: str, producer: str) -> tuple[int, str]:
    """Record the DECISION that order 11 asks for and the tool did not keep.

    `allow` saves the work. Order 11 then says "look at it, then decide - in
    that order, every time", and NOTHING recorded the second half: the patch sat
    in a GITIGNORED directory with no state saying whether it had been put back.
    That is QA's finding about a completed card, reproduced here in my own repo:
    a thing that was finished, and nothing that says it was finished.

    The sidecar is JSON beside the patch so it cannot be confused with it, and it
    carries a timestamp taken from the machine rather than typed by a person,
    because a typed time is a guess and nothing can check a guess."""
    try:
        p = Path(patch)
        if not p.is_absolute():
            p = repo / p
        if not p.exists():
            return 1, f"no such patch: {p}"
        if p.suffix != ".patch":
            return 1, f"not a patch file: {p}"
        payload = {
            "verdict": verdict,
            "producer": producer,
            "decided_at": time.strftime("%Y-%m-%d %H:%M:%S %Z"),
            "decided_at_epoch": int(time.time()),
            "patch_bytes": p.stat().st_size,
        }
        p.with_suffix(".decided.json").write_text(
            json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        return 0, str(p.with_suffix(".decided.json"))
    except OSError as exc:
        return 1, f"could not write the decision: {exc}"


def list_parked(repo: Path) -> tuple[int, str]:
    """Every saved patch, with its age and whether anybody DECIDED about it.

    Non-zero when any patch is undecided, because an undecided patch is
    unfinished business in a directory no commit can see: .agent-logs/ is
    gitignored, so this list is the ONLY record that the work exists at all.
    """
    d = discard_dir(repo)
    if not d.is_dir():
        print(f"no parked patches ({d} does not exist).")
        return 0, "none"
    patches = sorted(d.glob("*.patch"))
    if not patches:
        print(f"no parked patches in {d}.")
        return 0, "none"
    now = time.time()
    undecided = 0
    print(f"parked patches in {d}:")
    for p in patches:
        side = p.with_suffix(".decided.json")
        age = int((now - p.stat().st_mtime) // 60)
        if side.exists():
            try:
                v = json.loads(side.read_text(encoding="utf-8")).get("verdict", "?")
            except (OSError, ValueError):
                v = "UNREADABLE"
            print(f"  {age:>6}m  {v:<12} {p.name}")
        else:
            undecided += 1
            print(f"  {age:>6}m  {'UNDECIDED':<12} {p.name}")
    if undecided:
        print("")
        print(f"{undecided} patch(es) have no recorded decision. Order 11 is save,")
        print("look, THEN DECIDE, and the decision is the half that was not kept:")
        print("  python3 tools/guard_uncommitted.py decide <patch> \\")
        print("      --verdict restored|dead|superseded --producer \"who, when, why\"")
        return EXIT_UNSAFE, f"{undecided} undecided"
    print("")
    print("every parked patch carries a recorded decision.")
    return EXIT_SAFE, "all decided"


def _resolve(repo: Path, paths: list[str]) -> list[str]:
    """Repo-relative paths, refusing anything outside the tree.

    A relative path is interpreted against the REPO, not against the caller's
    cwd. Resolving against cwd is a quiet way to inspect a different tree than
    the one the caller meant - and the self-test caught exactly that.
    """
    out = []
    for p in paths:
        cand = Path(p)
        abs_ = cand if cand.is_absolute() else (repo / cand)
        try:
            rel = os.path.relpath(str(abs_.resolve()), str(repo.resolve()))
        except (OSError, ValueError):
            continue
        if rel == ".." or rel.startswith(".." + os.sep):
            continue  # outside this repo
        out.append(rel)
    return out


def self_test() -> int:
    """Build a throwaway repo, make uncommitted work, and read the exit codes.

    The point is that this prints what the guard DID, so a reader can disagree
    with it. A self-test that only says "ok" is the exact failure mode this
    whole tool exists to fix.
    """
    import shutil
    import tempfile

    root = Path(tempfile.mkdtemp(prefix="guard_uncommitted_selftest_"))
    fails = []
    try:
        def git(*a):
            return subprocess.run(["git", *a], cwd=str(root), capture_output=True,
                                  text=True)

        git("init", "-q")
        git("config", "user.email", "selftest@calmatters.app")
        git("config", "user.name", "SelfTest")
        (root / "tracked.txt").write_text("original\n", encoding="utf-8")
        git("add", "tracked.txt")
        git("commit", "-q", "-m", "base")

        clean = main(["check", "tracked.txt"], root_override=root)
        print(f"clean tracked file            -> exit {clean} (want 0)")
        if clean != EXIT_SAFE:
            fails.append("a clean file was not SAFE; the guard is noise")

        (root / "tracked.txt").write_text("original\nuncommitted work\n",
                                         encoding="utf-8")
        dirty = main(["check", "tracked.txt"], root_override=root)
        print(f"file with uncommitted changes -> exit {dirty} (want 1)")
        if dirty != EXIT_UNSAFE:
            fails.append("an uncommitted change was NOT refused - this is the "
                         "11:59 defect")

        still = (root / "tracked.txt").read_text(encoding="utf-8")
        print(f"the work is still on disk     -> "
              f"{'yes' if 'uncommitted work' in still else 'NO'}")
        if "uncommitted work" not in still:
            fails.append("the guard modified the file; it must only ever refuse")

        allowed = main(["allow", "tracked.txt"], root_override=root)
        patches = list((root / ".agent-logs" / "discard").glob("*.patch"))
        print(f"allow wrote {len(patches)} patch(es)        -> exit {allowed}")
        if allowed != EXIT_SAFE or not patches:
            fails.append("allow did not write a patch")
        elif "uncommitted work" not in patches[0].read_text(encoding="utf-8"):
            fails.append("the patch does not contain the work it claims to save")

        untracked = root / "brand_new.txt"
        untracked.write_text("mine\n", encoding="utf-8")
        u = main(["check", "brand_new.txt"], root_override=root)
        print(f"untracked file                -> exit {u} (want 0)")
        if u != EXIT_SAFE:
            fails.append("an untracked file was refused; there is no committed "
                         "version to lose")

        missed = [v for v in (["git", "checkout", "--", "x.py"],
                              ["git", "restore", "x.py"],
                              ["git", "stash", "push"],
                              ["git", "reset", "--hard"],
                              ["git", "clean", "-fd"])
                  if not is_destructive(v)]
        print(f"destructive verbs detected    -> {5 - len(missed)}/5")
        if missed:
            fails.append(f"destructive verbs no longer detected: {missed}")

        false_alarm = [v for v in (["git", "checkout", "-b", "new"],
                                   ["git", "status"], ["git", "add", "x.py"])
                       if is_destructive(v)]
        print(f"false alarms on safe commands -> {len(false_alarm)} (want 0)")
        if false_alarm:
            fails.append(f"safe commands flagged destructive: {false_alarm}")
    finally:
        shutil.rmtree(root, ignore_errors=True)

    if fails:
        print("")
        for f in fails:
            print(f"FAIL: {f}")
        return 1
    print("")
    # NAME THE WORLD. Learned from outside on 2026-09-29: a one-line answer with
    # one meaning and two worlds is a fault, because the reader cannot tell which
    # one produced it. This self-test ran in a THROWAWAY repo, and two different
    # repos produce this identical line - so the line now says which tree it
    # exercised. A self-test whose summary cannot be attributed is a summary
    # about nothing in particular.
    print(f"guard_uncommitted self-test in {root}: the guard refuses uncommitted "
          "work, leaves it on disk, and saves a patch before anything may be "
          "discarded")
    return 0


def _is_tracked(root: Path, rel: str) -> bool:
    """Is this path in the index? An untracked path has no committed copy at all.

    Read from git rather than from a filename, and the RETURN CODE is checked: a git
    that did not answer must not be read as "everything is untracked", which would
    print UNTRACKED for every file in the repository and make the new sentence a
    lie in the other direction.
    """
    p = subprocess.run(["git", "ls-files", "--error-unmatch", "--", rel],
                       cwd=str(root), capture_output=True, text=True)
    return p.returncode == 0


def main(argv: list[str] | None = None, root_override: Path | None = None) -> int:
    """`root_override` exists so the self-test exercises a throwaway repo.

    Without it the guard inspects whatever directory the caller happened to be
    standing in - which is exactly how a guard ends up checking a different tree
    than the one being destroyed.
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--self-test", action="store_true",
                    help="exercise the refusal path in a throwaway repo")
    ap.add_argument("mode", nargs="?",
                    choices=["guard", "allow", "check", "list", "decide"])
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--verdict", default="restored",
                    choices=["restored", "dead", "superseded"],
                    help="with `decide`: what became of the parked work")
    ap.add_argument("--producer", default="",
                    help="with `decide`: who, when, and why - it is written "
                         "into the record beside the patch")
    args = ap.parse_args(argv)

    if args.self_test:
        return self_test()
    if args.mode is None:
        print("REFUSED: no mode given. I cannot tell what is uncommitted.")
        return EXIT_UNSAFE

    # `list` and `decide` are about the parked patches, not about the working
    # tree, so they run BEFORE the "no path given" refusal below.
    root_early = root_override if root_override is not None else repo_root(Path.cwd())
    if root_early is None:
        print("REFUSED: not inside a git work tree; I cannot see what is uncommitted.")
        return EXIT_NOT_A_REPO

    if args.mode == "list":
        rc, _ = list_parked(root_early)
        return rc
    if args.mode == "decide":
        if not args.paths:
            print("REFUSED: decide needs the path of the parked patch.")
            return EXIT_UNSAFE
        rc, dest = decide(root_early, Path(args.paths[0]), args.verdict,
                          args.producer or "producer not stated")
        if rc != 0:
            print(f"REFUSED: {dest}")
            return EXIT_UNSAFE
        print(f"decision recorded: {dest}")
        print(f"  verdict: {args.verdict}")
        print(f"  producer: {args.producer or 'producer not stated'}")
        print("The patch stays on disk. A decision is a record, not a deletion.")
        return EXIT_SAFE

    if not args.paths:
        print("REFUSED: no path given. I cannot tell what is uncommitted.")
        return EXIT_UNSAFE

    if len(sys.argv) > 1 and is_destructive(sys.argv[1:]):
        # Someone ran `python3 tools/guard_uncommitted.py guard <file>` after
        # `git checkout <file>` on the same line. Say so rather than guess.
        print("WARNING: this command line also contains a destructive git verb.")

    root = root_override if root_override is not None else repo_root(Path.cwd())
    if root is None:
        print("REFUSED: not inside a git work tree; I cannot see what is uncommitted.")
        return EXIT_NOT_A_REPO

    paths = _resolve(root, args.paths)
    if not paths:
        print(f"REFUSED: none of {args.paths} is inside this repo ({root}).")
        return EXIT_NOT_A_REPO

    dirty = dirty_paths(root, paths)
    if not dirty:
        # WHICH WORLD. The bare filename is a throwaway temp name and identifies
        # nothing: the same line comes out of any repo on any machine. A reader
        # who is told "nothing uncommitted" needs to know which tree was checked.
        #
        # AND WHAT "SAFE" DOES NOT MEAN, added 2026-09-29. In git's vocabulary an
        # UNTRACKED file has nothing uncommitted about it, so the check is clean
        # and this used to print the same SAFE line it prints for a clean tracked
        # file. Those are not the same fact. A tracked file with no uncommitted
        # changes cannot be lost by `git checkout`; an untracked file has no
        # committed copy AT ALL, so `git clean -fd` takes it and nothing this tool
        # can see would notice. Six such files sit in this repository, not mine,
        # never touched by me.
        #
        # So the word is narrowed to what was actually established, rather than the
        # guard being deleted or made red. A red nobody reads is a comment, and
        # this is not a fault to be reported - it is a sentence that was doing more
        # work than it had earned.
        untracked_here = [p for p in paths
                          if not _is_tracked(root, p)]
        if untracked_here:
            print(f"UNTRACKED, not SAFE: {', '.join(untracked_here)} has no committed "
                  f"copy, so `git clean -fd` would take it and this guard cannot see "
                  f"that. Checked for uncommitted CHANGES only.  [repo: {root}]")
            return EXIT_SAFE
        print(f"SAFE: nothing uncommitted in {', '.join(paths)}  [repo: {root}]")
        return EXIT_SAFE

    print(f"REFUSED: uncommitted changes in a file I did not write  [repo: {root}]")
    for d in dirty:
        print(f"  modified: {d}")
    print("")
    print("Order 11: never git checkout / restore / stash / reset a file whose")
    print("change you did not write by hand. Save it first, then look, then decide.")
    print("  see it   ->  git diff HEAD -- " + " ".join(dirty))
    print("  save it  ->  python3 tools/guard_uncommitted.py allow " + " ".join(dirty))

    if args.mode == "check":
        return EXIT_UNSAFE
    if args.mode == "allow":
        rc, dest = take_patch(root, dirty)
        if rc != 0:
            print(f"REFUSED: could not write a patch: {dest}")
            return EXIT_UNSAFE
        size = Path(dest).stat().st_size
        print("")
        print(f"patch written: {dest}  ({size} bytes)")
        print("It is a patch, not a copy: it survives a rename, and you can read it.")
        print("Now LOOK at it, then decide. The decision is still yours.")
        return EXIT_SAFE

    return EXIT_UNSAFE


if __name__ == "__main__":
    sys.exit(main())
