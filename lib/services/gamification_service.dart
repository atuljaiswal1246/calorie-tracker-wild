/// Gamification core engine (plan §4.1–4.4).
///
/// Pure, clock-injectable logic over a [GamificationState]: it awards Cal
/// Points for *behaviour* (logging), tracks levels, advances the multi-action
/// streak (with automatic freeze forgiveness), grants NutriCoins, and enforces
/// the anti-exploit guardrails.
///
/// Health guardrail (plan §3.2): nothing in this file reads calories. A day
/// logged at 1200 kcal earns exactly the same as one logged at 2000 kcal.
library;

import '../models/gamification_state.dart';

/// A rewardable behaviour. `points`/`coins`/`dailyLimit` are the plan §4.1
/// values; `countsForStreak` marks the four qualifying actions of §4.3.
enum GamificationAction {
  mealManual('meal_manual', 10, 0, 3, true),
  mealScan('meal_scan', 15, 0, 3, true),
  waterGoal('water_goal', 10, 0, 1, true),
  weightLog('weight_log', 5, 0, 1, true),
  exerciseLog('exercise_log', 10, 0, 1, true),
  questComplete('quest_complete', 15, 10, 3, false),
  questBonus('quest_bonus', 25, 20, 1, false),
  streakDay('streak_day', 5, 0, 1, false),
  ashaChat('asha_chat', 5, 0, 2, false),
  fastingLog('fasting_log', 5, 0, 1, false);

  const GamificationAction(this.key, this.points, this.coins, this.dailyLimit,
      this.countsForStreak);

  final String key;
  final int points;
  final int coins;
  final int dailyLimit;
  final bool countsForStreak;

  static GamificationAction? byKey(String key) {
    for (final a in values) {
      if (a.key == key) return a;
    }
    return null;
  }
}

/// Outcome of recording one action. `calPoints` is what the action itself
/// awarded (the "+10 Cal Points" toast); bonuses are reported separately.
class RewardResult {
  final int calPoints;
  final int bonusCalPoints;
  final int nutriCoins;
  final int streakBonus;
  final int? milestone;
  final bool streakAdvanced;
  final int streak;
  final bool leveledUp;
  final int level;
  final String? reason;

  const RewardResult({
    this.calPoints = 0,
    this.bonusCalPoints = 0,
    this.nutriCoins = 0,
    this.streakBonus = 0,
    this.milestone,
    this.streakAdvanced = false,
    this.streak = 0,
    this.leveledUp = false,
    this.level = 1,
    this.reason,
  });

  bool get awarded =>
      calPoints > 0 || bonusCalPoints > 0 || streakBonus > 0 || nutriCoins > 0;

  @override
  String toString() => 'RewardResult(points=$calPoints, bonus=$bonusCalPoints, '
      'streakBonus=$streakBonus, '
      'coins=$nutriCoins, milestone=$milestone, streak=$streak, '
      'leveledUp=$leveledUp, level=$level, reason=$reason)';
}

class GamificationService {
  final GamificationState state;
  final DateTime Function() _now;

  GamificationService(this.state, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  /// Daily ceiling on Cal Points from actions (plan §4.1).
  static const int dailyCalPointCap = 200;

  /// Same action within this window earns nothing (plan §4.1 anti-exploit).
  static const Duration repeatCooldown = Duration(seconds: 60);

  /// Streak length → (Cal Points, NutriCoins). Bonus freeze at every hit.
  static const Map<int, List<int>> streakMilestones = {
    7: [25, 50],
    14: [50, 75],
    30: [100, 150],
    50: [150, 200],
    100: [300, 500],
    365: [1000, 2000],
  };

  // ── Levels (plan §4.2) ────────────────────────────────────────────────
  static const List<int> _thresholds = [
    0, 100, 300, 600, 1000, 1500, 2200, 3200, 4500, 6000,
  ];
  static const List<String> _titles = [
    'Sprout', 'Seedling', 'Grower', 'Green Thumb', 'Bloomer',
    'Harvester', 'Cultivator', 'Garden Master', 'Green Guardian',
    'Nutrition Sage',
  ];

  static int thresholdForLevel(int level) {
    if (level <= 1) return 0;
    if (level <= 10) return _thresholds[level - 1];
    if (level <= 20) return 6000 + (level - 10) * 1400;
    return 20000 + (level - 20) * 5000;
  }

  static int levelForPoints(int points) {
    var level = 1;
    while (level < 1000 && thresholdForLevel(level + 1) <= points) {
      level++;
    }
    return level;
  }

  static String titleForLevel(int level) {
    if (level <= 10) return _titles[level - 1];
    if (level <= 20) return 'Elite';
    return 'Legend';
  }

  int get level => levelForPoints(state.calPoints);

  String get levelTitle => titleForLevel(level);

  /// 0.0–1.0 progress from the current level to the next.
  double get levelProgress {
    final base = thresholdForLevel(level);
    final next = thresholdForLevel(level + 1);
    if (next <= base) return 1.0;
    return ((state.calPoints - base) / (next - base)).clamp(0.0, 1.0);
  }

  int get pointsToNextLevel =>
      (thresholdForLevel(level + 1) - state.calPoints).clamp(0, 1 << 31);

  // ── Day / week helpers ────────────────────────────────────────────────

  static String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday (midnight) of the week containing [d].
  static DateTime weekStart(DateTime d) {
    final day = _midnight(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  void _rollDay(DateTime when) {
    final today = dayKey(when);
    if (state.logDay != today) {
      state.logDay = today;
      state.todayActions = <String>[];
      state.todayPoints = 0;
      state.todayQuests = 0;
    }
    _pruneDays(when);
  }

  void _pruneDays(DateTime when) {
    if (state.pointsByDay.length <= 40) return;
    final cutoff = _midnight(when).subtract(const Duration(days: 35));
    state.pointsByDay.removeWhere((k, _) {
      final d = DateTime.tryParse(k);
      return d != null && d.isBefore(cutoff);
    });
  }

  int get todayPoints => state.todayPoints;

  int pointsThisWeek({DateTime? at}) {
    final start = weekStart(at ?? _now());
    final end = start.add(const Duration(days: 7));
    var total = 0;
    state.pointsByDay.forEach((key, pts) {
      final d = DateTime.tryParse(key);
      if (d != null && !d.isBefore(start) && d.isBefore(end)) total += pts;
    });
    return total;
  }

  // ── Recording actions ─────────────────────────────────────────────────

  /// Record [action] at [at] (now by default) and return the reward.
  ///
  /// Enforces the per-action daily limit, the 60s repeat cooldown and the
  /// 200/day Cal Point cap. Streak-qualifying actions advance the streak
  /// (awarding the daily streak bonus and any milestone) even if points are
  /// capped, so logging behaviour is never silently ignored.
  RewardResult recordAction(GamificationAction action, {DateTime? at}) =>
      _record(
        key: action.key,
        points: action.points,
        coins: action.coins,
        dailyLimit: action.dailyLimit,
        countsForStreak: action.countsForStreak,
        isQuest: action == GamificationAction.questComplete,
        at: at,
      );

  /// Award a completed daily quest. Quests carry their own point value per
  /// template (plan §4.5) rather than the flat "complete a quest" figure.
  RewardResult awardQuest(int points, {DateTime? at}) => _record(
        key: GamificationAction.questComplete.key,
        points: points,
        coins: GamificationAction.questComplete.coins,
        dailyLimit: GamificationAction.questComplete.dailyLimit,
        countsForStreak: false,
        isQuest: true,
        at: at,
      );

  RewardResult _record({
    required String key,
    required int points,
    required int coins,
    required int dailyLimit,
    required bool countsForStreak,
    bool isQuest = false,
    DateTime? at,
  }) {
    final when = at ?? _now();
    _rollDay(when);
    final today = dayKey(when);

    final countToday = state.todayActions.where((k) => k == key).length;
    if (countToday >= dailyLimit) {
      return RewardResult(
        streak: state.streak.current,
        level: level,
        reason: 'daily_limit',
      );
    }

    final lastIso = state.lastActionAt[key];
    final last = lastIso == null ? null : DateTime.tryParse(lastIso);
    // Quests are distinct events, so the rapid-repeat guard applies only to
    // physical logging actions (double-tap protection).
    if (!isQuest && last != null &&
        when.difference(last).abs() < repeatCooldown) {
      return RewardResult(
        streak: state.streak.current,
        level: level,
        reason: 'cooldown',
      );
    }

    final levelBefore = level;

    // Action points, clamped by the remaining daily budget.
    final budget = (dailyCalPointCap - state.todayPoints).clamp(0, dailyCalPointCap);
    final awarded = points <= budget ? points : budget;
    state.todayPoints += awarded;
    state.calPoints += awarded;
    state.pointsByDay[today] = (state.pointsByDay[today] ?? 0) + awarded;

    var coinsOut = coins;
    var bonusCalPoints = 0;
    if (isQuest) {
      state.todayQuests += 1;
      // Completing all three daily quests grants the completionist bonus.
      if (state.todayQuests == 3 &&
          !state.todayActions.contains(GamificationAction.questBonus.key)) {
        final bonus = GamificationAction.questBonus;
        final bonusBudget =
            (dailyCalPointCap - state.todayPoints).clamp(0, dailyCalPointCap);
        final bonusPts = bonus.points <= bonusBudget ? bonus.points : bonusBudget;
        state.todayPoints += bonusPts;
        state.calPoints += bonusPts;
        state.pointsByDay[today] =
            (state.pointsByDay[today] ?? 0) + bonusPts;
        coinsOut += bonus.coins;
        bonusCalPoints = bonusPts;
        state.todayActions.add(bonus.key);
      }
    }
    state.nutriCoins += coinsOut;

    state.todayActions.add(key);
    state.lastActionAt[key] = when.toIso8601String();

    var streakAdvanced = false;
    var streakBonus = 0;
    int? milestone;
    if (countsForStreak) {
      streakAdvanced = _touchStreak(when);
      if (streakAdvanced) {
        final budget2 =
            (dailyCalPointCap - state.todayPoints).clamp(0, dailyCalPointCap);
        streakBonus = GamificationAction.streakDay.points <= budget2
            ? GamificationAction.streakDay.points
            : budget2;
        state.todayPoints += streakBonus;
        state.calPoints += streakBonus;
        state.pointsByDay[today] =
            (state.pointsByDay[today] ?? 0) + streakBonus;

        final reward = streakMilestones[state.streak.current];
        if (reward != null) {
          milestone = state.streak.current;
          final budget3 =
              (dailyCalPointCap - state.todayPoints).clamp(0, dailyCalPointCap);
          final mPts = reward[0] <= budget3 ? reward[0] : budget3;
          state.todayPoints += mPts;
          state.calPoints += mPts;
          state.pointsByDay[today] = (state.pointsByDay[today] ?? 0) + mPts;
          state.nutriCoins += reward[1];
          coinsOut += reward[1];
          streakBonus += mPts;
          state.streak.freezeCount =
              (state.streak.freezeCount + 1).clamp(0, StreakState.maxFreezeBank);
        }
      }
    }

    return RewardResult(
      calPoints: awarded,
      bonusCalPoints: bonusCalPoints,
      nutriCoins: coinsOut,
      streakBonus: streakBonus,
      milestone: milestone,
      streakAdvanced: streakAdvanced,
      streak: state.streak.current,
      leveledUp: level > levelBefore,
      level: level,
    );
  }

  /// Advances the streak for a qualifying action on [when]. Returns whether
  /// the streak moved forward (i.e. this was the first qualifying action of
  /// the day).
  bool _touchStreak(DateTime when) {
    final today = _midnight(when);
    final last = state.streak.lastActionDate == null
        ? null
        : _midnight(state.streak.lastActionDate!);

    if (last != null && !last.isBefore(today)) {
      return false; // already qualified today
    }

    if (last == null) {
      state.streak.current = 1;
    } else {
      final missed = today.difference(last).inDays - 1;
      if (missed <= 0) {
        state.streak.current += 1;
      } else if (missed <= state.streak.freezeCount) {
        // Freezes cover the gap silently — rest days are not failure.
        state.streak.freezeCount -= missed;
        state.streak.current += 1;
      } else {
        state.streak.current = 1;
      }
    }

    state.streak.lastActionDate = today;
    if (state.streak.current > state.streak.longest) {
      state.streak.longest = state.streak.current;
    }
    return true;
  }

  /// Grant the once-a-day login NutriCoins. Returns coins granted (0 if
  /// already claimed today).
  int recordDailyLogin({DateTime? at}) {
    final when = at ?? _now();
    _rollDay(when);
    final today = dayKey(when);
    if (state.lastLoginDay == today) return 0;
    state.lastLoginDay = today;
    state.nutriCoins += 5;
    return 5;
  }

  /// Spend NutriCoins (shop). Returns false if the balance is insufficient.
  bool spendCoins(int amount) {
    if (amount <= 0 || state.nutriCoins < amount) return false;
    state.nutriCoins -= amount;
    return true;
  }

  /// Add freezes (earned or purchased), respecting the bank cap. Returns the
  /// number actually added.
  int addFreezes(int count) {
    if (count <= 0) return 0;
    final before = state.streak.freezeCount;
    state.streak.freezeCount =
        (before + count).clamp(0, StreakState.maxFreezeBank);
    return state.streak.freezeCount - before;
  }
}
