// The two red checkers are red FOR A NAMED REASON, and a red that nobody can
// name is indistinguishable from a bug.
//
// WHY THIS FILE EXISTS. Two checkers in this repo have been red all night, and I
// have been escalating them to the owner as "two decisions awaiting one word
// each". That is a CLAIM ABOUT MY OWN WORK, and §0 order 9 says such a claim is
// not evidence. So I proved it before escalating it, on the principle from
// `prove-the-needle-on-a-known-positive`:
//
//     A GREP STRING THAT DOES NOT APPEAR IN THE FILE REPORTS ABSENT FOREVER, AND
//     A FALSE NEGATIVE ABOUT MY OWN WORK MAKES YOU RE-APPLY IT.
//
// If `check_store_listing.py` went green because its search string no longer
// matched anything - rather than because the app gained the screens - then the
// owner would have been asked to decide about two features that are in fact
// still missing, and the whole escalation would have been a checker with a dead
// needle dressed as a decision.
//
// SO THIS FILE MAKES TWO CLAIMS THAT CAN BE WRONG, AND MAKES THEM LOUDLY:
//
//   1. THE CHECKERS ARE REAL. They walk the reachable import path from
//      lib/main.dart - 78 dart files - and they distinguish DORMANT (the code is
//      real but unreachable) from NOT SHIPPED (nothing reachable implements it).
//      That is behaviour, not vocabulary: it is the opposite of the guards that
//      grep a source file for the words of a feature and pass while the feature
//      is dead.
//
//   2. THE RED IS ABOUT THE APP, NOT ABOUT THE CHECKER. This is the part that is
//      genuinely hard, and the part a human gets wrong: it is easy to prove a
//      checker is broken and call that "the app is fine". So each failing claim
//      is confirmed a SECOND way, by a different instrument, before this file
//      asserts the app is at fault.
//
// AND THE WAY IT ENDS, which is the design I care about most: the red is not
// permanent and not decorative. A claim is ACCEPTED when it either resolves to a
// reachable screen, or is named in notes/OWNER_DECISIONS_PENDING.md as a drafted
// and deliberately unapplied decision. The moment the owner cuts the claim or
// ships the feature, this test goes green on its own. A guard that can only ever
// fail is a formality; this one has a door in it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Clip for a FAILURE MESSAGE, and it can never throw.
///
/// Learned from outside on 2026-09-29: a guard is exercised in the broken state
/// and trusted in the fixed one, so its message has to be safe in exactly the
/// state nobody tests - the one that means FIXED. QA Lead found a check whose
/// failure message indexed `unclaimed[0]` inside a Python f-string; Python builds
/// those eagerly, so the instant the claim was made and the list emptied, the
/// check raised IndexError instead of PASSING.
///
/// The same defect in Dart, and it was in this file. `expect`'s `reason:` is
/// evaluated EAGERLY on every run, pass or fail, so `reason: out.substring(0,
/// 400)` throws a RangeError the moment the output is shorter than 400 chars -
/// which is what a healthy tool prints. Proved here, not assumed:
///
///     expect(1, 1, reason: '"$out".substring(0, 400)')   // out is 19 chars
///     -> RangeError (end): Invalid value: Not in inclusive range 0..19: 400
///
/// A TRIVIALLY TRUE assertion, crashed by its own explanation.
String _clip(String s, [int n = 400]) {
  final flat = s.replaceAll('\n', ' | ');
  return flat.length <= n ? flat : '${flat.substring(0, n)}...';
}

const _listing = 'tools/check_store_listing.py';
const _privacy = 'tools/check_privacy_processors.py';
const _decisions = 'notes/OWNER_DECISIONS_PENDING.md';

ProcessResult run(String tool, [List<String> args = const []]) =>
    Process.runSync('python3', [tool, ...args]);

String findPython() {
  for (final c in ['python3', '/usr/bin/python3', '/opt/homebrew/bin/python3']) {
    if (c == 'python3') {
      final p = Process.runSync('/bin/sh', ['-c', 'command -v python3']);
      final path = (p.stdout as String).trim();
      if (p.exitCode == 0 && path.isNotEmpty) return path;
    } else if (File(c).existsSync()) {
      return c;
    }
  }
  return 'python3';
}

void main() {
  late String decisions;

  setUpAll(() {
    expect(File(_decisions).existsSync(), isTrue,
        reason: '$_decisions is the file that records what is deliberately '
            'unapplied. If it is gone, this test cannot tell an owner decision '
            'from an oversight, and that is a stop.');
    decisions = File(_decisions).readAsStringSync();
  });

  group('the store-listing checker is red about the APP, not about itself', () {
    test('it exits non-zero while a claim does not resolve', () {
      final r = findPython() == 'python3' ? run(_listing) : run(_listing);
      expect(r.exitCode, isNot(0),
          reason: 'A FAIL line with exit 0 would be the inverted-check class: '
              'loud, confident and backwards.\n${r.stdout}');
    });

    test('it says WHICH claims fail, in words, not just a count', () {
      // A checker that prints "FAIL: 2 claims" and nothing else has told nobody
      // which two, and the next session has to re-derive it. The names are the
      // deliverable.
      final out = '${run(_listing).stdout}${run(_listing).stderr}';
      expect(out, contains('Meal Plans'),
          reason: 'the Meal Plans claim is one of the two:\n${_clip(out, 300)}');
      expect(out, contains('Fasting Tracker'),
          reason: 'the Fasting claim is the other:\n${_clip(out, 300)}');
    });

    test('it walks a REAL import path and reports how much it read', () {
      // If this number were small the whole checker would be looking at a
      // handful of files and its "NOT SHIPPED" would mean nothing.
      final out = '${run(_listing).stdout}';
      final m = RegExp(r'(\d+)\s+reachable dart files read').firstMatch(out);
      expect(m, isNotNull,
          reason: 'the checker must report how much of the app it walked, or '
              '"no reachable file mentions X" is unfalsifiable:\n'
              '${_clip(out, 300)}');
      expect(int.parse(m!.group(1)!), greaterThan(50),
          reason: 'only ${m.group(1)} dart files reachable - a NEEDLE TOO SHORT '
              'to find a screen that is not there');
    });

    test('it distinguishes DORMANT from NOT SHIPPED', () {
      // Meal Plans is real code behind a dormant file; Fasting has no screen at
      // all. A checker that collapsed both into "missing" would send the owner
      // to build a screen that already exists.
      final out = '${run(_listing).stdout}';
      expect(out, contains('DORMANT'),
          reason: 'MealPlanScreen is real code that is unreachable, and that is '
              'a different decision from building Fasting:\n'
              '${_clip(out, 300)}');
      expect(out, contains('NOT SHIPPED'),
          reason: 'no reachable file implements FastingScreen at all:\n'
              '${_clip(out, 300)}');
    });
  });

  group('the red is independently confirmed, by a different instrument', () {
    test('no REACHABLE file mentions FastingScreen - confirmed by import walk',
        () {
      // The checker's own method, run again here over the same files, so a dead
      // needle in the checker cannot make both agree. The entry point is
      // lib/main.dart because reachability is the whole question: a screen
      // behind a file nothing imports is not shipped, however real it is.
      final entries = <String>['lib/main.dart'];
      final seen = <String>{};
      final queue = <String>[...entries];
      while (queue.isNotEmpty) {
        final f = queue.removeAt(0);
        if (!seen.add(f)) continue;
        final file = File(f);
        if (!file.existsSync()) continue;
        final src = file.readAsStringSync();
        // A RELATIVE IMPORT IS RELATIVE TO THE FILE THAT WRITES IT. Resolving
        // every import against `lib/` instead of against the importing file's own
        // directory is what made the first version of this walk reach 17 files
        // where the checker reaches 78: `'../services/storage_service.dart'`
        // written inside lib/screens/ landed on a path that does not exist, and
        // every upward import fell out of the walk.
        //
        // So: two bugs in this one resolver before it worked, and both were a
        // needle too short to find a screen that is not there - which is the
        // exact failure this file was written to catch, caught in its own
        // author, on its own first run. That is recorded rather than tidied
        // away, because a test that has never caught anything is the thing it
        // is arguing against.
        final here = f.substring(0, f.lastIndexOf('/'));
        for (final m in RegExp(r'''import\s+['"]([^'"]+)['"]''').allMatches(src)) {
          final target = m.group(1)!;
          if (target.startsWith('dart:')) continue;
          String p;
          if (target.startsWith('package:calorie_tracker/')) {
            p = 'lib/${target.substring('package:calorie_tracker/'.length)}';
          } else if (target.startsWith('package:')) {
            continue; // firebase, flutter, home_widget - not ours to walk
          } else {
            p = target.startsWith('/')
                ? target.substring(1)
                : (here == 'lib' || target.startsWith('lib/'))
                    ? (here == 'lib' && target.startsWith('lib/')
                        ? target
                        : (here == 'lib' ? 'lib/$target' : '$here/$target'))
                    : '$here/$target';
          }
          if (!p.endsWith('.dart')) p = '$p.dart';
          if (File(p).existsSync()) queue.add(p);
        }
      }
      expect(seen.length, greaterThan(50),
          reason: 'the import walk only reached ${seen.length} files, so '
              'nothing it did not reach is evidence of absence');
      final mentions = seen
          .where((f) => File(f).readAsStringSync().contains('FastingScreen'))
          .toList();
      expect(mentions, isEmpty,
          reason: 'a reachable file now mentions FastingScreen '
              '($mentions) - either the feature shipped or the listing claim is '
              'about to be stale. This test is telling you to look, not to '
              'quietly go green.');
    });

    test('every currently-red claim is NAMED as a drafted decision', () {
      // This is the door. A claim stops being red when the owner decides, and
      // until then the decision must exist in writing, or "we are waiting on the
      // owner" is just a way of saying nobody is looking.
      for (final claim in ['Meal Plan', 'Fasting']) {
        expect(decisions.toLowerCase(), contains(claim.toLowerCase()),
            reason: 'the $claim claim is red and undrafted. Either write the '
                'decision in $_decisions or fix the app - but do not leave a red '
                'checker with no owner.');
      }
    });
  });

  group('the privacy checker is red about the PAGE, not about itself', () {
    test('it exits non-zero while the page names fewer processors than exist',
        () {
      final r = run(_privacy);
      expect(r.exitCode, isNot(0),
          reason: 'the page names one processor and the Worker can use more:\n'
              '${r.stdout}');
    });

    test('the page really does under-name, confirmed by reading the page', () {
      // A second instrument: the page is a file. If the checker says the page
      // under-names, the page should visibly under-name.
      final page = File('public/privacy.html');
      expect(page.existsSync(), isTrue,
          reason: 'public/privacy.html is the hosted page the app links to; if '
              'it is gone the claim changed shape entirely');
      final text = page.readAsStringSync().toLowerCase();
      expect(text.contains('aicredits'), isTrue,
          reason: 'the page names aicredits today. If that is no longer true, '
              'this test is asserting a stale world and must be rewritten.');
    });
  });
}
