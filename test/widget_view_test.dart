import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/widgets/cal_widget_view.dart';
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('widget view: mid-afternoon', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CalWidgetView(
      remaining: 995,
      consumed: 1086,
      goal: 2081,
      week: [
        WidgetDay.empty,
        WidgetDay.logged,
        WidgetDay.logged,
        WidgetDay.future,
        WidgetDay.future,
        WidgetDay.future,
        WidgetDay.future,
      ],
      mealLabel: 'lunch',
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(CalWidgetView),
        matchesGoldenFile('goldens/cal_widget_lunch.png'));
  });

  testWidgets('widget view: over budget', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CalWidgetView(
      remaining: 0,
      consumed: 2210,
      goal: 2081,
      week: [
        WidgetDay.onTarget,
        WidgetDay.onTarget,
        WidgetDay.logged,
        WidgetDay.onTarget,
        WidgetDay.future,
        WidgetDay.future,
        WidgetDay.future,
      ],
      mealLabel: 'dinner',
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(CalWidgetView),
        matchesGoldenFile('goldens/cal_widget_over.png'));
  });
}
