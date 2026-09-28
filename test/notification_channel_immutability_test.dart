// Changing a notification's sound on an existing channel id does nothing.
//
// THE TRAP, recorded in AGENTS.md as a mechanic and never enforced:
//   "Android notification channels are IMMUTABLE. The current channel is
//    `reminders`; changing its sound requires a NEW channel id, or existing
//    installs keep the system default. Do it with the sound change, in one go."
//
// So the failure is: someone swaps the .wav, the code is unchanged, CI is green,
// the APK is correct, and every user who already installed the app keeps the
// OLD sound forever. Nothing errors. Nothing looks wrong. The new sound ships to
// new users only, and the two populations disagree permanently.
//
// A golden test cannot see it, because both versions render. A unit test cannot
// see it, because both are valid channel definitions. The only thing that can
// see it is HISTORY: has the sound file CHANGED since the channel id that plays
// it was introduced? If yes and the id did not move, the immutability rule has
// been broken and every existing install is silently stale.
//
// That is what this test asks git, and it is the only check in the repo that
// follows that path.
//
// The second job: there are TWO files called cal_notify.wav -
// android/app/src/main/res/raw/ (what the channel plays) and assets/sounds/
// (what in-app feedback uses). They are two different consumers of one name, and
// nothing records that. A person editing "the notify sound" has a 50% chance of
// editing the one the notification does not use, and will hear no difference in
// the app and no difference on the lock screen.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _service = 'lib/services/notification_service.dart';

void main() {
  late String src;
  late List<({String channel, String sound})> channels;

  /// Every (channel id, sound resource) pair the app declares.
  ///
  /// TWO parsing mistakes happened here and both are recorded, because both
  /// produced a VACUOUS guard - the failure mode this repo keeps paying for.
  ///
  /// 1. No DOTALL. `AndroidNotificationDetails(` opens a block that spans seven
  ///    lines, `.` does not match a newline, so the parser matched nothing and
  ///    three downstream tests passed on an empty list. A vacuous guard looks
  ///    exactly like a working one.
  /// 2. The terminator. `\(.*?\)\s*,` stops at the FIRST `)` followed by a comma
  ///    - which is the closing paren of
  ///    `RawResourceAndroidNotificationSound('cal_notify'),` - so the captured
  ///    block ended one character before the sound call was complete and every
  ///    sound parsed as absent. Four channels, four times, all "no sound".
  ///
  /// So the block is closed on its OWN line, which is how it is written, and the
  /// sound pattern is allowed to be complete inside the capture.
  List<({String channel, String sound})> readChannels(String source) {
    final out = <({String channel, String sound})>[];
    for (final block
        in RegExp(r'AndroidNotificationDetails\((.*?)\n\s*\)', dotAll: true)
            .allMatches(source)) {
      final b = block.group(1)!;
      final id = RegExp(r"'([a-z0-9_]+)'").firstMatch(b)?.group(1);
      if (id == null) continue;
      final snd = RegExp(r"RawResourceAndroidNotificationSound\('([^']+)'\)")
          .firstMatch(b)
          ?.group(1);
      out.add((channel: id, sound: snd ?? ''));
    }
    return out;
  }

  setUpAll(() {
    expect(File(_service).existsSync(), isTrue);
    src = File(_service).readAsStringSync();
    channels = readChannels(src);
  });

  test('the service declares at least one Android channel with a sound', () {
    expect(channels, isNotEmpty,
        reason: 'no AndroidNotificationDetails block was parsed. If the call '
            'shape changed, this test must be taught the new shape - silently '
            'finding nothing is how a guard becomes a comment.');
    expect(channels.any((c) => c.sound.isNotEmpty), isTrue,
        reason: 'every channel has no sound, which is either a real regression '
            'or a parse that stopped matching.');
  });

  test('every sound a channel names exists in res/raw', () {
    for (final c in channels.where((c) => c.sound.isNotEmpty)) {
      expect(
          File('android/app/src/main/res/raw/${c.sound}.wav').existsSync(),
          isTrue,
          reason: 'channel "${c.channel}" plays "${c.sound}" and there is no '
              'android/app/src/main/res/raw/${c.sound}.wav. Android silently '
              'falls back to the default sound, so the user hears something '
              'different from what the code says.');
    }
  });

  test('NO CHANNEL ID PLAYS A SOUND THAT CHANGED AFTER THE ID WAS BORN', () {
    // The immutability rule, enforced against git rather than against intent.
    for (final c in channels.where((c) => c.sound.isNotEmpty)) {
      final wav = 'android/app/src/main/res/raw/${c.sound}.wav';
      if (!File(wav).existsSync()) continue; // the previous test names it

      // When was this channel id first introduced?
      final born = Process.runSync(
          'git', ['log', '--reverse', '--format=%H', '-S', c.channel, '--', _service],
          workingDirectory: '.');
      final commits = '${born.stdout}'.trim().split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      expect(commits, isNotEmpty,
          reason: 'channel id "${c.channel}" has no history in $_service, so '
              'this test cannot tell when it was born. That is itself the '
              'finding: an untraceable channel id cannot be versioned.');

      final first = commits.first;
      // The sound file's BLOB HASH at that commit, and now. Compared as hashes,
      // not bytes: `git show` of a .wav writes binary to stdout, which leaves
      // ProcessResult.exitCode null and is a silent way to get no answer.
      final then = Process.runSync(
          'git', ['rev-parse', '$first:$wav'], workingDirectory: '.');
      final now = Process.runSync(
          'git', ['hash-object', wav], workingDirectory: '.');
      expect('${then.stdout}'.trim(), isNotEmpty,
          reason: 'the sound file did not exist at $first, so "${c.channel}" '
              'either predates the sound or names the wrong file.');
      expect('${now.stdout}'.trim(), isNotEmpty,
          reason: 'git hash-object produced nothing for $wav - the comparison '
              'below would then be a guess.');
      final same = '${then.stdout}'.trim() == '${now.stdout}'.trim();
      expect(
          same,
          isTrue,
          reason: 'IMMUTABILITY BROKEN. Channel "${c.channel}" has existed '
              'since ${first.substring(0, 7)} and plays "${c.sound}.wav", but '
              'that file has CHANGED since (blob ${then.stdout.toString().trim().substring(0, 8)} '
              '-> ${now.stdout.toString().trim().substring(0, 8)}). Android does '
              'not update the sound of an existing channel: every install that '
              'already has this channel keeps the OLD sound, permanently, with '
              'no error. New users get the new one.\n'
              'The fix is the pair, in one commit: change the sound AND give '
              'the channel a NEW id. Users who have the old channel keep the '
              'old one, which is the intended behaviour, not a bug to chase.');
    }
  });

  test('the two cal_notify.wav files are two consumers, and that is recorded',
      () {
    // android/app/src/main/res/raw/cal_notify.wav  -> the notification channel
    // assets/sounds/cal_notify.wav                  -> in-app feedback
    //
    // Same name, two consumers, one of which the channel depends on. This test
    // exists so that the pair is a decision on the record rather than a
    // coincidence. If the in-app one is ever deleted, this names the file the
    // channel actually needs, so nobody "tidies" the wrong one.
    final res = File('android/app/src/main/res/raw/cal_notify.wav');
    final asset = File('assets/sounds/cal_notify.wav');
    expect(res.existsSync(), isTrue,
        reason: 'the notification channel sound is missing from res/raw');
    expect(asset.existsSync(), isTrue,
        reason: 'the in-app sound is missing from assets/sounds. If it was '
            'deliberately dropped, say so here; do not let it look like the '
            'channel sound was removed.');
  });
}
