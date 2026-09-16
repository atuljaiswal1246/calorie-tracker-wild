import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../widgets/cal_widget_view.dart';
import 'storage_service.dart';
import 'widget_state.dart';

/// Pushes today's state to the home-screen widget.
///
/// The widget is drawn in Flutter and rendered to a PNG, so it looks exactly
/// like the app (ring, week chain, type) instead of being limited to what
/// RemoteViews can lay out. iOS needs a WidgetKit extension target before it
/// can show anything; until then this is Android-only.
class WidgetService {
  static const _androidName =
      'com.calorietracker.calorie_tracker.CalWidgetProvider';
  static const _imageKey = 'widget_image';

  static Future<void> push(StorageService storage) async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final goal = storage.profile?.calorieGoal ?? 1500;

      int calsOn(DateTime d) => storage.entries
          .where((e) => e.isOn(d))
          .fold<int>(0, (s, e) => s + e.totalCalories);

      final consumed = calsOn(today);
      final remaining = (goal - consumed).clamp(0, 99999);

      // Monday..Sunday of the current week.
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final week = List.generate(7, (i) {
        final d = monday.add(Duration(days: i));
        if (d.isAfter(today)) return WidgetDay.future;
        final cal = calsOn(d);
        if (goal > 0 && cal >= goal * 0.8) return WidgetDay.onTarget;
        if (cal > 0) return WidgetDay.logged;
        return WidgetDay.empty;
      });

      final states = CalCalWidgetStates.build(storage, now);
      final dark = PlatformDispatcher.instance.platformBrightness ==
          Brightness.dark;

      // Pre-render one bitmap per state and remember the slice of the day each
      // belongs to. The native side then has to do nothing but compare the
      // clock to those windows — so the widget changes through the day without
      // the app being open.
      final windows = <Map<String, int>>[];
      for (var i = 0; i < states.length && i < 8; i++) {
        await HomeWidget.renderFlutterWidget(
          CalWidgetView.fromState(states[i], dark: dark),
          key: 'widget_image_$i',
          logicalSize: const Size(340, 168),
          pixelRatio: 2.5,
        );
        windows.add({
          'start': states[i].startMinute,
          'end': states[i].endMinute,
        });
      }

      await HomeWidget.saveWidgetData<int>('state_count', windows.length);
      await HomeWidget.saveWidgetData<String>('state_windows', jsonEncode(windows));
      await HomeWidget.saveWidgetData<int>('remaining', remaining);
      await HomeWidget.saveWidgetData<int>('streak', streakOf(states));
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (e) {
      // Widget is best-effort — never break the app for it.
      debugPrint('Widget push failed: $e');
    }
  }

  static int streakOf(List<CalWidgetState> states) =>
      states.isEmpty ? 0 : states.first.streak;

  /// The meal the user is most likely to be logging right now.
  static String mealLabelFor(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 21) return 'dinner';
    return 'a snack';
  }
}
