enum LessonStepType {
  intro,
  action, // Do the actual action (log meal, water, etc)
  info,
  complete,
}

class LessonStep {
  final String id;
  final LessonStepType type;
  final String title;
  final String description;
  final String? icon;
  final String? actionType; // meal, water, exercise, weight
  final bool required;

  const LessonStep({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.icon,
    this.actionType,
    this.required = true,
  });
}

class Lesson {
  final String id;
  final String nodeId;
  final String title;
  final String subtitle;
  final String icon;
  final int xpReward;
  final int coinReward;
  final List<LessonStep> steps;

  const Lesson({
    required this.id,
    required this.nodeId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.xpReward,
    this.coinReward = 0,
    required this.steps,
  });
}

class LessonProgress {
  final String lessonId;
  int currentStepIndex;
  int hearts;
  bool completed;
  final List<String> completedSteps;

  LessonProgress({
    required this.lessonId,
    this.currentStepIndex = 0,
    this.hearts = 5,
    this.completed = false,
    List<String>? completedSteps,
  }) : completedSteps = completedSteps ?? [];
}
