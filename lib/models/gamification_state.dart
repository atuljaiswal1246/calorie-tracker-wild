/// Gamification state models for Cal Matters.
///
/// Mirrors the Firestore schema in `GAMIFICATION_PLAN_ASHA.md` §7.1. This is
/// the *engine's* state (points, level inputs, streak, currency, per-day
/// bookkeeping) — achievements, quests, leagues and notifications layer on
/// top of it in later modules.
///
/// Design rule (plan §3.2): points reward *logging behaviour*, never the
/// calorie value of what is logged. Nothing here reads or scores calories.
library;

/// Current streak bookkeeping (plan §4.3).
class StreakState {
  /// Days in the current unbroken streak.
  int current;

  /// All-time longest streak (never decreases).
  int longest;

  /// Last day an action qualified for the streak (midnight-normalised).
  DateTime? lastActionDate;

  /// Banked streak freezes. Freezes are consumed automatically when a day is
  /// missed so a health app never guilt-trips a rest day.
  int freezeCount;

  /// Hard cap on banked freezes (plan §4.3: generous, not infinite).
  static const int maxFreezeBank = 3;

  /// Freezes granted to a brand-new player.
  static const int startingFreezes = 1;

  StreakState({
    this.current = 0,
    this.longest = 0,
    this.lastActionDate,
    this.freezeCount = startingFreezes,
  });

  Map<String, dynamic> toJson() => {
        'current': current,
        'longest': longest,
        'lastActionDate': lastActionDate?.toIso8601String(),
        'freezeCount': freezeCount,
        'maxFreezeBank': maxFreezeBank,
      };

  factory StreakState.fromJson(Map<String, dynamic> json) => StreakState(
        current: (json['current'] as num?)?.toInt() ?? 0,
        longest: (json['longest'] as num?)?.toInt() ?? 0,
        lastActionDate: json['lastActionDate'] == null
            ? null
            : DateTime.tryParse(json['lastActionDate'] as String),
        freezeCount: (json['freezeCount'] as num?)?.toInt() ?? startingFreezes,
      );

  StreakState copy() => StreakState(
        current: current,
        longest: longest,
        lastActionDate: lastActionDate,
        freezeCount: freezeCount,
      );
}

/// Full gamification state persisted for one user.
class GamificationState {
  /// Lifetime Cal Points (never spent — prestige currency).
  int calPoints;

  /// Spendable NutriCoins balance.
  int nutriCoins;

  /// Streak bookkeeping.
  StreakState streak;

  /// The local day the per-day fields below refer to ("yyyy-MM-dd").
  String logDay;

  /// Every action recorded today, in order (may repeat).
  List<String> todayActions;

  /// Cal Points earned today from actions (subject to the daily cap).
  int todayPoints;

  /// Daily quests completed today.
  int todayQuests;

  /// Cal Points earned per day, kept for the current league week + trends.
  /// Keyed "yyyy-MM-dd". Pruned by the service to the last ~35 days.
  Map<String, int> pointsByDay;

  /// Last day the daily-login NutriCoins were granted ("yyyy-MM-dd").
  String? lastLoginDay;

  /// ISO timestamp of the last time each action earned points, used for the
  /// 60-second rapid-repeat anti-cheat cooldown (plan §4.1).
  Map<String, String> lastActionAt;

  GamificationState({
    this.calPoints = 0,
    this.nutriCoins = 0,
    StreakState? streak,
    this.logDay = '',
    List<String>? todayActions,
    this.todayPoints = 0,
    this.todayQuests = 0,
    Map<String, int>? pointsByDay,
    this.lastLoginDay,
    Map<String, String>? lastActionAt,
  })  : streak = streak ?? StreakState(),
        todayActions = todayActions ?? <String>[],
        pointsByDay = pointsByDay ?? <String, int>{},
        lastActionAt = lastActionAt ?? <String, String>{};

  Map<String, dynamic> toJson() => {
        'calPoints': calPoints,
        'nutriCoins': nutriCoins,
        'streak': streak.toJson(),
        'logDay': logDay,
        'todayActions': todayActions,
        'todayPoints': todayPoints,
        'todayQuests': todayQuests,
        'pointsByDay': pointsByDay,
        'lastLoginDay': lastLoginDay,
        'lastActionAt': lastActionAt,
      };

  factory GamificationState.fromJson(Map<String, dynamic> json) =>
      GamificationState(
        calPoints: (json['calPoints'] as num?)?.toInt() ?? 0,
        nutriCoins: (json['nutriCoins'] as num?)?.toInt() ?? 0,
        streak: json['streak'] == null
            ? null
            : StreakState.fromJson(
                (json['streak'] as Map).cast<String, dynamic>()),
        logDay: json['logDay'] as String? ?? '',
        todayActions: (json['todayActions'] as List?)
            ?.map((e) => e as String)
            .toList(),
        todayPoints: (json['todayPoints'] as num?)?.toInt() ?? 0,
        todayQuests: (json['todayQuests'] as num?)?.toInt() ?? 0,
        pointsByDay:
            (json['pointsByDay'] as Map?)?.map((k, v) => MapEntry(
                  k as String,
                  (v as num).toInt(),
                )),
        lastLoginDay: json['lastLoginDay'] as String?,
        lastActionAt: (json['lastActionAt'] as Map?)?.map((k, v) => MapEntry(
              k as String,
              v as String,
            )),
      );
}
