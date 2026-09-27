// ROUTE-AWARE FAILURE LABELS — the guard for the incident of 2026-09-28.
//
// What went wrong: I measured each named tier with `x-cm-force-provider`, saw
// 402 on all of them, and reported "the scanner is down for every user". The
// owner then measured the APP'S OWN ROUTE and got a working vision answer at
// 01:20. The app does not send that header and walks a different path, so my
// "outage" was a statement about my own probe, not about the app.
//
// Same mistake as the 11 wrong model ids: a probe that does not match the real
// path, used to make a big decision.
//
// A forced-tier failure and an app-route failure are DIFFERENT subjects and
// must never collapse into one label.
//
// The labels live in tools/ai_accuracy.py (Python), so this test asserts on
// that source rather than pretending to import it. What it protects is real:
// if someone merges the two labels, or makes the force header unconditional,
// this fails.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;

  setUpAll(() {
    src = File('tools/ai_accuracy.py').readAsStringSync();
  });

  test('a forced-tier failure and an app-route failure have SEPARATE labels', () {
    expect(
      src.contains('UNMEASURED_FORCED_TEMPLATE'),
      isTrue,
      reason: 'A forced-tier failure must have its own label template.',
    );
    expect(
      src.contains("UNMEASURED_APP_ROUTE"),
      isTrue,
      reason: "The app's own route must have its own label.",
    );
    // The forced template must NAME the tier, so it can never be read as an
    // app-wide statement.
    expect(
      src.contains("UNMEASURED_FORCED_TEMPLATE.format(tier=tier"),
      isTrue,
      reason: 'The forced label must interpolate the tier name.',
    );
    expect(
      src.contains('forced tier {tier}'),
      isTrue,
      reason: 'The forced label text must say "forced tier <name>".',
    );
    expect(
      src.contains("app's own route"),
      isTrue,
      reason: 'The route label must say it is the app route, not a tier.',
    );
  });

  test('the two labels are not aliases of each other', () {
    final forcedTpl = RegExp(r'UNMEASURED_FORCED_TEMPLATE\s*=\s*"([^"]+)"')
        .firstMatch(src)
        ?.group(1);
    final routeTpl =
        RegExp(r'UNMEASURED_APP_ROUTE\s*=\s*"([^"]+)"').firstMatch(src)?.group(1);
    expect(forcedTpl, isNotNull);
    expect(routeTpl, isNotNull);
    expect(
      forcedTpl,
      isNot(equals(routeTpl)),
      reason: 'If these two strings are ever the same, the guard is decorative.',
    );
    // And a forced label must never contain the app-route wording, which is how
    // a 402 became "the scanner is down for every user" in the first place.
    expect(forcedTpl, isNot(contains("app's own route")));
  });

  test('the force header is sent ONLY when explicitly asked for', () {
    // The single most important property. A run without --force-tier must be
    // the app's route, because that is the only thing that describes what users
    // experience.
    expect(
      src.contains('if force_tier else {}'),
      isTrue,
      reason: 'The force header must be conditional. If it is ever sent '
          'unconditionally, every run silently becomes a forced-tier run and '
          'its failures get reported as an app outage again.',
    );
    expect(
      src.contains('def ask_proxy(prompt: str, image_path: str, device_id: str,'),
      isTrue,
      reason: 'ask_proxy must accept force_tier so the header can be omitted.',
    );
  });

  test('the CLI asks for it explicitly, and names the route in its output', () {
    expect(
      src.contains('--force-tier'),
      isTrue,
      reason: 'The flag must exist so a tier can be tested deliberately.',
    );
    expect(
      src.contains('own default route'),
      isTrue,
      reason: 'Every run must print which route it measured. A run that does '
          'not say which route it took cannot be read correctly. Matched on '
          '"own default route" because the source escapes the apostrophe.',
    );
    expect(
      src.contains('FORCED TIER '),
      isTrue,
      reason: 'A forced run must announce itself as forced.',
    );
  });

  test('402 is never reported as a rate limit', () {
    // The original bug, pinned: a money outage labelled as a throttle.
    expect(
      src.contains('UNMEASURED_FUNDS'),
      isTrue,
      reason: 'A 402 must have its own label.',
    );
    expect(
      RegExp(r'UNMEASURED_FUNDS\s*=\s*"UNMEASURED - provider out of funds')
          .hasMatch(src),
      isTrue,
      reason: 'The 402 label must say "out of funds".',
    );
    expect(
      RegExp(r'UNMEASURED_RL\s*=\s*"UNMEASURED - rate limited').hasMatch(src),
      isTrue,
      reason: 'The 429 label must say "rate limited" and nothing else.',
    );
  });
}
