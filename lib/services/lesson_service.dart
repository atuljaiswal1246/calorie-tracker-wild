import '../models/lesson.dart';
import '../models/health_path.dart';

class LessonService {
  static List<Lesson> generateLessonsForPath(List<PathNode> path) {
    final lessons = <Lesson>[];
    
    for (final node in path) {
      lessons.add(_createLessonForNode(node));
    }
    
    return lessons;
  }
  
  static Lesson _createLessonForNode(PathNode node) {
    switch (node.type) {
      case PathNodeType.mealLog:
        return Lesson(
          id: 'lesson_${node.id}',
          nodeId: node.id,
          title: node.title,
          subtitle: node.subtitle,
          icon: node.icon,
          xpReward: node.xpReward,
          coinReward: node.coinReward,
          steps: [
            LessonStep(
              id: 'intro',
              type: LessonStepType.intro,
              title: 'Let\'s log a meal!',
              description: 'Tracking your meals is the first step to building awareness. Take a photo or log manually.',
              icon: '🍽️',
            ),
            LessonStep(
              id: 'action',
              type: LessonStepType.action,
              title: 'Log your meal now',
              description: 'Scan with AI or add manually. Every log counts!',
              icon: '📸',
              actionType: 'meal',
            ),
            LessonStep(
              id: 'complete',
              type: LessonStepType.complete,
              title: 'Nice work!',
              description: 'You\'re building a healthy habit. Keep it going!',
              icon: '🎉',
            ),
          ],
        );
      case PathNodeType.waterLog:
        return Lesson(
          id: 'lesson_${node.id}',
          nodeId: node.id,
          title: node.title,
          subtitle: node.subtitle,
          icon: node.icon,
          xpReward: node.xpReward,
          coinReward: node.coinReward,
          steps: [
            LessonStep(
              id: 'intro',
              type: LessonStepType.intro,
              title: 'Stay hydrated!',
              description: 'Water helps with digestion, energy, and overall health.',
              icon: '💧',
            ),
            LessonStep(
              id: 'action',
              type: LessonStepType.action,
              title: 'Add a glass of water',
              description: 'Tap to log 250ml of water right now.',
              icon: '💧',
              actionType: 'water',
            ),
            LessonStep(
              id: 'complete',
              type: LessonStepType.complete,
              title: 'Refreshing!',
              description: 'Every glass counts towards your goal!',
              icon: '✨',
            ),
          ],
        );
      case PathNodeType.exerciseLog:
        return Lesson(
          id: 'lesson_${node.id}',
          nodeId: node.id,
          title: node.title,
          subtitle: node.subtitle,
          icon: node.icon,
          xpReward: node.xpReward,
          coinReward: node.coinReward,
          steps: [
            LessonStep(
              id: 'intro',
              type: LessonStepType.intro,
              title: 'Get moving!',
              description: 'Even a short walk makes a difference.',
              icon: '🏃',
            ),
            LessonStep(
              id: 'action',
              type: LessonStepType.action,
              title: 'Log your activity',
              description: 'Add a workout or walk you did today.',
              icon: '💪',
              actionType: 'exercise',
            ),
            LessonStep(
              id: 'complete',
              type: LessonStepType.complete,
              title: 'Keep it up!',
              description: 'Movement is medicine. Great job!',
              icon: '🔥',
            ),
          ],
        );
      case PathNodeType.weightLog:
        return Lesson(
          id: 'lesson_${node.id}',
          nodeId: node.id,
          title: node.title,
          subtitle: node.subtitle,
          icon: node.icon,
          xpReward: node.xpReward,
          coinReward: node.coinReward,
          steps: [
            LessonStep(
              id: 'intro',
              type: LessonStepType.intro,
              title: 'Track your progress',
              description: 'Regular weigh-ins help you stay on track.',
              icon: '⚖️',
            ),
            LessonStep(
              id: 'action',
              type: LessonStepType.action,
              title: 'Log your weight',
              description: 'Enter your current weight.',
              icon: '⚖️',
              actionType: 'weight',
            ),
            LessonStep(
              id: 'complete',
              type: LessonStepType.complete,
              title: 'Progress tracked!',
              description: 'Consistency beats perfection.',
              icon: '📈',
            ),
          ],
        );
      default:
        return Lesson(
          id: 'lesson_${node.id}',
          nodeId: node.id,
          title: node.title,
          subtitle: node.subtitle,
          icon: node.icon,
          xpReward: node.xpReward,
          coinReward: node.coinReward,
          steps: [
            LessonStep(
              id: 'intro',
              type: LessonStepType.intro,
              title: node.title,
              description: node.subtitle,
              icon: node.icon,
            ),
            LessonStep(
              id: 'action',
              type: LessonStepType.action,
              title: 'Complete this step',
              description: 'Do it now to earn rewards!',
              icon: node.icon,
              actionType: 'streak',
            ),
            LessonStep(
              id: 'complete',
              type: LessonStepType.complete,
              title: 'Done!',
              description: 'Great job!',
              icon: '✨',
            ),
          ],
        );
    }
  }
}
