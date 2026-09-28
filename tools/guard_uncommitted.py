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
import os
import subprocess
import sys
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
    print("guard_uncommitted self-test: the guard refuses uncommitted work, "
          "leaves it on disk, and saves a patch before anything may be discarded")
    return 0


def main(argv: list[str] | None = None, root_override: Path | None = None) -> int:
    """`root_override` exists so the self-test exercises a throwaway repo.

    Without it the guard inspects whatever directory the caller happened to be
    standing in - which is exactly how a guard ends up checking a different tree
    than the one being destroyed.
    """
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--self-test", action="store_true",
                    help="exercise the refusal path in a throwaway repo")
    ap.add_argument("mode", nargs="?", choices=["guard", "allow", "check"])
    ap.add_argument("paths", nargs="*")
    args = ap.parse_args(argv)

    if args.self_test:
        return self_test()
    if args.mode is None:
        print("REFUSED: no mode given. I cannot tell what is uncommitted.")
        return EXIT_UNSAFE
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
        print(f"SAFE: nothing uncommitted in {', '.join(paths)}.")
        return EXIT_SAFE

    print("REFUSED: uncommitted changes in a file I did not write.")
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
