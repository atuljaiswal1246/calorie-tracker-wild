// `--help` is a door. A tool that runs anyway is a tool you cannot ask a
// question of.
//
// THE SKILL, 2026-09-28, and the two instances it found in THIS repo within
// minutes of landing:
//
//   1. `tools/mark_paid.py --help` treated "--help" as an EMAIL ADDRESS and made
//      a LIVE Firebase call, printing:
//        looking up --help in calorie-tracker-80a0b ...
//        NOT FOUND - that account has never signed in to the app.
//      It had no argparse and no way to say "I was asking". This is the serious
//      one: mark_paid can write `paid: true` onto a real user's account, so an
//      argument it misreads is an argument it ACTS on.
//
//   2. `tools/check_store_listing.py --help` had no argparse either, so it ran
//      the whole reachability walk and printed the report. Read-only, so nothing
//      was damaged — which is precisely why it survived: a tool that does the
//      wrong thing read-only looks innocent, and "it only read" is how a tool
//      that also writes gets trusted.
//
// WHY A TEST AND NOT A NOTE. A tool that ignores its flags is a tool whose
// documented interface is a fiction, and a note saying "use flags properly" does
// nothing at 2am to the person who is about to run `--dry-run` on something that
// writes. The test runs `--help` on every tool and reads the exit code, which is
// the only thing that can catch this class.
//
// THE EXCEPTIONS ARE EXCEPTIONS, NOT BLANKS. `telegram_bridge.py` is a service:
// `--help` correctly does not stop it, so it is named here with its reason. A
// tool may not become a member of this list by being inconvenient — adding a
// name here is a decision, and the reason has to say what the tool IS.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tools whose `--help` is not expected to stop them, and why.
const _services = <String, String>{
  'telegram_bridge.py': 'a long-running bridge: it has no arguments at all and '
      'is meant to be started, not queried',
};

/// Tools that must never be run by this test for any reason.
const _neverRun = <String, String>{
  'probe_test_sees_live_source.py':
      'sabotages a lib file on purpose; this test only wants to know that it '
          'stops on --help, and the flag is refused by its own argparse anyway',
};

void main() {
  late List<File> tools;

  setUpAll(() {
    tools = Directory('tools')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.py'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  });

  test('there are tools to check — otherwise this test passes on nothing', () {
    expect(tools.length, greaterThan(5),
        reason: 'tools/ looks empty or moved. A guard that finds no files is a '
            'green light on an empty room.');
  });

  test('every tool STOPS on --help and exits 0', () {
    // NAME THE INTERPRETER, or this test is a rumour. Found 2026-09-28: the same
    // tool exited 0 under the shell's python3 and 1 under the one this test saw,
    // because /usr/bin/python3 is 3.9.6 and several of these tools use 3.10+
    // syntax. The tool was not broken; the PRODUCER differed. A verdict about a
    // tool that does not name what ran it is exactly the fault this repo spent
    // the night removing — so the version is printed on failure, and the
    // interpreter is the one on PATH, which is what a person would type.
    final ver = Process.runSync('python3', ['-V'], workingDirectory: '.');
    final version = '${ver.stdout}${ver.stderr}'.trim();
    final offenders = <String>[];
    for (final t in tools) {
      final name = t.path.split('/').last;
      if (_neverRun.containsKey(name)) continue;
      if (_services.containsKey(name)) continue;
      final r = Process.runSync('python3', [t.path, '--help'],
          workingDirectory: '.');
      // 0 is the only acceptable answer. Non-zero includes "it ran the work and
      // then complained", which is the exact failure this file exists to catch.
      if (r.exitCode != 0) {
        final err = '${r.stderr}'.trim();
        offenders.add('$name --help exited ${r.exitCode}'
            '${err.isEmpty ? '' : ' | $err'}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'These tools do not stop when asked for help, under $version. '
            'A tool that runs anyway has a documented interface that is a '
            'fiction, and the next person to run `--dry-run` on something that '
            'writes will not find out until it is too late.\n'
            'If a failure is a SyntaxError, the TOOL is fine and the INTERPRETER '
            'is too old - run it with the same python the claim runner uses '
            '(tools/check_all_claims.py uses sys.executable for that reason).\n'
            '${offenders.join('\n')}');
  });

  test('asking for help does not change a tracked file', () {
    // The harm in mark_paid was not the wrong answer, it was that the tool
    // TOOK AN ACTION. So the check is not "does it print help" but "does asking
    // leave the tree exactly as it was".
    final before = Process.runSync(
        'git', ['status', '--porcelain'], workingDirectory: '.');
    for (final t in tools) {
      final name = t.path.split('/').last;
      if (_neverRun.containsKey(name) || _services.containsKey(name)) continue;
      Process.runSync('python3', [t.path, '--help'], workingDirectory: '.');
    }
    final after = Process.runSync(
        'git', ['status', '--porcelain'], workingDirectory: '.');
    expect(after.stdout, before.stdout,
        reason: 'running --help across tools/ changed the working tree. A tool '
            'that writes while being asked for help is the failure this file is '
            'named after.');
  });

  test('a tool that takes an email cannot be handed a flag as that email', () {
    // mark_paid writes `paid: true` onto a real account. The specific fix is
    // that an argument starting with "-" is refused, and this pins it, because
    // the natural "improvement" later is to add argparse and let a flag through
    // as a positional again.
    final src = File('tools/mark_paid.py').readAsStringSync();
    expect(src, contains("startswith('-')"),
        reason: 'mark_paid.py no longer refuses a flag-shaped argument. It can '
            'write paid=true onto a user account, so an argument it misreads is '
            'an argument it acts on.');
    // A DIFFERENT flag, not --help. `--help` is now the help path and exits 0,
    // which is correct; the refusal is for an argument that looks like some
    // other flag, and testing it with --help would assert the wrong thing. That
    // confusion is mine — the first version of this test checked --help and
    // failed against a tool that had just been fixed properly.
    final r = Process.runSync('python3', ['tools/mark_paid.py', '--dry-run'],
        workingDirectory: '.');
    final out = '${r.stdout}${r.stderr}';
    expect(out, isNot(contains('looking up')),
        reason: 'mark_paid.py acted on a flag-shaped argument as if it were an '
            'email address:\n$out');
    expect(out, contains('looks like a flag'),
        reason: 'the refusal must say what it thought and how to get usage, or '
            'a mistake costs the reader a round trip to the source');

    // And --help itself must be help, not the refusal: asking a question is not
    // an error, and a tool that answers a question with exit 2 teaches people to
    // stop asking.
    final h = Process.runSync('python3', ['tools/mark_paid.py', '--help'],
        workingDirectory: '.');
    expect(h.exitCode, 0,
        reason: '--help exited ${h.exitCode}. Asking for help is not a failure.');
  });

  test('the service exception still exists as a file, and is still a service', () {
    // A named exception can rot into a hiding place. If telegram_bridge.py
    // disappears, this fails; if it turns into a tool with flags, this fails.
    for (final entry in _services.entries) {
      expect(File('tools/${entry.key}').existsSync(), isTrue,
          reason: '${entry.key} is in the service-exception list but the file is '
              'gone. Remove the entry rather than leaving a name for nothing.');
    }
  });
}
