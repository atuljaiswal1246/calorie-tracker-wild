/// Weekly leagues (plan §4.6).
///
/// Scores users by Cal Points earned Mon–Sun — a measure of *engagement*, never
/// calorie restriction. Without a backend we simulate the other 29 members of
/// the tier deterministically (seeded by the week), so the leaderboard is
/// stable within a week and the tier still promotes/demotes the user.
library;

import 'dart:math';

import '../models/league.dart';
import 'gamification_controller.dart';
import 'gamification_service.dart';
import 'storage_service.dart';

class LeagueService {
  final StorageService storage;
  final GamificationController controller;

  LeagueService(this.storage, this.controller);

  static const int members = 30;

  /// Tier table from plan §4.6.
  static const List<LeagueTier> tiers = [
    LeagueTier(index: 1, name: 'Seedling', emoji: '🌱', promote: 20, demote: 5),
    LeagueTier(index: 2, name: 'Sprout', emoji: '🌿', promote: 15, demote: 5),
    LeagueTier(index: 3, name: 'Sapling', emoji: '🌳', promote: 10, demote: 5),
    LeagueTier(index: 4, name: 'Canopy', emoji: '🍃', promote: 7, demote: 3),
    LeagueTier(index: 5, name: 'Blossom', emoji: '🌸', promote: 7, demote: 3),
    LeagueTier(index: 6, name: 'Harvest', emoji: '🌾', promote: 5, demote: 3),
    LeagueTier(index: 7, name: 'Evergreen', emoji: '🌲', promote: 5, demote: 2),
    LeagueTier(index: 8, name: 'Ancient', emoji: '🌳', promote: 3, demote: 2),
    LeagueTier(
        index: 9, name: 'Sacred Grove', emoji: '🕊️', promote: 2, demote: 1),
    LeagueTier(
        index: 10, name: 'World Tree', emoji: '🌍', promote: 1, demote: 0),
  ];

  static LeagueTier tierFor(int index) =>
      tiers[(index - 1).clamp(0, tiers.length - 1)];

  LeagueState get state =>
      LeagueState.fromJson(storage.leagueStateRaw ?? const {});

  Future<void> _save(LeagueState s) => storage.saveLeagueState(s.toJson());

  static String _mondayKey(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  /// Ensure the league is in the current week. Settles the previous week if the
  /// window rolled over, then syncs this week's points.
  Future<LeagueState> sync({DateTime? at}) async {
    final now = at ?? DateTime.now();
    final s = state;
    final monday = _mondayKey(now);
    if (s.weekStart != monday) {
      if (s.weekStart.isNotEmpty) {
        await _settle(s, s.weekStart);
      }
      s.weekStart = monday;
      s.weeklyPoints = 0;
    }
    s.weeklyPoints = controller.weeklyPoints;
    await _save(s);
    return s;
  }

  Future<void> _settle(LeagueState s, String prevMondayKey) async {
    final prevStart = _parseMonday(prevMondayKey);
    final prevEnd = prevStart.add(const Duration(days: 7));
    var points = 0;
    controller.state.pointsByDay.forEach((key, value) {
      final d = DateTime.tryParse(key);
      if (d != null && !d.isBefore(prevStart) && d.isBefore(prevEnd)) {
        points += value;
      }
    });

    final rows = _buildRows(s.tier, points, seed: prevMondayKey);
    final you = rows.firstWhere((r) => r.isYou);
    final position = you.position;
    final tier = tierFor(s.tier);

    String result = 'stay';
    if (position <= tier.promote && s.tier < tiers.length) {
      s.tier += 1;
      result = 'promote';
    } else if (tier.demote > 0 && position > members - tier.demote && s.tier > 1) {
      s.tier -= 1;
      result = 'demote';
    }
    s.lastPosition = position;
    s.lastResult = result;
    s.weeksPlayed += 1;

    // Rewards (plan §4.6 league rewards table).
    var coins = 0;
    var bonusPoints = 0;
    var freezes = 0;
    if (position == 1) {
      coins = 100;
      bonusPoints = 50;
      freezes = 1;
    } else if (position == 2) {
      coins = 60;
      bonusPoints = 30;
    } else if (position == 3) {
      coins = 30;
      bonusPoints = 20;
    }
    if (coins > 0 || bonusPoints > 0 || freezes > 0) {
      controller.service.awardBonus(
          points: bonusPoints, coins: coins, freezes: freezes);
      controller.refresh();
    }
  }

  DateTime _parseMonday(String key) {
    final parts = key.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return DateTime.now();
  }

  /// The current week's leaderboard: the user plus 29 simulated members.
  List<LeagueRow> leaderboard({DateTime? at, int? overrideYourPoints}) {
    final s = state;
    final yourPoints =
        overrideYourPoints ?? controller.weeklyPoints;
    return _buildRows(s.tier, yourPoints, seed: s.weekStart);
  }

  List<LeagueRow> _buildRows(int tier, int yourPoints, {required String seed}) {
    final rng = Random(seed.hashCode ^ (tier * 7919));
    final level = controller.level;
    final mean = 40.0 + tier * 18 + level * 3;
    final names = _names;
    final scores = <int>[];
    for (var i = 0; i < members - 1; i++) {
      // Average of three draws → a rough bell around the tier mean.
      final draw = (rng.nextInt(100) + rng.nextInt(100) + rng.nextInt(100)) / 3;
      scores.add(max(0, (mean + (draw - 50) * 1.6).round()));
    }
    final entries = <({String name, int points, bool isYou})>[
      for (var i = 0; i < scores.length; i++)
        (name: names[i % names.length], points: scores[i], isYou: false),
      (name: 'You', points: yourPoints, isYou: true),
    ]..sort((a, b) => b.points.compareTo(a.points));

    return [
      for (var i = 0; i < entries.length; i++)
        LeagueRow(
          name: entries[i].name,
          points: entries[i].points,
          isYou: entries[i].isYou,
          position: i + 1,
        ),
    ];
  }

  static const List<String> _names = [
    'Aarav', 'Priya', 'Rohan', 'Ananya', 'Vikram', 'Neha', 'Karan', 'Diya',
    'Arjun', 'Sara', 'Rahul', 'Ishita', 'Dev', 'Meera', 'Kabir', 'Tara',
    'Aditya', 'Zoya', 'Nikhil', 'Pooja', 'Sanjay', 'Riya', 'Manish', 'Kavya',
    'Harsh', 'Nisha', 'Gaurav', 'Siya', 'Varun', 'Anika',
  ];
}
