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
}
