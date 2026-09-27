// No score without its corpus.
//
// Owner rule, 2026-09-28: a score may only be quoted alongside the corpus it
// came from — how many cases, which dishes, how many breakfast, how many
// non-breakfast. Otherwise the number is worthless, because its meaning comes
// entirely from what was measured.
//
// This caught me twice in one evening. I reported 15.4% as if it described the
// app, and it described twelve easy North-Indian cases. Widening the corpus to
// seventeen moved the same unchanged app to 20.0%.
//
// So the machine checks it: any note that quotes a median error must also
// state its corpus. A note with a number and no corpus FAILS.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A score, in the shapes I actually write them.
final _scorePatterns = <RegExp>[
  RegExp(r'median (?:calorie )?error', caseSensitive: false),
  RegExp(r'median_kcal_error_pct'),
  RegExp(r'\b\d{1,2}\.\d\s*%'), // e.g. "19.1%" or "20.0%"
];

/// What a note must say for that score to mean anything.
const _corpusMarkers = <String>[
  'cases',        // how many
  'breakfast',    // the composition
  'corpus',       // or an explicit reference to the corpus
  // Added 2026-09-28. A case count is not a fact count: the corpus is 22 cases
  // over 17 distinct dish families, and three families repeat, so a median over
  // cases is a median over cases. Quoting only the case count is how "22 cases"
  // became a sample size in my own notes. test/corpus_independence_test.dart
  // owns the counting; this one owns the rule that the number travels with it.
  'distinct',     // how many DISTINCT dishes, not just how many cases
];

void main() {
  test('every note quoting a score also states its corpus', () {
    final offenders = <String>[];
    final notes = Directory('notes');
    expect(notes.existsSync(), isTrue, reason: 'notes/ must exist');

    for (final entity in notes.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final text = entity.readAsStringSync();
      final quotesAScore = _scorePatterns.any((p) => p.hasMatch(text));
      if (!quotesAScore) continue;
      final statesCorpus =
          _corpusMarkers.every((m) => text.toLowerCase().contains(m));
      if (!statesCorpus) {
        final missing = _corpusMarkers
            .where((m) => !text.toLowerCase().contains(m))
            .toList();
        offenders.add('${entity.path}: quotes a score but never says $missing');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A note quotes a score without stating the corpus behind it, so the\n'
          'number cannot be interpreted. Add how many cases, which dishes, and\n'
          'how many breakfast vs non-breakfast. A score without its corpus is\n'
          'the single most misleading thing this repo can publish.\n\n'
          '${offenders.join('\n')}\n',
    );
  });

  test('the corpus itself is described, not just counted', () {
    // The count alone is not enough either: 20 idlis is not 20 meals. Require
    // the composition to be visible in the corpus file.
    final cases = File('tools/ai_accuracy/cases.json').readAsStringSync();
    expect(
      cases.contains('_readme'),
      isTrue,
      reason: 'cases.json must carry a _readme describing the corpus.',
    );
    expect(
      RegExp(r'breakfast', caseSensitive: false).hasMatch(cases),
      isTrue,
      reason: 'cases.json must state its breakfast/non-breakfast composition. '
          'A corpus of only breakfast items flatters the score.',
    );
  });

  test('a deleted corpus note cannot leave a bare score behind', () {
    // Belt and braces: if someone adds a new note with a score, the test above
    // catches it. This one makes sure the guard itself cannot be quietly
    // narrowed by emptying the notes directory.
    final md = Directory('notes')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(
      md.length,
      greaterThanOrEqualTo(5),
      reason: 'notes/ has almost no markdown left. The corpus rule needs the '
          'notes that quote scores to exist for the guard to mean anything.',
    );
  });
}
