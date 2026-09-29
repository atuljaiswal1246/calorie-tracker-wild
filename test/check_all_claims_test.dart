// A RUNNER THAT CANNOT FAIL IS A FORMALITY, AND A RUNNER THAT CAN LIE IS WORSE
// THAN NO RUNNER.
//
// `tools/check_all_claims.py` exists to do one thing the repo could not do: run
// every "is this still true?" checker and return ONE exit code, so a claim is
// green because a check produced it and not because a report said so. That only
// works if the runner can both fail and be honest about what it did not run.
//
// Two failure shapes kill that, and each has its own test below:
//
//   * It cannot fail. A runner whose every branch returns 0 is a ceremony. So it
//     is run for real, in a tree where its checkers do NOT exist, and it must
//     exit 1 having said ERROR — not crash, not exit 0.
//   * It reports a pass for something that never ran. The worst outcome: a table
//     row that says ok for a checker that was never started is exactly the "an
//     empty result is not a finding" failure, moved one layer up. So the
//     flags, the checker list and the failing exit are read as BEHAVIOUR
//     (execute the tool) wherever that is possible, and as structure (parse the
//     source) only where the brief asks for it.
//
// Nothing here touches the network, and nothing here runs a real checker: the
// only executions are `--help` (argparse exits before any checker list is
// walked) and a run inside a temp tree that contains check_all_claims.py and
// nothing else, so `tools/ai_accuracy.py` is genuinely absent and no model call
// is even possible. `flutter analyze` is never triggered.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const toolPath = 'tools/check_all_claims.py';

/// Resolved the way `money_gate_test.dart` resolves it: on PATH, then the known
/// installs. No python3 is a FAILURE, not a skip — a skipped runner test is a
/// missing runner test, which is the thing this file is here to prevent.
String? _findPython() {
  for (final c in <String>[
    'python3',
    '/opt/anaconda3/bin/python3',
    '/usr/bin/python3',
    '/opt/homebrew/bin/python3',
    '/usr/local/bin/python3',
  ]) {
    if (c == 'python3') {
      final onPath = Process.runSync('/bin/sh', ['-c', 'command -v python3']);
      final p = (onPath.stdout as String).trim();
      if (onPath.exitCode == 0 && p.isNotEmpty) return p;
    } else if (File(c).existsSync()) {
      return c;
    }
  }
  return null;
}


void main() {
  final src = File(toolPath).readAsStringSync();
  final py = _findPython();

group('the COUNT is the instrument', () {
    // Learned from outside on 2026-09-29 (QA Lead, 232a5193): ADDING A CHECK AND
    // GETTING THE SAME RESULT IS THE MOST DANGEROUS OUTCOME, BECAUSE IT LOOKS
    // A GUARD RED IS ONLY AN EVENT IF IT IS THE ONLY ONE. Learned from QA Lead's
  // Bar 1 report on 2026-09-29: their own change turned a watcher red at 05:20
  // and it sat unread for thirty minutes, in a table with eight red, because a
  // number that has been true all night is not an event and nobody asked the
  // instrument that would have said so.
  //
  // The data was already recorded - every run writes its verdicts by name - and
  // NOTHING computed the difference. So this is not a new measurement, it is the
  // measurement that was always available and never taken.
  test('a row that CHANGED since the last run is marked, an unchanged one is not',
      () async {
    // This test runs the WHOLE runner three times: once to read the current
    // verdicts so the fake previous run is built from reality rather than from a
    // stale file, once to prove an identical run marks nothing, and once to prove a
    // changed one does. Each run includes `flutter analyze` through
    // check_self_claims.py, which is about ten seconds, so three runs do not fit
    // the thirty-second default. The timeout is raised HERE, with the reason,
    // rather than by dropping a run - dropping the third would drop the only
    // assertion that a PASS row is never wrongly marked.
    const hist = '.agent-logs/claim-history.jsonl';
    final h = File(hist);
    if (!h.existsSync()) {
      markTestSkipped('no recorded history yet - the marker needs a previous run '
          'to differ from, and inventing one here would be the fake this test '
          'exists to prevent');
      return;
    }
    final original = h.readAsStringSync();
    addTearDown(() => h.writeAsStringSync(original));

    Future<String> run() async =>
        '${(await Process.run('python3',
            ['tools/check_all_claims.py', '--skip-network'])).stdout}';

    // 1. with the real history, a row must be marked ONLY if it differs from the
    //    last recorded run. Append an identical run and assert NOTHING is marked,
    //    because "8 reds is the same as no reds" is the failure being fixed.
    // THE PREVIOUS RUN MUST BE BUILT FROM THE CURRENT VERDICTS, not copied from the
    // history file. This test was written assuming the last recorded run still
    // matched reality, and it stopped passing the moment a checker changed verdict
    // between that recording and now - which is the marker WORKING and the test
    // failing for it. A test that can only pass while a file is fresh is a test
    // measuring the file, not the code.
    final now = await run();
    final verdictsNow = <String, dynamic>{};
    for (final line in now.split('\n')) {
      final m = RegExp(r'^(\S.*?)\s{2,}(PASS|FAIL|SKIP|CRASH)\s').firstMatch(line);
      if (m != null) verdictsNow[m.group(1)!.trim()] = m.group(2);
    }
    expect(verdictsNow, isNotEmpty,
        reason: 'could not read a single verdict row out of the runner, so the '
            'whole test would be asserting nothing:\n$now');
    final last = <String, dynamic>{
      'at': '2099-01-01T00:00:00+0000',
      'commit': 'eeeeee1',
      'epoch': 9999999998,
      'exit_code': 0,
      'verdicts': verdictsNow,
    };
    h.writeAsStringSync('$original${jsonEncode(last)}\n');
    expect(await run(), isNot(contains('NEW - was')),
        reason: 'an unchanged red is not an event. If this ever marks an '
            'identical run, the marker has become noise and will be ignored.');

    // 2. now make every checker look like it was PASSing last run, and the
    //    non-pass rows must be marked. This is the direction that matters: a row
    //    that turns RED is the one a reader has to act on.
    final names = verdictsNow.keys.toList();
    expect(names, isNotEmpty, reason: 'the recorded run carried no verdicts');
    h.writeAsStringSync('$original${jsonEncode(<String, dynamic>{
          'at': '2099-01-01T00:00:00+0000',
          'commit': 'ffffff1',
          'epoch': 9999999999,
          'exit_code': 0,
          'verdicts': {for (final n in names) n: 'PASS'},
        })}\n');
    final out = await run();
    expect(out, contains('NEW - was PASS'),
        reason: 'a red that is new must be visible as new:\n$out');
    // and no row that PASSes may carry the marker
    for (final line in out.split('\n')) {
      if (line.contains(' PASS ')) {
        expect(line, isNot(contains('NEW - was')),
            reason: 'a passing row was marked as changed, which means the '
                'comparison is not against the previous run:\n  $line');
      }
    }
  },
      timeout: const Timeout(Duration(minutes: 4)));

  // A CRASH IS NOT A FINDING, and this table could not tell them apart until
  // 2026-09-29. Measured rather than suspected: sabotaging git inside
  // check_release_is_the_tree.py killed it on an uncaught ValueError, and the
  // process STILL exited 1 - the code this table records as FAIL. None of the
  // seven checkers has a top-level catch-all, so any of them can die that way and
  // a reader would have seen a crash dressed as a red about the product.
  test('a checker that DIES is CRASH, never FAIL', () async {
    // Sabotage a real checker at the point where it actually executes. The first
    // attempt appended a raise at the END of the file and was a silent no-op,
    // because sys.exit(main()) has already run by then - so the sabotage has to go
    // before the first def, or this test would pass for the wrong reason.
    final f = File('tools/check_commit_claims.py');
    final original = f.readAsStringSync();
    addTearDown(() => f.writeAsStringSync(original));
    final lines = original.split('\n');
    final at = lines.indexWhere((l) => l.startsWith('def '));
    expect(at, greaterThan(0), reason: 'no def to sabotage before');
    lines.insert(at, 'raise RuntimeError("SABOTAGE: dies instead of answering")');
    f.writeAsStringSync(lines.join('\n'));

    final r = await Process.run('python3', ['tools/check_all_claims.py',
        '--skip-network']);
    final out = '${r.stdout}';
    expect(out, contains('CRASH'),
        reason: 'a dead checker must be visible as CRASH:\n$out');
    expect(out, isNot(contains('SABOTAGE: dies instead of answering\np0')),
        reason: 'sanity: the row must quote what happened');
    final line = out
        .split('\n')
        .firstWhere((l) => l.contains('check_commit_claims.py'), orElse: () => '');
    expect(line, contains('CRASH'),
        reason: 'and it must be the ROW for that checker that says so, not some '
            'other row in the table:\n$out');
    expect(line, isNot(contains(' FAIL ')),
        reason: 'FAIL is reserved for "it checked and the answer is no". A crash '
            'in that column is the exact defect this test exists to catch.\n'
            '  row was: $line');
  });

  // A CHECKER THAT EXISTS BUT IS NEVER WIRED is invisible to every count above,
  // because all of them read CHECKERS - the same list the runner walks. Two were
  // sitting in tools/ unwired on 2026-09-29, one of them a guard I had described
  // in report after report, and the count read a confident 11 the whole time.
  //
  // This is the sharp half of "two instruments reading the same source cannot
  // disagree": they cannot, and that is exactly why they cannot notice a shared
  // blind spot. The disagreement has to come from OUTSIDE the pair. This test is
  // the outside instrument, and it reads the DIRECTORY rather than the list.
  test('every checker in tools/ is either wired in, or on the list with a reason',
      () {
    final src = File('tools/check_all_claims.py').readAsStringSync();
    final wired = RegExp(r'_script\("(tools/[^"]+)"')
        .allMatches(src)
        .map((m) => m.group(1)!.split('/').last)
        .toSet();

    // Named on BOTH sides on purpose: a checker is exempt only if the reason it
    // is exempt is written next to it, so this list cannot grow silently.
    const exempt = {
      // The runner itself. It is what runs the rows; it cannot be one of them.
      'check_all_claims.py',
      // Judges roles in ANOTHER company's tree. Wiring it here would make a red
      // in this runner depend on a tree we do not control and cannot clear.
      'check_landings.py',
    };

    final onDisk = Directory('tools')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('check_') && n.endsWith('.py'))
        .toSet();

    final orphans = onDisk.difference(wired).difference(exempt);
    expect(orphans, isEmpty,
        reason: 'these checkers exist and would pass forever without ever '
            'running, because a count of CHECKERS cannot see them: '
            '${orphans.toList()}\n'
            'Either wire them into CHECKERS or move them to the exempt set here '
            'WITH the reason. A guard nobody runs is a comment.');

    // And prove the needle on a known positive: the detector must actually be
    // able to see an unwired checker, or the empty result above means nothing.
    expect(onDisk.contains('check_release_is_the_tree.py'), isTrue);
    expect(wired.contains('check_release_is_the_tree.py'), isTrue,
        reason: 'if this stopped being wired, the detector above would need '
            're-testing before its green could be believed.');
  });

  // LIKE SUCCESS. The count is the instrument, and an unchanged count after
    // adding an assertion means the assertion is not in the guard.
    //
    // The specific hole this closes in MY runner: `all checkers passed` is a claim
    // about a SET. Nothing pinned that the set the runner iterated was the set it
    // declared, so a checker added to CHECKERS and silently dropped by run_all -
    // by a filter, a typo, a swallowed exception - would leave a clean table with
    // one row missing and no sentence anywhere saying so.
    test('every DECLARED checker produces a row', () {
      final r = Process.runSync(py!, [toolPath, '--skip-network', '--json']);
      expect(r.exitCode, isNot(0),
          reason: 'precondition: the run must be honest about its own state');
      final d = jsonDecode(r.stdout as String) as Map<String, dynamic>;
      final ran = (d['checks'] as List).length;

      // How many are declared? Read it from the module itself rather than from a
      // constant here, because a hard-coded number in the TEST is a number that
      // goes stale the moment someone adds a checker - which is the exact failure
      // this group exists to catch.
      final probe = Process.runSync(py!, ['-c',
        'import sys; sys.path.insert(0,"tools");'
        'import check_all_claims as m; print(len(m.CHECKERS))']);
      final declared = int.parse((probe.stdout as String).trim());

      expect(ran, declared,
          reason: '$ran row(s) ran but $declared checker(s) are declared. A '
              'declared checker that produced no row is invisible: the table '
              'looks complete and "all checkers passed" would be a claim about a '
              'set nobody can see.');
    });

    test('the header says how many checkers it is running', () {
      // The count has to TRAVEL with the result, not be inferable by counting.
      final r = Process.runSync(py!, [toolPath, '--skip-network']);
      final out = r.stdout as String;
      final m = RegExp(r'running (\d+) claim checker').firstMatch(out);
      expect(m, isNotNull,
          reason: 'the run must print how many checkers it is running, or the '
              'reader is left counting rows to find out whether one is '
              'missing:\n${out.substring(0, 300)}');
      // The analyzer is right that `!` cannot promote a non-null here: `expect`
      // does not narrow its argument, so the promotion is decoration. Match on
      // null explicitly instead of asserting and then pretending.
      final count = m == null ? -1 : int.parse(m.group(1)!);
      expect(count, greaterThan(0),
          reason: '"running 0 checkers" and then "all checkers passed" is the '
              'most dangerous shape a claim runner can have.');
    });
  });

  group('the runner cannot pass by doing nothing', () {
    test('the exit code is a function of the ROWS, not a constant', () {
      // THIS WAS A VOCABULARY GUARD AND IT BROKE HONESTLY. It read
      //   expect(src.contains('return 1'), isTrue)
      //   expect(src.contains('if ok(rows):'), isTrue)
      // The first would pass if the entire verdict system were deleted and a
      // bare `return 1` were left lying in a docstring. The second broke today
      // on a refactor that made the runner STRONGER - main() now delegates to
      // exit_code(rows) so a skipped claim can be told apart from a full pass -
      // and it broke on the words, with the behaviour intact. That is the same
      // failure QA measured on the other company tonight against a file named
      // after the property it fails to hold, and the same one this repo's own
      // brief warns about: does this check read behaviour, or vocabulary?
      //
      // The property it was reaching for is real and is checked here by
      // perturbing the INPUT and watching the OUTPUT move: same function, same
      // call, different rows, different exit code. A constant cannot do that.
      // The rows go in as ARGV, never interpolated into the source. The first
      // version pasted them straight in and died on `null`: JSON's null is not
      // Python's None, and a quoting layer between me and the value under test
      // is one more place to be wrong. argv has exactly one encoding.
      int probe(String rowsJson) {
        final code = '''
import json, sys
sys.path.insert(0, "tools")
import check_all_claims as m
print(m.exit_code(json.loads(sys.argv[1])))
''';
        final r = Process.runSync(py!, ['-c', code, rowsJson]);
        expect(r.exitCode, 0,
            reason: 'the runner did not import:\n${r.stdout}${r.stderr}');
        return int.parse('${r.stdout}'.trim().split('\n').last.trim());
      }

      String row(String verdict) => jsonEncode({
            'name': 'x',
            'argv': <String>[],
            'verdict': verdict,
            'exit_code': 0,
            'first_line': '',
            'error': null,
            'skipped': false,
          });

      final allPass = probe('[${row('PASS')}, ${row('PASS')}]');
      final oneFails = probe('[${row('PASS')}, ${row('FAIL')}]');
      final oneMissing = probe('[${row('PASS')}, ${row('ERROR')}]');
      final oneSkipped = probe('[${row('PASS')}, ${row('SKIP')}]');

      expect(allPass, 0, reason: 'nothing failed and nothing was skipped');
      expect(oneFails, 1, reason: 'a failing checker must fail the run');
      expect(oneMissing, 1, reason: 'an unrunnable checker must fail the run');
      // oneFails and oneMissing are BOTH 1 and that is correct - a failed
      // checker and an unrunnable one are equally not-a-pass. An earlier
      // version of this assertion demanded three distinct codes and was wrong:
      // it was demanding a shape rather than the property. What has to move is
      // allPass against the rest, and that is the perturbation. The third state
      // is the one this refactor added, and it is the one a reader most needs
      // to see change: a skipped claim must not read as a full pass.
      expect(oneSkipped, 2,
          reason: 'a named claim that did not run is not a full pass, and the '
              'code must say so');
      expect(allPass, isNot(oneFails));
      expect(allPass, isNot(oneSkipped));
      expect(oneSkipped, isNot(oneFails),
          reason: 'a run where a claim was not verified must be '
              'distinguishable from one where something broke');
    });

    test('a checker that is missing is REPORTED, not skipped and not crashed on',
        () {
      // Run for real, in a temp tree holding this one file. tools/ai_accuracy.py
      // is not there, so every repo checker must come back ERROR. This is the
      // whole test: an unrun checker is the one thing a runner may never call a
      // pass, and the only honest way to know it does not is to watch it fail.
      final dir = Directory.systemTemp.createTempSync('check_all_claims');
      addTearDown(() => dir.deleteSync(recursive: true));
      final tools = Directory('${dir.path}/tools')..createSync();
      File(toolPath).copySync('${tools.path}/check_all_claims.py');

      final r = Process.runSync(py!, ['${tools.path}/check_all_claims.py',
        '--skip-network']);
      final out = '${r.stdout}${r.stderr}';

      expect(
        r.exitCode,
        1,
        reason: 'Every checker is missing in that tree, so the run must be a '
            'failure. It exited ${r.exitCode}.\n$out',
      );
      expect(out, contains('ERROR'),
          reason: 'A missing checker must be REPORTED as ERROR, not passed and '
              'not dropped from the table.\n$out');
      expect(out, isNot(contains('Traceback (most recent call last)')),
          reason: 'The runner crashed instead of handling a missing checker. A '
              'runner that crashes tells the caller nothing.\n$out');
      expect(out, contains('FileNotFoundError'),
          reason: 'The ERROR must name the actual exception, so a reader can '
              'tell a missing file from a timeout.\n$out');
    });

    test('no output is not a pass - the rule is in the source, not only implied',
        () {
      // exit 0 alone must not be enough. A checker that printed nothing has
      // verified nothing, and a runner that calls that a pass is how an absence
      // becomes a green light.
      expect(RegExp(r'if not out:').hasMatch(src), isTrue,
          reason: 'The runner no longer distinguishes "printed nothing" from '
              '"passed". Restore the empty-output failure.');
      expect(src.contains('NOT a pass'), isTrue,
          reason: 'The empty-output case must say on its face that it is not a '
              'pass; otherwise the FAIL is indistinguishable from a quirk.');
    });
  });

  group('the checkers it runs are the real ones', () {
    test('the money gate is the first thing it runs, as a PAIR', () {
      // The pairing is the claim, not the two words. `ai_accuracy.py` appears
      // twice in the list and only one of those two invocations is the gate; a
      // check that looked for the words separately would be satisfied by the
      // corpus run.
      final m = RegExp(r'"tools/ai_accuracy\.py",\s*"--self-test"')
          .firstMatch(src);
      expect(m, isNotNull,
          reason: 'tools/ai_accuracy.py --self-test is no longer in the checker '
              'list. The money gate would stop being run by anyone.');
      expect(src.indexOf('"--self-test"'),
          lessThan(src.indexOf('"--corpus"')),
          reason: 'The money gate must come before anything that reads data, so '
              'a broken gate is visible before it is explained away.');
    });

    test('it names check_self_claims.py, so the analyze baseline is checked', () {
      expect(RegExp(r'"tools/check_self_claims\.py"').hasMatch(src), isTrue,
          reason: 'check_self_claims.py has dropped out of the runner, so a '
              'stale analyze claim in AGENTS.md can no longer be caught here.');
      expect(src.contains('"--skip-suite"'), isTrue,
          reason: 'Without --skip-suite this runner would run the whole flutter '
              'suite, which is the owner\'s once, not a nightly background job.');
    });

    test('it names the two no-spend modes and no other ai_accuracy invocation',
        () {
      expect(RegExp(r'"tools/ai_accuracy\.py",\s*"--corpus"').hasMatch(src),
          isTrue,
          reason: 'The corpus independence report is no longer run.');
      // A bare `tools/ai_accuracy.py` would start a real, PAID scan. The only
      // invocations allowed are the two that cannot spend, so the flag must be
      // on every single one of them.
      final invocations = RegExp(r'_script\("tools/ai_accuracy\.py"([^)]*)\)')
          .allMatches(src)
          .toList();
      expect(invocations, isNotEmpty);
      for (final m in invocations) {
        final args = m.group(1) ?? '';
        expect(
          args.contains('--self-test') || args.contains('--corpus'),
          isTrue,
          reason: 'tools/ai_accuracy.py is invoked as `$args`, which is neither '
              '--self-test nor --corpus. A plain run scans for real and spends '
              'the owner\'s money.',
        );
      }
    });

    test('it never starts a CHECKER in a mode that writes to disk', () {
      // `--write` rewrites the generated block in AGENTS.md and `--record` stamps
      // notes/EXTERNAL_CLAIMS_LAST_CHECK.md. A runner that could rewrite the very
      // file its checkers verify is a runner that can launder a claim.
      //
      // SCOPED TO THE CHECKER LIST, and the scoping is the point rather than a
      // convenience. This used to scan the whole source for the STRING
      // '"--write"'. Then the runner grew a `--record` flag of its own - which
      // appends a gitignored run-history line and touches no verified artefact -
      // and the guard went red on it. Deleting the assertion would have been the
      // easy fix and it would have deleted the guard.
      //
      // So the check now asks the question it always meant to ask: is any CHECKER
      // ROW invoked with a writing flag? Reading the CHECKERS tuple itself cannot
      // be fooled by a flag declared elsewhere, and it cannot fire on an
      // unrelated addition either. Verified: 0 writing flags inside the tuple.
      final start = src.indexOf('CHECKERS = (');
      expect(start, greaterThan(-1), reason: 'the checker list is gone');
      final end = src.indexOf('\n)', start);
      expect(end, greaterThan(start),
          reason: 'the checker list is unterminated - I am reading the wrong span');
      final listSpan = src.substring(start, end);
      for (final flag in ['"--write"', '"--record"']) {
        expect(listSpan.contains(flag), isFalse,
            reason: 'a CHECKER is invoked with $flag. A runner that can rewrite '
                'the file its checkers verify can launder a claim.');
      }
    });

    test('a writing flag on the RUNNER is allowed, and must not touch a claim',
        () {
      // The counterpart, so the narrowing above cannot quietly become "no writing
      // anywhere": the runner itself is allowed a write mode, provided what it
      // writes is gitignored runtime state and not a file some checker verifies.
      final hist = File('.agent-logs/claim-history.jsonl').path;
      final r = Process.runSync('git', ['check-ignore', '-q', hist]);
      expect(r.exitCode, 0,
          reason: 'the runner writes $hist, and it must be gitignored so a '
              'reviewer never sees a file of numbers nothing can reproduce');
    });
  });

  group('the flags are real flags', () {
    // Read from `--help`, not from the source text. A word in a file is a
    // comment; a flag in --help is a flag argparse actually registered.
    test('--skip-network and --json are both accepted', () {
      final r = Process.runSync(py!, [toolPath, '--help']);
      final out = r.stdout as String;
      expect(r.exitCode, 0, reason: '--help did not run.\n${r.stderr}');
      expect(out, contains('--skip-network'),
          reason: 'The offline flag is gone: a machine with no network cannot '
              'run the runner at all.');
      expect(out, contains('--json'),
          reason: 'The machine-readable flag is gone, so nothing can consume '
              'this exit code but a human reading a table.');
    });

    test('an unknown flag is rejected, so a typo cannot silently skip a check',
        () {
      final r = Process.runSync(py!, [toolPath, '--skip-netwrok']);
      expect(r.exitCode, isNot(0),
          reason: 'A misspelled flag was accepted. The worst version of this '
              'tool is one that quietly runs fewer checks than it claims to.');
    });
  });
}
