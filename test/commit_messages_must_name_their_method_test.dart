// A commit subject is a claim nobody verifies.
//
// LEARNED FROM OUTSIDE on 2026-09-29, twice, from two directions.
//
// QA Lead, commit 0f5cda68: they wrote that a perturbation had been proven BEFORE
// they ran it. The claim was true when it landed and the ORDER was wrong - which
// is the only kind of wrong nobody downstream can detect, because a commit that
// performed a check and a commit that claims one read identically.
//
// And in the other company a commit subject read "a typed turn is written where
// it can be read back" while a marker typed into the same product, in the same
// minute, was found in zero rows of the store.
//
// So: `tools/check_commit_claims.py` reads commit messages and asks ONE question
// - if a message ASSERTS a verification, does it say HOW? It cannot judge whether
// the verification was real; from the text alone "verified by sabotage" and
// "verified" said after doing nothing are the same words.
//
// THE FINDING IT PRODUCED IN MY OWN HISTORY, which is why it exists:
//
//     6a5b4c59  ... (opencode-go/muse-spark-1.3-contributor), brain-verified.
//     6b67da3b  merge: design system foundation (worker-written, brain-verified)
//
// "brain-verified" names a verifier and no method whatsoever. That is a self-
// declared role in the one place this repo records who did what, and it is
// exactly the fault: A CLAIM THE RECORD FILES AS FACT WITH NOTHING TO CHECK.
//
// THESE TESTS CALL THE PURE FUNCTION with synthetic rows rather than making real
// commits, because a guard that needs a commit to prove itself would have to
// pollute the history it is guarding. The real-history run is a separate,
// deliberate act and its output is in the commit that landed this file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tool = 'tools/check_commit_claims.py';

/// Run the tool's own `offenders()` over rows given as JSON.
List<String> offenders(List<(String, String)> rows) {
  final code = '''
import json, sys
sys.path.insert(0, "tools")
import check_commit_claims as c
rows = [(a, b) for a, b in json.loads(sys.argv[1])]
print(json.dumps([list(x) for x in c.offenders(rows)]))
''';
  final payload = jsonEncode([
    for (final (sha, msg) in rows) [sha, msg],
  ]);
  final r = Process.runSync('python3', ['-c', code, payload]);
  expect(r.exitCode, 0, reason: 'the tool did not import:\n${r.stdout}${r.stderr}');
  return (jsonDecode('${r.stdout}'.trim()) as List)
      .map((e) => (e as List).first as String)
      .toList();
}

void main() {
  test('an assertion with NO method is caught', () {
    final bad = offenders([
      ('aaaa111', 'fix: the thing\n\nbrain-verified.'),
    ]);
    expect(bad, contains('aaaa111'),
        reason: '"brain-verified" names a verifier and no method at all');
  });

  test('an assertion that names a method passes', () {
    expect(
      offenders([
        ('bbbb222', 'fix: the thing\n\nBites: sabotaged on disk, 2 tests fail.'),
      ]),
      isEmpty,
      reason: 'a method named is the whole requirement',
    );
  });

  test('a message with no assertion at all is not this check\'s business', () {
    // The tool is narrow on purpose. Flagging every commit would make it noise,
    // and noise is what gets a guard switched off.
    expect(
      offenders([
        ('cccc333', 'docs: rewrite the onboarding copy'),
        ('dddd444', 'chore: bump the linter'),
      ]),
      isEmpty,
    );
  });

  test('the negated forms are not assertions', () {
    expect(
      offenders([
        ('eeee555', 'fix: the thing\n\nNot verified on a real device yet.'),
        ('ffff666', 'fix: other\n\nThis is unproven and I know why.'),
      ]),
      isEmpty,
      reason: 'saying a thing is NOT verified is the honest case, not the bad one',
    );
  });

  test('the two false positives this tool produced are now NOT flagged', () {
    // Both were real messages that said how, and both were flagged by an earlier
    // matcher of mine. They are here so a third calibration cannot quietly
    // reintroduce them - a checker that cries wolf gets switched off, and then it
    // protects nothing.
    expect(
      offenders([
        ('7777aaa', 'fix(widgets): two bugs found on a real device\n'
            'Device-verified bug list is in AGENTS.md.'),
        ('8888bbb', 'feat(home): rebuild Home\n'
            'Verified: flutter analyze 160 / 0 errors; flutter test 213/213.'),
      ]),
      isEmpty,
      reason: 'these name a device, a file, a tool and a count. Flagging them '
          'was my matcher being too narrow, not the commit being weak.',
    );
  });

  test('it is honest when it cannot read anything', () {
    // Run it outside a git tree. A checker that read nothing must not exit 0.
    final dir = Directory.systemTemp.createTempSync('no_git_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final tools = Directory('${dir.path}/tools')..createSync();
    File(_tool).copySync('${tools.path}/check_commit_claims.py');
    final r = Process.runSync(
        'python3', ['${tools.path}/check_commit_claims.py', '--since', '5'],
        workingDirectory: dir.path);
    expect(r.exitCode, isNot(0),
        reason: 'no git tree means no history was read, and reading nothing is '
            'not a pass:\n${r.stdout}${r.stderr}');
  });

  test('this repo\'s last 40 commits are clean', () {
    final r = Process.runSync('python3', [_tool, '--since', '40']);
    expect(r.exitCode, 0,
        reason: 'a commit in the last 40 claims a verification and names no '
            'method - which is exactly what I did at 0f5cda68 in the other '
            'company, and it would be hypocrisy to ship the guard and fail it:\n'
            '${r.stdout}');
  });
}
