// A ledger nobody checks is a document.
//
// notes/FREE_TIER_ACCOUNTING.md carries a per-batch table of queries, candidates,
// accepted, rejected, model calls and money. Its own falsification section used to
// admit the defect in the first person: *"It cannot see money, so the money column
// above is asserted by the next person who runs a batch."* The columns are now
// checked against the artefacts by tools/ai_accuracy/test_free_tier_ledger.py.
//
// This wrapper exists so that guard is part of the suite that actually runs, rather
// than a script in tools/ that nobody remembers to invoke. It is the same pattern
// corpus_independence_test.dart uses for `ai_accuracy.py --corpus`: run the Python,
// do not re-derive its numbers in Dart, because two definitions of "batch" would
// drift and the note would stop matching the guard.
//
// Costs nothing: the module reads cases.json and the note, calls no network, and
// invokes no model. The network-poisoned check inside it takes well under a second.
//
// The 8-of-8 bite proof that keeps this guard from being a comment lives beside it:
// tools/ai_accuracy/prove_the_ledger_guard_bites.py

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
  test('the free-tier ledger is checkable, and its own guard bites', () {
    final py = _findPython();
    expect(py, isNotNull, reason: 'no python3 found to run the ledger guard with');

    final proc = Process.runSync(py!, <String>[
      'tools/ai_accuracy/test_free_tier_ledger.py',
    ]);

    expect(
      proc.exitCode,
      0,
      reason: 'the free-tier ledger guard is RED. The note '
          '(notes/FREE_TIER_ACCOUNTING.md) has drifted from the corpus, or has stopped '
          'claiming zero cost, or the producer now needs the network. Read the failure '
          'below before changing the note — the corpus is the fact, so the fix is '
          'almost always in the note.\n'
          '${proc.stdout}\n${proc.stderr}',
    );

    // The number of checks is asserted so that someone who empties the module does
    // not turn this into a test that passes on an empty TestCase.
    final ran = RegExp(r'Ran (\d+) tests').firstMatch(proc.stderr as String);
    expect(ran, isNotNull,
        reason: 'the ledger guard did not report a test count:\n${proc.stderr}');
    expect(int.parse(ran!.group(1)!), greaterThanOrEqualTo(6),
        reason: 'the ledger guard now runs fewer than 6 checks. If checks were '
            'removed on purpose, say so in the note; if not, this module was gutted '
            'and the green is vacuous.');
  });
}
