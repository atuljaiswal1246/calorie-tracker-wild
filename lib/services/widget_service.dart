import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../widgets/cal_widget_view.dart';
import 'storage_service.dart';

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

      final view = CalWidgetView(
        remaining: remaining,
        consumed: consumed,
        goal: goal,
        week: week,
        mealLabel: mealLabelFor(now),
      );

      await HomeWidget.saveWidgetData<int>('remaining', remaining);
      await HomeWidget.saveWidgetData<int>('consumed', consumed);
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.renderFlutterWidget(
        view,
        key: _imageKey,
        logicalSize: Size(view.width, view.height),
        pixelRatio: 2.5,
      );
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (e) {
      // Widget is best-effort — never break the app for it.
      debugPrint('Widget push failed: $e');
    }
  }

  /// The meal the user is most likely to be logging right now.
  static String mealLabelFor(DateTime now) {
    final h = now.hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 21) return 'dinner';
    return 'a snack';
  }
}
