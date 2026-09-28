// THE OWNER'S LOCKED SCREENS, AS DIGESTS.
//
// AGENTS.md carries eight "LOCKED - do not change without an explicit new
// request" sections: the welcome screen, onboarding screens 1-6, the sign-up
// screen, the paywall, and the DOB picker that lives inside onboarding screen 2.
// Until now that lock was PROSE. A `--update-goldens` run rewrites every PNG in
// test/goldens/, and committing that looks exactly like a tidy-up - which is
// precisely how a locked screen changes without anyone deciding it should.
//
// So the lock is a set of SHA-256 digests, pinned here. A locked screen that
// changes cannot be committed with a green suite unless the digests are updated
// DELIBERATELY, and this test never updates them itself: a lock that can rewrite
// itself is a lock that can be silenced. The update path is
//
//   CALM_UPDATE_GOLDEN_LOCKS=1 flutter test test/locked_screens_golden_digests_test.dart
//
// which PRINTS the new map to paste into this file. Read the diff it causes, and
// decide whether the owner asked for it.
//
// The one honest caveat, stated here because it will otherwise look like a bug:
// these digests also move when the RENDERER moves - a Flutter upgrade, a font
// change, a Material version bump. So a failure is a question, not a verdict:
// did a locked screen change, or did the thing that draws it change? Answer that
// before pasting anything.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// file name under test/goldens/ -> SHA-256 of the file as it is committed.
const lockedGoldenDigests = <String, String>{
  'welcome_0.png':
      '835a2df059024c86fd3953242445c56d2f1144ba6d728d490b1b2b25ed9693c5',
  'welcome_1.png':
      '1a41d94dd2ff8f270b7651ea1a650f95a2c4580ef3b6b2ee8c6299fcf7adc473',
  'welcome_2.png':
      '13f0bcf82ce82f6028391336a51ebf4f99950012f4f97ac7a72adf0a5ed48989',
  'welcome_3.png':
      'e0d2b8658bb7dc57948e2494864d8dcf76d7066376dce7dc63c860ec49ac6473',
  'onboarding_0.png':
      'c58aa9f2b262a815318d59063b152636539a41a915fcc3dfafeffd50d282888b',
  'onboarding_1.png':
      '57aa5335234d50f285372d677e47dac7fe17391598e01f6e88b89b5948abee40',
  'onboarding_2.png':
      'd9275b734ad2c9dabb839229d711daec6ceba2725903f3c9061498dfc0b85000',
  'onboarding_3.png':
      'cb7b2a879a61e2b55e99faefd1d925a4852439df68758cb28fd71785e3d81296',
  'onboarding_4.png':
      '329d28e7abb89bb5fd03765b194cef349934d80c9e234b961515996667203df5',
  'onboarding_5.png':
      'd25060f751c83dd044b62527f0e3330d8225dd2cf6fb7b21f25b83c2d45ac767',
  'onboarding_6.png':
      '20a05d508fa5625c5df33d0d3c1f5b503dc3cdb66d1858075f0d085e3ee72302',
  'dob_picker.png':
      'ab95e2c782255b635d4eb827afb7128eaa5d6d2992d8bbc0636f9c433cc6b91c',
  'signup.png':
      'afe513bd423656826643242c6c5a4bd530aa1f9b822cfe1258acb96086348ffb',
  'signin.png':
      '07be6abd2b0b5c3a99237b6546df63ff5804f97d773a932b1d6a36d33b51455a',
  'paywall.png':
      '430ca6b51c3e09a10f958ab062fc581e7a963790aadf0fb51cce954071397e17',
  'paywall_android.png':
      '75b89dda6ae4a198de347bff6c6d1a7fc52a6a5d2489aa5bbe33e530163809e9',
  'demo_scan_result.png':
      '3ca8ab25489e03c5992a6dce4f18a74462e8ae99e60cf9c8eae4e8aa4e94cb6c',
  'demo_scan_scanning.png':
      '3ca8ab25489e03c5992a6dce4f18a74462e8ae99e60cf9c8eae4e8aa4e94cb6c',
  'demo_search.png':
      'b862477e6f09a7f8246db4dd1f6058e92571464c4748c00792d527b03000f91a',
  'demo_exercise.png':
      '4caeeacb9955a557d21d0285998b2b9c9e48e2c658149d7781e21c9739f00cbc',
  'demo_water.png':
      '1848f9e88a088b49c41850c1205b947659eb53416f3eb817b53e260927fd80e7',
};

final _updating = Platform.environment['CALM_UPDATE_GOLDEN_LOCKS'] == '1';

String _digest(String name) =>
    sha256.convert(File('test/goldens/$name').readAsBytesSync()).toString();

void main() {
  test('the lock covers every screen the owner locked', () {
    // Named explicitly rather than derived, so that forgetting one is a visible
    // omission and not a pattern that quietly stops matching.
    final expected = <String>[
      ...[for (var i = 0; i < 4; i++) 'welcome_$i.png'],
      ...[for (var i = 0; i < 7; i++) 'onboarding_$i.png'],
      'dob_picker.png',
      'signup.png',
      'signin.png',
      'paywall.png',
      'paywall_android.png',
      // The four Try-before-you-buy demos are locked WITH the first screen
      // (AGENTS.md: "## Try-before-you-buy demos (locked with the first screen)"),
      // and I left all five of their goldens out when I built this lock an hour
      // after the owner had signed them off. An incomplete lock presented as a
      // complete one is worse than no lock, because it reads as done. The
      // scan_scanning state is pinned too - it is an animation a user sees, and
      // being over-inclusive on a lock is the safe direction.
      'demo_scan_result.png',
      'demo_scan_scanning.png',
      'demo_search.png',
      'demo_exercise.png',
      'demo_water.png',
    ];
    expect(lockedGoldenDigests.keys.toSet(), expected.toSet(),
        reason: 'The locked-screen list has drifted. Expected ${expected.length} '
            'screens, found ${lockedGoldenDigests.length}. If a screen was '
            'added, add it to BOTH sides and say why; if one was dropped, say '
            'which owner decision stopped applying.');
    expect(lockedGoldenDigests, hasLength(21));
  });

  test('every locked golden is byte-for-byte what the owner approved', () {
    if (_updating) {
      stdout.writeln('\n=== PASTE THIS INTO lockedGoldenDigests ===');
      for (final name in lockedGoldenDigests.keys) {
        stdout.writeln("  '$name':\n      '${_digest(name)}',");
      }
      stdout.writeln('=== END ===\n');
    }
    final changed = <String>[];
    final missing = <String>[];
    for (final name in lockedGoldenDigests.keys) {
      final f = File('test/goldens/$name');
      if (!f.existsSync()) {
        missing.add(name);
        continue;
      }
      final actual = _digest(name);
      if (actual != lockedGoldenDigests[name]) {
        changed.add('$name\n      was ${lockedGoldenDigests[name]}\n'
            '      now $actual');
      }
    }
    expect(missing, isEmpty,
        reason: 'A locked golden is gone: ${missing.join(', ')}. Deleting one is '
            'a change to a locked screen too.');
    expect(changed, isEmpty,
        reason: 'A LOCKED SCREEN CHANGED, or the renderer did:\n\n'
            '${changed.join('\n')}\n\n'
            'Before you touch this file: did the owner ask for this? If yes, '
            'say so in the commit. If no, revert the golden. If the Flutter '
            'version or a font moved, say THAT in the commit instead - a lock '
            'that cannot distinguish the two is not a lock.\n'
            'New digests: CALM_UPDATE_GOLDEN_LOCKS=1 flutter test '
            'test/locked_screens_golden_digests_test.dart');
  });

  test('a golden outside the lock cannot be used to smuggle one inside', () {
    // Someone could rename a modified PNG to dodge the digest list. The lock is
    // only as good as the claim that these are the right files, so the count is
    // pinned and the naming is checked against the screens AGENTS.md locks.
    for (final name in lockedGoldenDigests.keys) {
      expect(
        RegExp(r'^(welcome|onboarding|dob_picker|signup|signin|paywall|demo)').hasMatch(name),
        isTrue,
        reason: '$name is in the locked list but is not one of the screens the '
            'owner locked. Either it is a new locked screen, which needs a '
            'decision recorded in AGENTS.md, or it does not belong here.',
      );
    }
  });

  test('every section AGENTS.md calls LOCKED is covered by this lock', () {
    // The omission risk, joined shut. This digest list is the ONE place a locked
    // screen can be forgotten, and I proved it by building the lock an hour after
    // the owner signed off the demos and leaving all five of their goldens out -
    // so the lock was incomplete while looking complete.
    //
    // So AGENTS.md is the source of truth for WHAT is locked, and every such
    // section must be joined to goldens that are in the digest map. Marking a new
    // screen LOCKED without pinning its golden fails here, with the section named.
    const sectionToGoldens = <String, List<String>>{
      'First screen (locked 2026-09-15': [
        'welcome_0.png', 'welcome_1.png', 'welcome_2.png', 'welcome_3.png'],
      'Try-before-you-buy demos (locked with the first screen)': [
        'demo_scan_result.png', 'demo_scan_scanning.png', 'demo_search.png',
        'demo_exercise.png', 'demo_water.png'],
      'Onboarding screen 1 (Goal)': ['onboarding_0.png'],
      'Onboarding screen 2 (You /': ['onboarding_1.png', 'dob_picker.png'],
      'Onboarding screen 3 (Height & weight)': ['onboarding_2.png'],
      'Onboarding screen 4 (Activity)': ['onboarding_3.png'],
      'Onboarding screen 5 (Target & pace)': ['onboarding_4.png'],
      'Onboarding screen 6 (Plan ready)': ['onboarding_5.png'],
      'Payment screen (paywall)': ['paywall.png', 'paywall_android.png'],
      'Sign-up screen': ['signup.png', 'signin.png'],
    };

    final agents = File('AGENTS.md').readAsStringSync();
    // Headings that lock a SCREEN. AGENTS.md also uses "locked" for rules and for
    // memory (standing orders, the one-thing lock), and for the exact opposite
    // claim - "the eyes for NON-locked screens". The filter has to be precise or it
    // invents screens that do not exist: my first version also required the word
    // "paywall", which matched "Sign in with Apple - blocked by Apple's paywall", a
    // section that locks nothing. Both false positives were caught by this very
    // test, which is the only reason I trust it now.
    final lockedWord = RegExp(r'(?<!non-)\blocked\b', caseSensitive: false);
    final screenSections = <String>[];
    for (final line in agents.split('\n')) {
      if (!line.startsWith('## ')) continue;
      final low = line.toLowerCase();
      if (lockedWord.hasMatch(line) &&
          (low.contains('screen') || low.contains('demo'))) {
        screenSections.add(line);
      }
    }
    expect(screenSections, isNotEmpty,
        reason: 'No locked screen sections found in AGENTS.md. The join below '
            'cannot work, and the lock has become a list of files with no '
            'decision behind it.');

    final unmatched = <String>[];
    for (final section in screenSections) {
      if (!sectionToGoldens.entries.any((e) => section.contains(e.key))) {
        unmatched.add(section);
      }
    }
    expect(unmatched, isEmpty,
        reason: 'AGENTS.md locks a screen that this lock does not cover:\n'
            '${unmatched.join('\n')}\nAdd its goldens to sectionToGoldens AND '
            'to lockedGoldenDigests, or delete the claim from AGENTS.md. A lock '
            'nobody joins to a decision is a filing cabinet.');

    // And the join must point at files that are actually pinned - which is exactly
    // the half that let the demos go missing.
    final missingFromLock = <String>[];
    for (final entry in sectionToGoldens.entries) {
      for (final name in entry.value) {
        if (!lockedGoldenDigests.containsKey(name)) {
          missingFromLock.add('${entry.key} -> $name');
        }
      }
    }
    expect(missingFromLock, isEmpty,
        reason: 'These goldens are joined to an owner decision but are NOT in the '
            'digest lock, which is how the demos went missing:\n'
            '${missingFromLock.join('\n')}');
  });
}
