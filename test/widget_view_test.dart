import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/services/widget_state.dart';
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
      hero: 'Lunch?',
      subline: 'You usually log around 1:30pm.',
      pill: '+ Log lunch',
      remaining: 995,
      streak: 12,
      mood: WidgetMood.due,
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

  testWidgets('widget view: dark mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CalWidgetView(
      hero: "Dinner's the last call",
      subline: 'Still unlogged at 9:40pm.',
      pill: '+ Log dinner',
      remaining: 640,
      streak: 12,
      streakAtRisk: true,
      dark: true,
      mood: WidgetMood.lastCall,
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
        matchesGoldenFile('goldens/cal_widget_dark.png'));
  });

  testWidgets('widget view: calm morning', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CalWidgetView(
      hero: 'Breakfast?',
      subline: 'Takes about five seconds.',
      pill: '+ Log breakfast',
      remaining: 2081,
      streak: 0,
      mood: WidgetMood.calm,
      week: [
        WidgetDay.onTarget,
        WidgetDay.onTarget,
        WidgetDay.logged,
        WidgetDay.future,
        WidgetDay.future,
        WidgetDay.future,
        WidgetDay.future,
      ],
      mealLabel: 'breakfast',
    )));
    await tester.pumpAndSettle();
    await expectLater(find.byType(CalWidgetView),
        matchesGoldenFile('goldens/cal_widget_calm.png'));
  });

  testWidgets('widget view: over budget', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CalWidgetView(
      hero: 'Over by 129 kcal',
      subline: '2210 of 2081 kcal.',
      pill: null,
      remaining: 0,
      streak: 12,
      mood: WidgetMood.over,
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
