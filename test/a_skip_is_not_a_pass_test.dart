// A checker that did not run is not a checker that passed.
//
// THE CLASS THIS PINS, learned from outside on 2026-09-28: the other company
// found that `python3 -m unittest <file>` prints
//
//     Ran 0 tests in 0.000s
//     NO TESTS RAN
//
// and EXITS 0. Their runner is `unittest` (run_suite.sh lines 3, 54, 318-319),
// so 23 of their 492 test files — including the single check their own card had
// proven "bites" — had never executed and reported GREEN. A check that cannot
// run is indistinguishable from a check that passes.
//
// APPLYING IT TO MYSELF FOUND A REAL DEFECT IN MY OWN RUNNER, and that is why
// this file exists. `tools/check_all_claims.py` had:
//
//     def ok(rows):
//         return all(r["verdict"] in (VERDICT_PASS, VERDICT_SKIP) for r in rows)
//     ...
//     if ok(rows):
//         return 0
//
// so with `--skip-network`, ONE named claim unverified left ok() true, exit 0,
// and the report printed "RESULT: all checkers passed" — on the same screen as
// "A skip is not a pass; re-run without --skip-network". Two sentences, one
// false, and a caller reading only the exit code could not tell them apart.
//
// WHY IT SURVIVED AS LONG AS IT DID, and this is the part worth keeping: every
// real run of that tool was either all-passing or loudly broken, so the
// contradiction lived in a middle case that nothing ever produced. And the
// first version of the test written to catch it asserted on the SOURCE -
// `expect(src, isNot(contains('verdict in ("PASS", "SKIP")')))` - a string that
// does not exist in the file because the code writes VERDICT_PASS,
// VERDICT_SKIP. That test passed with the defect still present and would have
// passed if the whole verdict system had been deleted. A guard that reads
// vocabulary instead of behaviour is the exact failure QA measured tonight
// against a file named after the property it fails to hold.
//
// SO EVERY ASSERTION HERE IS BEHAVIOUR, against the runner's own code:
//   * the real subprocess, run for real, verdicts parsed from real output;
//   * the runner's own `exit_code()` imported and handed synthetic rows,
//     including the middle case no real run produces.
//
// WHAT exit_code() NOW PROMISES, and what a caller can act on:
//     0  every checker ran and passed - nothing was skipped
//     1  something failed, could not run, or NO checker ran at all
//     2  nothing failed, but a named claim is NOT VERIFIED (skipped)
// The empty case is in there because `all()` over nothing is True: the naive
// version reports a vacuous "all checkers passed" for having started zero
// checkers, which is the oldest silence-as-success in that file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _runner = 'tools/check_all_claims.py';

/// One runner row as the runner itself builds it. The field the verdict is read
/// from is the same one `run_checker` sets.
String _row(String verdict) =>
    '{"name": "x", "argv": [], "verdict": "$verdict", "exit_code": 0, '
    '"first_line": "", "error": null, "skipped": ${verdict == 'SKIP'}}';

/// Imports the runner and calls its own `exit_code` on the given verdicts.
/// Returns the integer it produced. Nothing in the repo is modified: this reads
/// the module and calls a pure function, so it cannot be passing because a
/// subprocess happened to be slow or a file happened to be present.
int _exitCodeFor(List<String> verdicts) {
  final rows = '[${verdicts.map(_row).join(',')}]';
  final code = '''
import json, sys
sys.path.insert(0, "tools")
import check_all_claims as m
rows = json.loads(${jsonEncode(rows)})
print(m.exit_code(rows))
''';
  final r = Process.runSync('python3', ['-c', code], workingDirectory: '.');
  final out = '${r.stdout}${r.stderr}'.trim();
  expect(r.exitCode, 0,
      reason: 'the runner did not import, so nothing was measured:\n$out');
  return int.parse(out.split('\n').last.trim());
}

/// The runner's own output, run for real.
ProcessResult _run(List<String> args, {String? cwd}) =>
    Process.runSync('python3', [_runner, ...args], workingDirectory: cwd ?? '.');

void main() {
  group('a skip is not a pass, and the exit code says so', () {
    test('exit 2 when a claim is skipped and nothing else went wrong', () {
      // The middle case. It could not be produced by any real run of the tool
      // before this change, which is precisely why the defect lived.
      expect(_exitCodeFor(['PASS', 'PASS', 'SKIP']), 2);
    });

    test('exit 0 ONLY when every checker ran and passed', () {
      expect(_exitCodeFor(['PASS', 'PASS', 'PASS']), 0);
    });

    test('exit 1 when anything failed or could not run, even beside a skip', () {
      expect(_exitCodeFor(['SKIP', 'FAIL']), 1);
      expect(_exitCodeFor(['SKIP', 'ERROR']), 1);
      expect(_exitCodeFor(['FAIL']), 1);
    });

    test('exit 1 for a run that checked NOTHING (all() over nothing is True)',
        () {
      // The vacuous-success trap, caught the moment the function was written.
      expect(_exitCodeFor([]), 1);
    });

    test('a run with a skip says so in its own words, never "all passed"', () {
      // The sentence is what a skimming reader sees, so the sentence is pinned
      // as well as the exit code.
      final r = _run(['--skip-network']);
      final out = '${r.stdout}${r.stderr}';
      // Case-insensitive on purpose: the runner sentence-begins with "A", and a
      // test that pins the exact casing of prose breaks when somebody tidies a
      // capital letter — which teaches the next reader that this test is noise.
      expect(out.toLowerCase(), contains('a skip is not a pass'),
          reason: 'the skipped checker must be named as not verified:\n'
              '${out.substring(0, 400)}');
      expect(out, isNot(contains('RESULT: all checkers passed')),
          reason: 'this run skipped a claim, so the word "all" is false:\n'
              '${out.substring(0, 400)}');
      expect(r.exitCode, isNot(0),
          reason: 'a run that did not check everything must not report '
              'success. It exited ${r.exitCode}.\n${out.substring(0, 400)}');
    });
  });

  group('a checker that cannot be RUN is reported, not dropped', () {
    // BEHAVIOUR, NOT VOCABULARY. An earlier version of this file grepped the
    // runner's source for the string 'is not None' and failed — the right
    // outcome for the wrong reason, since a grep proves a word is present, not
    // that a missing checker produces a failed row.
    //
    // The instrument: copy the runner into an EMPTY temp directory. It resolves
    // ROOT from __file__ by design, so every one of its checkers is then
    // genuinely absent — no repo file is renamed, nothing is touched, and the
    // situation produced is the real one: every child cannot be run.
    late Directory dir;
    late ProcessResult r;
    late String out;

    setUpAll(() {
      dir = Directory.systemTemp.createTempSync('skip_is_not_pass_');
      final src = File(_runner).readAsStringSync();
      File('${dir.path}/check_all_claims.py').writeAsStringSync(src);
      r = Process.runSync('python3', ['${dir.path}/check_all_claims.py',
        '--skip-network'],
        workingDirectory: dir.path);
      out = '${r.stdout}${r.stderr}';
    });
    tearDownAll(() => dir.deleteSync(recursive: true));

    /// Verdicts parsed from the printed table. A row is a line whose columns,
    /// split on runs of two or more spaces, contain a column that is EXACTLY one
    /// of the four words; prose cannot be mistaken for a row because prose is
    /// single-spaced and splits into one column.
    ///
    /// Three versions of this parse were wrong before this one, and none of the
    /// failures were the runner's: one grepped the output for 'PASS' and hit the
    /// legend ("PASS means: ran, exit 0..."), one assumed the verdict was the
    /// second column when the check name spans two tokens, and one required rows
    /// to be indented — an indentation that was never in the output, only in how
    /// the test reporter rendered it. A check that asserts a shape it imagined
    /// is the same mistake in a new place.
    List<String> verdicts() {
      const known = {'PASS', 'FAIL', 'SKIP', 'ERROR'};
      final seen = <String>[];
      for (final line in const LineSplitter().convert(out)) {
        final cols = line.trim().split(RegExp(r'\s{2,}')).toList();
        if (cols.length < 2) continue;
        final v = cols.map((c) => c.trim()).where(known.contains);
        if (v.isNotEmpty) seen.add(v.first);
      }
      return seen;
    }

    test('the run prints rows at all', () {
      expect(verdicts(), isNotEmpty,
          reason: 'a run with no rows has told nobody anything:\n'
              '${out.substring(0, 400)}');
    });

    test('no row in a run where nothing could run is a PASS', () {
      expect(verdicts().contains('PASS'), isFalse,
          reason: 'nothing ran, so nothing passed:\n${out.substring(0, 400)}');
    });

    test('a missing checker is an ERROR row, not a dropped row', () {
      // A dropped row and a passing row look identical to a reader of the
      // summary line, so the count of failures is part of the claim.
      expect(verdicts().where((v) => v == 'ERROR').length,
          greaterThanOrEqualTo(1),
          reason: 'every repo checker is missing in this tree, so every one of '
              'them must be a named ERROR row:\n${out.substring(0, 400)}');
    });

    test('the run exits 1 when every checker is missing', () {
      expect(r.exitCode, 1,
          reason: 'exited ${r.exitCode}:\n${out.substring(0, 400)}');
    });

    test('a SKIP is not what a missing file is reported as', () {
      // The SKIP in that run is the network checker --skip-network named by
      // hand, which is correct and must not be "fixed". The ERROR rows beside
      // it are the missing files. Both are honest; conflating them would make
      // the flag a way to hide a broken repo.
      expect(out, contains('FileNotFoundError'),
          reason: 'a missing child must name the exception it hit:\n'
              '${out.substring(0, 400)}');
    });
  });

  group('the offline check of a claim is separate from its live check', () {
    // The design that keeps this repo out of the other company's 23: a claim is
    // decided offline from the Worker's own source, and the network read is an
    // extra. Folding the network read INTO the deciding row would make a
    // network failure a way to PASS a claim — the same class of bug in a
    // different costume.
    test('the privacy claim is decided by an offline row of its own', () {
      final src = File(_runner).readAsStringSync();
      expect(src, contains('_script("tools/check_privacy_processors.py")'),
          reason: 'the privacy claim must be checkable without a network, or a '
              'dropped connection becomes a way to pass it.');
    });
  });

  group('a Dart-side skip says what was not verified', () {
    // The same rule in my own language. A skip whose message is too short to
    // say what was not verified is a silent pass.
    test('no skip in this suite has a message under 12 characters', () {
      final offenders = <String>[];
      for (final f in Directory('test').listSync().whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final text = f.readAsStringSync();
        for (final m in RegExp(r'markTestSkipped\(\s*([^)]*)\)').allMatches(text)) {
          final msg = (m.group(1) ?? '').trim();
          if (msg.length < 12) {
            offenders.add('${f.path.split('/').last}: $msg');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'a skip that cannot say what was not verified is a silent '
              'pass:\n${offenders.join('\n')}');
    });
  });
}
