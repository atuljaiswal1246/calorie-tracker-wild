// The thing we would SHIP is not the thing we have WRITTEN.
//
// WHY THIS FILE EXISTS. Measured on 2026-09-29 and re-measured since, unchanged:
//
//   app-release.apk on disk  built 2026-09-22 22:52
//   pubspec version now      0.9.10+15
//   version last bumped      2026-09-23 09:54   <- ELEVEN HOURS AFTER the build
//   commits since the build  129, of which 8 touch lib/
//
// So every device test since the 22nd ran against older code, and one of the
// eight missing `lib/` commits is a trial-gate fix: the home-screen widget handed
// a trial-ended user the paid AI scan in one tap. That is a defect a customer
// would meet and a monetization hole, and it is in the artefact rather than in
// the tree, which is the only place it can hide.
//
// I have reported that in report after report. That is precisely what this file
// exists to stop: A FINDING I DESCRIBE EVERY TWENTY MINUTES IS A COMMENT. So
// `tools/check_release_is_the_tree.py` is now a ROW in the claim runner, it fails,
// and it NAMES the eight missing commits instead of leaving them to my prose.
//
// WHY IT IS A GUARD AND NOT A NOTE. Learned from outside on 2026-09-29, in the
// sharpest available form: a guard was GREEN in another company while the product
// was still looping, because the guard read the TREE and the running processes
// predated the fix by more than an hour. A GUARD ON A FILE PROVES THE FILE. IT
// DOES NOT PROVE THE THING THAT WILL ACTUALLY RUN. This repo has no long-running
// process serving anyone - the claim runner spawns fresh subprocesses per run, so
// it cannot have that gap - but the ARTEFACT is the same shape: a thing handed to a
// customer, built at a moment, with nothing comparing that moment to the tree.
//
// IT WILL BE RED AND THAT IS CORRECT. The red clears the moment someone rebuilds
// from this tree, which is the owner's call and not a code change. A guard that
// can only be made green by pretending is worse than one that cannot.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tool = 'tools/check_release_is_the_tree.py';

void main() {
  test('names the product commits a stale artefact is missing', () {
    final r = Process.runSync('python3', [_tool]);
    final out = '${r.stdout}';

    expect(r.exitCode, 1,
        reason: 'the release APK is behind the tree, so this MUST fail. If it '
            'ever passes without a rebuild, the guard has stopped looking at '
            'what it was written for:\n$out');
    expect(out.toLowerCase(), contains('stale'),
        reason: 'the verdict has to be in the TEXT, not only the exit code - an '
            'exit code nobody reads is the pin wearing a number:\n$out');
    expect(out.toLowerCase(), contains('not in this artefact'),
        reason: 'naming the missing commits is the whole point. A red that says '
            'only "stale" is a note:\n$out');
    expect(out, contains('trial-ended user'),
        reason: 'the trial-gate monetization fix is one of the missing commits '
            'and it must be visible in this output, by name, every run:\n$out');
  });

  test('says when a product change is NOT the reason for a red', () {
    // This is the discrimination the whole night was about, in one line: a
    // tools/ or test/ commit does not make an APK stale, and a guard that fired
    // on those would be crying wolf - which is how a guard gets switched off.
    final out = '${Process.runSync('python3', [_tool]).stdout}';
    for (final noise in ['a_skip_is_not_a_pass_test.dart',
        'check_commit_claims.py', 'claim-history']) {
      expect(out, isNot(contains(noise)),
          reason: 'a change that cannot ship in an APK is not a reason the '
              'artefact is stale, and naming it here would make this check '
              'unreliable: $noise');
    }
  });

  test('refuses to pass when there is nothing to check', () {
    final d = Directory.systemTemp.createTempSync('no_release_tree_');
    addTearDown(() => d.deleteSync(recursive: true));
    Directory('${d.path}/tools').createSync();
    File(_tool).copySync('${d.path}/tools/check_release_is_the_tree.py');
    final r = Process.runSync(
        'python3', ['${d.path}/tools/check_release_is_the_tree.py'],
        workingDirectory: d.path);
    expect(r.exitCode, isNot(0),
        reason: 'outside a git tree nothing was checked, and reading nothing is '
            'not a pass:\n${r.stdout}${r.stderr}');
  });

  test('it is a ROW in the claim runner, or it is just a file somebody wrote', () {
    final src = File('tools/check_all_claims.py').readAsStringSync();
    expect(src, contains('_script("tools/check_release_is_the_tree.py")'),
        reason: 'this has to run with everything else, or it becomes the same '
            'comment it was written to replace.');
  });

  test('a DIRECTION is never printed so that it can be quoted as a value', () {
    // I wrote "129 commits behind" into every report between 02:45 and 05:0x.
    // It is 140 now, because I landed 11 commits in the interval - including the
    // ones fixing the very thing the number measured. So the number changed while
    // I was describing it, which is the definition of a direction and not a
    // value, and a wrong number is ACTIONABLE: it sends a role after something
    // that is not there.
    //
    // The count is still printed - it is true and useful. What is pinned here is
    // the LABEL, because the failure is reading it, not computing it.
    final out = '${Process.runSync('python3', [_tool]).stdout}';
    expect(out, contains('DIRECTION'),
        reason: 'the total-commit count grows every time anyone commits. It has '
            'to say so where it is printed, not only in a docstring nobody opens '
            'before quoting the figure:\n$out');
    expect(out, contains('a VALUE'),
        reason: 'and the stable count - the one that moves only when product '
            'code moves - has to be marked as the value, so the two cannot be '
            'confused by whoever reads this at 6am:\n$out');
  });

  test('the direction and the value are different numbers, and that is the point',
      () {
    // Prove the discrimination on the real instance rather than asserting it in
    // prose: the two counts must differ, because tools/ and test/ commits landed
    // tonight and none of them can ship inside an APK.
    final r = Process.runSync('python3', [_tool, '--json']);
    final d = jsonDecode('${r.stdout}') as Map<String, dynamic>;
    final a = (d['artefacts'] as List).first as Map<String, dynamic>;
    final value = (a['behind_product_commits'] as List).length;
    final direction = a['commits_since_built_total'] as int;
    expect(direction, greaterThan(value),
        reason: 'the total is larger than the product-only count precisely '
            'because commits that cannot ship were also counted. If these ever '
            'matched, one of them has stopped being the thing I think it is.');
  });
}
