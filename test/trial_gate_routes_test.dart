// THE TRIAL GATE, AND THE ROUTE THAT WENT AROUND IT.
//
// Found 2026-09-28 by reading the ROUTES rather than the screens, and only after a
// probe nearly reported the opposite lie. The sequence matters, because the near
// miss is the lesson:
//
//   1. I grepped capture_screen.dart and progress_screen.dart for the gate and
//      found ZERO mentions in both. My first conclusion was "two of the owner's
//      seven locks are not implemented" - which would have been a serious,
//      confident, wrong thing to tell him about his own product.
//   2. It was wrong because the gate is not in the screens. It is at the ENTRY
//      POINTS in home_screen: `_gate(...)` on seven call sites, plus the nav tap
//      handler, which blocks Progress and Trophy before the tab ever switches.
//      Every surface the owner named IS locked. The screens themselves are
//      deliberately ungated, because they are not reached by any other route.
//
// That is the "scanner is down for every user" mistake for the third time: a
// probe that does not follow the real path, used to make a big claim. So the check
// has to follow the real path too.
//
// WHICH FOUND THE ACTUAL HOLE: having established that gates live at call sites,
// the next question is the one that matters - is there a call site that forgot?
// There is. `_openLogFromWidget` is reached from the widget uri handler on both
// cold start and warm start, it pushed `CaptureScreen` directly, and its own
// comment says "the widget's promise is one tap". So a user whose trial had ended
// could tap the home-screen widget and get the AI scan for nothing - the single
// most locked surface in the product, through the shortest path in the app.
//
// Two things are checked, because there are two ways this breaks:
//   1. the DECISION, as a pure function, unit-tested
//   2. the WIRING, structurally: no screen the trial locks may be pushed by a raw
//      MaterialPageRoute, only through `_pushGated`

import 'dart:io';

import 'package:calorie_tracker/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The surfaces the owner's 2026-09-21 decision locks. Named here so a new locked
/// surface has to be added in two places, and the second place is a test failure.
const lockedSurfaces = <String>[
  'CaptureScreen', // AI scan
  'BarcodeScannerScreen', // Barcode
  'QuickPicksScreen', // Quick picks
  'ProgressScreen', // Progress
  'AchievementsScreen', // Trophy
  'GalleryScreen', // Gallery (picked from the device, then scanned)
];

void main() {
  group('the decision itself', () {
    test('a full account opens everything', () {
      expect(gateDecision(limited: false), GateDecision.open);
    });

    test('a limited account is sent to the paywall', () {
      expect(gateDecision(limited: true), GateDecision.paywall);
    });

    test('the same answer for every locked surface', () {
      // The rule is one boolean, so it cannot be right for five surfaces and wrong
      // for the sixth. The loop is over a named list rather than a hardcoded
      // number, because I asserted "seven" here and in three commit messages
      // before counting: AI scan, Gallery, Quick picks, Barcode, Progress and
      // Trophy is SIX. The count is pinned so a new locked surface has to be
      // added here deliberately.
      for (final surface in lockedSurfaces) {
        expect(gateDecision(limited: true), GateDecision.paywall,
            reason: 'limited must be paywalled for $surface');
        expect(gateDecision(limited: false), GateDecision.open,
            reason: 'full must be open for $surface');
      }
      expect(lockedSurfaces, hasLength(6),
          reason: 'The number of locked surfaces changed. Update this AND the '
              'note in home_screen, and say in the commit why.');
    });
  });

  group('the wiring', () {
    late String home;

    setUpAll(() {
      home = File('lib/screens/home_screen.dart').readAsStringSync();
    });

    test('there is exactly one way in, and it consults the gate', () {
      expect(home.contains('_pushGated'), isTrue,
          reason: 'home_screen must have a single gated route helper.');
      final body = RegExp(r'Future<T\?> _pushGated<T>\(Widget page\) \{[\s\S]{0,900}?\n  \}')
          .firstMatch(home)
          ?.group(0);
      expect(body, isNotNull,
          reason: 'The _pushGated helper is gone; this test must be rewritten to '
              'match whatever replaced it.');
      expect(body, contains('gateDecision('),
          reason: '_pushGated must ask gateDecision, not decide for itself.\n$body');
      expect(body, contains('_openPricing()'),
          reason: 'A limited user must be shown the paywall, not simply '
              'dropped.\n$body');
    });

    test('no locked screen is pushed by a raw route any more', () {
      // The structural invariant. A raw `MaterialPageRoute(builder: (_) =>
      // CaptureScreen(...))` is a locked surface with no gate on it, and that is
      // the exact shape of the bug: a new call site that nobody remembered.
      final offenders = <String>[];
      for (final surface in lockedSurfaces) {
        // allow the ONE occurrence inside _pushGated's own signature area
        for (final m in RegExp(
                r'MaterialPageRoute[^;]{0,400}?builder:\s*\(_?\)?\s*=>\s*'
                '$surface')
            .allMatches(home)) {
          offenders.add('$surface at offset ${m.start}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'A locked surface is being pushed by a raw route:\n'
              '${offenders.join('\n')}\nEvery route to a locked surface must go '
              'through _pushGated, or a trial-ended user reaches it for nothing.');
    });

    test('the widget deep link - the shortest path in the app - is gated', () {
      // Named specifically, because this is the one that shipped broken and the
      // one most likely to be reintroduced: a deep link feels like plumbing, and
      // plumbing feels like it is exempt from product rules.
      final method = RegExp(r'void _openLogFromWidget\(\[Uri\? uri\]\) \{[\s\S]{0,1400}?\n  \}')
          .firstMatch(home)
          ?.group(0);
      expect(method, isNotNull,
          reason: '_openLogFromWidget is gone. If the widget entry point was '
              'renamed or removed, say so in this test rather than leaving it '
              'green.');
      expect(method, contains('_pushGated'),
          reason: 'The widget route must go through _pushGated. Ungated, it hands '
              'a trial-ended user the AI scan in one tap.\n$method');
      expect(method, isNot(contains('MaterialPageRoute')),
          reason: 'There is a raw route inside the widget handler again.\n$method');
    });

    test('the nav still blocks Progress and Trophy before the tab switches', () {
      // These two are gated in the tap handler rather than by _pushGated, because
      // they are pages, not routes. Pinned so a refactor of the nav cannot quietly
      // drop them.
      final onTap = RegExp(r'onTap: \(i\) \{[\s\S]{0,1200}?\n                \},')
          .firstMatch(home)
          ?.group(0);
      expect(onTap, isNotNull, reason: 'The nav tap handler moved; update this.');
      expect(onTap, contains('_limited'),
          reason: 'The nav gate must still consult the trial state.\n$onTap');
      expect(RegExp(r'if \(i == 1 && _limited\)').hasMatch(home), isTrue,
          reason: 'Progress must stay blocked for a limited account.');
      expect(RegExp(r'if \(i == 2\)').hasMatch(home), isTrue,
          reason: 'Trophy/Achievements must keep its own gate branch.');
    });
  });
}
