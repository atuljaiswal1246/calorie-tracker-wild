// The failure line a user reads, rendered — not classified in isolation.
//
// THE GAP THIS CLOSES, and it is one I created. On 2026-09-28 I fixed the failed-
// scan path: the app used to tell users "Invalid API key. Go to Settings and check
// your key" when it has no key anywhere, and a 402 — WE having no budget — used to
// fall through to "Something went wrong." I extracted the logic into
// `lib/services/scan_failure.dart` as a pure library and unit-tested every branch,
// and then wrote in a report that the mapping was tested and THE WIRING WAS NOT:
// the catch block assigned `_error` and a bare `Text(_error!)` rendered it. A
// chain whose last link is a line nobody can read under test has only been tested
// at its convenient end.
//
// The fix is structural, not another assertion: the notice is now a widget
// (`ScanFailureNotice`), so what the user sees is a thing a test can pump — with
// no camera, no image_picker, no path_provider.
//
// The assertions are on VISIBLE TEXT, found with `find.text`, which is the only
// way to know a string reached a human. Asserting that a function returns an enum
// tells you the function works; it does not tell you the app shows it.

import 'package:calorie_tracker/services/scan_failure.dart';
import 'package:calorie_tracker/widgets/scan_failure_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pump the notice and return the strings a user could actually read.
Future<List<String>> visibleText(WidgetTester tester, String raw) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ScanFailureNotice(
        rawError: raw,
        onRetry: () {},
        onEnterManually: () {},
      ),
    ),
  ));
  await tester.pump();
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

void main() {
  testWidgets('a 402 shows the money line, and the user is told their data is safe',
      (tester) async {
    // The live condition tonight: all three tiers are out of money, so this is
    // what a real user would see today, not a hypothetical.
    final shown = await visibleText(
        tester, 'Exception: AI request failed (402): insufficient_quota');
    expect(shown, contains(scanFailureMessage(ScanFailure.noBudget)));
    expect(shown.first.toLowerCase(), contains('safe'),
        reason: 'the money case must reassure that logged meals are intact, or a '
            'pause in our funding reads as a loss of their history');
  });

  testWidgets('no 403 mentions an API key or sends them to Settings',
      (tester) async {
    // The bug of 2026-09-28, asserted on the rendered string rather than on the
    // function that produces it.
    final shown = await visibleText(tester, 'Exception: AI request failed (403)');
    final joined = shown.join(' ').toLowerCase();
    expect(joined, isNot(contains('api key')),
        reason: 'the app has no key and never will (§0 rule 2). A user shown '
            '"check your key" hunts through Settings for a field that is not '
            'there and concludes the app is broken.\nRendered: $joined');
    expect(joined, isNot(contains('settings')));
  });

  testWidgets('the two recovery actions are on screen and work', (tester) async {
    var retried = 0;
    var manual = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScanFailureNotice(
          rawError: 'SocketException: Connection refused',
          onRetry: () => retried++,
          onEnterManually: () => manual++,
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Enter manually'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.tap(find.text('Enter manually'));
    expect(retried, 1, reason: 'Try again did nothing — a button that cannot be '
        'pressed is the same class of dead surface as the dead widget');
    expect(manual, 1);
  });

  testWidgets('nothing rendered leaks our money, our providers, or blame',
      (tester) async {
    final banned = [
      'api key', 'quota', 'billing', 'credit', 'payment', '402',
      'aicredits', 'openrouter', 'opencode', 'provider', 'invoice',
      'you must', 'you didn', 'your fault', 'invalid',
    ];
    final raws = [
      'Exception: AI request failed (402): insufficient_quota',
      'Exception: AI request failed (429): rate limit',
      'Exception: AI request failed (403)',
      'Exception: AI request failed (500): internal',
      'Exception: AI request failed (502): bad gateway',
      'SocketException: Connection refused',
      'Exception: Could not find the food',
      'HandshakeException: timed out',
      'Exception: something nobody has seen before',
    ];
    for (final raw in raws) {
      final shown = (await visibleText(tester, raw)).join(' ').toLowerCase();
      for (final b in banned) {
        expect(shown, isNot(contains(b)),
            reason: 'rendered text for "$raw" contains "$b". Our suppliers and '
                'our billing are not the user\'s business, and a user who reads '
                'a 402 understands a fault that is not theirs.\nRendered: $shown');
      }
    }
  });

  testWidgets('it survives a long upstream body without overflowing',
      (tester) async {
    // The old inline version printed the WHOLE exception, upstream body and all,
    // into a Text with no maxLines. A 402 body is a JSON blob. If that ever comes
    // back, it must fail here rather than on a phone.
    final blob = '{"error":{"message":"insufficient credits","detail":"';
    final long = 'Exception: AI request failed (402): ${blob * 12}';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ScanFailureNotice(
            rawError: long,
            onRetry: () {},
            onEnterManually: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'a long upstream body overflowed the notice');
  });
}
