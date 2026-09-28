// A failed scan must never send a user somewhere that does not exist, and must
// never blame them for our money.
//
// TWO LIVE DEFECTS, both found on 2026-09-28 while all three provider tiers were
// MONEY BLOCKED — which is precisely the condition a user meets on the day we
// cannot pay for their scan.
//
// 1. THE APP SENT USERS TO A SETTINGS FIELD THAT DOES NOT EXIST.
//    On a 403 the user was told: "Invalid API key. Go to Settings and check your
//    key." There is no key in Settings. There is no key anywhere in the app —
//    §0 rule 2 removed it deliberately and test/no_provider_keys_test.dart fails
//    if one ever returns. So the one message that told a user how to fix
//    something pointed at nothing, and blamed them for our fault. A user who saw
//    it would hunt through Settings, find nothing, and conclude the app is
//    broken.
//
// 2. A 402 — WE have no budget — FELL THROUGH TO "Something went wrong. Please
//    try again." Our billing state, reported to the user as their mistake, with
//    no information and no action they can take. And `analyzeImage` retried it
//    three times, two seconds apart, so a guaranteed failure cost four seconds
//    of spinner and hit the Worker three times for nothing.
//
// WHY A TEST AND NOT A REVIEW. The old code was a private static method on a
// screen, taking a raw exception string. Nobody could enumerate the status codes
// it handled, which is why 402 was missing from a list that already had 429, 500,
// 502, timeout and SocketException. It is now a pure library with a switch, so
// every branch is reachable and the forbidden words are greppable across all of
// them at once.

import 'package:calorie_tracker/services/scan_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classification', () {
    test('402 is OUR money, not the user\'s quota, and wins over 429', () {
      // The order is the point. "quota" appears in real 402 bodies; if the quota
      // branch were checked first, our billing state would be reported to users
      // as their own rate limit.
      expect(classifyScanFailure('AI request failed (402): payment required'),
          ScanFailure.noBudget);
      expect(
          classifyScanFailure(
              'AI request failed (402): You exceeded your current quota'),
          ScanFailure.noBudget);
    });

    test('the other classes still land where they did', () {
      expect(classifyScanFailure('SocketException: Connection refused'),
          ScanFailure.offline);
      expect(classifyScanFailure('AI request failed (429): rate limit'),
          ScanFailure.busy);
      expect(classifyScanFailure('AI request failed (502): bad gateway'),
          ScanFailure.upstreamDown);
      expect(classifyScanFailure('Request timed out'), ScanFailure.timedOut);
      expect(classifyScanFailure('Could not find the food'), ScanFailure.badImage);
      expect(classifyScanFailure('something entirely novel'),
          ScanFailure.unknown);
    });

    test('403 no longer pretends to be a user key problem', () {
      // It still classifies as unknown rather than inventing a cause, which is
      // the honest answer: a 403 from our own Worker means the request was
      // refused, and we do not know why, so we must not guess "your key".
      expect(classifyScanFailure('AI request failed (403)'), ScanFailure.unknown);
    });
  });

  group('retry policy', () {
    test('a 402 is NEVER retried', () {
      // This is the live money case. An identical retry spends nothing, succeeds
      // never, and makes the user wait.
      expect(shouldRetryScan(ScanFailure.noBudget), isFalse,
          reason: 'retrying a payment-required error made a guaranteed failure '
              'guaranteed three times over');
    });

    test('transient things are still retried', () {
      for (final f in [
        ScanFailure.offline,
        ScanFailure.busy,
        ScanFailure.upstreamDown,
        ScanFailure.timedOut,
      ]) {
        expect(shouldRetryScan(f), isTrue, reason: '$f should be retried');
      }
    });

    test('an unreadable photo is not retried — a second read fails the same way',
        () {
      expect(shouldRetryScan(ScanFailure.badImage), isFalse);
    });
  });

  group('what the user is told', () {
    const all = ScanFailure.values;

    test('NO message mentions an API key — the app has none', () {
      for (final f in all) {
        final m = scanFailureMessage(f).toLowerCase();
        expect(m.contains('api key'), isFalse,
            reason: '$f tells the user to fix an API key. There is no key in '
                'this app and there never will be (§0 rule 2). This is the '
                'message that sent users hunting through Settings for a field '
                'that does not exist.');
        expect(m.contains('apikey'), isFalse, reason: '$f');
      }
    });

    test('NO message tells a user to go and fix something themselves', () {
      // "check your", "go to settings", "update your" — the shapes of an
      // instruction pointing at a control the user does not have.
      final banned = ['go to settings', 'check your key', 'update your',
                      'check your api', 'your account settings'];
      for (final f in all) {
        final m = scanFailureMessage(f).toLowerCase();
        for (final b in banned) {
          expect(m.contains(b), isFalse,
              reason: '$f contains "$b", which sends the user to a place that '
                  'cannot help them: ${scanFailureMessage(f)}');
        }
      }
    });

    test('NO message leaks our money, quota, or provider names', () {
      final banned = [
        'quota', 'billing', 'credit', 'payment', '402', 'aicredits', 'openrouter',
        'opencode', 'zen', 'provider', 'api key', 'insufficient', 'invoice',
      ];
      for (final f in all) {
        final m = scanFailureMessage(f).toLowerCase();
        for (final b in banned) {
          expect(m.contains(b), isFalse,
              reason: '$f leaks "$b" to the user. Our money and our suppliers '
                  'are not the user\'s business, and a user who reads a 402 '
                  'understands a fault that is not theirs: ${scanFailureMessage(f)}');
        }
      }
    });

    test('NO message blames the user or shames them', () {
      // Same rule as test/quiet_copy_test.dart, applied to the one place the app
      // speaks about something going wrong.
      //
      // Note "you " is banned, "your" is not. Second person is allowed when it
      // is reassurance ("Your logged meals are safe") and refused when it is an
      // accusation ("You forgot to..."). The distinction is intention, and a
      // blanket ban would have deleted the reassurance that makes a pause in
      // our funding stop reading as data loss.
      final banned = [
        'you ', 'your fault', 'invalid', 'you must', 'make sure you',
        'you didn', 'you forgot', 'incorrect',
      ];
      for (final f in all) {
        final m = scanFailureMessage(f).toLowerCase();
        for (final b in banned) {
          expect(m.contains(b), isFalse,
              reason: '$f talks to the user about what they did wrong: '
                  '${scanFailureMessage(f)}');
        }
      }
    });

    test('every failure has a message, and none is empty', () {
      for (final f in all) {
        expect(scanFailureMessage(f).trim(), isNotEmpty, reason: '$f');
      }
    });

    test('the money case reassures that the user\'s data is safe', () {
      // The one thing a user CAN be told when we cannot serve them: what they
      // already logged is untouched. Silence about that is what makes a moment
      // like this feel like data loss.
      final m = scanFailureMessage(ScanFailure.noBudget).toLowerCase();
      expect(m.contains('safe'), isTrue,
          reason: 'the money case must say their logged data is safe, or a '
              'pause in our funding reads as a loss of their history: $m');
    });
  });
}
