import '../widgets/cal_widget_view.dart';
import 'storage_service.dart';

enum WidgetMood { calm, due, lastCall, done, over }

/// One look the widget can wear, plus the slice of the day it applies to.
///
/// The windows are not a fixed schedule: they are derived from when *this user*
/// normally logs each meal (median of their own last 30 days), so "you usually
/// log lunch around 1:30pm" is true for them and not a generic guess.
class CalWidgetState {
  final WidgetMood mood;
  final String line;
  final String caption;
  final int remaining;
  final int consumed;
  final int goal;
  final int streak;
  final List<WidgetDay> week;
  final String mealLabel;
  final int startMinute;
  final int endMinute;

  const CalWidgetState({
    required this.mood,
    required this.line,
    required this.caption,
    required this.remaining,
    required this.consumed,
    required this.goal,
    required this.streak,
    required this.week,
    required this.mealLabel,
    required this.startMinute,
    required this.endMinute,
  });

  double get progress => goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

  /// How many meals the user normally logs, in order.
  static const meals = ['breakfast', 'lunch', 'dinner'];

  /// Fallback times (minutes past midnight) used only until we know better.
  static const _fallback = {'breakfast': 8 * 60, 'lunch': 13 * 60, 'dinner': 20 * 60};
}

class CalCalWidgetStates {
  /// Build today's states, with windows, from real data.
  static List<CalWidgetState> build(StorageService storage, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final goal = storage.profile?.calorieGoal ?? 1500;

    int calsOn(DateTime d) => storage.entries
        .where((e) => e.isOn(d))
        .fold<int>(0, (s, e) => s + e.totalCalories);

    final consumed = calsOn(today);
    final remaining = (goal - consumed).clamp(0, 99999);

    // The week chain (Monday..Sunday).
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      if (d.isAfter(today)) return WidgetDay.future;
      final cal = calsOn(d);
      if (goal > 0 && cal >= goal * 0.8) return WidgetDay.onTarget;
      if (cal > 0) return WidgetDay.logged;
      return WidgetDay.empty;
    });

    final streak = _streak(storage, today);
    final usual = _usualTimes(storage, today);
    final loggedToday = _loggedMealsToday(storage, today);

    CalWidgetState make(
      WidgetMood mood,
      String line,
      String meal,
      int start,
      int end, {
      String? caption,
    }) =>
        CalWidgetState(
          mood: mood,
          line: line,
          caption: caption ?? '$streak-day streak · $remaining left',
          remaining: remaining,
          consumed: consumed,
          goal: goal,
          streak: streak,
          week: week,
          mealLabel: meal,
          startMinute: start,
          endMinute: end,
        );

    // Over budget overrides everything — the only thing worth saying.
    if (remaining <= 0) {
      return [
        make(WidgetMood.over, 'Over by ${consumed - goal} kcal',
            _nextMeal(loggedToday), 0, 1440,
            caption: '$streak-day streak'),
      ];
    }

    // Everything they normally log is in: relax for the rest of the day.
    if (CalWidgetState.meals.every(loggedToday.contains)) {
      return [
        make(WidgetMood.done, "Logged — day's on track", '',
            _minutesOf(now), 1440),
      ];
    }

    // Otherwise lay out the whole day as non-overlapping windows anchored on
    // this user's own meal times, so whatever the clock says, the widget has
    // the right thing to show — breakfast calm, lunch due, dinner last call.
    final unlogged =
        CalWidgetState.meals.where((m) => !loggedToday.contains(m)).toList();
    final states = <CalWidgetState>[];
    var cursor = 0;
    for (var i = 0; i < unlogged.length; i++) {
      final m = unlogged[i];
      final at = usual[m] ?? CalWidgetState._fallback[m]!;
      final nextStart = i + 1 < unlogged.length
          ? (usual[unlogged[i + 1]] ?? 0) - 60
          : 1440;
      final calmEnd = (at - 60).clamp(cursor, 1440);
      final dueEnd = (at + 120).clamp(calmEnd + 1, 1440);
      final lastEnd = nextStart.clamp(dueEnd, 1440);
      final isLast = m == CalWidgetState.meals.last;

      if (calmEnd > cursor) {
        states.add(make(WidgetMood.calm, 'Today · $streak-day streak', m,
            cursor, calmEnd,
            caption: '$consumed of $goal kcal'));
      }
      states.add(make(
        WidgetMood.due,
        'You usually log $m around ${_clock(at)}',
        m,
        calmEnd,
        dueEnd,
      ));
      states.add(make(
        WidgetMood.lastCall,
        isLast ? 'Dinner is the last call' : '${_label(m)} still unlogged',
        m,
        dueEnd,
        lastEnd,
      ));
      cursor = lastEnd;
    }

    if (states.isEmpty) {
      return [
        make(WidgetMood.calm, 'Today · $streak-day streak', '', 0, 1440),
      ];
    }
    return states;
  }

  /// The hour this user normally logs each meal, from their own history.
  static Map<String, int> _usualTimes(StorageService storage, DateTime today) {
    final out = <String, int>{};
    final cutoff = today.subtract(const Duration(days: 30));
    for (final meal in CalWidgetState.meals) {
      final hours = storage.entries
          .where((e) =>
              e.mealType == meal &&
              e.dateTime.isBefore(today) &&
              e.dateTime.isAfter(cutoff))
          .map((e) => e.dateTime.hour * 60 + e.dateTime.minute)
          .toList()
        ..sort();
      if (hours.length >= 3) {
        out[meal] = hours[hours.length ~/ 2]; // median
      } else {
        out[meal] = CalWidgetState._fallback[meal]!;
      }
    }
    return out;
  }

  static Set<String> _loggedMealsToday(StorageService storage, DateTime today) =>
      storage.entries
          .where((e) => e.isOn(today))
          .map((e) => e.mealType)
          .toSet();

  static int _streak(StorageService storage, DateTime today) {
    var streak = 0;
    var day = storage.entries.any((e) => e.isOn(today))
        ? today
        : today.subtract(const Duration(days: 1));
    while (storage.entries.any((e) => e.isOn(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String _nextMeal(Set<String> logged) {
    for (final m in CalWidgetState.meals) {
      if (!logged.contains(m)) return m;
    }
    return 'snack';
  }

  static String _label(String meal) =>
      meal.isEmpty ? meal : meal[0].toUpperCase() + meal.substring(1);

  static String _clock(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final ampm = h < 12 ? 'am' : 'pm';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return m == 0 ? '$h12$ampm' : '$h12:${m.toString().padLeft(2, '0')}$ampm';
  }

  static int _minutesOf(DateTime t) => t.hour * 60 + t.minute;

  /// Which state covers [minute] — used by the native side to pick, and by
  /// tests.
  static CalWidgetState pick(List<CalWidgetState> states, int minute) {
    for (final s in states) {
      if (minute >= s.startMinute && minute < s.endMinute) return s;
    }
    return states.last;
  }
}
