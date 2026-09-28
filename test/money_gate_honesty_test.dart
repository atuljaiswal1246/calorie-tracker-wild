// A money gate that overclaims is worse than one that stops.
//
// THE DEFECT, measured 2026-09-28 17:05 IST. `ai_accuracy.py --preflight-only`
// printed:
//
//   - aicredits: UNKNOWN - kv read failed (exit 1)
//   - openrouter: OUT OF MONEY (402 ...)
//   - go:         OUT OF MONEY (429 ...)
//   MONEY BLOCKED - no budget, not an attempt
//
// Two of those tiers were measured out of money. The third was a READ THAT FAILED
// - a probe that did not complete. The summary line collapsed both into "no
// budget", so a reader took away "all three tiers are out of money" when what was
// actually known was "two are, and we could not read the third".
//
// That difference is not pedantry. The owner's decision is sized from this line:
// "we are broke on all three, fund the cheapest" and "we are broke on two and do
// not know the third" are different amounts of money and different urgencies.
// And a failed probe is the standing-order-4 case in its purest form: silence
// from a broken command, which reads exactly like silence from a real absence.
//
// WHY IT WAS WRONG IN THE FIRST PLACE. The summary printed a FIXED string
// (`MONEY_BLOCKED`) instead of the gate's own verdict, so even once the gate
// learned to tell the two apart, the honest answer could not reach the output.
// A correct computation behind a hardcoded sentence is a correct computation
// nobody reads.
//
// WHAT MUST STAY TRUE. The gate still fails closed. An unreadable tier still
// blocks the run, and zero provider calls are still made. Nothing here loosens a
// money gate to make an instrument more honest - the honesty is entirely in the
// LABEL.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tool = 'tools/ai_accuracy.py';

void main() {
  /// Run the tool's own gate logic in-process, so these are tests of the shipped
  /// decision and not of a re-implementation of it.
  String gateFor(String tierJson) {
    final script = '''
import json, sys
sys.argv = ["ai_accuracy.py"]
import importlib.util
spec = importlib.util.spec_from_file_location("m", ${json.encode(_tool)})
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
tiers = json.loads(${json.encode(tierJson)})
health = {"paid_usage": {"est_cost_usd_today": 0, "requests_billed": 0},
          "secrets_configured": {k: True for k in tiers}}
g = m.preflight(health, tiers)
print(json.dumps(g))
''';
    final f = File('${Directory.systemTemp.path}/gate_probe.py')
      ..writeAsStringSync(script);
    final r = Process.runSync('python3', [f.path], workingDirectory: '.');
    if (r.exitCode != 0) {
      throw StateError('gate probe failed: ${r.stdout}${r.stderr}');
    }
    return '${r.stdout}'.trim().split('\n').last;
  }

  test('every tier out of money -> blocked, and says so exactly', () {
    final g = gateFor('{"aicredits": "402 Insufficient Balance",'
        ' "openrouter": "402 Insufficient credits",'
        ' "go": "429 GoUsageLimit"}');
    expect(g, contains('"ok": false'));
    expect(g, contains('MONEY BLOCKED'));
    expect(g, isNot(contains('MONEY STATE UNKNOWN')),
        reason: 'nothing was unreadable, so nothing should be called unknown');
  });

  test('a tier that could not be READ is not counted as out of money', () {
    // The defect, exactly. Two measured, one unreadable.
    final g = gateFor('{"aicredits": "UNKNOWN - kv read failed (exit 1)",'
        ' "openrouter": "402 Insufficient credits",'
        ' "go": "429 GoUsageLimit"}');
    expect(g, contains('"ok": false'),
        reason: 'the gate must still fail closed - an unreadable tier blocks '
            'the run exactly as an out-of-money tier does');
    expect(g, contains('MONEY STATE UNKNOWN'),
        reason: 'the verdict must admit that part of the state is unread');
    expect(g, contains('Blocked, but the blocked'),
        reason: 'the blocked count is a FLOOR, not a total, and the reader '
            'needs to be told that in the sentence they actually read');
  });

  test('ALL tiers unreadable is not "MONEY BLOCKED - no budget"', () {
    final g = gateFor('{"aicredits": "UNKNOWN - kv read failed (exit 1)",'
        ' "openrouter": "UNKNOWN - wrangler not found"}');
    expect(g, contains('"ok": false'));
    expect(g, contains('MONEY STATE UNKNOWN'));
    expect(g, isNot(contains('MONEY BLOCKED - no budget')),
        reason: 'nothing was measured. Saying "no budget" here is exactly the '
            'claim this test exists to stop: a broken probe reported as an '
            'empty account');
  });

  test('the fixed sentence is not used where the gate has a verdict', () {
    // The bug behind the bug: the summary printed a constant.
    final src = File(_tool).readAsStringSync();
    final block = src.substring(src.indexOf('if not gate["ok"]:'),
                                src.indexOf('if args.preflight_only:'));
    expect(block, contains("gate['verdict']"),
        reason: 'the printed line must be the GATE\'s verdict, or a correct '
            'computation can never reach the reader');
    expect(block, isNot(contains('{MONEY_BLOCKED} —')),
        reason: 'the fixed sentence is still being printed here, so an honest '
            'verdict never reaches the output');
  });

  test('the gate still refuses to run on an UNKNOWN tier — honesty is not laxity',
      () {
    // The one thing that must not move while fixing the label.
    final g = gateFor('{"aicredits": "UNKNOWN - kv read failed (exit 1)"}');
    expect(g, contains('"ok": false'),
        reason: 'an unreadable tier must block. Making the label honest must '
            'never become a reason to let a run through');
  });
}
