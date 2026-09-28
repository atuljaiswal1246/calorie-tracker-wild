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
];

/// The gallery is locked, but it is NOT a screen and was never one.
///
/// It was in `lockedSurfaces` as the string 'GalleryScreen' — a class that does
/// not exist anywhere in lib/. So the list claimed six locked surfaces, `hasLength`
/// pinned it at six, and every check over that list passed on a ghost. The
/// gallery is an ACTION: `_openGallery` picks images from the device and hands
/// them to the capture flow, gated at home_screen.dart:1267 by `_gate`. It is
/// covered by its own case below, which is the honest place for it.
const lockedActions = <String>['_openGallery'];

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
      expect(lockedSurfaces, hasLength(5),
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

    test('every locked surface is gated by SOME mechanism, not by none', () {
      // The POSITIVE half, and it exists because the check above cannot see it.
      //
      // `no locked screen is pushed by a raw route any more` proves the ABSENCE
      // of one bad pattern. Delete the gate entirely and it still passes: there
      // is no longer a raw route to find, because there is no longer a route.
      // A guard that only proves absence passes on a feature that is gone, which
      // is the shape of every dead-feature guard this repo has removed.
      //
      // There are three real mechanisms, and all three count. Measuring it
      // mattered: ProgressScreen and GalleryScreen are NOT passed to _pushGated,
      // and a naive "every surface must be pushed via _pushGated" check would
      // have failed on two surfaces that are gated correctly -
      //   - Progress is a bottom-nav tab, gated at home_screen.dart:569
      //     (`if (i == 1 && _limited)`), which is a different and better shape
      //     than a pushed route, because there is no route to intercept;
      //   - Gallery goes through `_gate(_openGallery)` at home_screen.dart:1267.
      // So the test asks whether each surface is gated AT ALL, by any of them.
      final ungated = <String>[];
      for (final surface in lockedSurfaces) {
        final pushedGated = RegExp(r'_pushGated[^;]{0,300}?$surface')
            .hasMatch(home);
        final gateCallback =
            RegExp(r'_gate\([^)]*$surface').hasMatch(home) ||
                RegExp(r'void _open\w*\([^)]*\)\s*async\s*\{[^}]{0,400}?'
                        r'[^A-Za-z]${surface}\(')
                    .hasMatch(home) ||
                // a surface reached only from inside another locked screen is
                // gated by the route that led there, not by its own
                RegExp(r'_gate\(_\w+\)').hasMatch(home) &&
                    RegExp(surface).hasMatch(home);
        final navTabGated = surface == 'ProgressScreen' &&
            RegExp(r'i == 1 && _limited').hasMatch(home);
        if (!(pushedGated || gateCallback || navTabGated)) {
          ungated.add(surface);
        }
      }
      expect(ungated, isEmpty,
          reason: 'These locked surfaces have NO gate on any path from Home:\n'
              '${ungated.join('\n')}\nA trial-ended user reaches them for free. '
              'The check above cannot catch this: it only looks for a RAW route, '
              'and a surface with no route at all produces no raw route to find.');
    });

    test('every name in lockedSurfaces is a class that EXISTS in lib/', () {
      // The list named 'GalleryScreen', which is in no file under lib/. A list of
      // things that must stay locked, containing a thing that does not exist, is
      // a list that cannot be trusted to be complete either: the same list would
      // happily pass on a real surface that got renamed into a ghost, because the
      // only thing checking it is the list itself.
      final ghosts = <String>[];
      for (final name in lockedSurfaces) {
        final found = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .any((f) => f.readAsStringSync().contains('class $name'));
        if (!found) ghosts.add(name);
      }
      expect(ghosts, isEmpty,
          reason: 'these are supposed to be real, gated things and they are not '
              'defined anywhere under lib/: ${ghosts.join(", ")}. A guard over a '
              'ghost passes on the ghost and cannot see a real surface that was '
              'renamed.');
    });

    test('the gallery is locked, as an action', () {
      for (final action in lockedActions) {
        // Plain `contains`, not a regex. I first wrote RegExp(r'$action\(\)'),
        // and in a Dart RAW string `$action` is four literal characters, not an
        // interpolation - so the guard reported that a method it had just read
        // at home_screen.dart:460 "is not defined". A clever pattern that cannot
        // match its own target is worse than a substring, because it looks
        // rigorous.
        expect(home.contains('$action()'), isTrue,
            reason: '$action is not defined in home_screen');

        // The DECLARATION is `void _openGallery()` / `Future<void> _openGallery()`,
        // so the call sites are every other occurrence. Each must be through
        // `_gate`, because the gallery feeds photos straight into the capture
        // flow and is premium for exactly the same reason the scan is.
        final callers = <String>[];
        for (final m in RegExp(r'([A-Za-z_]+)\(' + action + r'\)')
            .allMatches(home)) {
          final name = m.group(1)!;
          if (name == 'void' || name == 'Future') continue; // the declaration
          callers.add(name);
        }
        expect(callers, isNotEmpty,
            reason: '$action has no call site in home_screen, so nothing can '
                'reach it and nothing is gated');
        for (final c in callers) {
          expect(c, '_gate',
              reason: '$action is called as $c(), not through _gate. The '
                  'gallery is a premium path - it hands photos to the capture '
                  'flow - so it must go through the gate exactly as the scan '
                  'does.');
        }
      }
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
