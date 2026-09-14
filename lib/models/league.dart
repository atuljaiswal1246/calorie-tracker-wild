/// Weekly league models (plan §4.6).
library;

/// A league tier (1 = Seedling … 10 = World Tree).
class LeagueTier {
  final int index;
  final String name;
  final String emoji;
  final int promote; // top N promote
  final int demote; // bottom N demote

  const LeagueTier({
    required this.index,
    required this.name,
    required this.emoji,
    required this.promote,
    required this.demote,
  });
}

/// One row on the weekly leaderboard.
class LeagueRow {
  final String name;
  final int points;
  final bool isYou;
  final int position;

  const LeagueRow({
    required this.name,
    required this.points,
    required this.isYou,
    required this.position,
  });
}

/// Persisted league state (tier, this week's window, last week's result).
class LeagueState {
  int tier; // 1..10
  String weekStart; // Monday key "yyyy-M-d"
  int weeklyPoints;
  int? lastPosition;
  String? lastResult; // promote | demote | stay
  int weeksPlayed;

  LeagueState({
    this.tier = 1,
    this.weekStart = '',
    this.weeklyPoints = 0,
    this.lastPosition,
    this.lastResult,
    this.weeksPlayed = 0,
  });

  Map<String, dynamic> toJson() => {
        'tier': tier,
        'weekStart': weekStart,
        'weeklyPoints': weeklyPoints,
        'lastPosition': lastPosition,
        'lastResult': lastResult,
        'weeksPlayed': weeksPlayed,
      };

  factory LeagueState.fromJson(Map<String, dynamic> json) => LeagueState(
        tier: (json['tier'] as num?)?.toInt() ?? 1,
        weekStart: json['weekStart'] as String? ?? '',
        weeklyPoints: (json['weeklyPoints'] as num?)?.toInt() ?? 0,
        lastPosition: (json['lastPosition'] as num?)?.toInt(),
        lastResult: json['lastResult'] as String?,
        weeksPlayed: (json['weeksPlayed'] as num?)?.toInt() ?? 0,
      );
}
