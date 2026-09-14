/// Daily quest models for Cal Matters (plan §4.5).
///
/// A quest is a small daily goal drawn from a fixed pool. Progress is driven
/// by the same behaviour events the gamification engine already records, and
/// completing one pays its template's Cal Points plus NutriCoins.
library;

/// What kind of event advances a quest. The app reports these from the
/// relevant feature (camera scan, water log, Asha chat, ...).
enum QuestMetric {
  mealScan,
  mealsLogged,
  waterGoal,
  weightLog,
  withinTarget,
  newFood,
  ashaChat,
  exercise,
  timelyMeal,
  proteinTarget,
  fasting,
  homeCooked,
}

/// A quest definition in the pool.
class QuestTemplate {
  final String id;
  final String title;
  final String category;
  final int calPoints;
  final QuestMetric metric;
  final int target;

  /// Whether >80% of users are expected to finish it — the selection
  /// algorithm always keeps at least one easy quest in the daily set.
  final bool easy;

  /// Nutrition-quality quests are capped at one per day so the game never
  /// pushes users toward calorie-obsessive patterns (plan §4.5).
  final bool nutritionQuality;

  const QuestTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.calPoints,
    required this.metric,
    this.target = 1,
    this.easy = false,
    this.nutritionQuality = false,
  });
}

/// One of today's active quests (a template plus live progress).
class ActiveQuest {
  final QuestTemplate template;
  int current;
  bool completed;
  bool claimed;

  ActiveQuest({
    required this.template,
    this.current = 0,
    this.completed = false,
    this.claimed = false,
  });

  String get id => template.id;
  int get target => template.target;
  int get calPoints => template.calPoints;

  double get progress =>
      target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': template.id,
        'current': current,
        'completed': completed,
        'claimed': claimed,
      };
}
