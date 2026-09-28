#!/usr/bin/env python3
"""Upload a release to a Google Play track.

    python3 tools/publish.py <aab> <track> [notes-file] [--draft]

Reads credentials from tools/serviceAccountKey.json (gitignored).
Nothing is published without a successful commit at the end.
"""
import socket
import sys

# Big uploads on a home connection need patience and retries.
socket.setdefaulttimeout(900)

# The Google libraries are imported INSIDE main(), after the --help and argument
# handling, and not at module scope. Found 2026-09-28: a module-scope
# `from google.oauth2 import service_account` meant `publish.py --help` died with
# ModuleNotFoundError on any interpreter without that package — so the one
# question that cannot cost anything was the one question you could not ask.
#
# This is the same fault as a --help that runs the work, one layer earlier: a
# tool that cannot answer without doing its setup has no door, and the person who
# needs the door most is the person whose environment is the thing that is
# broken. Import late, or not at all until the work is certain.


def _google():
    """Import the Google client libraries at the moment they are needed."""
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
    return service_account, build, MediaFileUpload

KEY = 'tools/serviceAccountKey.json'
PKG = 'com.neharohilla.calorietracker'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']


def main() -> int:
    # --help must STOP this tool, and it is the tool that most needs to: it
    # UPLOADS A RELEASE to a Play track. It has flags, so "it probably handles
    # --help" was an assumption nobody had checked until
    # test/tools_help_is_a_door_test.dart ran --help on every tool and read the
    # exit code. Found 2026-09-28.
    if any(a in ('-h', '--help') for a in sys.argv[1:]):
        print(__doc__)
        return 0
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    draft = '--draft' in sys.argv
    if len(args) < 2:
        print(__doc__)
        return 2
    aab, track = args[0], args[1]
    notes = open(args[2]).read().strip() if len(args) > 2 else None

    service_account, build, MediaFileUpload = _google()
    creds = service_account.Credentials.from_service_account_file(KEY, scopes=SCOPES)
    svc = build('androidpublisher', 'v3', credentials=creds, cache_discovery=False)

    edit = svc.edits().insert(packageName=PKG, body={}).execute()
    eid = edit['id']
    print('edit', eid)

    print('uploading', aab, '...')
    bundle = svc.edits().bundles().upload(
        packageName=PKG, editId=eid,
        media_body=MediaFileUpload(aab, mimetype='application/octet-stream',
                                   resumable=True, chunksize=16 * 1024 * 1024),
    ).execute(num_retries=5)
    vc = bundle['versionCode']
    print('uploaded versionCode', vc)

    release = {
        'versionCodes': [str(vc)],
        'status': 'draft' if draft else 'completed',
    }
    if notes:
        release['releaseNotes'] = [{'language': 'en-US', 'text': notes}]

    svc.edits().tracks().update(
        packageName=PKG, editId=eid, track=track,
        body={'track': track, 'releases': [release]},
    ).execute()
    print(f"track '{track}' set to versionCode {vc} ({release['status']})")

    svc.edits().commit(packageName=PKG, editId=eid).execute()
    print('COMMITTED — release is live for the track' if not draft else 'COMMITTED as draft')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
