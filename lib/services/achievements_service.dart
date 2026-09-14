import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../services/storage_service.dart';
import 'gamification_service.dart';

/// A dynamic achievement. Replaces the old fixed set of 10 — every
/// achievement now carries a category and live progress toward its target.
class Achievement {
  final String id;
  final String category;
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;
  final DateTime? unlockedAt;
  final double progress;

  Achievement({
    required this.id,
    this.category = 'General',
    required this.title,
    required this.description,
    required this.emoji,
    this.unlocked = false,
    this.unlockedAt,
    this.progress = 1.0,
  });
}

/// Everything the achievement engine derives achievements from, computed once
/// per [AchievementsService.getAll] call.
class AchievementStats {
  final int totalMeals;
  final int scans;
  final int uniqueFoods;
  final int waterGoalDays;
  final int weightDays;
  final int exerciseCount;
  final int exerciseBestStreak;
  final int proteinGoalDays;
  final int friends;
  final int level;
  final int coins;
  final int longestStreak;
  final bool hasProfile;
  final bool nightOwl;
  final bool balancedDay;
  final bool weightChanged;
  final int monthDaysLogged;

  const AchievementStats({
    required this.totalMeals,
    required this.scans,
    required this.uniqueFoods,
    required this.waterGoalDays,
    required this.weightDays,
    required this.exerciseCount,
    required this.exerciseBestStreak,
    required this.proteinGoalDays,
    required this.friends,
    required this.level,
    required this.coins,
    required this.longestStreak,
    required this.hasProfile,
    required this.nightOwl,
    required this.balancedDay,
    required this.weightChanged,
    required this.monthDaysLogged,
  });
}

class _Def {
  final String id;
  final String category;
  final String title;
  final String description;
  final String emoji;
  final int target;
  final int Function(AchievementStats s) value;
  final bool secret;

  const _Def({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.emoji,
    required this.target,
    required this.value,
    this.secret = false,
  });
}

class AchievementsService {
  final StorageService _storage;

  AchievementsService(this._storage);

  Map<String, String> get _unlocked {
    final raw = _storage.getAchievementsRaw();
    if (raw == null) return {};
    return Map<String, String>.from(raw);
  }

  /// The full dynamic catalogue (plan §4.7). ~40 achievements across 10
  /// categories; the count grows as we add seasonal/secret entries.
  static final List<_Def> _defs = [
    // ── Streaks ──────────────────────────────────────────────────────
    _Def(id: 'streak_3', category: 'Streaks', title: 'Getting Started', emoji: '🔥', description: 'Reach a 3-day streak', target: 3, value: (s) => s.longestStreak),
    _Def(id: 'streak_7', category: 'Streaks', title: 'Week Warrior', emoji: '⚡', description: 'Reach a 7-day streak', target: 7, value: (s) => s.longestStreak),
    _Def(id: 'streak_14', category: 'Streaks', title: 'Fortnight Champion', emoji: '💪', description: 'Reach a 14-day streak', target: 14, value: (s) => s.longestStreak),
    _Def(id: 'streak_30', category: 'Streaks', title: 'Monthly Master', emoji: '👑', description: 'Reach a 30-day streak', target: 30, value: (s) => s.longestStreak),
    _Def(id: 'streak_50', category: 'Streaks', title: 'Unstoppable', emoji: '🌩️', description: 'Reach a 50-day streak', target: 50, value: (s) => s.longestStreak),
    _Def(id: 'streak_100', category: 'Streaks', title: 'Century Legend', emoji: '💎', description: 'Reach a 100-day streak', target: 100, value: (s) => s.longestStreak),
    _Def(id: 'streak_365', category: 'Streaks', title: 'Year of Growth', emoji: '🏆', description: 'Reach a 365-day streak', target: 365, value: (s) => s.longestStreak),

    // ── Meal logging ─────────────────────────────────────────────────
    _Def(id: 'meals_1', category: 'Meal Logging', title: 'First Bite', emoji: '🍽️', description: 'Log your first meal', target: 1, value: (s) => s.totalMeals),
    _Def(id: 'meals_10', category: 'Meal Logging', title: 'Meal Logger', emoji: '📝', description: 'Log 10 meals', target: 10, value: (s) => s.totalMeals),
    _Def(id: 'meals_50', category: 'Meal Logging', title: 'Dedicated Logger', emoji: '📒', description: 'Log 50 meals', target: 50, value: (s) => s.totalMeals),
    _Def(id: 'meals_100', category: 'Meal Logging', title: 'Century Club', emoji: '💯', description: 'Log 100 meals', target: 100, value: (s) => s.totalMeals),
    _Def(id: 'meals_500', category: 'Meal Logging', title: 'Consistent', emoji: '📚', description: 'Log 500 meals', target: 500, value: (s) => s.totalMeals),
    _Def(id: 'meals_1000', category: 'Meal Logging', title: 'Thousand Plates', emoji: '🗃️', description: 'Log 1000 meals', target: 1000, value: (s) => s.totalMeals),

    // ── Hydration ────────────────────────────────────────────────────
    _Def(id: 'water_1', category: 'Hydration', title: 'Hydrated', emoji: '💧', description: 'Hit your water goal once', target: 1, value: (s) => s.waterGoalDays),
    _Def(id: 'water_7', category: 'Hydration', title: 'Well Watered', emoji: '🌊', description: 'Hit your water goal 7 days', target: 7, value: (s) => s.waterGoalDays),
    _Def(id: 'water_30', category: 'Hydration', title: 'Water Ritual', emoji: '🚰', description: 'Hit your water goal 30 days', target: 30, value: (s) => s.waterGoalDays),
    _Def(id: 'water_100', category: 'Hydration', title: 'Fountain', emoji: '⛲', description: 'Hit your water goal 100 days', target: 100, value: (s) => s.waterGoalDays),

    // ── Weight tracking ──────────────────────────────────────────────
    _Def(id: 'weight_1', category: 'Weight Tracking', title: 'On the Scale', emoji: '⚖️', description: 'Log your weight', target: 1, value: (s) => s.weightDays),
    _Def(id: 'weight_7', category: 'Weight Tracking', title: 'Weekly Check-in', emoji: '📆', description: 'Log your weight 7 days', target: 7, value: (s) => s.weightDays),
    _Def(id: 'weight_30', category: 'Weight Tracking', title: 'Trend Watcher', emoji: '📈', description: 'Log your weight 30 days', target: 30, value: (s) => s.weightDays),
    _Def(id: 'weight_90', category: 'Weight Tracking', title: 'Long View', emoji: '🔭', description: 'Log your weight 90 days', target: 90, value: (s) => s.weightDays),
    _Def(id: 'weight_change', category: 'Weight Tracking', title: 'Progress', emoji: '🎯', description: 'Record your first change', target: 1, value: (s) => s.weightChanged ? 1 : 0),

    // ── Activity ─────────────────────────────────────────────────────
    _Def(id: 'exercise_1', category: 'Activity', title: 'Move It', emoji: '🏃', description: 'Log exercise', target: 1, value: (s) => s.exerciseCount),
    _Def(id: 'exercise_10', category: 'Activity', title: 'Active Habit', emoji: '🚴', description: 'Log exercise 10 times', target: 10, value: (s) => s.exerciseCount),
    _Def(id: 'exercise_50', category: 'Activity', title: 'Athlete', emoji: '🏋️', description: 'Log exercise 50 times', target: 50, value: (s) => s.exerciseCount),
    _Def(id: 'exercise_week', category: 'Activity', title: 'Active Week', emoji: '📅', description: 'Log exercise 7 days in a row', target: 7, value: (s) => s.exerciseBestStreak),

    // ── AI Explorer ──────────────────────────────────────────────────
    _Def(id: 'scan_1', category: 'AI Explorer', title: 'First Scan', emoji: '📸', description: 'Scan your first meal', target: 1, value: (s) => s.scans),
    _Def(id: 'scan_10', category: 'AI Explorer', title: 'Scanner', emoji: '🔎', description: 'Scan 10 meals', target: 10, value: (s) => s.scans),
    _Def(id: 'scan_50', category: 'AI Explorer', title: 'AI Native', emoji: '🤖', description: 'Scan 50 meals', target: 50, value: (s) => s.scans),
    _Def(id: 'night_owl', category: 'AI Explorer', title: 'Night Owl', emoji: '🦉', description: 'Hidden achievement', target: 1, value: (s) => s.nightOwl ? 1 : 0, secret: true),

    // ── Nutrition ────────────────────────────────────────────────────
    _Def(id: 'unique_20', category: 'Nutrition', title: 'Explorer', emoji: '🧭', description: 'Try 20 unique foods', target: 20, value: (s) => s.uniqueFoods),
    _Def(id: 'protein_5', category: 'Nutrition', title: 'Protein Pro', emoji: '🥚', description: 'Hit your protein goal 5 days', target: 5, value: (s) => s.proteinGoalDays),
    _Def(id: 'protein_20', category: 'Nutrition', title: 'Protein Master', emoji: '🍗', description: 'Hit your protein goal 20 days', target: 20, value: (s) => s.proteinGoalDays),
    _Def(id: 'balanced_day', category: 'Nutrition', title: 'Balanced', emoji: '🥗', description: 'Log a balanced macro day', target: 1, value: (s) => s.balancedDay ? 1 : 0),

    // ── Milestones ───────────────────────────────────────────────────
    _Def(id: 'level_5', category: 'Milestones', title: 'Bloomer', emoji: '🌸', description: 'Reach level 5', target: 5, value: (s) => s.level),
    _Def(id: 'level_10', category: 'Milestones', title: 'Nutrition Sage', emoji: '🧘', description: 'Reach level 10', target: 10, value: (s) => s.level),
    _Def(id: 'level_20', category: 'Milestones', title: 'Legend', emoji: '🌟', description: 'Reach level 20', target: 20, value: (s) => s.level),
    _Def(id: 'coins_1000', category: 'Milestones', title: 'Coin Collector', emoji: '🪙', description: 'Earn 1000 NutriCoins', target: 1000, value: (s) => s.coins),

    // ── Social & profile ─────────────────────────────────────────────
    _Def(id: 'friend_1', category: 'Social', title: 'Not Alone', emoji: '🤝', description: 'Add your first friend', target: 1, value: (s) => s.friends),
    _Def(id: 'friend_5', category: 'Social', title: 'Squad', emoji: '👥', description: 'Add 5 friends', target: 5, value: (s) => s.friends),
    _Def(id: 'profile_setup', category: 'Profile', title: 'Profile Complete', emoji: '✅', description: 'Set up your profile', target: 1, value: (s) => s.hasProfile ? 1 : 0),
  ];

  AchievementStats _stats() {
    final entries = _storage.entries;
    final profile = _storage.profile;
    final gami = _storage.gamification;

    final scans = entries.where((e) => e.imagePath.isNotEmpty).length;
    final uniqueFoods = <String>{};
    final entriesByDay = <String, List<FoodEntry>>{};
    var nightOwl = false;
    for (final e in entries) {
      for (final item in e.items) {
        if (item.name.trim().isNotEmpty) {
          uniqueFoods.add(item.name.trim().toLowerCase());
        }
      }
      final key = '${e.dateTime.year}-${e.dateTime.month}-${e.dateTime.day}';
      entriesByDay.putIfAbsent(key, () => []).add(e);
      if (e.dateTime.hour >= 2 && e.dateTime.hour <= 4) nightOwl = true;
    }

    final proteinTarget = profile?.proteinGrams ?? 0;
    var proteinGoalDays = 0;
    var balancedDay = false;
    if (proteinTarget > 0) {
      entriesByDay.forEach((_, list) {
        final protein = list.fold<double>(0, (a, e) => a + e.totalProtein);
        final carbs = list.fold<double>(0, (a, e) => a + e.totalCarbs);
        final fat = list.fold<double>(0, (a, e) => a + e.totalFat);
        if (protein >= proteinTarget) proteinGoalDays++;
        if (protein >= proteinTarget * 0.8 && carbs > 0 && fat > 0) {
          balancedDay = true;
        }
      });
    }

    final weights = _storage.weightEntries;
    final weightChanged = weights.length >= 2 &&
        weights.first.weightKg != weights.last.weightKg;

    final now = DateTime.now();
    final monthDaysLogged = entries
        .where((e) => e.dateTime.year == now.year && e.dateTime.month == now.month)
        .map((e) => e.dateTime.day)
        .toSet()
        .length;

    final exercises = _storage.exercises;
    final level = GamificationService.levelForPoints(gami.calPoints);

    return AchievementStats(
      totalMeals: entries.length,
      scans: scans,
      uniqueFoods: uniqueFoods.length,
      waterGoalDays:
          _storage.waterEntries.where((w) => w.ml >= _storage.waterGoalMl).length,
      weightDays: weights.length,
      exerciseCount: exercises.length,
      exerciseBestStreak: _longestDayRun(exercises.map((e) => e.dateTime)),
      proteinGoalDays: proteinGoalDays,
      friends: _storage.friends.length,
      level: level,
      coins: gami.nutriCoins,
      longestStreak: gami.streak.longest,
      hasProfile: profile != null,
      nightOwl: nightOwl,
      balancedDay: balancedDay,
      weightChanged: weightChanged,
      monthDaysLogged: monthDaysLogged,
    );
  }

  /// Longest run of consecutive calendar days in [dates].
  int _longestDayRun(Iterable<DateTime> dates) {
    final days = dates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();
    if (days.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  /// A rotating monthly achievement ("Monsoon Warrior" in July, etc.).
  Achievement _seasonal(AchievementStats stats, Map<String, String> unlocked) {
    final now = DateTime.now();
    final id = 'seasonal_${now.year}_${now.month}';
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final iso = unlocked[id];
    return Achievement(
      id: id,
      category: 'Seasonal',
      title: '${names[now.month]} Warrior',
      description: 'Log 10 days this month',
      emoji: _seasonEmoji(now.month),
      unlocked: stats.monthDaysLogged >= 10,
      unlockedAt: iso != null ? DateTime.tryParse(iso) : null,
      progress: (stats.monthDaysLogged / 10).clamp(0.0, 1.0).toDouble(),
    );
  }

  static String _seasonEmoji(int month) {
    if (month >= 6 && month <= 9) return '🌧️'; // monsoon
    if (month >= 10 && month <= 11) return '🍂';
    if (month == 12 || month <= 2) return '❄️';
    return '☀️';
  }

  List<Achievement> getAll() {
    final unlocked = _unlocked;
    final stats = _stats();
    return [
      _seasonal(stats, unlocked),
      for (final def in _defs)
        () {
          final value = def.value(stats);
          final isUnlocked = value >= def.target;
          final iso = unlocked[def.id];
          return Achievement(
            id: def.id,
            category: def.category,
            title: def.secret && !isUnlocked ? 'Secret' : def.title,
            description: def.secret && !isUnlocked
                ? 'Keep logging to reveal this one'
                : def.description,
            emoji: def.secret && !isUnlocked ? '❓' : def.emoji,
            unlocked: isUnlocked,
            unlockedAt: iso != null ? DateTime.tryParse(iso) : null,
            progress: def.target <= 0
                ? 1.0
                : (value / def.target).clamp(0.0, 1.0).toDouble(),
          );
        }(),
    ];
  }

  int get unlockedCount => getAll().where((a) => a.unlocked).length;

  int get totalCount => getAll().length;

  /// Check and persist newly unlocked achievements. Returns the new ones.
  List<Achievement> checkAndUpdate() {
    final old = _unlocked;
    final current = getAll();
    final newlyUnlocked = <Achievement>[];

    for (final a in current) {
      if (a.unlocked && !old.containsKey(a.id)) {
        newlyUnlocked.add(a);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      final updated = Map<String, String>.from(old);
      for (final a in newlyUnlocked) {
        updated[a.id] = DateTime.now().toIso8601String();
      }
      _storage.saveAchievements(updated);
    }

    return newlyUnlocked;
  }
}
