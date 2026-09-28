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
// contradiction lived in a middle case that nothing ever produced.
//
// AND WHY THIS REPO STRUCTURALLY CANNOT HAVE THAT CLASS, measured rather than
// assumed - because "we are fine" is exactly the sentence nobody checked.
// Probe run 2026-09-29 00:13 IST, this machine, this working tree, the probe
// file written and deleted inside the same command:
//
//     $ flutter test test/zz_probe_no_tests_test.dart   # main(), no test()
//       No tests ran.
//       No tests were found.
//       REAL EXIT=79
//
// `flutter test` scores a module with no tests as a NON-ZERO exit. The unittest
// runner scores the same module exit 0 - a pass. That difference, not any care
// taken here, is the structural reason 23 of 492 files there could sit
// unexecuted and green while this repo's tests cannot.
//
// NOT PINNED BY A TEST HERE, and the reason is the point: pinning it would mean
// running `flutter test` from inside a `flutter test`, so every suite execution
// would pay a nested toolchain start to re-confirm somebody else's exit code -
// a property of the RUNNER, not of this repo. The measurement above carries its
// producer, its minute and its tree, which is what a claim needs to be
// checkable by the next session. A guard that costs a toolchain start on every
// run to re-read a constant is a cost with no new evidence.
//
// And the
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

/// order 11's machine, run against a throwaway repo. Never against the working
/// tree: a test that parked real work would be the accident it exists to stop.
///
/// ABSOLUTE, and the reason is one I already paid for tonight in a different
/// costume: the subprocess cwd is the throwaway repo, which has no tools/
/// directory, so a relative path to the tool resolves to nothing and python3
/// exits 2. The tool then finds no repo and says NOT_A_REPO - a correct refusal
/// about the wrong thing, which is exactly what a misleading failure looks like.
final String guardTool = File('tools/guard_uncommitted.py').absolute.path;

ProcessResult guard(Directory repo, List<String> args) => Process.runSync(
    'python3', [guardTool, ...args],
    workingDirectory: repo.path);

void run(String exe, List<String> args) {
  final r = Process.runSync(exe, args, workingDirectory: repoDir);
  expect(r.exitCode, 0, reason: '$exe ${args.join(' ')}: ${r.stderr}');
}

/// Set by [setUp] for the throwaway repo helper above. Kept explicit rather than
/// passed everywhere so a call cannot accidentally target the real tree.
late String repoDir;

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
              '${_clip(out, 400)}');
      expect(out, isNot(contains('RESULT: all checkers passed')),
          reason: 'this run skipped a claim, so the word "all" is false:\n'
              '${_clip(out, 400)}');
      expect(r.exitCode, isNot(0),
          reason: 'a run that did not check everything must not report '
              'success. It exited ${r.exitCode}.\n${_clip(out, 400)}');
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
              '${_clip(out, 400)}');
    });

    test('no row in a run where nothing could run is a PASS', () {
      expect(verdicts().contains('PASS'), isFalse,
          reason: 'nothing ran, so nothing passed:\n${_clip(out, 400)}');
    });

    test('a missing checker is an ERROR row, not a dropped row', () {
      // A dropped row and a passing row look identical to a reader of the
      // summary line, so the count of failures is part of the claim.
      expect(verdicts().where((v) => v == 'ERROR').length,
          greaterThanOrEqualTo(1),
          reason: 'every repo checker is missing in this tree, so every one of '
              'them must be a named ERROR row:\n${_clip(out, 400)}');
    });

    test('the run exits 1 when every checker is missing', () {
      expect(r.exitCode, 1,
          reason: 'exited ${r.exitCode}:\n${_clip(out, 400)}');
    });

    test('a SKIP is not what a missing file is reported as', () {
      // The SKIP in that run is the network checker --skip-network named by
      // hand, which is correct and must not be "fixed". The ERROR rows beside
      // it are the missing files. Both are honest; conflating them would make
      // the flag a way to hide a broken repo.
      expect(out, contains('FileNotFoundError'),
          reason: 'a missing child must name the exception it hit:\n'
              '${_clip(out, 400)}');
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

  group('a failure message is safe in the state that means FIXED', () {
    // QA Lead's principle, from their own report: THE STATE NOBODY EVER TESTS IS
    // THE STATE THAT MEANS FIXED. A guard is exercised in the broken state and
    // trusted in the fixed one, so its message has to be safe in exactly the
    // state where there is nothing left to name.
    //
    // Their check indexed `unclaimed[0]` inside a Python f-string. Python builds
    // f-strings eagerly, so the instant the claim was made and the list emptied,
    // the check raised IndexError instead of PASSING - and the next person would
    // have filed that as "the guard is flaky".
    //
    // The same defect in Dart, and it was in THIS FILE, eight times. Dart
    // evaluates `reason:` eagerly too, so `reason: out.substring(0, 400)` throws
    // a RangeError whenever the output is shorter than 400 characters - which is
    // what a healthy tool prints.

    test('_clip cannot throw, at any boundary', () {
      // The boundary is where a truncation helper dies: exactly n, and one over.
      expect(_clip(''), '');
      expect(_clip('a'), 'a');
      expect(_clip('x' * 10), 'x' * 10);
      expect(_clip('x' * 400), 'x' * 400);
      expect(_clip('x' * 401), '${'x' * 400}...');
      expect(_clip('y' * 100000).length, 403);
    });

    test('_clip flattens newlines so a table stays readable on one line', () {
      expect(_clip('a\nb\nc'), 'a | b | c');
    });

    test('a trivially TRUE assertion with a short reason does not throw', () {
      // The proof, run every time. Before _clip, this raised
      // RangeError (end): Not in inclusive range 0..19: 400 - on an assertion
      // that could not have failed.
      final out = 'all checkers passed'; // 19 characters: a FIXED product
      Object? caught;
      try {
        expect(1, 1, reason: 'looked at: ${_clip(out, 400)}');
      } catch (e) {
        caught = e;
      }
      expect(caught, isNull,
          reason: 'the message itself threw: $caught. A guard whose explanation '
              'can crash it is not a guard in the state that means fixed.');
    });

    test('no reason in MY suite truncates with substring()', () {
      // A vocabulary check on purpose, and the last line of defence: the class
      // is a literal one, so a sweep is the cheapest guard against it creeping
      // back in. The behavioural proof is the test above. Comment lines are
      // exempt so the two files that DOCUMENT this bug can quote it.
      final offenders = <String>[];
      for (final f in Directory('test').listSync().whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lines = f.readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          final m = RegExp(r'reason:\s*(.*)').firstMatch(line);
          if (m != null && m.group(1)!.contains('.substring(')) {
            offenders.add('${f.path.split('/').last}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'these reason strings can throw RangeError when the output is '
              'short - which is what a FIXED tool prints:\n${offenders.join('\n')}');
    });
  });

  group('a saved patch leaves no state saying it was dealt with', () {
    // QA Lead found this in the other company on 2026-09-29 00:12 and it is in
    // MY repo too, in my own tool. A completed card left no state saying
    // finished, so a role holding no work and a role whose work is invisible
    // looked identical - and 592 minutes of heartbeat re-sent a card that had
    // been done for hours.
    //
    // The same shape was here, and it is order 11's own machine. `allow` SAVES
    // the uncommitted work; order 11 then says "look at it, then decide - in
    // that order, every time" - and NOTHING recorded the second half. The patch
    // landed in `.agent-logs/discard/`, which is GITIGNORED (.gitignore:73), so
    // no commit could ever prove it existed, and no state anywhere said whether
    // it had been put back. Saving is the half that is easy to notice.
    //
    // Measured before the fix: 0 patches parked, so nothing was lost. That is
    // the good news and it is a measurement, not an assumption - which is the
    // only reason it is safe to change the tool rather than rescue a patch.
    late Directory repo;
    late String patch;

    setUp(() {
      repo = Directory.systemTemp.createTempSync('guard_decided_');
      repoDir = repo.path;
      run('git', ['init', '-q', '.']);
      run('git', ['config', 'user.email', 't@t']);
      run('git', ['config', 'user.name', 't']);
      File('${repo.path}/f.txt').writeAsStringSync('original\n');
      run('git', ['add', 'f.txt']);
      run('git', ['commit', '-qm', 'init']);
      // The uncommitted work order 11 exists to protect.
      File('${repo.path}/f.txt').writeAsStringSync('work nobody owns yet\n');
      expect(guard(repo, ['allow', 'f.txt']).exitCode, 0);
      patch = Directory('${repo.path}/.agent-logs/discard')
          .listSync()
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.patch'))
          .path;
    });
    tearDown(() => repo.deleteSync(recursive: true));

    test('a parked patch with no decision is REPORTED and exits non-zero', () {
      // The whole point. Silence here is how 592 minutes of noise happens.
      final r = guard(repo, ['list']);
      expect(r.exitCode, isNot(0),
          reason: 'an undecided patch is unfinished business, and this list is '
              'the only record it exists:\n${r.stdout}');
      expect('${r.stdout}', contains('UNDECIDED'),
          reason: 'the patch must be named as undecided, not merely counted:\n'
              '${r.stdout}');
    });

    test('after a decision the same list is clean and exits zero', () {
      final d = guard(repo, ['decide', patch,
        '--verdict', 'restored', '--producer', 'test, throwaway repo']);
      expect(d.exitCode, 0, reason: '${d.stdout}${d.stderr}');

      final r = guard(repo, ['list']);
      expect(r.exitCode, 0,
          reason: 'every patch now carries a decision:\n${r.stdout}');
      expect('${r.stdout}', contains('restored'));
      expect('${r.stdout}', isNot(contains('UNDECIDED')));
    });

    test('the decision records a producer and a MACHINE time, not a typed one',
        () {
      guard(repo, ['decide', patch,
        '--verdict', 'dead', '--producer', 'who, when, why']);
      final side = jsonDecode(
          File(patch.replaceAll('.patch', '.decided.json')).readAsStringSync());
      expect(side['verdict'], 'dead');
      expect(side['producer'], 'who, when, why');
      // A typed time is a guess and nothing can check a guess.
      expect(side['decided_at_epoch'], isA<int>());
      expect(side['decided_at_epoch'], closeTo(DateTime.now().millisecondsSinceEpoch ~/ 1000, 120));
    });

    test('deciding a patch does NOT delete it - a decision is a record', () {
      guard(repo, ['decide', patch, '--verdict', 'superseded',
        '--producer', 'p']);
      expect(File(patch).existsSync(), isTrue,
          reason: 'the parked work must survive the decision. Recording a '
              'verdict is not permission to throw the work away.');
      expect(File(patch).readAsStringSync(), contains('work nobody owns yet'),
          reason: 'and the patch must still hold the content it was saved for');
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
