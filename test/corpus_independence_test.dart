// A case count is not a fact count.
//
// Order 6 says name the producer of every number. The corpus IS part of the
// producer, and until tonight I was quoting case counts as if they were the
// sample size. They are not.
//
// Measured 2026-09-28 (tools/ai_accuracy.py --corpus, cases.json @ 22 cases):
// 22 cases over **17 distinct dish families**; 8 of 22 cases sit in a family
// that appears more than once — dal x3, chole x3, sambar x2. So a family's
// error carries up to 3x the weight of a family that appears once, and only 14
// cases are the sole case of their family. The owner's bar is 20 MEALS, i.e. 20
// distinct dishes: **17 < 20, so the bar is not met** on the honest measure.
//
// The trap is the same trap the _readme already documents for the SEARCH (8 of
// 16 candidates were bhindi, 8 of 18 were masala dosa): I escaped it in the
// candidate list and carried it into the corpus itself.
//
// This test EXECUTES `tools/ai_accuracy.py --corpus` rather than re-deriving a
// family count in Dart, because two definitions of "family" would drift and the
// note would stop matching the guard. Costs nothing: it reads cases.json and
// never calls a model.

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

/// "CORPUS: 22 cases over 17 distinct dish families; 8 of 22 ..."
final _header = RegExp(
    r'CORPUS:\s*(\d+)\s*cases over\s*(\d+)\s*distinct dish families;\s*(\d+) of (\d+) cases');

void main() {
  late ProcessResult report;
  late String out;
  late int cases;
  late int families;
  late int inRepeated;

  setUpAll(() {
    final py = _findPython();
    expect(py, isNotNull,
        reason: 'python3 not found, so corpus independence cannot be checked. '
            'Fail, do not skip: an unchecked corpus is a mis-stated number.');
    report =
        Process.runSync(py!, ['tools/ai_accuracy.py', '--corpus']);
    out = '${report.stdout}${report.stderr}';
    final m = _header.firstMatch(out);
    expect(m, isNotNull,
        reason: 'The independence header is gone or reworded. If the harness '
            'no longer prints the case/family split, this test cannot see what '
            'a reader sees, and it must be rewritten to match reality.\n$out');
    cases = int.parse(m!.group(1)!);
    families = int.parse(m.group(2)!);
    inRepeated = int.parse(m.group(3)!);
  });

  test('the corpus report runs and costs nothing', () {
    expect(report.exitCode, 0, reason: '--corpus failed.\n$out');
  });

  test('a case count is never reported as if it were a fact count', () {
    // The whole point: these are two different numbers, and the honest one is
    // smaller. If they are equal the corpus has no duplication and this file is
    // stale; if cases < families the accounting is broken.
    expect(
      families,
      lessThanOrEqualTo(cases),
      reason: 'More families than cases means the counting is wrong, and every '
          'number built on it is wrong.\n$out',
    );
    expect(
      families,
      lessThan(cases),
      reason: 'Cases == families, so this corpus happens to be independent. '
          'If that is really true, delete the duplication facts from '
          'cases.json _readme and this expectation with them - but do not leave '
          'both claiming to be true.\n$out',
    );
  });

  test('the duplication is named, with the families and their counts', () {
    expect(out, contains('repeated:'),
        reason: 'A duplicated corpus that does not say which families are '
            'duplicated is a hidden duplication.\n$out');
    for (final family in const ['dal', 'chole', 'sambar']) {
      expect(
        out,
        contains(family),
        reason: 'A family that repeats in cases.json is missing from the '
            'report. The three known repeats are dal x3, chole x3, sambar x2; '
            'if one has been fixed, this test should be updated to say so '
            'rather than loosened.\n$out',
      );
    }
    expect(
      inRepeated,
      greaterThan(0),
      reason: 'inRepeated is 0, so the report and the warning disagree.\n$out',
    );
  });

  test('no dish family is over the cap — the search trap cannot come back', () {
    // dal x3 and chole x3 are AT the cap. A fourth dal is the trap returning,
    // and it would be invisible in a case count.
    expect(
      out,
      isNot(contains('are over the cap')),
      reason: 'A family has exceeded FAMILY_REPEAT_CAP in tools/ai_accuracy.py. '
          'That is the duplicate trap re-entering the corpus, which is exactly '
          'what batches 1-3 each hit and I thought I had solved by searching '
          'dish by dish. Fix the corpus, do not raise the cap.\n$out',
    );
  });

  test('the declared numbers in cases.json still match the corpus', () {
    // The _readme states the counts in prose. If the corpus changes and the
    // prose does not, the note is a lie and every score quoted through it
    // inherits the lie.
    final readme = File('tools/ai_accuracy/cases.json').readAsStringSync();
    // Case-insensitive on purpose: the check is about the NUMBERS being current,
    // not about how the sentence capitalises "distinct". A guard that fails on
    // capitalisation trains you to uppercase things, which is not the habit I
    // want. (5th instance of a guard failing on my wording rather than on a
    // defect — reported, not hidden.)
    final declared = '$cases cases over $families distinct dish families';
    expect(
      readme.toLowerCase().contains(declared),
      isTrue,
      reason: 'cases.json _readme does not declare "$declared", which is what '
          'the corpus actually contains. Update the _readme with the real '
          'numbers.\n$out',
    );
    expect(
      readme.contains('17 < 20') || readme.contains('$families < 20'),
      isTrue,
      reason: 'The _readme must state the honest position against the bar: '
          '20 MEALS = 20 distinct dishes, and we have $families. Delete the '
          'claim only if the corpus genuinely reaches 20 distinct families.',
    );
  });

  test('a run prints the independence split, not just the case count', () {
    final src = File('tools/ai_accuracy.py').readAsStringSync();
    expect(
      src.contains('print_independence(cases)'),
      isTrue,
      reason: 'The run header must print the corpus split. A run that prints '
          '"cases: 22" and nothing else is what I have been reading.',
    );
    expect(
      src.contains('20 MEALS = 20 distinct dishes'),
      isTrue,
      reason: 'The bar must be quoted in distinct dishes wherever it is quoted '
          'in the harness.',
    );
  });

  // ---- a dish NAME is not a dish CLASS -------------------------------------
  //
  // "Dal", "Dal Makhani" and "Urad Dal" are three names and ONE judgement. Same
  // for Chole / Chana Masala, and Palak Paneer / Matar Paneer. Measured 2026-09-28
  // on the same 22 cases: 17 distinct names, but only **13 dish classes**, and
  // dal+chole+sambar alone hold 14 of the 22 cases. I reported 17 to Jarvis at
  // 02:45 as the honest figure. 13 is more honest, and 20 meals is further
  // away than 17 suggested.
  test('the dish-CLASS count is reported, and it is never larger than the name count', () {
    final m =
        RegExp(r'DISH CLASSES:\s*(\d+)\s*distinct classes').firstMatch(out);
    expect(m, isNotNull,
        reason: 'The dish-class line is gone. Without it the corpus looks like '
            '17 independent meals.\n$out');
    final classes = int.parse(m!.group(1)!);
    expect(
      classes,
      lessThanOrEqualTo(families),
      reason: 'Classes cannot outnumber names.\n$out',
    );
    expect(
      classes,
      lessThan(families),
      reason: 'Classes == names, so DISH_CLASS is empty or the map is gone. '
          'That makes every class number a restatement of the name count, which '
          'is the number I got wrong.\n$out',
    );
  });

  test('the coverage number is printed too, so the conservative one cannot be hidden', () {
    // 26 distinct classes across EVERY labelled item, because a thali holds four
    // judgements and class_of() only sees the first non-staple. Publishing only
    // the flattering one would be me choosing my own number.
    final m =
        RegExp(r'COVERAGE:\s*(\d+)\s*distinct classes').firstMatch(out);
    expect(m, isNotNull,
        reason: 'The coverage line is gone, so only the conservative number is '
            'visible and the generous one has quietly disappeared.\n$out');
    final coverage = int.parse(m!.group(1)!);
    final classes =
        int.parse(RegExp(r'DISH CLASSES:\s*(\d+)').firstMatch(out)!.group(1)!);
    expect(
      coverage,
      greaterThan(classes),
      reason: 'Coverage counts every labelled item and must exceed the '
          'case-level class count.\n$out',
    );
    expect(
      out,
      contains('judged on $classes'),
      reason: 'The harness must say which number the bar is judged on, or the '
          'choice is silent and therefore mine.\n$out',
    );
  });

  test('the declared class count in cases.json still matches the corpus', () {
    final classes =
        int.parse(RegExp(r'DISH CLASSES:\s*(\d+)').firstMatch(out)!.group(1)!);
    final readme = File('tools/ai_accuracy/cases.json').readAsStringSync();
    expect(
      readme.contains('$classes distinct dish classes') ||
          readme.contains('$classes distinct dish CLASSES'),
      isTrue,
      reason: 'cases.json _readme does not declare "$classes distinct dish '
          'classes", which is what the corpus now measures. If you changed a '
          'DISH_CLASS mapping or added a case, update the _readme with the '
          'real number rather than deleting this.\n$out',
    );
  });
}
