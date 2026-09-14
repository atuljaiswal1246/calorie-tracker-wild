/// Daily quests (plan §4.5).
///
/// Generates a fresh set of three quests each day, tracks progress from the
/// app's behaviour events, and pays out rewards through the gamification
/// engine. Selection follows the plan's four rules: yesterday's quests are
/// excluded, at least one *easy* quest is always present, at most one
/// nutrition-quality quest is included, and quests can be weighted toward the
/// user's weakest engagement area.
library;

import 'dart:math';

import '../models/quest.dart';
import 'gamification_service.dart';

class QuestService {
  /// The full quest pool (plan §4.5).
  static const List<QuestTemplate> pool = [
    QuestTemplate(
      id: 'photo_scan',
      title: 'Log a meal using AI Photo Scan',
      category: 'Core Feature',
      calPoints: 15,
      metric: QuestMetric.mealScan,
      easy: true,
    ),
    QuestTemplate(
      id: 'all_three_meals',
      title: 'Log all 3 meals today',
      category: 'Consistency',
      calPoints: 15,
      metric: QuestMetric.mealsLogged,
      target: 3,
    ),
    QuestTemplate(
      id: 'water_goal',
      title: 'Hit your daily water goal',
      category: 'Hydration',
      calPoints: 10,
      metric: QuestMetric.waterGoal,
      easy: true,
    ),
    QuestTemplate(
      id: 'morning_weight',
      title: 'Log your morning weight',
      category: 'Tracking',
      calPoints: 5,
      metric: QuestMetric.weightLog,
      easy: true,
    ),
    QuestTemplate(
      id: 'within_target',
      title: 'Stay within 200 kcal of your daily target',
      category: 'Mindfulness',
      calPoints: 15,
      metric: QuestMetric.withinTarget,
      nutritionQuality: true,
    ),
    QuestTemplate(
      id: 'new_food',
      title: 'Try a new food (first-time scan)',
      category: 'Exploration',
      calPoints: 15,
      metric: QuestMetric.newFood,
    ),
    QuestTemplate(
      id: 'asha_chat',
      title: 'Chat with Asha about your nutrition',
      category: 'AI Coach',
      calPoints: 5,
      metric: QuestMetric.ashaChat,
      easy: true,
    ),
    QuestTemplate(
      id: 'exercise_30',
      title: 'Log 30 minutes of exercise',
      category: 'Activity',
      calPoints: 10,
      metric: QuestMetric.exercise,
    ),
    QuestTemplate(
      id: 'timely_meal',
      title: 'Log a meal within 30 minutes of eating',
      category: 'Timeliness',
      calPoints: 10,
      metric: QuestMetric.timelyMeal,
    ),
    QuestTemplate(
      id: 'protein_goal',
      title: 'Hit your protein target today',
      category: 'Nutrition Quality',
      calPoints: 15,
      metric: QuestMetric.proteinTarget,
      nutritionQuality: true,
    ),
    QuestTemplate(
      id: 'fasting_12',
      title: 'Complete a fasting window of 12+ hours',
      category: 'Fasting',
      calPoints: 5,
      metric: QuestMetric.fasting,
      easy: true,
    ),
    QuestTemplate(
      id: 'home_cooked',
      title: 'Scan a home-cooked meal',
      category: 'Indian Focus',
      calPoints: 15,
      metric: QuestMetric.homeCooked,
    ),
  ];

  static QuestTemplate? templateById(String id) {
    for (final t in pool) {
      if (t.id == id) return t;
    }
    return null;
  }

  final GamificationService gamification;
  final Random _rng;
  String day;
  List<ActiveQuest> quests;

  QuestService(this.gamification,
      {List<ActiveQuest>? quests, this.day = '', Random? rng})
      : quests = quests ?? <ActiveQuest>[],
        _rng = rng ?? Random();

  int get questCount => quests.length;
  int get completedCount => quests.where((q) => q.completed).length;
  int get claimedCount => quests.where((q) => q.claimed).length;
  bool get allCompleted => quests.isNotEmpty && completedCount == quests.length;

  bool isForDay(DateTime at) => day == GamificationService.dayKey(at);

  /// Whether today's quests exist and were generated for [at]'s day.
  bool needsGeneration(DateTime at) => !isForDay(at);

  /// Build a fresh daily set. [excludeIds] are quests completed yesterday
  /// (variety), and [priority] weights metrics the user is weakest at
  /// (higher = more likely to be chosen).
  List<ActiveQuest> generate({
    DateTime? at,
    Set<String> excludeIds = const {},
    Map<QuestMetric, int> priority = const {},
    int count = 3,
  }) {
    final when = at ?? DateTime.now();
    day = GamificationService.dayKey(when);

    var candidates =
        pool.where((t) => !excludeIds.contains(t.id)).toList();
    if (candidates.length < count) {
      candidates = pool.toList(); // fall back to the whole pool
    }

    final chosen = <QuestTemplate>[];
    var hasNutrition = false;

    void tryAdd(QuestTemplate t) {
      if (chosen.any((c) => c.id == t.id)) return;
      if (t.nutritionQuality && hasNutrition) return;
      chosen.add(t);
      if (t.nutritionQuality) hasNutrition = true;
    }

    // Rule 3: always include at least one easy quest.
    final easy = candidates.where((t) => t.easy).toList();
    if (easy.isNotEmpty) {
      tryAdd(_weightedPick(easy, priority));
    }

    // Fill the rest, weighted toward weak areas and capped at one
    // nutrition-quality quest (rule 4).
    while (chosen.length < count && chosen.length < candidates.length) {
      final remaining = candidates
          .where((t) => !chosen.any((c) => c.id == t.id))
          .where((t) => !(t.nutritionQuality && hasNutrition))
          .toList();
      if (remaining.isEmpty) break;
      tryAdd(_weightedPick(remaining, priority));
    }

    quests = chosen.map((t) => ActiveQuest(template: t)).toList();
    return quests;
  }

  QuestTemplate _weightedPick(
      List<QuestTemplate> options, Map<QuestMetric, int> priority) {
    final weights = [
      for (final t in options) 1 + (priority[t.metric] ?? 0),
    ];
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = _rng.nextInt(total);
    for (var i = 0; i < options.length; i++) {
      roll -= weights[i];
      if (roll < 0) return options[i];
    }
    return options.last;
  }

  /// Advance every incomplete quest matching [metric]. Returns the quests
  /// that just completed.
  List<ActiveQuest> report(QuestMetric metric, {int amount = 1}) {
    final newly = <ActiveQuest>[];
    for (final q in quests) {
      if (q.completed || q.template.metric != metric) continue;
      q.current += amount;
      if (q.current >= q.target) {
        q.current = q.target;
        q.completed = true;
        newly.add(q);
      }
    }
    return newly;
  }

  /// Claim a completed quest's reward. Idempotent — claiming twice pays once.
  RewardResult claim(ActiveQuest quest, {DateTime? at}) {
    if (!quest.completed || quest.claimed) {
      return RewardResult(
        streak: gamification.state.streak.current,
        level: gamification.level,
        reason: quest.claimed ? 'already_claimed' : 'not_completed',
      );
    }
    quest.claimed = true;
    return gamification.awardQuest(quest.calPoints, at: at);
  }

  /// Claim every completed quest. Returns the total rewards paid.
  ({int calPoints, int nutriCoins, int milestones}) claimAll({DateTime? at}) {
    var points = 0;
    var coins = 0;
    var milestones = 0;
    for (final q in quests) {
      if (q.completed && !q.claimed) {
        final r = claim(q, at: at);
        points += r.calPoints + r.bonusCalPoints + r.streakBonus;
        coins += r.nutriCoins;
        if (r.milestone != null) milestones++;
      }
    }
    return (calPoints: points, nutriCoins: coins, milestones: milestones);
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'quests': quests.map((q) => q.toJson()).toList(),
      };

  static QuestService fromJson(GamificationService gamification,
      Map<String, dynamic> json) {
    final list = <ActiveQuest>[];
    for (final raw in (json['quests'] as List? ?? [])) {
      final m = (raw as Map).cast<String, dynamic>();
      final t = templateById(m['id'] as String? ?? '');
      if (t == null) continue;
      list.add(ActiveQuest(
        template: t,
        current: (m['current'] as num?)?.toInt() ?? 0,
        completed: m['completed'] as bool? ?? false,
        claimed: m['claimed'] as bool? ?? false,
      ));
    }
    return QuestService(gamification,
        quests: list, day: json['day'] as String? ?? '');
  }
}
