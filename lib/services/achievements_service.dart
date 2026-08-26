import '../services/storage_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) => Achievement(
        id: id,
        title: title,
        description: description,
        emoji: emoji,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
}

class AchievementsService {
  final StorageService _storage;

  AchievementsService(this._storage);

  static const _unlockedKey = 'unlocked_achievements';

  Map<String, String> get _unlocked {
    final raw = _storage.getAchievementsRaw();
    if (raw == null) return {};
    return Map<String, String>.from(raw);
  }

  List<Achievement> getAll() {
    final unlocked = _unlocked;
    final entries = _storage.entries;
    final waterMl = _storage.waterMlForDay(DateTime.now());
    final streak = _calculateStreak(entries);

    final all = <Achievement>[
      // Streak achievements
      Achievement(
        id: 'streak_3',
        title: 'Getting Started',
        description: 'Log meals 3 days in a row',
        emoji: '🔥',
        unlocked: streak >= 3,
        unlockedAt: unlocked['streak_3'] != null
            ? DateTime.tryParse(unlocked['streak_3']!)
            : null,
      ),
      Achievement(
        id: 'streak_7',
        title: 'One Week Warrior',
        description: 'Log meals 7 days in a row',
        emoji: '⚡',
        unlocked: streak >= 7,
        unlockedAt: unlocked['streak_7'] != null
            ? DateTime.tryParse(unlocked['streak_7']!)
            : null,
      ),
      Achievement(
        id: 'streak_14',
        title: 'Fortnight Fighter',
        description: 'Log meals 14 days in a row',
        emoji: '💪',
        unlocked: streak >= 14,
        unlockedAt: unlocked['streak_14'] != null
            ? DateTime.tryParse(unlocked['streak_14']!)
            : null,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Monthly Master',
        description: 'Log meals 30 days in a row',
        emoji: '👑',
        unlocked: streak >= 30,
        unlockedAt: unlocked['streak_30'] != null
            ? DateTime.tryParse(unlocked['streak_30']!)
            : null,
      ),

      // Meal milestones
      Achievement(
        id: 'meals_1',
        title: 'First Bite',
        description: 'Log your first meal',
        emoji: '🍽️',
        unlocked: entries.isNotEmpty,
        unlockedAt: unlocked['meals_1'] != null
            ? DateTime.tryParse(unlocked['meals_1']!)
            : null,
      ),
      Achievement(
        id: 'meals_10',
        title: 'Meal Logger',
        description: 'Log 10 meals',
        emoji: '📝',
        unlocked: entries.length >= 10,
        unlockedAt: unlocked['meals_10'] != null
            ? DateTime.tryParse(unlocked['meals_10']!)
            : null,
      ),
      Achievement(
        id: 'meals_50',
        title: 'Dedicated Logger',
        description: 'Log 50 meals',
        emoji: '🏆',
        unlocked: entries.length >= 50,
        unlockedAt: unlocked['meals_50'] != null
            ? DateTime.tryParse(unlocked['meals_50']!)
            : null,
      ),
      Achievement(
        id: 'meals_100',
        title: 'Century Club',
        description: 'Log 100 meals',
        emoji: '💯',
        unlocked: entries.length >= 100,
        unlockedAt: unlocked['meals_100'] != null
            ? DateTime.tryParse(unlocked['meals_100']!)
            : null,
      ),

      // Water achievements
      Achievement(
        id: 'water_today',
        title: 'Hydrated',
        description: 'Hit your daily water goal',
        emoji: '💧',
        unlocked: waterMl >= _storage.waterGoalMl,
        unlockedAt: unlocked['water_today'] != null
            ? DateTime.tryParse(unlocked['water_today']!)
            : null,
      ),

      // Profile achievements
      Achievement(
        id: 'profile_setup',
        title: 'Profile Complete',
        description: 'Set up your profile',
        emoji: '✅',
        unlocked: _storage.profile != null,
        unlockedAt: unlocked['profile_setup'] != null
            ? DateTime.tryParse(unlocked['profile_setup']!)
            : null,
      ),
    ];

    return all;
  }

  int get unlockedCount => getAll().where((a) => a.unlocked).length;

  int get totalCount => getAll().length;

  /// Check and persist newly unlocked achievements. Returns list of newly unlocked.
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

  int _calculateStreak(List<dynamic> entries) {
    if (entries.isEmpty) return 0;

    final today = DateTime.now();
    int streak = 0;
    var checkDay = DateTime(today.year, today.month, today.day);

    while (true) {
      final hasEntry = entries.any((e) {
        final d = e.dateTime;
        return d.year == checkDay.year &&
            d.month == checkDay.month &&
            d.day == checkDay.day;
      });

      if (!hasEntry) break;
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
