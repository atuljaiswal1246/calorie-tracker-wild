/// Health Path model - Duolingo-style learning path for health habits.
/// Each node represents a bite-sized health action to complete.
library;

enum PathNodeType {
  mealLog,
  waterLog,
  exerciseLog,
  weightLog,
  streak,
  quest,
  milestone,
}

enum PathNodeState {
  locked,
  current,
  completed,
}

class PathNode {
  final String id;
  final int level;
  final int order;
  final PathNodeType type;
  final String title;
  final String subtitle;
  final String icon;
  final int xpReward;
  final int coinReward;

  const PathNode({
    required this.id,
    required this.level,
    required this.order,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.xpReward,
    this.coinReward = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'order': order,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'xpReward': xpReward,
        'coinReward': coinReward,
      };

  factory PathNode.fromJson(Map<String, dynamic> json) => PathNode(
        id: json['id'] as String,
        level: json['level'] as int,
        order: json['order'] as int,
        type: PathNodeType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => PathNodeType.mealLog,
        ),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        icon: json['icon'] as String,
        xpReward: json['xpReward'] as int,
        coinReward: json['coinReward'] as int? ?? 0,
      );
}

class HealthPathState {
  final Set<String> completedNodeIds;
  final String? currentNodeId;
  final int pathLevel;

  HealthPathState({
    Set<String>? completedNodeIds,
    this.currentNodeId,
    this.pathLevel = 1,
  }) : completedNodeIds = completedNodeIds ?? <String>{};

  PathNodeState getStateFor(String nodeId, String? firstUncompleted) {
    if (completedNodeIds.contains(nodeId)) return PathNodeState.completed;
    if (nodeId == currentNodeId || nodeId == firstUncompleted) {
      return PathNodeState.current;
    }
    // Nodes after current are locked
    return PathNodeState.locked;
  }

  HealthPathState copyWith({
    Set<String>? completedNodeIds,
    String? currentNodeId,
    int? pathLevel,
  }) {
    return HealthPathState(
      completedNodeIds: completedNodeIds ?? this.completedNodeIds,
      currentNodeId: currentNodeId ?? this.currentNodeId,
      pathLevel: pathLevel ?? this.pathLevel,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedNodeIds': completedNodeIds.toList(),
        'currentNodeId': currentNodeId,
        'pathLevel': pathLevel,
      };

  factory HealthPathState.fromJson(Map<String, dynamic> json) {
    return HealthPathState(
      completedNodeIds: (json['completedNodeIds'] as List?)
              ?.map((e) => e as String)
              .toSet() ??
          <String>{},
      currentNodeId: json['currentNodeId'] as String?,
      pathLevel: json['pathLevel'] as int? ?? 1,
    );
  }
}
