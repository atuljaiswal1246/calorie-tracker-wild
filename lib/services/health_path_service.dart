import '../models/health_path.dart';
import '../models/gamification_state.dart';
import 'gamification_service.dart';

/// Service to manage the Duolingo-style health path.
/// Generates a progressive path of health habits and rewards completion.
class HealthPathService {
  final GamificationState gamificationState;
  final HealthPathState pathState;

  HealthPathService(
    this.gamificationState,
    this.pathState,
  );

  /// Generate the default health path
  static List<PathNode> generateDefaultPath() {
    return [
      // Level 1: Getting Started
      const PathNode(
        id: 'l1_intro',
        level: 1,
        order: 1,
        type: PathNodeType.mealLog,
        title: 'First Meal',
        subtitle: 'Log your first meal',
        icon: '🍽️',
        xpReward: 20,
      ),
      const PathNode(
        id: 'l1_hydrate',
        level: 1,
        order: 2,
        type: PathNodeType.waterLog,
        title: 'Stay Hydrated',
        subtitle: 'Log a glass of water',
        icon: '💧',
        xpReward: 15,
      ),
      const PathNode(
        id: 'l1_streak',
        level: 1,
        order: 3,
        type: PathNodeType.streak,
        title: 'Start Your Streak',
        subtitle: 'Complete 2 actions today',
        icon: '🔥',
        xpReward: 25,
      ),
      // Level 2: Building Habits
      const PathNode(
        id: 'l2_scan',
        level: 2,
        order: 1,
        type: PathNodeType.mealLog,
        title: 'AI Scan',
        subtitle: 'Scan a meal with AI',
        icon: '📸',
        xpReward: 30,
      ),
      const PathNode(
        id: 'l2_water_goal',
        level: 2,
        order: 2,
        type: PathNodeType.waterLog,
        title: 'Hit Water Goal',
        subtitle: 'Reach your water target',
        icon: '💧',
        xpReward: 25,
      ),
      const PathNode(
        id: 'l2_move',
        level: 2,
        order: 3,
        type: PathNodeType.exerciseLog,
        title: 'Get Moving',
        subtitle: 'Log some exercise',
        icon: '🏃',
        xpReward: 30,
      ),
      // Level 3: Consistency
      const PathNode(
        id: 'l3_weigh',
        level: 3,
        order: 1,
        type: PathNodeType.weightLog,
        title: 'Track Progress',
        subtitle: 'Log your weight',
        icon: '⚖️',
        xpReward: 25,
      ),
      const PathNode(
        id: 'l3_streak3',
        level: 3,
        order: 2,
        type: PathNodeType.streak,
        title: '3-Day Streak',
        subtitle: 'Keep the momentum going',
        icon: '🔥',
        xpReward: 40,
      ),
      const PathNode(
        id: 'l3_milestone',
        level: 3,
        order: 3,
        type: PathNodeType.milestone,
        title: 'Milestone!',
        subtitle: 'You\'re building great habits',
        icon: '🏆',
        xpReward: 50,
        coinReward: 25,
      ),
      // Level 4: Going Strong
      const PathNode(
        id: 'l4_scan3',
        level: 4,
        order: 1,
        type: PathNodeType.mealLog,
        title: 'Meal Master',
        subtitle: 'Log 3 meals today',
        icon: '🍽️',
        xpReward: 40,
      ),
      const PathNode(
        id: 'l4_streak7',
        level: 4,
        order: 2,
        type: PathNodeType.streak,
        title: 'Week Warrior',
        subtitle: 'Reach 7-day streak',
        icon: '⚡',
        xpReward: 75,
        coinReward: 50,
      ),
      const PathNode(
        id: 'l4_quest',
        level: 4,
        order: 3,
        type: PathNodeType.quest,
        title: 'Quest Complete',
        subtitle: 'Finish all daily quests',
        icon: '🎯',
        xpReward: 45,
        coinReward: 20,
      ),
    ];
  }

  /// Get all nodes
  List<PathNode> get path => generateDefaultPath();

  /// Get nodes grouped by level
  Map<int, List<PathNode>> get nodesByLevel {
    final map = <int, List<PathNode>>{};
    for (final node in path) {
      map.putIfAbsent(node.level, () => []).add(node);
    }
    // Sort by order within level
    for (final level in map.keys) {
      map[level]!.sort((a, b) => a.order.compareTo(b.order));
    }
    return map;
  }

  /// Get current node to complete
  PathNode? get currentNode {
    for (final node in path) {
      if (!pathState.completedNodeIds.contains(node.id)) {
        return node;
      }
    }
    return null; // All completed
  }

  /// Get next node after a completed one
  PathNode? getNextNode(String completedId) {
    final index = path.indexWhere((n) => n.id == completedId);
    if (index >= 0 && index + 1 < path.length) {
      return path[index + 1];
    }
    return null;
  }

  /// Complete a node and award rewards
  NodeCompletionResult completeNode(String nodeId) {
    if (pathState.completedNodeIds.contains(nodeId)) {
      return NodeCompletionResult(
        success: false,
        reason: 'already_completed',
      );
    }

    final node = path.firstWhere((n) => n.id == nodeId);
    
    // Award XP
    gamificationState.calPoints += node.xpReward;
    gamificationState.nutriCoins += node.coinReward;
    
    // Mark completed
    pathState.completedNodeIds.add(nodeId);
    final next = getNextNode(nodeId);
    // currentNodeId is final in model, handled differently

    // Check if leveled up
    final newLevel = GamificationService.levelForPoints(gamificationState.calPoints);
    
    return NodeCompletionResult(
      success: true,
      node: node,
      xpEarned: node.xpReward,
      coinsEarned: node.coinReward,
      leveledUp: false, // We'll check separately
      newLevel: newLevel,
      nextNode: next,
    );
  }

  /// Check if a node can be auto-completed based on user activity
  bool shouldAutoComplete(PathNode node) {
    // This will be called by gamification controller based on actions
    switch (node.type) {
      case PathNodeType.mealLog:
        // Check if user logged meals today
        return gamificationState.todayActions
            .where((a) => a.contains('meal'))
            .isNotEmpty;
      case PathNodeType.waterLog:
        return gamificationState.todayActions.contains('water_goal');
      case PathNodeType.exerciseLog:
        return gamificationState.todayActions.contains('exercise_log');
      case PathNodeType.weightLog:
        return gamificationState.todayActions.contains('weight_log');
      case PathNodeType.streak:
        return gamificationState.streak.current >= 1;
      case PathNodeType.quest:
        return gamificationState.todayQuests >= 1;
      case PathNodeType.milestone:
        return false;
    }
  }

  /// Get progress percentage
  double get progressPercent {
    if (path.isEmpty) return 0;
    return pathState.completedNodeIds.length / path.length;
  }

  /// Get completed count
  int get completedCount => pathState.completedNodeIds.length;

  /// Get total count
  int get totalCount => path.length;
}

class NodeCompletionResult {
  final bool success;
  final String? reason;
  final PathNode? node;
  final int xpEarned;
  final int coinsEarned;
  final bool leveledUp;
  final int newLevel;
  final PathNode? nextNode;

  NodeCompletionResult({
    required this.success,
    this.reason,
    this.node,
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.leveledUp = false,
    this.newLevel = 1,
    this.nextNode,
  });
}
