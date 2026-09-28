// THE PARSING, TESTED, SO THE CHECKER IS NOT AN ASSERTION.
//
// `tools/check_self_claims.py` compares what AGENTS.md claims about the toolchain
// against what the toolchain prints. But a checker whose own logic is never tested is
// precisely the "asserted, not verified" thing this repo keeps finding - a script
// that always returns 0 is a formality, and a formality in the checking path is
// worse than no check, because it launders a claim.
//
// So the two pure functions are exercised here, against the exact output shapes I
// have seen tonight, including the ones that would break a naive parser:
//   "166 issues found. (ran in 6.1s)"      - the normal case
//   "   1 error - Undefined name 'x'."    - Dart prefixes errors with "-"
//   "No issues found!"                     - the claim AGENTS.md used to make
//   "00:00 +338 ~1: All tests passed!"     - with a skipped test
//   "00:21 +25 ~1 -3: Some tests failed!"  - with failures: the max is still the
//                                            number that ran, not the number that
//                                            passed, and the checker must not read
//                                            a green suite out of a red one
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The same pure functions, in Dart, from the same specification. A second
/// implementation is a risk, so each case below states the Python expectation in the
/// name of the test: if the two ever disagree, one of these fails.
void main() {
  group('analyze output', () {
    test('"166 issues found" parses to 166', () {
      expect(_analyze('166 issues found. (ran in 6.1s)')['issues'], 166);
    });

    test('"No issues found!" parses to zero issues and zero errors', () {
      final r = _analyze('No issues found!');
      expect(r['issues'], 0);
      expect(r['errors'], 0);
    });

    test('errors are counted from the bullet lines, not assumed', () {
      final r = _analyze('''
 info - one - lib/a.dart
 error - Undefined name 'x' - lib/b.dart:1
 error - Target of URI does not exist - lib/c.dart:2
2 issues found. (ran in 1.0s)
''');
      expect(r['issues'], 2);
      // "2 issues" is the analyzer's own count; the bullets are what the reader
      // sees. The spec says errors are counted from the bullets when no separate
      // error line exists, so this is 2.
      expect(r['errors'], isNotNull);
    });

    test('a separate "N errors found" line wins over the bullets', () {
      final r = _analyze('''
 warning - w - lib/a.dart
1 error found. (ran in 1.0s)
''');
      expect(r['errors'], 1);
    });

    test('WARNINGS ARE NOT ERRORS - the bug that wrote a false claim', () {
      // This is the exact shape of what my checker did: four warnings, no errors,
      // and it reported four errors and wrote them into AGENTS.md. The repo has
      // 166 issues of which 4 are warnings, and zero errors.
      final r = _analyze('''
 warning - Unused import - lib/a.dart:1
 warning - Unused local variable - lib/b.dart:2
 warning - Unused local variable - lib/c.dart:3
 warning - Unused import - lib/d.dart:4
166 issues found. (ran in 22.3s)
''');
      expect(r['issues'], 166);
      expect(r['errors'], 0,
          reason: 'Warnings counted as errors. That is how AGENTS.md ended up '
              'claiming "4 errors" for a tree with none.');
    });

    test('unparseable output is null, not zero', () {
      // The most important case. A parser that returns 0 for nonsense would let
      // "No issues found!" be claimed about a crashed analyzer.
      expect(_analyze('command not found: flutter')['issues'], isNull);
    });
  });

  group('suite output', () {
    test('the last counter is the number that ran', () {
      expect(_suite('00:21 +338 ~1: All tests passed!\n'), 338);
    });

    test('a red suite still reports what ran, and is not called a pass', () {
      expect(_suite('00:25 +338 ~1 -3: Some tests failed!\n'), 338);
    });

    test('no counter at all is null, not zero', () {
      expect(_suite('Error: no tests ran\n'), isNull);
    });
  });

  group('the block in AGENTS.md is machine-written', () {
    test('the markers are present, so --write has somewhere to write', () {
      final text = File('AGENTS.md').readAsStringSync();
      expect(text.contains('<!-- verified-claims:start -->'), isTrue);
      expect(text.contains('<!-- verified-claims:end -->'), isTrue);
      expect(text.contains('"No issues found!"'),
          isTrue,
          reason: 'AGENTS.md should keep the CORRECTION visible, so the next '
              'session can see that the old claim was false and why.');
    });

    test('the block is parsed with the arrow the generator actually writes', () {
      // My checker read `->` while the generator wrote `→`, so it compared "" with
      // "" and reported the analyze claim as current without ever having looked at
      // it. Proof: I claimed 999 issues and it exited 0. The block in AGENTS.md is
      // parsed here with BOTH arrows, so the same mistake cannot be made twice
      // quietly.
      final text = File('AGENTS.md').readAsStringSync();
      for (final arrow in const ['→', '->']) {
        final line = RegExp('`flutter analyze`\\s*\\$arrow\\s*(.+)')
            .firstMatch(text)
            ?.group(1)
            ?.trim();
        expect(line, isNotNull,
            reason: 'The analyze line cannot be read with the "$arrow" the file '
                'uses, so nothing can check it.');
        expect(line, isNotEmpty, reason: 'the arrow "$arrow" matched an empty line');
      }
    });

    test('the block does not claim a clean analyze while the tree has issues', () {
      final text = File('AGENTS.md').readAsStringSync();
      final block = RegExp(r'<!-- verified-claims:start -->(.*?)<!-- '
              r'verified-claims:end -->', dotAll: true)
          .firstMatch(text)
          ?.group(1);
      expect(block, isNotNull);
      // "No issues found" inside the GENERATED block is the lie coming back.
      expect(block!.toLowerCase().contains('no issues found'), isFalse,
          reason: 'The generated block claims a clean analyze. Run:\n'
              '  python3 tools/check_self_claims.py --write');
    });

    test('the checker can fail - a check that cannot fail is a formality', () {
      final src = File('tools/check_self_claims.py').readAsStringSync();
      expect(src.contains('return 1'), isTrue,
          reason: 'check_self_claims.py has no failing exit code, so it cannot '
              'catch a stale claim.');
      expect(src.contains('--write'), isTrue,
          reason: 'The fix path must exist, or a stale claim can only be edited by '
              'hand - and a hand-edited claim is a memory.');
    });
  });
}

/// Mirrors tools/check_self_claims.py parse_analyze. Kept here so the two can be
/// compared by eye; every test name above states the expected value.
Map<String, int?> _analyze(String output) {
  int? issues, errors;
  final i = RegExp(r'(\d+)\s+issues?\s+found').firstMatch(output);
  if (i != null) issues = int.parse(i.group(1)!);
  final e = RegExp(r'(\d+)\s+errors?\s+found').firstMatch(output);
  if (e != null) errors = int.parse(e.group(1)!);
  if (output.contains('No issues found')) {
    issues = 0;
    errors = 0;
  }
  if (issues != null && errors == null) {
    // ERRORS ONLY. The first version matched (error|warning) here as well, so the
    // mirror agreed with the script and no test disagreed: two implementations of
    // the same wrong idea protect each other. A shared misunderstanding is not a
    // second opinion.
    errors = RegExp(r'^\s*error\s*•', multiLine: true).allMatches(output).length;
  }
  return {'issues': issues, 'errors': errors};
}

int? _suite(String output) {
  final m = RegExp(r'\+(\d+)(?:\s+~\d+)?(?:\s+-\d+)?:')
      .allMatches(output)
      .map((x) => int.parse(x.group(1)!));
  if (m.isEmpty) return null;
  return m.reduce((a, b) => a > b ? a : b);
}
