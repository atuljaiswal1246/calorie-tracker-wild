// ORDER 9 MADE INTO A MACHINE: every decision has something that can disagree
// with it.
//
// "A claim about my own work is not evidence" is a rule until each decision is
// paired with a test that would FAIL if the decision stopped being true. That is
// the only form of this rule a future session can check without trusting me, and
// the pairing is the point: a decision with no behavioural test behind it is a
// decision I am reporting on faith.
//
// WHY "SYMBOL" AND NOT "THE TEST FILE EXISTS". The vocababulary failure of this
// repo is a guard that passes while the feature is dead: it greps a source file
// for the words of a feature, and the words are there, and the feature is not.
// test/abstain_path_test.dart did exactly that for a day while the abstain flag
// was set and cleared two lines apart. So each row below names a SYMBOL the
// evidence test must actually exercise - a pure function, a widget, or a harness
// flag. A string check cannot satisfy this table, because a string check cannot
// call anything.
//
// A note on what this table is NOT: passing it does not mean these features are
// correct. It means each one is now falsifiable, and the failure will be loud.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// (decision, who decided it, implementation, evidence test, symbol the evidence
///  must exercise)
const _decisions = <List<String>>[
  [
    'ABSTAIN: a wrong number is worse than no number',
    'owner, 2026-09-28',
    'lib/screens/capture_screen.dart',
    'test/abstain_state_machine_test.dart',
    'scanOutcome(',
    'function',
  ],
  [
    'ABSTAIN: the card the user actually sees',
    'owner, 2026-09-28',
    'lib/widgets/abstain_card.dart',
    'test/abstain_card_render_test.dart',
    'AbstainCard(',
    'widget',
  ],
  [
    'TRIAL LOCKS: six surfaces paywalled when the trial ends',
    'owner, 2026-09-21',
    'lib/screens/home_screen.dart',
    'test/trial_gate_routes_test.dart',
    'gateDecision(',
    'function',
  ],
  [
    'MONEY GATE: /health before any scan, ceiling in money',
    'CEO, 2026-09-28 (order 8)',
    'tools/ai_accuracy.py',
    'test/money_gate_test.dart',
    '--self-test',
    'process',
  ],
  [
    'ABSTENTION IS SCORED AS AN ABSTENTION, not as 0 kcal',
    'owner, 2026-09-28',
    'tools/ai_accuracy.py',
    'test/abstain_scoring_test.dart',
    'unrecognised',
    'process',
  ],
  [
    'THE A/B RUNS: side-by-side mechanism, no silent no-op',
    'ROADMAP M1',
    'tools/ai_accuracy.py',
    'test/compare_path_test.dart',
    '--compare',
    'process',
  ],
  [
    'REPORT TIMES ARE MACHINE-READ, never typed',
    'CEO, 2026-09-28',
    'tools/report_to_jarvis.py',
    'test/report_clock_test.dart',
    'tools/now.py',
    'process',
  ],
  [
    'CORPUS HONESTY: a case count is not a fact count',
    'CEO, 2026-09-28',
    'tools/ai_accuracy.py',
    'test/corpus_independence_test.dart',
    '--corpus',
    'process',
  ],
  [
    'LOCKED SCREENS: eight screens the owner said not to change',
    'owner, 2026-09-15 (AGENTS.md)',
    'test/goldens/paywall.png',
    'test/locked_screens_golden_digests_test.dart',
    'lockedGoldenDigests',
    'data',
  ],
  [
    'CORPUS INTEGRITY: every case has its photo on disk',
    'CEO, 2026-09-28',
    'tools/ai_accuracy.py',
    'test/corpus_photos_present_test.dart',
    'cases.json',
    'data',
  ],
];

void main() {
  test('every owner decision has evidence that can disagree with me', () {
    final problems = <String>[];
    for (final row in _decisions) {
      final decision = row[0];
      final who = row[1];
      final impl = row[2];
      final evidence = row[3];
      final symbol = row[4];

      if (!File(impl).existsSync()) {
        problems.add('$decision ($who): $impl does not exist, so the decision '
            'is either gone or was never where I said it was');
        continue;
      }
      final testFile = File(evidence);
      if (!testFile.existsSync()) {
        problems.add('$decision ($who): $evidence is missing. A decision with no '
            'test is a decision I am reporting on faith.');
        continue;
      }
      final src = testFile.readAsStringSync();
      if (!src.contains(symbol)) {
        problems.add('$decision ($who): $evidence never exercises "$symbol", so '
            'it cannot fail when the decision stops being true. A guard that '
            'only READS a source file is not evidence - it is vocabulary.');
      }
    }
    expect(problems, isEmpty,
        reason: 'Decisions without falsifiable evidence:\n\n'
            '${problems.join('\n')}\n');
  });

  test('the table is not allowed to shrink quietly', () {
    // Order 9 is only as good as the list behind it. If a row is deleted, the
    // count moves and this fails - the same trick as the locked-surface list,
    // which caught me asserting the owner named seven when he named six.
    expect(_decisions.every((r) => r.length == 6), isTrue,
        reason: 'Every row needs six columns: decision, who, implementation, '
            'evidence test, symbol, and the kind of evidence.');
    expect(_decisions, hasLength(10),
        reason: 'The number of paired decisions changed from 10. A row was added '
            'or removed. If it was removed, say in a commit which decision lost '
            'its evidence and why. If one was added, make sure its test really '
            'exercises the symbol named.');
  });

  test('the kinds of evidence are declared, true, and not all the same', () {
    // I first wrote a check that flagged any evidence file which only READS
    // source, and it flagged three of my own files - including two that genuinely
    // call pure functions and one that checks files on disk, which IS the
    // behaviour "every case has its photo on disk" is about. Then I noticed what
    // the check was: a detector of test STYLE. A style detector is a vocabulary
    // check, which is the exact class of check order 9 says does not work, and it
    // would have been satisfied by writing the word testWidgets in a file.
    //
    // So it is replaced. Each row DECLARES the kind of evidence it has, the
    // declaration is checked against what the file does, and the table must
    // cover all three kinds - so the set cannot be satisfied entirely by string
    // greps, or entirely by one technique.
    // 'data' accepts either way of reading a real artefact. I first narrowed it
    // to readAsStringSync and the locked-screens test failed for reading PNG
    // BYTES, which is the correct way to digest a PNG. The two options were: bend
    // the digest test into reading its PNGs as text, or fix the over-narrow
    // definition. Fixing it is the honest one - the rule is "touches the real
    // artefact", and how it reads bytes is not the point.
    const markers = <String, List<String>?>{
      'function': null, // it must call the pure function named in the row
      'widget': ['testWidgets('],
      'process': ['Process.runSync'],
      'data': ['readAsStringSync', 'readAsBytesSync'],
    };
    final problems = <String>[];
    final seen = <String>{};
    for (final row in _decisions) {
      final decision = row[0];
      final evidence = row[3];
      final symbol = row[4];
      final kind = row[5];
      seen.add(kind);
      if (!markers.containsKey(kind)) {
        problems.add('$decision: unknown evidence kind "$kind"');
        continue;
      }
      final src = File(evidence).readAsStringSync();
      if (kind == 'function') {
        if (!src.contains(symbol)) {
          problems.add('$decision: declared a function test but never calls '
              '$symbol');
        }
        continue;
      }
      final options = markers[kind]!;
      if (!options.any(src.contains)) {
        problems.add('$decision: declared "$kind" evidence but $evidence never '
            'uses any of ${options.join(' / ')}. Declare what it really is '
            'instead of bending the file to the label.');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    for (final kind in const ['function', 'widget', 'process', 'data']) {
      expect(seen, contains(kind),
          reason: 'No decision is evidenced by a $kind check. The whole table '
              'can then be satisfied by one technique, and one technique is '
              'what misses things.');
    }
  });
}
