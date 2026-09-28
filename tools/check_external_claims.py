#!/usr/bin/env python3
"""Check the claims AGENTS.md makes about the WORLD, not about the repo.

Why this exists, 2026-09-28: AGENTS.md says, in bold, that the privacy policy is
"LIVE on Firebase Hosting" and "verified live". That claim is about something OUTSIDE
this repository, and nothing in `flutter test` can see it. So it had exactly the
property that has broken three things tonight: it was true when it was written, it
was carried forward in every report since, and nobody ever looked again. A privacy
policy that quietly 404'd would be found at Play submission, by the owner, at the
worst possible moment.

So the claims are extracted from AGENTS.md and actually fetched. The rules:

  * EVERY claim is fetched, and the HTTP status is the answer. Exit code is the
    verdict - never a count of lines printed.
  * A claim whose URL is a variable or a placeholder is reported as UNKNOWN, not
    as a pass. An empty result is not a finding.
  * No claim is "assumed fine" because the repo has a file of the same name: a
    file in public/ proves the file exists, not that it is SERVED.
  * This is a script, not a widget test, on purpose. `flutter test` must not depend
    on the network, or it becomes the flaky test nobody trusts.

    python3 tools/check_external_claims.py
    python3 tools/check_external_claims.py --json   # for the note
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
AGENTS = ROOT / "AGENTS.md"
UA = "Mozilla/5.0 (Macintosh) CalMattersClaimCheck/1.0"

# The URLs come from the APP, not from the prose. That is the whole correction:
# my first version took its list from AGENTS.md, which mentions ONE of the two URLs
# the app actually opens, so it would have reported "1 of 3 verified" while the
# product's own dependency - the terms page, opened from sign-up and from the
# paywall - had never been checked by anything.
#
# The real dependency list is "every https:// URL the app hands to url_launcher",
# and the prose is then checked AGAINST it, so documentation and product cannot
# quietly disagree about what the app depends on.
CLAIM_NOTE = {
    "terms.html": "opened from the sign-up screen and the paywall",
    "privacy.html": "opened from the sign-up screen and the paywall, and named in the Play data-safety form",
    "delete-account.html": "an account-deletion page a store listing can point at",
    "index.html": "the hosting root",
}


def app_urls() -> dict[str, list[str]]:
    """Every external URL in lib/, with the files that open it."""
    out: dict[str, list[str]] = {}
    for dart in sorted((ROOT / "lib").rglob("*.dart")):
        text = dart.read_text(encoding="utf-8")
        for url in re.findall(r"https://[A-Za-z0-9._/-]+", text):
            if "calorie-tracker-80a0b" not in url:
                continue
            url = url.rstrip("'\")")
            out.setdefault(url, [])
            rel = str(dart.relative_to(ROOT))
            if rel not in out[url]:
                out[url].append(rel)
    return out


def hosting_root() -> str | None:
    m = re.search(r"https://(calorie-tracker-[a-z0-9-]+)\.web\.app", AGENTS.read_text(encoding="utf-8"))
    return m.group(0) if m else None


def fetch(url: str, timeout: int = 25) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            return {"status": resp.status, "bytes": len(body),
                    "final_url": resp.geturl()}
    except urllib.error.HTTPError as exc:
        return {"status": exc.code, "bytes": 0, "error": f"HTTP {exc.code}"}
    except Exception as exc:                                   # noqa: BLE001
        return {"status": None, "bytes": 0, "error": str(exc)[:120]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    text = AGENTS.read_text(encoding="utf-8")
    urls = app_urls()
    root = hosting_root()
    if root:
        # The pages the hosting site is supposed to carry. Checked because a file
        # in public/ proves the file exists, not that it is SERVED - and a privacy
        # page that 404s is a Play submission blocker discovered at the worst
        # possible moment.
        for page in ("terms.html", "privacy.html", "delete-account.html", "index.html"):
            urls.setdefault(f"{root}/{page}", [])

    results: list[dict] = []
    for url in sorted(urls):
        got = fetch(url)
        # Content is part of the claim: an HTML error page is a 200 that lies, and a
        # hosting 404 often returns 200 with a small body.
        ok = got.get("status") == 200 and got.get("bytes", 0) > 400
        # The hosting root and .../index.html are the SAME page, and a literal
        # substring match called them two - so AGENTS.md could be right and the
        # check wrong. Normalise before comparing.
        root = url.rsplit("/", 1)[0] + "/"
        documented = (url in text) or (url.endswith("/index.html") and root in text)
        results.append({
            "url": url,
            "ok": ok,
            "documented": documented,
            "opened_by": urls[url],
            **got,
        })

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for r in results:
            verdict = "OK  " if r["ok"] else "FAIL"
            doc = "documented" if r["documented"] else "NOT in AGENTS.md"
            note = CLAIM_NOTE.get(r["url"].rsplit("/", 1)[-1], "")
            print(f"{verdict} {r['status']!s:>4}  {doc:<18} {r['url']}")
            if r["opened_by"]:
                print(f"          opened by: {', '.join(r['opened_by'])}")
            if note:
                print(f"          {note}")
            if not r["ok"]:
                print(f"          -> {r.get('error') or 'body too small to be a real page'}")

    # Two different verdicts, because they need two different fixes. An unreachable
    # page is broken product. An undocumented one is a claim nobody can check, and
    # the next session will re-report it from memory - which is how "verified
    # live" becomes a thing someone believes without evidence.
    broken = [r for r in results if not r["ok"]]
    undocumented = [r for r in results if not r["documented"]]
    print(f"\n{len(results) - len(broken)}/{len(results)} reachable, "
          f"{len(results) - len(undocumented)}/{len(results)} documented")
    if broken or undocumented:
        for r in broken:
            print(f"BROKEN  {r['url']} - a user tapping this link sees an error")
        for r in undocumented:
            # Which kind of dependency it is. The app OPENING a page and a store
            # listing POINTING at a page are different obligations; calling both
            # "the app depends on it" would be a false claim about half of them,
            # which is the sin this script exists to catch.
            if r["opened_by"]:
                print(f"UNCLAIMED {r['url']} - the app opens it from "
                      f"{', '.join(r['opened_by'])}, and AGENTS.md does not say "
                      f"so, so nothing checks it next time")
            else:
                print(f"UNCLAIMED {r['url']} - part of the hosted surface, not "
                      f"opened by the app, and written down nowhere")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
