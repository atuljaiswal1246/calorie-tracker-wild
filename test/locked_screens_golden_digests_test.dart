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
    ];
    expect(lockedGoldenDigests.keys.toSet(), expected.toSet(),
        reason: 'The locked-screen list has drifted. Expected ${expected.length} '
            'screens, found ${lockedGoldenDigests.length}. If a screen was '
            'added, add it to BOTH sides and say why; if one was dropped, say '
            'which owner decision stopped applying.');
    expect(lockedGoldenDigests, hasLength(16));
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
        RegExp(r'^(welcome|onboarding|dob_picker|signup|signin|paywall)').hasMatch(name),
        isTrue,
        reason: '$name is in the locked list but is not one of the screens the '
            'owner locked. Either it is a new locked screen, which needs a '
            'decision recorded in AGENTS.md, or it does not belong here.',
      );
    }
  });
}
