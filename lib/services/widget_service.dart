import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';

import 'storage_service.dart';

/// Pushes today's summary to the native home-screen widget (Android).
/// iOS widget extension is a later platform task; this is a no-op there.
class WidgetService {
  static const _name = 'com.calorietracker.calorie_tracker.CalWidgetProvider';

  static Future<void> push(StorageService storage) async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now();
      final entries = storage.entries.where((e) => e.isOn(now));
      final cals = entries.fold<int>(0, (s, e) => s + e.totalCalories);
      final goal = storage.profile?.calorieGoal ?? 1500;

      var streak = 0;
      var day = now;
      if (!storage.entries.any((e) => e.isOn(day))) {
        day = day.subtract(const Duration(days: 1));
      }
      while (storage.entries.any((e) => e.isOn(day))) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      }

      await HomeWidget.saveWidgetData<int>('calories', cals);
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.updateWidget(androidName: _name);
    } catch (_) {
      // Widget is best-effort — never break the app for it.
    }
  }
}
