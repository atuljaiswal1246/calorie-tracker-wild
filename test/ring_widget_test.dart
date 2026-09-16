import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/widgets/cal_ring_widget_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _materialIcons =
    '/opt/homebrew/Caskroom/flutter/3.47.1/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  final icons = FontLoader('MaterialIcons');
  icons.addFont(Future.value(
      ByteData.view((await File(_materialIcons).readAsBytes()).buffer)));
  await Future.wait([inter.load(), icons.load()]);
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      home: Scaffold(
        backgroundColor: const Color(0xFFDDE3EA),
        body: Center(child: child),
      ),
    );

/// (consumed, goal, remaining) for each ring colour.
const _cases = {
  'empty': (0, 2081, 2081),
  'ontrack': (600, 2081, 1481),
  'halfway': (1086, 2081, 995),
  'ontarget': (1750, 2081, 331),
  'over': (2210, 2081, 0),
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  for (final entry in _cases.entries) {
    testWidgets('ring widget: ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final (consumed, goal, remaining) = entry.value;
      await tester.pumpWidget(_wrap(CalRingWidgetView(
        consumed: consumed,
        goal: goal,
        remaining: remaining,
      )));
      await tester.pumpAndSettle();
      await expectLater(find.byType(CalRingWidgetView),
          matchesGoldenFile('goldens/ring_widget_${entry.key}.png'));
    });
  }

  testWidgets('ring widget: small, dark', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CalRingWidgetView(
      consumed: 1086,
      goal: 2081,
      remaining: 995,
      dark: true,
      width: 160,
      height: 160,
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(CalRingWidgetView),
        matchesGoldenFile('goldens/ring_widget_small_dark.png'));
  });
}
