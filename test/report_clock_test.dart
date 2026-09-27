// A REPORT'S TIME MUST COME FROM THE CLOCK, AND THE CLOCK MUST BE CHECKED.
//
// 2026-09-28. Seven consecutive reports to my CEO carried a hand-typed
// "Time: ~HH:MM IST". They were guesses, not readings. The machine said 05:13:38
// when the seventh landed; `git log` said that commit was made at 05:12:31. My
// reports and my commits gave two different answers to "when", two hours apart,
// and a session in three weeks deciding "what did he believe when he wrote that"
// would get a different answer from each of them.
//
// The CEO's first hypothesis was an offset bug, and it was worth testing rather
// than dismissing: `datetime.now()` with a hardcoded +2:07, an offset applied
// twice, or utcnow() labelled IST would all look like this. None of them was true.
// grep proved it - NOTHING in the repo produced that number, because the number
// was typed into a chat message. There was no producer, so there was nothing to
// check. That is standing order 6 arriving through the most ordinary door there
// is, and it is why the fix is a CODE PATH rather than a habit.
//
// So: the time is read in exactly one place (tools/now.py), the report script
// builds its own header from it and accepts no time from the caller, and this
// test proves the two agree to within two minutes - which is the guard that would
// have caught a hardcoded offset too, had that been the bug.

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

String _date(ProcessResult r) => (r.stdout as String).trim();

int _minutesOf(String hhmm) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) throw StateError('no time in "$hhmm"');
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

int _driftMinutes(int a, int b) {
  // Modulo BEFORE wrapping, for the same reason the script does it: a raw
  // difference of 5725 minutes minus 1440 is negative, and a negative drift
  // passes every "<= 2" check there is.
  final raw = (a - b) % (24 * 60);
  return raw > 12 * 60 ? 24 * 60 - raw : raw;
}

void main() {
  late ProcessResult dateOut;
  late ProcessResult nowOut;
  late ProcessResult headerOut;

  setUpAll(() {
    final py = _python();
    expect(py, isNotNull,
        reason: 'python3 not found, so the report clock cannot be checked.');
    dateOut = Process.runSync(py!, ['-c', 'import time; print(time.strftime("%H:%M"))']);
    nowOut = Process.runSync(py, ['tools/now.py', '--stamp']);
    headerOut = Process.runSync(py, ['tools/now.py', '--header']);
  });

  test('tools/now.py agrees with the shell clock', () {
    expect(dateOut.exitCode, 0, reason: 'date did not run');
    expect(nowOut.exitCode, 0, reason: 'tools/now.py failed: ${nowOut.stderr}');
    final drift = _driftMinutes(_minutesOf(_date(dateOut)), _minutesOf(_date(nowOut)));
    expect(
      drift,
      lessThanOrEqualTo(2),
      reason: 'tools/now.py says ${_date(nowOut)} and the shell clock says '
          '${_date(dateOut)} - $drift minutes apart. If this is a hardcoded '
          'offset, a doubled offset, or a utcnow() labelled as local, it shows '
          'up HERE, which is the whole reason this test exists.\n'
          '  now.py: ${nowOut.stdout}\n  date  : ${dateOut.stdout}',
    );
  });

  test('the report header is machine-read, and says which zone it is in', () {
    final h = _date(headerOut);
    expect(RegExp(r'~\d{2}:\d{2} \S+, \d{4}-\d{2}-\d{2}').hasMatch(h), isTrue,
        reason: 'the header is not in the expected form: "$h"');
    expect(RegExp(r'IST|UTC|[+-]\d{2}:\d{2}|[A-Z]{2,5}').hasMatch(h), isTrue,
        reason: 'the header does not name its time zone, so it cannot be '
            'compared with anything: "$h"');
    expect(
      _driftMinutes(_minutesOf(_date(dateOut)), _minutesOf(h)),
      lessThanOrEqualTo(2),
      reason: 'the header time is not the machine time.\n  header: $h\n'
          '  date  : ${_date(dateOut)}',
    );
  });

  test('the report script has NO way to accept a caller-supplied time', () {
    // If a time can be passed in, it can be typed, and typing is the bug. So the
    // absence of the option is the property, not an oversight.
    final src = File('tools/report_to_jarvis.py').readAsStringSync();
    expect(src.contains('add_argument("--time"'), isFalse,
        reason: 'report_to_jarvis.py accepts a --time. That is the defect '
            'reintroduced as a feature.');
    expect(src.contains('clock.header()'), isTrue,
        reason: 'the header must come from tools/now.py.');
    expect(src.contains('CLOCK_DRIFT_LIMIT_S'), isTrue,
        reason: 'the script must re-read the clock and refuse a drifted stamp.');
  });

  test('a drifted stamp is REFUSED, and the guard says how far off it was', () {
    // Exercise the refusal directly: a stamp two hours out must not be sent.
    // runpy so the real function is used rather than a copy of it.
    final py = _python()!;
    final probe = '''
import sys, runpy
sys.path.insert(0, "tools")
mod = runpy.run_path("tools/report_to_jarvis.py", run_name="not_main")
f = mod["verify"]
try:
    f("Time: ~99:99 IST")
    print("SENT")
except SystemExit as e:
    print("REFUSED:", str(e)[:160])
''';
    final r = Process.runSync(py, ['-c', probe]);
    final out = '${r.stdout}${r.stderr}';
    expect(out.contains('REFUSED'), isTrue,
        reason: 'verify() did not refuse a nonsense stamp.\n$out');
    expect(out.contains('REFUSING TO SEND'), isTrue,
        reason: 'the refusal must explain itself, so a future session can tell '
            'a guard from a crash.\n$out');
  });

  test('a typed Time: line in the body is replaced, not trusted', () {
    final py = _python()!;
    final probe = '''
import sys, runpy, re
sys.path.insert(0, "tools")
mod = runpy.run_path("tools/report_to_jarvis.py", run_name="not_main")
out = mod["build"]("Landed: abc.\\n\\nTime: ~07:20 IST, 2026-09-28")
stamped = re.search(r"~\\d{2}:\\d{2}", out).group(0)
print("TYPED", "07:20" in out)
print("HEADER", stamped)
''';
    final r = Process.runSync(py, ['-c', probe]);
    final out = (r.stdout as String).trim();
    expect(out.contains('TYPED False'), isTrue,
        reason: 'a hand-typed time survived into the report.\n$out');
    expect(out.contains('HEADER ~'), isTrue,
        reason: 'no machine-read header was added.\n$out');
  });

  test('the newest commit is not dated in the FUTURE', () {
    // I first wrote this as "the last commit is within two minutes of the
    // clock", and it failed immediately - correctly: a commit is allowed to
    // age. The invariant that actually matters runs the other way. My
    // fabricated times were all AHEAD of reality, so a commit stamped in the
    // future is the fingerprint of the whole class: a number with no producer,
    // drifting forward. A commit that is merely old is fine.
    final log = Process.runSync('git', [
      'log', '-1', '--format=%ad', '--date=format:%H:%M'
    ]);
    expect(log.exitCode, 0, reason: 'git log failed');
    final commit = _date(log);
    final clockNow = _date(dateOut);
    // Cyclic difference: small positive means the commit is AHEAD of the clock,
    // large means it is behind. A commit in the past is fine and expected.
    final raw = (_minutesOf(commit) - _minutesOf(clockNow)) % (24 * 60);
    final ahead = raw <= 12 * 60 ? raw : 0;      // 0 = behind, which is fine
    expect(
      ahead,
      lessThanOrEqualTo(2),
      reason: 'The newest commit is dated $commit and the clock reads '
          '$clockNow - the commit is $ahead minutes in the FUTURE. That is what '
          'a made-up "now" looks like in a repo, and it is how a future session '
          'would end up reasoning about the wrong hour. (A commit that is merely '
          'OLD is normal and is not flagged.)\n'
          '  commit: $commit\n  clock : $clockNow',
    );
  });
}
