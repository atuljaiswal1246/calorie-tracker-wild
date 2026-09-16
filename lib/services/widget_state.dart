import 'storage_service.dart';

enum WidgetMood { calm, due, lastCall, done, over }

/// One look the widget can wear, plus the slice of the day it applies to.
///
/// The widget's only job is to bring the user into the app, so a state carries
/// a *trigger* (the hero), a reason, and one action — not a dashboard. The
/// windows are not a fixed schedule: they come from when *this user* normally
/// logs each meal (median of their own last 30 days).
class CalWidgetState {
  final WidgetMood mood;

  /// The trigger: "Lunch?" / "Dinner's the last call".
  final String hero;

  /// Why now: their own meal time, or an honest invitation when unknown.
  final String context;

  /// The single action, or null when the day is closed (go quiet).
  final String? pill;

  final int remaining;
  final int consumed;
  final int goal;
  final int streak;

  /// Only true late in the day, still unlogged — the stake.
  final bool streakAtRisk;

  final List<WidgetDay> week;
  final String mealLabel;

  /// How many of the user's own logs backed the meal time we're quoting.
  final bool learnedTime;

  final int startMinute;
  final int endMinute;

  const CalWidgetState({
    required this.mood,
    required this.hero,
    required this.context,
    required this.pill,
    required this.remaining,
    required this.consumed,
    required this.goal,
    required this.streak,
    required this.streakAtRisk,
    required this.week,
    required this.mealLabel,
    required this.learnedTime,
    required this.startMinute,
    required this.endMinute,
  });

  double get progress => goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
}

/// A day in the widget's week chain.
enum WidgetDay { future, empty, logged, onTarget }

class CalWidgetStates {
  static const meals = ['breakfast', 'lunch', 'dinner'];

  /// Fallback times (minutes past midnight) — used for *windows* only, never
  /// for copy that claims to know the user.
  static const fallback = {
    'breakfast': 8 * 60,
    'lunch': 13 * 60,
    'dinner': 20 * 60,
  };

  /// How many of the user's own logs before we may quote their meal time.
  static const minLogsToLearn = 3;

  static List<CalWidgetState> build(StorageService storage, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final goal = storage.profile?.calorieGoal ?? 1500;

    int calsOn(DateTime d) => storage.entries
        .where((e) => e.isOn(d))
        .fold<int>(0, (s, e) => s + e.totalCalories);

    final consumed = calsOn(today);
    final remaining = (goal - consumed).clamp(0, 99999);
    final streak = _streak(storage, today);
    final usual = _usualTimes(storage, today);
    final loggedToday = _loggedMealsToday(storage, today);
    final firstEver = _firstEntryDate(storage);
    final week = _weekChain(storage, today, firstEver, goal, calsOn);

    CalWidgetState make(
      WidgetMood mood,
      String hero,
      String context,
      String? pill,
      String meal,
      int start,
      int end, {
      bool atRisk = false,
      bool learned = false,
    }) =>
        CalWidgetState(
          mood: mood,
          hero: hero,
          context: context,
          pill: pill,
          remaining: remaining,
          consumed: consumed,
          goal: goal,
          streak: streak,
          streakAtRisk: atRisk,
          week: week,
          mealLabel: meal,
          learnedTime: learned,
          startMinute: start,
          endMinute: end,
        );

    String invitation(String meal) {
      final learned = usual[meal]?.learned ?? false;
      return learned
          ? 'You usually log around ${_clock(usual[meal]!.minute)}.'
          : 'Takes about five seconds.';
    }

    // Over budget overrides everything.
    if (remaining <= 0) {
      return [
        make(WidgetMood.over, 'Over by ${consumed - goal} kcal',
            '$consumed of $goal kcal.', null, '', 0, 1440),
      ];
    }

    // Everything they normally log is in: go quiet.
    if (meals.every(loggedToday.contains)) {
      return [
        make(WidgetMood.done, 'Done for today', '$consumed of $goal kcal.',
            null, '', _minutesOf(now), 1440),
      ];
    }

    final unlogged = meals.where((m) => !loggedToday.contains(m)).toList();
    final states = <CalWidgetState>[];
    var cursor = 0;
    for (var i = 0; i < unlogged.length; i++) {
      final m = unlogged[i];
      final info = usual[m]!;
      final nextStart =
          i + 1 < unlogged.length ? (usual[unlogged[i + 1]]!.minute - 60) : 1440;
      final calmEnd = (info.minute - 60).clamp(cursor, 1440);
      final dueEnd = (info.minute + 120).clamp(calmEnd + 1, 1440);
      final lastEnd = nextStart.clamp(dueEnd, 1440);
      final isLast = m == meals.last;
      final label = _label(m);

      if (calmEnd > cursor) {
        states.add(make(WidgetMood.calm, '$label?', invitation(m),
            '+ Log $m', m, cursor, calmEnd,
            learned: info.learned));
      }
      states.add(make(WidgetMood.due, '$label?', invitation(m), '+ Log $m', m,
          calmEnd, dueEnd,
          learned: info.learned));
      states.add(make(
        WidgetMood.lastCall,
        isLast ? "Dinner's the last call" : "$label's still unlogged",
        'Still unlogged at ${_clock(_minutesOf(now))}.',
        '+ Log $m',
        m,
        dueEnd,
        lastEnd,
        atRisk: streak > 0,
        learned: info.learned,
      ));
      cursor = lastEnd;
    }

    if (states.isEmpty) {
      return [
        make(WidgetMood.calm, 'Today', '$consumed of $goal kcal.', '+ Log a meal',
            'snack', 0, 1440),
      ];
    }
    return states;
  }

  /// The user's usual minute for a meal, and whether we've actually earned the
  /// right to say so (>= minLogsToLearn of their own logs).
  static Map<String, _Usual> _usualTimes(
      StorageService storage, DateTime today) {
    final out = <String, _Usual>{};
    final cutoff = today.subtract(const Duration(days: 30));
    for (final meal in meals) {
      final minutes = storage.entries
          .where((e) =>
              e.mealType == meal &&
              e.dateTime.isBefore(today) &&
              e.dateTime.isAfter(cutoff))
          .map((e) => e.dateTime.hour * 60 + e.dateTime.minute)
          .toList()
        ..sort();
      out[meal] = minutes.length >= minLogsToLearn
          ? _Usual(minutes[minutes.length ~/ 2], true)
          : _Usual(fallback[meal]!, false);
    }
    return out;
  }

  /// Monday..Sunday. Days before the user's very first entry are neutral —
  /// nothing was "missed" before they started.
  static List<WidgetDay> _weekChain(
    StorageService storage,
    DateTime today,
    DateTime? firstEver,
    int goal,
    int Function(DateTime) calsOn,
  ) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      if (d.isAfter(today)) return WidgetDay.future;
      if (firstEver != null && d.isBefore(firstEver)) return WidgetDay.future;
      final cal = calsOn(d);
      if (goal > 0 && cal >= goal * 0.8) return WidgetDay.onTarget;
      if (cal > 0) return WidgetDay.logged;
      return WidgetDay.empty;
    });
  }

  static DateTime? _firstEntryDate(StorageService storage) {
    if (storage.entries.isEmpty) return null;
    final earliest = storage.entries
        .map((e) => e.dateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(earliest.year, earliest.month, earliest.day);
  }

  static Set<String> _loggedMealsToday(StorageService storage, DateTime today) =>
      storage.entries.where((e) => e.isOn(today)).map((e) => e.mealType).toSet();

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

  /// Which state covers [minute] — used by tests, and the same rule the native
  /// side applies.
  static CalWidgetState pick(List<CalWidgetState> states, int minute) {
    for (final s in states) {
      if (minute >= s.startMinute && minute < s.endMinute) return s;
    }
    return states.last;
  }
}

class _Usual {
  final int minute;
  final bool learned;
  const _Usual(this.minute, this.learned);
}
