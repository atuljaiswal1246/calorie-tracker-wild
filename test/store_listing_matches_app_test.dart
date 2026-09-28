// The Play Store listing must describe the app we actually ship.
//
// THE DEFECT THIS EXISTS FOR (2026-09-28): PLAY_STORE_LISTING.md advertises a
// "Fasting Tracker" and "Meal Plans".
//   - Fasting has no screen at all. The word "fasting" appears in
//     models/quest.dart (a quest category) and in one sentence in
//     settings_screen.dart. A grep for the word passes; a user tapping the
//     listing's promise finds nothing.
//   - MealPlanScreen is real, finished, 700 lines — and reachable ONLY from
//     discover_screen.dart, which AGENTS.md has documented as dormant and
//     unreferenced since the Firestore rules denied the reads it needed. So the
//     screen exists and the user cannot open it.
// Both survived because nobody compared the listing against the code, and both
// are a Play-submission risk and a 1-star review.
//
// WHY THIS IS NOT A SOURCE SCAN: the temptation is to grep lib/ for the words
// "fasting" and "meal plan", and that grep PASSES on both. The words are there.
// The question is whether a user can get there, so the test runs the real
// reachability walk and reads its exit code.
//
// THE CHECKER MADE TWO FALSE CALLS BEFORE IT GOT HERE, and both are worth
// recording because they are the failure this repo keeps meeting: it first
// demanded a water_screen.dart (water is real, it lives in home_screen), and
// then accepted storage_service.addWeightEntry as proof of weight tracking (that
// is the persistence API; it exists whether or not a user can log a weight).
// A check that reads vocabulary rather than behaviour passes a dead feature —
// so the test below asserts the false-alarm cases too, not just the failure.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tool = 'tools/check_store_listing.py';

void main() {
  int run(String args) {
    final r = Process.runSync('python3', [_tool, ...args.split(' ')]);
    return r.exitCode;
  }

  String output() {
    final r = Process.runSync('python3', [_tool]);
    return '${r.stdout}${r.stderr}';
  }

  test('the checker exists — a rule with no machine is a wish', () {
    expect(File(_tool).existsSync(), isTrue, reason: '$_tool is missing');
  });

  test('it runs, and it fails today — the listing promises two dead features', () {
    final code = run('');
    expect(code, 1,
        reason: 'the checker passed. Either the two defects were fixed (then '
            'this test is obsolete and the claim is gone) or the checker is '
            'not looking at the real path.\n\n${output()}');
  });

  test('it names Meal Plans as DORMANT, not as missing', () {
    // The distinction matters. MealPlanScreen is 700 lines of working code. If
    // the checker said "NOT SHIPPED" it would invite someone to rebuild a
    // screen that already exists; the honest verdict is "real, unreachable".
    final out = output();
    expect(out, contains('Meal Plans'));
    expect(out, contains('DORMANT'));
    expect(out, contains('discover_screen.dart'),
        reason: 'the dormant verdict must name the file that blocks it, so a '
            'reader can check the claim instead of trusting the label');
  });

  test('it names Fasting as not shipped, with the reason it looked shipped', () {
    final out = output();
    expect(out, contains('Fasting'));
    expect(out, contains('NOT SHIPPED'));
    // The trap, named in the output: the word exists in a quest category and a
    // settings sentence, and neither is a screen a user can open.
    expect(out, contains('quest category'),
        reason: 'without this, the next reader greps for "fasting", finds it, '
            'and concludes the feature exists');
  });

  test('it does NOT false-alarm on water or weight tracking', () {
    // Both are real, shipped, and reachable. There is no water_screen.dart and
    // no WeightTrend class, and the first version of the checker failed on both
    // because it looked for filenames instead of behaviour.
    final out = output();
    // Matched loosely on purpose: pinning the exact column padding would make
    // this test fail when a longer feature name is added, which trains us to
    // edit tests to make them pass.
    expect(out, matches(RegExp(r'Water Tracking\s+OK')),
        reason: 'water tracking is real and reachable; a failure here means the '
            'checker went back to looking for a water_screen.dart\n\n$out');
    expect(out, matches(RegExp(r'Weight Tracking\s+OK')),
        reason: 'weight tracking is real and reachable\n\n$out');
    expect(out, isNot(matches(RegExp(r'(Water|Weight) Tracking\s+NOT SHIPPED'))));
  });

  test('it credits water and weight to a SCREEN, never to a service', () {
    // storage_service.addWeightEntry exists whether or not a user can log a
    // weight. A user-facing claim satisfied by the persistence layer is the
    // same category of mistake as a claim satisfied by a quest category name.
    final out = output();
    expect(out, isNot(contains('lib/services/')),
        reason: 'a listing claim was satisfied by a service file:\n$out');
    expect(out, contains('progress_screen.dart uses _weightChart'),
        reason: 'weight tracking should be credited to the chart a user sees');
  });

  test('it prints what it read, so a reader can disagree with it', () {
    final out = output();
    expect(out, contains('reachable dart files read'),
        reason: 'a checker that prints only PASS/FAIL cannot be argued with. '
            'The file count is what makes the walk auditable.');
    expect(out, contains('lib/main.dart'),
        reason: 'the walk must name its entry point');
  });

  test('the dormant blocker is declared, not inferred at runtime', () {
    final src = File(_tool).readAsStringSync();
    expect(src, contains('DORMANT_BY_DESIGN'));
    expect(src, contains('discover_screen.dart'));
    // If a dormant file were ever silently treated as an entry point, every
    // claim behind it would read OK. That is the failure that made "meal plans"
    // look shipped, so the set must be visible in the source.
  });

  test('AGENTS.md still documents discover_screen as dormant, so the two agree', () {
    final agents = File('AGENTS.md').readAsStringSync();
    expect(agents, contains('discover_screen.dart'),
        reason: 'AGENTS.md is where the dormancy is recorded. If the listing '
            'checker and AGENTS.md disagree about what is dormant, one of them '
            'is stale and the next session inherits the wrong one.');
  });

  test('the listing itself is what carries the two bad claims', () {
    // So the failure is attributable: it is the listing's wording, and the fix
    // is either in the listing or in lib/, not in the checker.
    final listing = File('PLAY_STORE_LISTING.md').readAsStringSync();
    expect(listing, contains('Fasting Tracker'));
    expect(listing, contains('Meal Plans'));
  });
}
