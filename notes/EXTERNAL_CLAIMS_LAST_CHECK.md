# External claims - last checked

**Checked 2026-09-28 09:39 IST** by `python3 tools/check_external_claims.py --record`.

This file exists so a verification carries its own age. The check itself is a network call and so cannot live in `flutter test`; the RECORD is in the repo, and `test/external_claims_test.dart` fails if it goes stale, if it is older than 14 days, or if the app's URL set no longer matches it.

| url | HTTP | bytes | opened by the app |
|---|---|---|---|
| https://calorie-tracker-80a0b.web.app/delete-account.html | 200 | 3223 | - |
| https://calorie-tracker-80a0b.web.app/index.html | 200 | 3187 | - |
| https://calorie-tracker-80a0b.web.app/privacy.html | 200 | 5134 | lib/screens/auth_screen.dart, lib/screens/pricing_screen.dart |
| https://calorie-tracker-80a0b.web.app/terms.html | 200 | 3446 | lib/screens/auth_screen.dart, lib/screens/pricing_screen.dart |

A 200 is not proof on its own: each body had to be over 400 bytes, because a hosting 404 often returns 200 with a small page.
