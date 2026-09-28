// A VERIFICATION MUST CARRY ITS OWN AGE.
//
// The external-claims check cannot live in `flutter test` - it is a network call,
// and a test that depends on the network becomes the flaky test nobody trusts. So
// the check is a script, which creates the problem it was written to fix: a script
// run once, and a result carried in AGENTS.md forever as "verified live".
//
// That is the decay this file makes visible. The record of the last run lives in the
// repo with a DATE on it, and this test fails when:
//
//   1. the record is missing, or carries no date
//   2. the record is older than MAX_AGE_DAYS - a verification from a month ago is
//      not a verification, it is a memory
//   3. the URL set in the record no longer matches what the APP opens, which means
//      someone changed a link after the last check and nothing noticed
//
// Point 3 is the one that matters most: it turns "the claims are true" into "the
// claims were true when we last looked, and we will notice if they stop being
// true". That is the difference between a claim and a fact, and it is the whole of
// standing order 6 applied to something outside the repo.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A hosted page a user can reach is a promise. Two weeks is long enough that
/// nobody re-checks every morning, and short enough that a dead page is found
/// before a Play submission rather than during one.
const maxAgeDays = 14;

void main() {
  late File record;
  late String text;

  setUpAll(() {
    record = File('notes/EXTERNAL_CLAIMS_LAST_CHECK.md');
    if (record.existsSync()) text = record.readAsStringSync();
  });

  test('the last check is recorded, with a date', () {
    expect(record.existsSync(), isTrue,
        reason: 'No record of the external-claim check. Run:\n'
            '  python3 tools/check_external_claims.py --record\n'
            'A verification nobody can date is a claim nobody can check.');
    final m = RegExp(r'\*\*Checked (\d{4}-\d{2}-\d{2})').firstMatch(text);
    expect(m, isNotNull,
        reason: 'The record has no date on it, which is the whole point of the '
            'file:\n${text.split('\n').take(6).join('\n')}');
  });

  test('the check is recent enough to mean something', () {
    final m = RegExp(r'\*\*Checked (\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    expect(m, isNotNull, reason: 'no date');
    final when = DateTime.utc(
        int.parse(m!.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    final age = DateTime.now().toUtc().difference(when).inDays;
    expect(
      age,
      lessThanOrEqualTo(maxAgeDays),
      reason: 'The last external-claim check is $age days old. A hosted page that '
          'quietly 404s would be found at Play submission by the owner, at the '
          'worst possible moment. Re-run:\n'
          '  python3 tools/check_external_claims.py --record',
    );
  });

  test('the record covers every URL the app opens', () {
    // The one that matters. If someone changes a link in the app after the last
    // check, this goes red - which is the difference between "the claims were
    // true when we last looked" and "the claims are true".
    final urls = <String>{};
    for (final dart in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!dart.path.endsWith('.dart')) continue;
      for (final m in RegExp(r'https://calorie-tracker-[a-z0-9-]+\.web\.app'
              r'/[A-Za-z0-9._/-]*')
          .allMatches(dart.readAsStringSync())) {
        urls.add(m.group(0)!);
      }
    }
    expect(urls, isNotEmpty,
        reason: 'The app opens no hosted URL any more, so this guard is pointing '
            'at nothing. Find out why before deleting it - the Terms and Privacy '
            'links are a store requirement.');

    final missing = urls.where((u) => !text.contains(u)).toList();
    expect(missing, isEmpty,
        reason: 'The app opens these, and the last check does not cover them, so '
            'nobody has verified them:\n${missing.join('\n')}\nRe-run the check '
            'with --record.');
  });

  test('the record says the pages were reachable, not just checked', () {
    // A table of URLs proves nothing about what came back. The statuses are the
    // evidence, so they are required to be present and to be 200s.
    final rows = RegExp(r'^\| (\S+) \| (\d{3}) \| (\d+) \|', multiLine: true)
        .allMatches(text)
        .toList();
    expect(rows.length, greaterThanOrEqualTo(2),
        reason: 'The record has no result table.\n$text');
    for (final row in rows) {
      expect(row.group(2), '200',
          reason: '${row.group(1)} came back ${row.group(2)} at the time of the '
              'check. If this is a 404 the record is history, not a claim - '
              're-run it.');
      expect(int.parse(row.group(3)!), greaterThan(400),
          reason: '${row.group(1)} returned a tiny body. A hosting 404 often '
              'answers 200 with a small page, which is why the size is recorded.');
    }
  });

  test('the check itself is runnable, and its flags are the ones it claims', () {
    // The script's own contract, checked without the network: it exists, it exits
    // non-zero when something is wrong, and it can record.
    final script = File('tools/check_external_claims.py');
    expect(script.existsSync(), isTrue);
    final src = script.readAsStringSync();
    for (final flag in const ['--json', '--record']) {
      expect(src.contains(flag), isTrue,
          reason: 'tools/check_external_claims.py lost its $flag option, and this '
              'file refers to it.');
    }
    expect(src.contains('return 1'),
        isTrue,
        reason: 'The script must be able to FAIL. A check that cannot fail is a '
            'formality.');
  });
}
