import '../models/food_entry.dart';
import '../models/profile.dart';
import 'openai_service.dart';
import 'storage_service.dart';

/// Builds the week's context, asks Asha to review it, and caches the
/// result per calendar week. Reuses the existing proxy/chat pipeline.
class WeeklySummaryService {
  final StorageService storage;

  WeeklySummaryService(this.storage);

  String get _weekKey => StorageService.weekKey(DateTime.now());

  /// Cached summary for the current week, if already generated.
  String? cached() => storage.getWeeklySummary(_weekKey);

  Future<void> clearCache() => storage.saveWeeklySummary(_weekKey, '');
  Future<String> generate() async {
    final summary = await OpenAIService().chat(_systemPrompt, [
      {'role': 'user', 'content': _buildWeekContext()},
    ], maxTokens: 700);
    // Cache even on regenerated runs.
    await storage.saveWeeklySummary(_weekKey, summary);
    return summary;
  }

  String get _systemPrompt =>
      'You are Asha, the warm, witty Hinglish nutrition bestie inside the '
      'Cal Matters app for Indian users. You are given the user\'s goal and '
      'their last 7 days of logged food, weight and exercise. Write a short '
      'weekly review in 2-3 sentences in the same voice: encouraging, '
      'specific, and funny, mixing Hindi/English slang naturally (arre, '
      'bas, bhai, yaar, theek hai). Reference the actual numbers. Celebrate '
      'real wins; nudge the one thing worth fixing. Never lecture, never '
      'sound clinical. If data is thin, say what\'s useful anyway. No emoji '
      'overload: at most 2-3 emojis.';

  String _buildWeekContext() {
    final profile = storage.profile;
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    final dayLines = <String>[];
    for (final d in days) {
      final entries = storage.entries.where((e) => e.isOn(d)).toList();
      if (entries.isEmpty) {
        dayLines.add('  ${d.year}-${d.month}-${d.day}: nothing logged');
        continue;
      }
      final cals = entries.fold<int>(0, (s, e) => s + e.totalCalories);
      final protein = entries.fold<double>(0.0, (s, e) => s + e.totalProtein);
      final carbs = entries.fold<double>(0.0, (s, e) => s + e.totalCarbs);
      final fat = entries.fold<double>(0.0, (s, e) => s + e.totalFat);
      final names = entries
          .expand((e) => e.items)
          .map((i) => i.name)
          .toList();
      dayLines.add(
          '  ${d.year}-${d.month}-${d.day}: $cals kcal, P${protein.round()}g '
          'C${carbs.round()}g F${fat.round()}g — ${names.take(4).join(' / ')}');
    }

    final logged = days.where((d) => storage.entries.any((e) => e.isOn(d))).length;

    // Weight in window: first -> latest.
    double? firstW, lastW;
    final weights = storage.weightEntries
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final w in weights) {
      if (w.date.isBefore(days.first)) continue;
      if (w.date.isAfter(now)) continue;
      firstW ??= w.weightKg;
      lastW = w.weightKg;
    }

    final weekExercises = storage.exercises.where((e) {
      final d = e.dateTime;
      return d.isAfter(days.first.subtract(Duration(days: 1))) && d.isBefore(now.add(const Duration(days: 1)));
    }).toList();
    final exMinutes = weekExercises.fold(0, (s, e) => s + e.minutes);
    final exKcal = weekExercises.fold(0, (s, e) => s + e.calories);

    final goal = profile?.calorieGoal ?? 1500;
    final p = profile;
    return '''
USER PROFILE:
- goal: ${p?.goal ?? 'unknown'} (${goal} kcal/day)
- sex: ${p?.sex ?? '?'}, weight: ${p?.weightKg ?? '?'}kg, height: ${p?.heightCm ?? '?'}cm
- workout frequency: ${p?.workoutFreq ?? '?'}

LAST 7 DAYS (oldest first):
${dayLines.join('\n')}

SUMMARY FACTS:
- days logged: $logged / 7
- daily goal: $goal kcal
- weight change in window: ${firstW != null && lastW != null ? '${firstW}kg -> ${lastW}kg (${(lastW - firstW).toStringAsFixed(1)} change)' : 'no weight logs this week'}
- exercise: ${weekExercises.length} session(s), $exMinutes min, $exKcal kcal burned

Write the weekly review now. Keep it 2-3 sentences, specific to these numbers.''';
  }
}
