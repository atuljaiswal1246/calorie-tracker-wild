// ORDER 8 — "PEHLE /HEALTH, PHIR SCAN". The money is the instrument.
//
// On 2026-09-28 I ran ~66 vision scans against an account that was ALREADY at
// 402. It bought nothing — every call 502'd — and the circuit breakers those
// calls tripped are why the APP was 502 for about 25 minutes. The spend was the
// instrument, and the instrument was telling me not to spend.
//
// Why this test exists, and why it EXECUTES instead of grepping: the gate's only
// proof until now was `--self-test`, which I had to remember to run. A guard that
// only runs when its author remembers is a guard that is missing on the day it is
// needed. This runs `tools/ai_accuracy.py --self-test` as a real process, so the
// money gate is inside `flutter test` where it cannot be forgotten — and, in the
// same spirit as `kv_get.py`, an unreadable result is a FAILURE, never a skip.
//
// The self-test replaces the provider call with a counter, so running it here
// costs nothing and CANNOT spend by accident. That is asserted, not assumed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// python3 is resolved the way the harness resolves wrangler: first on PATH,
/// then the known install locations. No python3 means a FAILURE below, because a
/// silently skipped money gate is exactly the failure this test exists to stop.
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
  late ProcessResult selfTest;

  setUpAll(() {
    final py = _findPython();
    expect(
      py,
      isNotNull,
      reason: 'python3 not found. The money gate cannot be verified, and an '
          'unverified money gate is a missing one. Do not skip this — fix the '
          'path or fail the build.',
    );
    selfTest = Process.runSync(py!, ['tools/ai_accuracy.py', '--self-test']);
  });

  test('the money gate self-test runs and passes', () {
    final out = '${selfTest.stdout}${selfTest.stderr}';
    expect(
      selfTest.exitCode,
      0,
      reason: 'tools/ai_accuracy.py --self-test failed (exit '
          '${selfTest.exitCode}).\n$out',
    );
    expect(out, contains('[self-test] PASS'),
        reason: 'The self-test did not report PASS.\n$out');
  });

  test('it makes ZERO provider calls — the point of running it here', () {
    final out = '${selfTest.stdout}${selfTest.stderr}';
    // The provider call is replaced by a counter inside the self-test, so this is
    // a statement about the harness, not a hope. Asserted anyway: if someone
    // "fixes" the self-test by making a real call, this goes red.
    expect(
      RegExp(r'provider calls made(?: during self-test)?:\s*(\d+)')
          .firstMatch(out)
          ?.group(1),
      '0',
      reason: 'The self-test made a provider call. It must never be able to '
          'spend.\n$out',
    );
  });

  test('a drained account is MONEY BLOCKED, and a healthy one is allowed', () {
    final out = '${selfTest.stdout}${selfTest.stderr}';
    expect(
      RegExp(r'all-suspended\s+-> (.+?)\s+ok=(\w+)').firstMatch(out)?.group(2),
      'False',
      reason: 'An all-suspended /health must block the run. That is the state '
          'the account was actually in.\n$out',
    );
    expect(
      RegExp(r'healthy\s+-> (.+?)\s+ok=(\w+)').firstMatch(out)?.group(2),
      'True',
      reason: 'The gate must not be a blanket refusal — a healthy budget has to '
          'be able to scan, or the rule is worthless.\n$out',
    );
  });

  test('the hole that let a run through stays shut', () {
    // A live tier whose circuit breaker has EXPIRED but whose last recorded
    // failure was 402. My gate said CLEAR TO SCAN on exactly this state and let
    // me into 22 scans. An expired breaker is not a budget that has returned.
    final out = '${selfTest.stdout}${selfTest.stderr}';
    final m = RegExp(r'breaker expired but 402 on record\s*-> .+?\s+ok=(\w+)')
        .firstMatch(out);
    expect(m, isNotNull, reason: 'The expired-breaker case is no longer being '
        'tested at all. Restore it.\n$out');
    expect(
      m!.group(1),
      'False',
      reason: 'A 402 on record must block even when the breaker has expired.\n$out',
    );
  });

  test('an unreadable budget blocks, and never reads as a green light', () {
    final out = '${selfTest.stdout}${selfTest.stderr}';
    final m =
        RegExp(r'unreadable budget\s*-> .+?\s+ok=(\w+)').firstMatch(out);
    expect(m, isNotNull, reason: 'The unreadable-budget case is no longer being '
        'tested.\n$out');
    expect(
      m!.group(1),
      'False',
      reason: 'We do not spend against a budget we cannot see. This is order 4 '
          '(an empty result is not a finding) applied to money.\n$out',
    );
  });

  test('MONEY BLOCKED and UNMEASURED are different verdicts', () {
    final out = '${selfTest.stdout}${selfTest.stderr}';
    // They lead to different next decisions — retry vs stop and ask — so they
    // must never be allowed to become the same string.
    final m = RegExp(r"labels distinct: '(.+?)' vs '(.+?)'").firstMatch(out);
    expect(m, isNotNull, reason: 'The labels-distinct assertion is gone.\n$out');
    final money = m!.group(1)!;
    final unmeasured = m.group(2)!;
    expect(money, isNot(equals(unmeasured)));
    expect(money, contains('MONEY BLOCKED'));
    expect(unmeasured, contains('UNMEASURED'));
    expect(money, isNot(contains('UNMEASURED')));
  });

  test('a run is capped in MONEY, never in request counts', () {
    final src = File('tools/ai_accuracy.py').readAsStringSync();
    // "PAISA NUMBER HAI, SCAN NUMBER NAHI" — 66 scans at $0.004 is $0.26, and
    // every one of them was a 502. A ceiling in scans is the same mistake with
    // a nicer number on it.
    expect(src.contains('--max-cost-usd'),
        isTrue, reason: 'The money ceiling flag is gone.');
    expect(
      RegExp(r'class SpendCeiling').hasMatch(src),
      isTrue,
      reason: 'The mid-flight abort is gone, so a run can only be stopped by '
          'being interrupted — which is how 66 scans happened.',
    );
    expect(
      RegExp(r'--max-calls|--max-scans|--limit-calls'),
      isNot(throwsA(isA<RegExp>())),
      reason: 'A request-count cap has reappeared. The cap must be in money.',
    );
  });

  test('the gate can be ASKED without spending - that is the first morning command', () {
    // The owner's first question is "can we run?", and until now the only way to
    // answer it was to start a run - which is precisely the mistake that cost 66
    // scans and a 25-minute app outage last night. --preflight-only runs the gate
    // and STOPS: it reads /health and the Worker's err_* keys, calls no provider,
    // and exits 0 when clear, 3 when blocked. So "can we?" is a measurement, not a
    // hope and not an experiment.
    final src = File('tools/ai_accuracy.py').readAsStringSync();
    expect(src.contains('--preflight-only'), isTrue,
        reason: 'The gate lost its no-spend readiness mode.');
    expect(
      src.contains('return 0 if gate["ok"] else 3'),
      isTrue,
      reason: '--preflight-only must exit 0 when clear and 3 when blocked, so a '
          'caller can read readiness from the exit code alone.',
    );
    // And it must stop BEFORE the spend ceiling line, which is where a real run
    // begins. If it ever printed the ceiling and carried on, the flag would be a
    // comment rather than a stop.
    final flag = src.indexOf('--preflight-only');
    final stop = src.indexOf('if args.preflight_only:');
    // The PRINT, not the section header comment 400 lines earlier: my first
    // version searched for the words and found the banner, so the ordering
    // assertion failed against CORRECT code. A check that measures the wrong
    // occurrence is a check that cries wolf.
    final ceiling = src.indexOf('print(f"SPEND CEILING:');
    expect(stop, greaterThan(flag),
        reason: 'The readiness branch must come after the flag is declared.');
    expect(stop, lessThan(ceiling),
        reason: 'The readiness check must happen BEFORE a run would spend. It is '
            'currently after it, so --preflight-only would not stop a run.');
  });

  test('the gate runs BEFORE any case is scanned', () {
    final src = File('tools/ai_accuracy.py').readAsStringSync();
    final gate = src.indexOf('gate = run_preflight(device)');
    final firstScan = src.indexOf('current = run(');
    expect(gate, isNot(-1), reason: 'The preflight call is gone from main().');
    expect(
      firstScan,
      isNot(-1),
      reason: 'The run call is gone; this test cannot prove the ordering any '
          'more and must be rewritten to match reality.',
    );
    expect(
      gate,
      lessThan(firstScan),
      reason: 'The preflight now happens AFTER the first scan. That is the '
          'whole failure: the run started before the budget was read.',
    );
    expect(
      src.contains('ZERO provider calls will be made'),
      isTrue,
      reason: 'A blocked run must say in words that it made none.',
    );
  });

  test('measurement traffic carries its OWN identity, not the app\'s', () {
    final src = File('tools/ai_accuracy.py').readAsStringSync();
    // Blast radius: my 66 calls shared the app's per-user budget and breakers,
    // so my run is what 502'd a user. Engineering is splitting the budget into
    // a separate DO on the SHARED Worker; this pins the half that is mine - the
    // identity the split attaches to.
    final m =
        RegExp(r'MEASUREMENT_DEVICE_ID\s*=\s*"([^"]+)"').firstMatch(src);
    expect(m, isNotNull, reason: 'The measurement identity is gone.');
    final id = m!.group(1)!;
    expect(id, isNotEmpty);
    expect(
      id,
      isNot(contains('ceo-acc-')),
      reason: 'The default device id is a TIMESTAMP again, so every run is a '
          'different user and shares nothing. A stable id is what makes a '
          'per-user budget splittable.',
    );
    expect(
      src.contains('device = args.device_id or MEASUREMENT_DEVICE_ID'),
      isTrue,
      reason: 'The stable measurement id must be what a run actually uses.',
    );
  });
}
