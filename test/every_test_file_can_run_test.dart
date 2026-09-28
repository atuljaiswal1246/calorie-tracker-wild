// A repo that has no instrument for what it does not know will be told once, by
// a human, in a chat, and then forget it.
//
// THE FINDING THIS PINS, from the other company on 2026-09-29: 34 of its test
// files declared ZERO test cases, 14 of them written that night, in the comments
// and health area where its real faults lived. Their runner printed the sentence
// on every single run:
//
//     a test file with no unittest.TestCase is a check that cannot run,
//     and a check that cannot run is a check that passes
//
// The important half is the second clause. An inert file is not a weak check. It
// is an ABSENT check that reports success, and it grows silently, because
// nothing about it is ever surprising.
//
// I MEASURED THIS REPO AND IT IS CLEAN, and that is the part that made this
// file necessary. 68 test files under test/, zero without a `test()` or
// `testWidgets()`, checked at 03:05. That measurement is worth nothing by
// morning, because I made it with a shell loop I typed into a terminal and then
// discarded. So `tools/check_tests_can_run.py` now says it again, on every claim
// run, and these tests pin that it is telling the truth in BOTH directions.
//
// BOTH DIRECTIONS MATTER, and that is not symmetry for its own sake. The first
// version of the matcher anchored on line-start and reported
// `void main() { test('x', () {}); }` as INERT - a file that demonstrably runs.
// A false positive here is the same class of fault as the false negatives it was
// built to catch: the instrument contradicting reality. A guard that cries wolf
// gets switched off, and then the real thing is invisible again.
//
// So: an inert file must be reported, a file with an inline `test()` must not
// be, a file whose only mention of the word is in a comment must be reported
// (a comment is not a case), and a file that calls `expect(` and `subtest(` must
// be reported, because neither is a declaration.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tool = 'tools/check_tests_can_run.py';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tests_can_run_');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void write(String name, String body) =>
      File('${dir.path}/$name').writeAsStringSync(body);

  ProcessResult run([List<String> extra = const []]) => Process.runSync(
      'python3', [_tool, '--dir', dir.path, ...extra]);

  test('an inert file is reported and exits non-zero', () {
    write('a_inert_test.dart', 'void main() {}\n');
    final r = run();
    expect(r.exitCode, 1,
        reason: 'a file declaring no case cannot fail, so it passes forever:\n'
            '${r.stdout}');
    expect('${r.stdout}', contains('a_inert_test.dart'));
  });

  test('a case declared INLINE is not reported - and this is the one that was '
      'wrong first', () {
    write('b_inline_test.dart',
        "import 'package:flutter_test/flutter_test.dart';\n"
        "void main() { test('x', () {}); }\n");
    final r = run();
    expect(r.exitCode, 0,
        reason: 'this file DOES declare a case and does run. Reporting it as '
            'inert is the instrument disagreeing with reality:\n${r.stdout}');
  });

  test('a file whose only mention of the word is a comment IS reported', () {
    // A comment saying "this is a test" is not a case. A matcher that counted
    // the word would pass this file forever.
    write('c_comment_only_test.dart',
        '// this is a test file, honestly\nvoid helper() {}\n');
    final r = run();
    expect(r.exitCode, 1,
        reason: 'a comment is not a declaration:\n${r.stdout}');
    expect('${r.stdout}', contains('c_comment_only_test.dart'));
  });

  test('lookalike calls are not declarations', () {
    // `expect(` and `subtest(` both contain the letters, and neither creates a
    // case. This is the other direction of the same mistake.
    write('d_lookalike_test.dart',
        "void main() { expect(1, 1); subtest('y', 1); }\n");
    final r = run();
    expect(r.exitCode, 1,
        reason: 'neither expect() nor subtest() declares a case:\n${r.stdout}');
  });

  test('testWidgets counts, because a widget test is a case', () {
    write('e_widgets_test.dart',
        "void main() { testWidgets('x', (t) async {}); }\n");
    expect(run().exitCode, 0,
        reason: 'a widget test is a real case:\n${run().stdout}');
  });

  test('a directory it cannot read is an ERROR, never a pass', () {
    final r = Process.runSync(
        'python3', [_tool, '--dir', '${dir.path}/does_not_exist']);
    expect(r.exitCode, 1,
        reason: 'a checker that read nothing must not report success:\n'
            '${r.stdout}${r.stderr}');
  });

  test('THIS repo is clean right now, and that is a measurement not a hope', () {
    final r = Process.runSync('python3', [_tool]);
    expect(r.exitCode, 0,
        reason: 'test/ declares an inert file, or the tool is looking at the '
            'wrong directory:\n${r.stdout}${r.stderr}');
    expect('${r.stdout}', contains('0 of them declare no case'));
  });

  test('the JSON says the same thing as the table', () {
    write('f_inert_test.dart', 'void main() {}\n');
    final r = run(['--json']);
    expect(r.exitCode, 1);
    final d = jsonDecode('${r.stdout}') as Map<String, dynamic>;
    expect(d['files'], 1);
    expect(d['ok'], isFalse);
    expect(d['inert'], contains('f_inert_test.dart'));
  });

  test('the claim runner carries it, so it runs with everything else', () {
    // A checker nothing invokes is a checker that will be true by accident.
    final src = File('tools/check_all_claims.py').readAsStringSync();
    expect(src, contains('_script("tools/check_tests_can_run.py")'),
        reason: 'this instrument has to be a row in the claim runner, or it is '
            'just a file somebody wrote once.');
  });
}
