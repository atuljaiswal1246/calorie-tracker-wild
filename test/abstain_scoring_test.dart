// AN ABSTENTION IS AN ANSWER. The harness could not tell the difference.
//
// The owner personally decided this app should say "I don't recognise this dish"
// and offer to name it, rather than log a number the user cannot verify. The
// prompt asks the model for `"unrecognised": true` and the app parses it. The
// accuracy harness did NOT: score_case read `items`, found none, and scored the
// case as zero calories with every item missed.
//
// That is the worst-looking number a correct behaviour can produce. A median that
// folded abstentions in would have argued AGAINST the feature the owner chose, and
// the "fix" it invites - tell the model to answer anyway - is the exact failure
// the decision was made to prevent. No run could ever have told me, because no
// abstention had ever been measured.
//
// So this test drives a stub where every third scan abstains, and asserts:
//   - the abstain is counted, not scored
//   - it is excluded from the median, and the run says so
//   - it is not an invention and not a miss
//   - it is not UNMEASURED either, because it is not a missing measurement
// Three outcomes, three labels, because they lead to three different decisions.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String? _python() {
  for (final c in const [
    '/opt/anaconda3/bin/python3',
    '/usr/bin/python3',
    '/opt/homebrew/bin/python3',
    '/usr/local/bin/python3',
  ]) {
    if (File(c).existsSync()) return c;
  }
  final onPath = Process.runSync('/bin/sh', ['-c', 'command -v python3']);
  final p = (onPath.stdout as String).trim();
  return onPath.exitCode == 0 && p.isNotEmpty ? p : null;
}

void main() {
  final tmp = Directory.systemTemp.createTempSync('cm_abstain_');
  final jsonPath = '${tmp.path}/abstain.json';

  late ProcessResult result;
  late String out;
  late Map<String, dynamic> summary;
  late List<dynamic> rows;

  setUpAll(() {
    final py = _python();
    expect(py, isNotNull,
        reason: 'python3 not found, so abstention handling cannot be verified.');
    result = Process.runSync(py!, ['tools/ai_accuracy.py', '--stub',
        '--repeat', '1', '--json', jsonPath]);
    out = '${result.stdout}${result.stderr}';
    final payload =
        jsonDecode(File(jsonPath).readAsStringSync()) as Map<String, dynamic>;
    summary = (payload['shipped'] as Map<String, dynamic>)['summary']
        as Map<String, dynamic>;
    rows = (payload['shipped'] as Map<String, dynamic>)['rows'] as List<dynamic>;
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('the stub produces abstentions as well as answers', () {
    expect(result.exitCode, 0, reason: 'the stubbed run failed\n$out');
    expect(summary['abstained'], isA<num>(), reason: 'No abstention count.\n$out');
    expect(summary['abstained'] as num, greaterThan(0),
        reason: 'The stub did not abstain on any case, so none of the arithmetic '
            'below was exercised. That is how the original gap survived: the '
            'path that needed testing was the path that never ran.\n$out');
    expect(summary['scored'] as num, greaterThan(0),
        reason: 'No answered scans either - the stub must exercise BOTH '
            'paths in one run.\n$out');
  });

  test('an abstention is not scored as a wrong number', () {
    final abstained =
        rows.where((r) => (r as Map<String, dynamic>)['abstained'] == true).toList();
    expect(abstained, isNotEmpty, reason: 'No abstained row found.\n$out');
    for (final raw in abstained) {
      final r = raw as Map<String, dynamic>;
      expect(r['pred_kcal'], isNull,
          reason: '${r['id']}: an abstention reported ${r['pred_kcal']} kcal. '
              'Declining to name a dish is not a calorie estimate, and a number '
              'here is exactly the number that would argue against the feature '
              'the owner chose.\n$out');
      expect(r['kcal_error_pct'], isNull,
          reason: '${r['id']}: an abstention has a calorie error. There is no '
              'prediction to be wrong about.\n$out');
      expect(r['invented'], isEmpty,
          reason: '${r['id']}: an abstention cannot invent a dish. Inventing is '
              'the failure this feature exists to prevent, so counting one here '
              'would punish the model for not doing it.\n$out');
      expect(r['missed'], isEmpty,
          reason: '${r['id']}: an abstention is not "missing" the truth - it '
              'declined to answer, which is a different thing with a different '
              'fix.\n$out');
    }
  });

  test('an abstention is not UNMEASURED either', () {
    // Three outcomes, three labels. UNMEASURED means nothing came back, which
    // asks "did the request fail". An abstention means something came back and
    // it was a refusal to name the dish, which asks a completely different
    // question. Collapsing them would hide the feature in the error count.
    final abstained = rows
        .where((r) => (r as Map<String, dynamic>)['abstained'] == true)
        .toList();
    for (final raw in abstained) {
      final row = raw as Map<String, dynamic>;
      final status = row['status'] as String?;
      expect(status, isNotNull, reason: 'An abstained row has no status.\n$out');
      expect(status, isNot(contains('UNMEASURED')),
          reason: 'An abstention was labelled as an UNMEASURED measurement. '
              'It is a real answer and it must not disappear into the '
              'unmeasured bucket.\n$out');
      expect(status, contains('ABSTAINED'),
          reason: 'The status must say ABSTAINED, so a reader of the table can '
              'tell a refusal from a failure.\n$out');
    }
    expect(summary['unmeasured'], 0,
        reason: 'The stub answers every scan (one way or the other), so nothing '
            'should be unmeasured. If this is non-zero, abstentions are being '
            'filed as missing measurements.\n$out');
  });

  test('the median is over ANSWERED scans, and the run says which', () {
    expect((summary['scored'] as num) + (summary['abstained'] as num),
        summary['meals'],
        reason: 'answered + abstained must account for every scan; anything else '
            'is a case being quietly dropped from the accounting.');
    expect(summary['median_excludes_abstained'], summary['abstained'],
        reason: 'The summary must state how many scans the median excludes.\n$out');
    expect(summary['abstain_rate_pct'], isA<num>(),
        reason: 'No abstain RATE. A count without a rate cannot be compared '
            'between a 12-case and a 31-case corpus.\n$out');
    expect(out.contains('Report the two together or neither'), isTrue,
        reason: 'A run that reports a median over answered scans must say so, '
            'or the number reads as a number over all scans.\n$out');
    expect(out.contains('an abstention is an answer'), isTrue,
        reason: 'The run must state why an abstention is excluded from the '
            'median, in words.\n$out');
  });

  test('the source still recognises the flag the app\'s prompt asks for', () {
    // The contract with the app: the prompt asks for "unrecognised": true. If
    // the key is renamed in the Dart prompt and not here, every abstention goes
    // back to being scored as a zero-calorie miss - silently, and only visible
    // in a median.
    final dart = File('lib/services/openai_service.dart').readAsStringSync();
    expect(dart.contains('"unrecognised"'),
        isTrue, reason: 'The app prompt no longer asks for "unrecognised". The '
            'harness scores that key by name, so rename it in both places or '
            'abstention scoring breaks silently.');
    final src = File('tools/ai_accuracy.py').readAsStringSync();
    expect(src.contains('result.get("unrecognised") is True'),
        isTrue, reason: 'score_case no longer recognises an abstention. That is '
            'the exact defect this file exists to prevent, reintroduced.');
  });
}
