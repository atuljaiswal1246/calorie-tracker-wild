/// Meal-aware nudge decision, using the same engine the widget uses.
///
/// Pure logic over [StorageService]: it looks at the widget state covering
/// `now` and returns a single nudge only when the user is inside the window
/// where they usually log a meal ([WidgetMood.due]) and that meal is still
/// unlogged. Everything else (done / over / calm / lastCall) returns null.
library;

import 'storage_service.dart';
import 'widget_state.dart';

class MealNudge {
  final String meal;
  final String title;
  final String body;
  final int sendAtMinute;

  const MealNudge({
    required this.meal,
    required this.title,
    required this.body,
    required this.sendAtMinute,
  });
}

/// Allowed window: 08:00 (inclusive) to 21:00 (exclusive). Anything outside
/// returns null so nothing is ever scheduled at night.
const int mealNudgeEarliestMinute = 8 * 60;
const int mealNudgeLatestMinuteExclusive = 21 * 60;

/// Storage key for the dedupe slot: "yyyyMMdd|meal".
String mealNudgeSentKey(DateTime now, String meal) {
  final d =
      '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return '$d|$meal';
}

final _timePattern = RegExp(r'\d{1,2}(?::\d{2})?\s?[ap]m', caseSensitive: false);

/// Time string quoted by the widget (e.g. "2:30pm"), or null when the widget
/// itself does not claim a time ("Takes about five seconds.").
String? mealNudgeTimeFromContext(String context) {
  final m = _timePattern.firstMatch(context);
  return m?.group(0);
}

MealNudge? decideMealNudge(StorageService storage, DateTime now) {
  // Silent hours: nothing scheduled at night.
  final minute = now.hour * 60 + now.minute;
  if (minute < mealNudgeEarliestMinute ||
      minute >= mealNudgeLatestMinuteExclusive) {
    return null;
  }

  final states = CalWidgetStates.build(storage, now);
  if (states.isEmpty) return null;
  final current = CalWidgetStates.pick(states, minute);

  // Only the due window triggers: inside the user's usual log window with
  // the meal still unlogged. Done / over / calm / lastCall stay quiet.
  if (current.mood != WidgetMood.due) return null;
  final meal = current.mealLabel;
  if (meal.isEmpty) return null;

  // Dedupe: at most once per meal per day.
  final sent = storage.mealNudgeSentRaw;
  if (sent == mealNudgeSentKey(now, meal)) return null;

  // Copy comes from the widget state so the notification never disagrees
  // with what the widget shows.
  final time = mealNudgeTimeFromContext(current.context);
  final body = time != null
      ? 'You usually log around $time - one tap and it\'s done.'
      : 'One tap and it\'s done.';

  return MealNudge(
    meal: meal,
    title: current.hero,
    body: body,
    sendAtMinute: minute,
  );
}
