// The corpus is 42 PHOTOGRAPHS, and nothing was checking that they are 42 photographs.
//
// corpus_independence_test.dart is a guard on the corpus ARITHMETIC: it re-derives
// the declared counts and the concentration from `ai_accuracy.py --corpus` and goes
// red when the note goes stale. Both corpus guards until now were about numbers. This
// one is about the images behind them, because this card's headline number is a CLASS
// COUNT and a duplicate photograph is two cases of one class wearing two names.
//
// The sharpest version of that failure is a re-encoded copy: different bytes, same
// picture. It passes every sha256 check in existence and inflates the class count
// without changing a single byte-hash. So the module under test uses the fetcher's own
// dHash, imported rather than restated, and the bite proof includes a breach that
// re-encodes one photograph over another to show the perceptual check is doing work
// the cheap check cannot.
//
// Measured by the module on the corpus as committed: 42 cases, 42 open, 0
// byte-identical pairs, 0 pairs within NEAR_DUP_DISTANCE, closest pair hamming 13
// against a floor of 8 across 861 comparisons. The three repeated families (baingan,
// aloo gobi, kofta) are different photographs of the same dish, not the same
// photograph twice.
//
// Costs nothing and takes under two seconds: it opens 42 local JPEGs, calls no
// network and no model.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  test('the corpus is made of distinct, real photographs', () {
    final py = _findPython();
    expect(py, isNotNull, reason: 'no python3 found to run the guard with');

    final proc = Process.runSync(py!, <String>[
      'tools/ai_accuracy/test_the_corpus_photographs_are_distinct.py',
    ]);

    expect(
      proc.exitCode,
      0,
      reason: 'the photograph-distinctness guard is RED. Either a case names an image '
          'that is missing, empty or undecodable, or two cases are the same picture — '
          'which is the duplicate that inflates the class count this card reports. '
          'Read the failure below; do not fix it by widening the threshold.\n'
          '${proc.stdout}\n${proc.stderr}',
    );

    final ran = RegExp(r'Ran (\d+) tests').firstMatch(proc.stderr as String);
    expect(ran, isNotNull,
        reason: 'the guard did not report a test count:\n${proc.stderr}');
    expect(int.parse(ran!.group(1)!), greaterThanOrEqualTo(5),
        reason: 'the photograph guard now runs fewer than 5 checks. If checks were '
            'removed deliberately, say so in the module; if not, it was gutted and '
            'this green is vacuous.');
  });
}
