#!/usr/bin/env python3
"""Mark a Cal Matters account as paid in Firestore (so it clears the paywall).

    python3 tools/mark_paid.py ariefshaik999@gmail.com

Why this exists: release builds always follow the real gate (no sandbox), so an
Android tester needs `paid: true` on their user doc to reach Home instead of the
paywall. This is the documented dev route; the product route is a real purchase.

Credentials: reuses the Firebase CLI's own login (it is already authenticated on
this machine), so no service-account key is needed. Reads the refresh token from
~/.config/configstore/firebase-tools.json and mints a short-lived access token.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

PROJECT = 'calorie-tracker-80a0b'
CLI_CONFIG = os.path.expanduser('~/.config/configstore/firebase-tools.json')
# Public firebase-tools OAuth client (ships in the open-source CLI).
CLIENT_ID = ('563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6'
             '.apps.googleusercontent.com')
CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi'


def access_token() -> str:
    cfg = json.load(open(CLI_CONFIG))
    refresh = cfg['tokens']['refresh_token']
    body = urllib.parse.urlencode({
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'refresh_token': refresh,
        'grant_type': 'refresh_token',
    }).encode()
    req = urllib.request.Request('https://oauth2.googleapis.com/token', data=body)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())['access_token']


def api(url, token, payload=None, method=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url, data=data, method=method or ('POST' if data else 'GET'),
        headers={'Authorization': f'Bearer {token}',
                 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read() or b'{}')


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    email = sys.argv[1].strip()

    # A FLAG IS NOT AN EMAIL ADDRESS. Found 2026-09-28: `mark_paid.py --help`
    # took "--help" as the address to look up and made a LIVE Firebase call,
    # printing "looking up --help in calorie-tracker-80a0b ... NOT FOUND". The
    # tool had no argparse and no way to say "I was asking".
    #
    # This matters more than the joke of it. This tool can WRITE a `paid: true`
    # onto a user's account, so an argument it misreads is an argument it acts
    # on. Anything starting with `-` is refused here, and the refusal says how to
    # get the usage, so a mistake costs nothing.
    if email in ('-h', '--help'):
        # Asking for help is not an error: exit 0. The refusal below is for an
        # argument that LOOKS like some other flag, which is a different mistake
        # and a different exit code.
        print(__doc__)
        return 0
    if email.startswith('-'):
        print(f'"{email}" looks like a flag, not an email address.')
        print('This tool marks a PAID USER by email and can write paid=true onto')
        print('their account, so it will not guess what an argument meant.')
        print('')
        print(__doc__)
        return 2

    token = access_token()
    print(f'looking up {email} in {PROJECT} ...')
    found = api(f'https://identitytoolkit.googleapis.com/v1/projects/'
                f'{PROJECT}/accounts:lookup', token, {'email': [email]})
    users = found.get('users', [])
    if not users:
        print('  NOT FOUND - that account has never signed in to the app.')
        print('  Ask them to open the app and sign in once, then run this again.')
        return 1
    uid = users[0]['localId']
    print(f'  uid = {uid}')

    doc = (f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
           f'/databases/(default)/documents/users/{uid}')
    api(doc + '?updateMask.fieldPaths=paid', token,
        {'fields': {'paid': {'booleanValue': True}}}, method='PATCH')
    check = api(doc, token)
    paid = check.get('fields', {}).get('paid', {}).get('booleanValue')
    print(f'  users/{uid}.paid = {paid}')
    print('  DONE - the paywall will clear on their next app open.'
          if paid else '  FAILED - field did not stick.')
    return 0 if paid else 1


if __name__ == '__main__':
    raise SystemExit(main())
