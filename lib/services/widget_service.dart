import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/cal_ring_widget_view.dart';
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
  static const _waterAndroidName =
      'com.calorietracker.calorie_tracker.CalWaterWidgetProvider';
  static const _ringAndroidName =
      'com.calorietracker.calorie_tracker.CalRingWidgetProvider';
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

      final states = CalWidgetStates.build(storage, now);
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
        // The native side echoes this back in the deep link, so a tap can be
        // attributed to the state that caused it.
        await HomeWidget.saveWidgetData<String>(
            'state_mood_$i', states[i].mood.name);
      }

      await HomeWidget.saveWidgetData<int>('state_count', windows.length);
      await HomeWidget.saveWidgetData<String>(
          'state_windows', jsonEncode(windows));
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

  /// One glass. The water widget is drawn natively, so this only has to hand
  /// it the numbers — it never needs a rendered picture, and therefore can
  /// never be stale.
  static const glassMl = 250;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The ring widget — status only, no prompt. Rendered at two sizes so the
  /// native side can pick without scaling artifacts.
  static Future<void> pushRing(StorageService storage) async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now();
      final goal = storage.profile?.calorieGoal ?? 1500;
      final consumed = storage.entries
          .where((e) => e.isOn(now))
          .fold<int>(0, (s, e) => s + e.totalCalories);
      final remaining = (goal - consumed).clamp(0, 999999);
      final dark = PlatformDispatcher.instance.platformBrightness ==
          Brightness.dark;

      await HomeWidget.renderFlutterWidget(
        CalRingWidgetView(
          consumed: consumed,
          goal: goal,
          remaining: remaining,
          dark: dark,
          width: 160,
          height: 160,
        ),
        key: 'ring_small',
        logicalSize: const Size(160, 160),
        pixelRatio: 2.5,
      );
      await HomeWidget.renderFlutterWidget(
        CalRingWidgetView(
          consumed: consumed,
          goal: goal,
          remaining: remaining,
          dark: dark,
        ),
        key: 'ring_medium',
        logicalSize: const Size(340, 168),
        pixelRatio: 2.5,
      );
      await HomeWidget.saveWidgetData<int>('ring_over', remaining <= 0 ? 1 : 0);
      await HomeWidget.updateWidget(androidName: _ringAndroidName);
    } catch (e) {
      debugPrint('Ring widget push failed: $e');
    }
  }

  static Future<void> pushWater(StorageService storage) async {
    if (!Platform.isAndroid) return;
    try {
      final now = DateTime.now();
      await HomeWidget.saveWidgetData<int>(
          'water_ml', storage.waterMlForDay(now));
      await HomeWidget.saveWidgetData<int>('water_goal', storage.waterGoalMl);
      // The native side zeroes the count if this no longer matches today,
      // which is what makes the widget reset at midnight.
      await HomeWidget.saveWidgetData<String>('water_day', dayKey(now));
      await HomeWidget.updateWidget(androidName: _waterAndroidName);
    } catch (e) {
      debugPrint('Water widget push failed: $e');
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


/// Entry point for the water widget's one-tap action.
///
/// Runs in a background isolate with no UI — it writes the glass through the
/// same StorageService rules the in-app card uses, then hands the widget fresh
/// numbers. It must never render Flutter (there is no view here), which is
/// exactly why the water widget is drawn natively.
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  if (uri == null) return;
  try {
    if (uri.host == 'water') {
      final ml =
          int.tryParse(uri.queryParameters['ml'] ?? '') ?? WidgetService.glassMl;
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      await storage.addWater(ml);
      await WidgetService.pushWater(storage);
    }
  } catch (e) {
    debugPrint('widgetInteractivityCallback failed: $e');
  }
}
