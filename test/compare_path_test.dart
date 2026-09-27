// M1's second obligation - "run it twice, old prompt vs new prompt, side by
// side" - had code that had NEVER BEEN EXECUTED. The one paid run in the morning
// is too expensive to discover a bug in it, so the path is now exercised for
// free by `--stub`: the whole loop, both printed blocks, the A/B table and the
// JSON run exactly as they would for real, and the model is never called.
//
// This test drives that path. It is the reason the owner does not have to pay to
// find out that --compare throws.
//
// Two traps it closes, both of which cost nothing to close:
//   1. A stub that printed a plausible median without saying it was synthetic
//      would be a trap with a table. The banner is required.
//   2. An A/B whose two prompts are IDENTICAL produces a beautiful, meaningless
//      table - and the ref that does that is HEAD~1, which is what you would
//      reach for by reflex. The harness must say so out loud.

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
  final tmp = Directory.systemTemp.createTempSync('cm_compare_');
  final jsonPath = '${tmp.path}/ab.json';

  late ProcessResult result;
  late Map<String, dynamic> payload;
  late String out;

  setUpAll(() {
    final py = _python();
    expect(py, isNotNull, reason: 'python3 not found, so the A/B path cannot be '
        'verified before spending the owner\'s money on it. Fail, do not skip.');

    // A ref whose prompt genuinely differs from the working tree's, found from
    // git rather than hardcoded, so this survives a rebase.
    const finder = '''
import sys, hashlib
sys.path.insert(0, "tools")
import ai_accuracy as H
head = H.image_prompt()
out = subprocess = None
import subprocess as sp
refs = sp.run(["git","log","--format=%h","-25","--","lib/services/openai_service.dart"],
              capture_output=True, text=True).stdout.split()
for r in refs:
    try:
        p = H.image_prompt(r)
    except SystemExit:
        continue
    if p != head:
        print(r)
        break
''';
    final found = Process.runSync(py!, ['-c', finder]);
    final ref = (found.stdout as String).trim();
    expect(ref, isNotEmpty,
        reason: 'No commit in the last 25 touching openai_service.dart has a '
            'different image prompt, so --compare cannot be shown to compare '
            'two prompts. Change a prompt, or extend the search.');

    result = Process.runSync(py, [
      'tools/ai_accuracy.py', '--compare', ref, '--stub', '--repeat', '1',
      '--json', jsonPath,
    ]);
    out = '${result.stdout}${result.stderr}';
    payload = jsonDecode(File(jsonPath).readAsStringSync())
        as Map<String, dynamic>;
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('the A/B path runs to completion', () {
    expect(result.exitCode, 0, reason: 'A stubbed A/B failed.\n$out');
    expect(payload['stub'], isTrue, reason: 'The JSON does not record that '
        'this was a stub run. A run that cannot be identified as a stub in its '
        'own output is a stub someone will quote.\n$out');
  });

  test('it is announced as synthetic, loudly, before any number', () {
    expect(out.contains('STUB MODE'), isTrue,
        reason: 'A stub that prints a plausible median without saying it is '
            'synthetic is a trap with a table.\n$out');
    expect(out.contains('meaningless as accuracy'), isTrue,
        reason: 'The banner must say the numbers are not accuracy.\n$out');
    expect(out.indexOf('STUB MODE'),
        lessThan(out.indexOf('A/B: shipped vs pre-fix')),
        reason: 'The banner must come BEFORE the table it is warning about.\n$out');
  });

  test('it really called nothing: no usage, no cost, on any row', () {
    for (final side in ['shipped', 'compare']) {
      final rows = ((payload[side] as Map<String, dynamic>)['rows'])
          as List<dynamic>;
      expect(rows, isNotEmpty, reason: '$side produced no rows.\n$out');
      final withUsage =
          rows.where((r) => (r as Map<String, dynamic>).containsKey('usage'));
      expect(withUsage, isEmpty,
          reason: 'A stub row carries usage/cost, which means a real provider '
              'was called during a run that claims to have called nothing.\n$out');
    }
  });

  test('both sides are scored from the APP\'s response schema', () {
    // The contract that matters: the stub speaks the same keys the app's prompt
    // asks for ("calories", "protein", "carbs", "fat"), so a stub run really
    // exercises the scorer. My first stub used kcal/protein_g and every case
    // scored 0 - and a 0 is the tell. Assert the numbers are alive.
    for (final side in ['shipped', 'compare']) {
      final summary =
          (payload[side] as Map<String, dynamic>)['summary'] as Map<String, dynamic>;
      final median = summary['median_kcal_error_pct'];
      expect(median, isA<num>(), reason: '$side has no median error at all.\n$out');
      expect(median, greaterThan(0),
          reason: '$side scored 0 for every case, which means the stub response '
              'did not match the schema score_case reads. That is exactly the '
              'mismatch this test exists to catch.\n$out');
      expect(summary['median_atwater_pct'], isA<num>(),
          reason: '$side has no Atwater figure. Atwater is only computed when '
              'pred_kcal > 0, so a null here means the predictions were zero.\n$out');
    }
  });

  test('the two prompts are fingerprinted, and they DIFFER', () {
    expect(payload.containsKey('prompts_differ'), isTrue,
        reason: 'The run does not say whether the two prompts were the same.\n$out');
    expect(payload['prompts_differ'], isTrue,
        reason: 'The A/B compared a prompt with ITSELF. Any difference in the '
            'table would be noise, and the table would look convincing.\n$out');
    expect((payload['shipped_prompt'] as Map<String, dynamic>)['sha256_12'],
        isNot((payload['compare_prompt'] as Map<String, dynamic>)['sha256_12']),
        reason: 'Both prompt fingerprints are identical.\n$out');
    expect(out.contains('DIFFERENT, so the A/B compares two prompts'), isTrue,
        reason: 'The run must say in words that the two prompts differ.\n$out');
  });

  test('an A/B against an IDENTICAL prompt says it would prove nothing', () {
    // The ref you reach for by reflex is HEAD~1, and after a prompt-neutral
    // commit that is the same prompt. A silent, meaningless table is the worst
    // outcome available, so the harness has to refuse to be one.
    final py = _python()!;
    const finder = '''
import sys
sys.path.insert(0, "tools")
import ai_accuracy as H
import subprocess as sp
head = H.image_prompt()
refs = sp.run(["git","log","--format=%h","-25","--","lib/services/openai_service.dart"],
              capture_output=True, text=True).stdout.split()
for r in refs:
    try:
        if H.image_prompt(r) == head:
            print(r); break
    except SystemExit:
        pass
''';
    final same = (Process.runSync(py, ['-c', finder]).stdout as String).trim();
    expect(same, isNotEmpty,
        reason: 'No commit with an IDENTICAL prompt was found, so the warning '
            'path is untestable. That is worth knowing, not worth failing over.');
    if (same.isEmpty) return;

    final warn = Process.runSync(py, [
      'tools/ai_accuracy.py', '--compare', same, '--stub', '--repeat', '1',
    ]);
    final text = '${warn.stdout}${warn.stderr}';
    expect(text.contains('IDENTICAL'), isTrue,
        reason: 'Comparing a prompt with itself must be announced.\n$text');
    expect(text.contains('prove NOTHING'), isTrue,
        reason: 'The warning must say the comparison proves nothing, not merely '
            'that the prompts match.\n$text');
  });
}
