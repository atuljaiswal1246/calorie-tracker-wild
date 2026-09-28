// The published privacy page must name every company that can receive a photo.
//
// THE DEFECT (2026-09-28). public/privacy.html says, in full:
//
//   "AICredits: Used for food image analysis."
//
// That is the whole list. The Worker's own /health, read at 07:19Z, says the
// last billed request was served by
//
//   {"provider": "openrouter", "served_model": "openai/gpt-4o-mini"}
//
// so a user's food photograph can be processed by a company the privacy policy
// does not name and does not mention. The Play data-safety declaration is
// written FROM this page, so the declaration and the behaviour disagree — with
// a user's photograph in the gap.
//
// It is a static page describing a dynamic rotation. Standing order 2: the model
// is not chosen by us and not chosen by the app; whichever key is funded serves
// the scan. So the check derives the processor set from the Worker's own
// `const rotation = [...]` — the list the serving loop actually iterates — and
// requires the policy to cover ALL of it. Add a tier to the Worker and this
// fails until the policy names it. That is the direction a guard should fail in.
//
// THE CHECKER GOT THIS WRONG FIRST, twice, and both are pinned below:
//   1. It counted any `env.X_KEY` in worker.js, so it reported ZEN as a missing
//      processor. ZEN_KEY exists but ZEN is not in the serving rotation at all
//      — it appears only in the probe list. Presence is not capability, which is
//      the same error as counting the word "fasting" as a fasting screen, and as
//      counting storage_service.addWeightEntry as proof a user can log a weight.
//   2. Its evidence column came out empty, so a reader could not check where the
//      tier list came from. A guard that cannot be audited is a claim.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tool = 'tools/check_privacy_processors.py';

void main() {
  int run([String flag = '']) {
    final r = Process.runSync('python3', [_tool, ...(flag.isEmpty ? [] : [flag])]);
    return r.exitCode;
  }

  String output([String flag = '']) {
    final r = Process.runSync('python3', [_tool, ...(flag.isEmpty ? [] : [flag])]);
    return '${r.stdout}${r.stderr}';
  }

  test('the checker exists', () {
    expect(File(_tool).existsSync(), isTrue, reason: '$_tool is missing');
  });

  test('it FAILS today: two serving tiers are absent from the privacy page', () {
    expect(run(), 1,
        reason: 'the policy now names every processor, so this test is obsolete '
            'and the defect is closed. If instead it passes, the checker is no '
            'longer reading the serving rotation.\n\n${output()}');
  });

  test('it names openrouter — the provider that actually served', () {
    // Not "some tier is missing". The specific one, because /health said
    // openrouter served the last billed request, and a vague failure would not
    // tell the owner which company's name has to go on the page.
    final out = output();
    expect(out, contains('openrouter'));
    expect(out, contains('NOT NAMED'));
  });

  test('it does NOT claim zen is a missing processor', () {
    // ZEN_KEY is set in the environment, so an env-presence check calls it a
    // processor. It is not in the serving rotation and cannot receive a photo.
    // If this ever fails, the checker has gone back to counting key presence.
    final out = output();
    expect(out, isNot(matches(RegExp(r'\bzen\b.*NOT NAMED'))),
        reason: 'zen is not in the serving rotation; naming it as a missing '
            'processor would put a false obligation on the privacy page:\n$out');
    expect(out, isNot(contains('go, openrouter, zen')));
  });

  test('it derives the tiers from the serving rotation, not from key presence', () {
    final src = File(_tool).readAsStringSync();
    expect(src, contains('rotation'),
        reason: 'the tier list must come from the list the serving loop iterates');
    expect(src, isNot(contains('env\\.')),
        reason: 'reading env.X_KEY is the presence-is-not-capability error; the '
            'checker is not allowed to go back to it');
  });

  test('every verdict carries a worker.js line, so the derivation is auditable', () {
    final out = output();
    expect(out, matches(RegExp(r'worker\.js:\d+ rotation \+= "aicredits"')),
        reason: 'the evidence column is empty or untraceable; a reader cannot '
            'then check where the tier list came from:\n$out');
  });

  test('a failed /health read is reported as NOT VERIFIED, never as "no '
      'third parties"', () {
    // Standing order 4. The static part must stand alone, and the live part must
    // not be able to turn a network error into a pass.
    final out = output('--live');
    expect(out, contains('live /health'),
        reason: 'the live section is missing entirely');
    expect(out, isNot(contains('NOT READ')), // we expect the read to succeed here
        reason: 'the live /health read failed in a test environment; that is a '
        'network condition, not a verdict on the page');
  });

  test('the privacy page is what carries the single-processor claim', () {
    final policy = File('public/privacy.html').readAsStringSync();
    expect(policy, contains('AICredits'));
    expect(policy, isNot(contains('OpenRouter')),
        reason: 'the page now names OpenRouter. If so the defect is closed and '
            'the fix belongs in the page, not in the checker.');
  });

  test('the live provider really is openrouter — read, not assumed', () {
    // This one is skipped when there is no network, because a network failure
    // is not evidence about the provider. It is here so that when it DOES run,
    // the "openrouter is not named" claim is backed by the Worker and not by
    // my memory of an earlier reading.
    final r = Process.runSync('curl', [
      '-s', '-m', '20', '-X', 'POST',
      '-H', 'content-type: application/json',
      '-d', '{}',
      'https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev/health',
    ]);
    if (r.exitCode != 0) {
      markTestSkipped('no network: NOT VERIFIED, which is not a pass');
      return;
    }
    final body = '${r.stdout}';
    expect(body, contains('"provider"'),
        reason: '/health returned no provider field: $body');
    expect(body, contains('openrouter'),
        reason: 'the last billed provider changed since this test was written. '
            'Re-read /health and re-check the page before trusting this test:\n'
            '$body');
  });
}
