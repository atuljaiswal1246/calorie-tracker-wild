#!/usr/bin/env python3
"""Read a Worker KV key without ever confusing "missing" for "empty".

Written 2026-09-27 after I drew a real conclusion from an empty stdout: I ran
`wrangler kv key get` in a shell where `wrangler` was not on PATH, got exit 127
and empty output, and reported "the key is empty, so the provider is never
attempted". The command had FAILED. The finding was about my shell, not the
system.

`wrangler kv key get` is actually well behaved: a missing key exits 1 with a
message, an existing key exits 0 with the value. It never succeeds silently.
The danger is entirely in a wrapper (or a missing binary) turning a failure into
empty output.

This helper refuses to blur it. Every call prints an explicit verdict and the
exit code, and returns non-zero when the read could not be trusted, so no
downstream note can say "empty" when the truth is "the command broke".
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys

BINDING = "QUOTA"
# wrangler lives in the node bin dir that is NOT on a default shell's PATH.
CANDIDATE_PATHS = [
    shutil.which("wrangler"),
    "/Users/neharohilla/.nvm/versions/node/v26.2.0/bin/wrangler",
    "/opt/homebrew/bin/wrangler",
    "/usr/local/bin/wrangler",
]


def find_wrangler() -> str | None:
    for path in CANDIDATE_PATHS:
        if path and shutil.os.path.exists(path):
            return path
    return None


def read(key: str) -> dict:
    """Returns {state, value, exit_code}. state is VALUE | MISSING | ERROR."""
    exe = find_wrangler()
    if exe is None:
        return {"state": "ERROR", "value": None, "exit_code": 127,
                "detail": "wrangler not found on PATH or in the known locations - "
                          "this is a BROKEN READ, not an empty value"}

    proc = subprocess.run(
        [exe, "kv", "key", "get", "--binding", BINDING, key, "--remote"],
        capture_output=True, text=True, cwd="cloudflare_worker")

    if proc.returncode == 0:
        return {"state": "VALUE", "value": proc.stdout.strip(),
                "exit_code": 0, "detail": "read succeeded"}

    blob = (proc.stdout + proc.stderr).lower()
    # wrangler reports a genuinely absent key differently from a broken call.
    if "not found" in blob or "no such key" in blob or "does not exist" in blob:
        return {"state": "MISSING", "value": None, "exit_code": proc.returncode,
                "detail": "the key does not exist (this is a real absence)"}

    return {"state": "ERROR", "value": None, "exit_code": proc.returncode,
            "detail": (proc.stdout + proc.stderr).strip()[:300] or
                      "non-zero exit with no output - do NOT read this as empty"}


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        print("usage: python3 tools/kv_get.py <key> [<key> ...]", file=sys.stderr)
        return 2
    verdict = 0
    for key in sys.argv[1:]:
        got = read(key)
        print(f"{key}: {got['state']}  (exit {got['exit_code']})")
        if got["state"] == "VALUE":
            print(f"    value: {got['value']}")
        else:
            print(f"    detail: {got['detail']}")
        if got["state"] == "ERROR":
            verdict = 1
    return verdict


if __name__ == "__main__":
    raise SystemExit(main())
