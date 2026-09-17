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
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

KEY = 'tools/serviceAccountKey.json'
PKG = 'com.neharohilla.calorietracker'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    draft = '--draft' in sys.argv
    if len(args) < 2:
        print(__doc__)
        return 2
    aab, track = args[0], args[1]
    notes = open(args[2]).read().strip() if len(args) > 2 else None

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
