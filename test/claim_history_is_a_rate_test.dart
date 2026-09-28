// The number nobody had: N in M.
//
// WHY THIS FILE EXISTS. On 2026-09-29 the other company's monitor printed ONE
// line per sample, so a two-minute total failure and a two-hour clean run looked
// identical in the record. QA Lead named what was missing: not "it works", but
// "it worked N times in M, over a window that includes the restarts". Nobody was
// counting the N.
//
// This repo had exactly that gap and did not know it. Every claim number in a
// report tonight was a SINGLE SAMPLE - and the clearest evidence is me re-running
// the money gate by hand five times, purely because one sample could not tell me
// whether a tier had recovered. I was doing the counting by hand in a terminal
// and throwing it away, which is the same defect `check_tests_can_run.py` was
// written against: a measurement made by something that does not survive.
//
// So `--record` appends one line per run and `--history` prints N in M. Nothing
// else about the runner changes, and it never spends: this records verdicts the
// run had already decided.
//
// AND THE HONESTY REQUIREMENT, which is the part that matters most. A history of
// three runs must NOT be reported as a rate. So the tool says so out loud, and
// this test holds it to that: the most dangerous version of this feature is one
// that turns three samples into "0 of 3, consistently failing", which is a
// conclusion nobody drew and no run established.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Clip for a FAILURE MESSAGE, and it can never throw - see the identical helper
/// and the full reasoning in a_skip_is_not_a_pass_test.dart.
///
/// It is here because of how this line came to exist. The sweep guard in
/// a_skip_is_not_a_pass_test.dart flags any `reason:` string that calls
/// `.substring(`, because `reason:` is evaluated EAGERLY and would throw a
/// RangeError on a short output - which is what a HEALTHY tool prints. I landed
/// that guard, and twenty minutes later I wrote this file with a bare
/// `out.substring(0, 300)` in a reason. MY OWN INSTRUMENT CAUGHT ME LANDING THE
/// EXACT DEFECT IT WAS WRITTEN FOR, one commit later, and nothing about the
/// process noticed except the process.
String _clip(String s, [int n = 400]) {
  final flat = s.replaceAll('\n', ' | ');
  return flat.length <= n ? flat : '${flat.substring(0, n)}...';
}

const _runner = 'tools/check_all_claims.py';
final _history = File('.agent-logs/claim-history.jsonl');

void main() {
  test('the history file is gitignored, so it can never be mistaken for evidence',
      () {
    // A reviewer must not be able to find a file of unverifiable numbers in a
    // commit. It is runtime state by design, exactly like the parked patches.
    final r = Process.runSync('git', ['check-ignore', '-v', _history.path]);
    expect(r.exitCode, 0,
        reason: 'claim-history.jsonl is NOT ignored, so a reviewer will see a '
            'file of numbers nothing can reproduce:\n${r.stdout}${r.stderr}');
  });

  group('N in M, and the honesty about small samples', () {
    test('a small history says it is a sample and not a rate', () {
      // Write a tiny history directly rather than running the suite: this test
      // is about what the tool SAYS, not about what the checkers do.
      final before = _history.existsSync() ? _history.readAsStringSync() : '';
      _history.parent.createSync(recursive: true);
      _history.writeAsStringSync([
        for (var i = 0; i < 3; i++)
          jsonEncode({
            'at': '2026-09-29T0$i:00:00+0530',
            'epoch': 1756000000 + i,
            'commit': 'abc12345',
            'exit_code': 1,
            'verdicts': {'tools/check_store_listing.py': 'FAIL'},
          }),
      ].join('\n'));
      addTearDown(() {
        if (before.isEmpty) {
          if (_history.existsSync()) _history.deleteSync();
        } else {
          _history.writeAsStringSync(before);
        }
      });

      final r = Process.runSync('python3', [_runner, '--history']);
      final out = '${r.stdout}';
      expect(r.exitCode, 0, reason: '--history must not run any checker:\n$out');
      expect(out, contains('0 of 3'),
          reason: 'the N in M must be stated:\n$out');
      expect(out.toLowerCase(), contains('sample, not a rate'),
          reason: 'three runs is a sample. Reporting it as a rate is the failure '
              'mode of this whole feature:\n$out');
      expect(out, contains('check_store_listing.py=FAIL'),
          reason: 'name WHICH check moved, so a reader does not have to guess:\n'
              '$out');
    });

    test('a truncated line is excluded from the denominator AND reported', () {
      // A half-written tail must not silently turn "5 of 5" into "5 of 4". The
      // whole value of a rate is the denominator.
      final before = _history.existsSync() ? _history.readAsStringSync() : '';
      _history.parent.createSync(recursive: true);
      final good = [
        for (var i = 0; i < 6; i++)
          jsonEncode({
            'at': '2026-09-29T0$i:00:00+0530',
            'epoch': 1756000000 + i,
            'commit': 'abc12345',
            'exit_code': 0,
            'verdicts': {'tools/check_all_claims.py': 'PASS'},
          }),
      ].join('\n');
      _history.writeAsStringSync('$good\n{"at": "2026-09-29T99:00:00+05');
      addTearDown(() {
        if (before.isEmpty) {
          if (_history.existsSync()) _history.deleteSync();
        } else {
          _history.writeAsStringSync(before);
        }
      });

      final out = '${Process.runSync('python3', [_runner, '--history']).stdout}';
      expect(out, contains('6 of 6'),
          reason: 'the six readable runs are the denominator:\n$out');
      expect(out, contains('1 unreadable line'),
          reason: 'the truncated tail must be NAMED, not quietly dropped:\n$out');
    });

    test('no history at all says so, and does not claim a rate', () {
      final dir = Directory.systemTemp.createTempSync('no_history_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final tree = Directory('${dir.path}/tools')..createSync();
      File(_runner).copySync('${tree.path}/check_all_claims.py');
      final r = Process.runSync('python3', ['${tree.path}/check_all_claims.py',
        '--history'],
        workingDirectory: dir.path);
      expect('${r.stdout}', contains('no recorded history yet'));
      expect('${r.stdout}', contains('not a rate'),
          reason: 'an empty history is not a good record, and saying only '
              '"none" would read as one.');
    });

    test('--record writes one line per run, with the verdicts and a machine time',
        () {
      final dir = Directory.systemTemp.createTempSync('rec_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final tree = Directory('${dir.path}/tools')..createSync();
      File(_runner).copySync('${tree.path}/check_all_claims.py');

      // Run it in an empty tree: every checker is missing, so the run exits 1 -
      // which is exactly the interesting case, because the history must record a
      // FAILING run just as faithfully as a clean one.
      final r = Process.runSync(
          'python3', ['${tree.path}/check_all_claims.py', '--skip-network',
            '--record'],
          workingDirectory: dir.path);
      expect(r.exitCode, 1,
          reason: 'precondition: every checker missing, so the run must fail');

      final hist = File('${dir.path}/.agent-logs/claim-history.jsonl');
      expect(hist.existsSync(), isTrue,
          reason: '--record must have written a history file');
      final lines = hist.readAsStringSync().trim().split('\n');
      expect(lines, hasLength(1));
      final e = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(e['exit_code'], 1,
          reason: 'the recorded exit code must be the one the run really had');
      expect(e['at'], isA<String>());
      expect(e['epoch'], isA<int>(),
          reason: 'a machine time, not a typed one');
      expect(e['verdicts'], isA<Map<String, dynamic>>(),
          reason: 'per-check verdicts, so a reader can see WHICH moved');
      final verdicts = (e['verdicts'] as Map).values.cast<String>().toList();
      expect(verdicts.contains('PASS'), isFalse,
          reason: 'in an empty tree nothing ran, so nothing may be recorded as '
              'a PASS. This is the recorded-history version of the class: a '
              'number that could survive in a file forever and be read as a '
              'result: $verdicts');
      expect(verdicts.contains('ERROR'), isTrue,
          reason: 'the missing checkers must appear as ERROR rows, not be '
              'omitted: $verdicts');
      // NOT "every verdict is ERROR": with --skip-network the network checker is
      // legitimately SKIP and `git rev-parse` legitimately FAILs in a non-repo.
      // I asserted that first and the tool was right and I was wrong, which is
      // the same lesson from the other side - the assertion that is easiest to
      // write is rarely the one that is true.
    });
  });

  group('the rate travels WITH the failure, not in a separate command', () {
    // Learned from the other company's 6c1bbd6b on 2026-09-29: it prints N/M in
    // its OWN output, so the number travels with the failure instead of being
    // looked up afterwards. `--history` can print the rate, but a rate that needs
    // a second command is the same gap one step on - and a failure that does not
    // say how often it has happened reads as a first observation.
    test('a FAILING run prints its own rate on the result line', () {
      final before = _history.existsSync() ? _history.readAsStringSync() : '';
      _history.parent.createSync(recursive: true);
      _history.writeAsStringSync([
        for (var i = 0; i < 4; i++)
          jsonEncode({
            'at': '2026-09-29T0$i:00:00+0530',
            'epoch': 1756000000 + i,
            'commit': 'abc12345',
            'exit_code': 0,
            'verdicts': {'tools/check_store_listing.py': 'PASS'},
          }),
      ].join('\n'));
      addTearDown(() {
        if (before.isEmpty) {
          if (_history.existsSync()) _history.deleteSync();
        } else {
          _history.writeAsStringSync(before);
        }
      });

      final r = Process.runSync('python3', [_runner, '--skip-network']);
      final out = '${r.stdout}';
      expect(out, contains('recorded:'),
          reason: 'the run must carry its own rate:\n${_clip(out, 300)}');
      expect(out, contains('4 of 4'),
          reason: 'N in M, on the line the reader is already reading:\n'
              '${_clip(out, 300)}');
    });

    test('with too little history it says NOTHING rather than a silly rate', () {
      // "0 of 1" is a worse sentence than no sentence: it invites reading one
      // sample as a rate, which is the failure mode of the whole feature.
      final before = _history.existsSync() ? _history.readAsStringSync() : '';
      _history.parent.createSync(recursive: true);
      _history.writeAsStringSync(jsonEncode({
        'at': '2026-09-29T01:00:00+0530',
        'epoch': 1756000001,
        'commit': 'abc12345',
        'exit_code': 0,
        'verdicts': {'tools/check_store_listing.py': 'PASS'},
      }));
      addTearDown(() {
        if (before.isEmpty) {
          if (_history.existsSync()) _history.deleteSync();
        } else {
          _history.writeAsStringSync(before);
        }
      });

      final out = '${Process.runSync('python3', [_runner, '--skip-network']).stdout}';
      expect(out, isNot(contains('recorded:')),
          reason: 'one run is a sample, not a rate, and printing it as one is '
              'worse than printing nothing:\n${_clip(out, 300)}');
    });
  });
}
