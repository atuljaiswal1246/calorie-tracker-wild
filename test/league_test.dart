import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/models/league.dart';
import 'package:calorie_tracker/services/gamification_controller.dart';
import 'package:calorie_tracker/services/league_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;
  late GamificationController gami;
  late LeagueService league;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    gami = GamificationController(storage);
    await gami.init();
    league = LeagueService(storage, gami);
  });

  test('the ten tiers match the plan', () {
    expect(LeagueService.tiers.length, 10);
    expect(LeagueService.tierFor(1).name, 'Seedling');
    expect(LeagueService.tierFor(10).name, 'World Tree');
    expect(LeagueService.tierFor(10).demote, 0);
    expect(LeagueService.tierFor(4).promote, 7);
  });

  test('sync starts the week with zero points', () async {
    final s = await league.sync(at: DateTime(2026, 9, 7));
    expect(s.weekStart, '2026-9-7');
    expect(s.weeklyPoints, 0);
    expect(s.weeksPlayed, 0);
  });

  test('the leaderboard has 30 rows with the user included once', () async {
    await league.sync(at: DateTime(2026, 9, 7));
    final rows = league.leaderboard(at: DateTime(2026, 9, 7));
    expect(rows.length, 30);
    expect(rows.where((r) => r.isYou).length, 1);
    expect(rows.first.position, 1);
    expect(rows.last.position, 30);
    // Sorted by points, highest first.
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i - 1].points, greaterThanOrEqualTo(rows[i].points));
    }
  });

  test('a very strong week promotes and pays the podium reward', () async {
    // Set up a previous week with a huge score.
    await storage.saveLeagueState(
        LeagueState(tier: 1, weekStart: '2026-8-31').toJson());
    gami.state.pointsByDay['2026-09-01'] = 5000;
    await gami.persist();

    final s = await league.sync(at: DateTime(2026, 9, 7));
    expect(s.tier, 2);
    expect(s.lastResult, 'promote');
    expect(s.weeksPlayed, 1);
    // 1st place: +100 coins, +50 points and a freeze.
    expect(gami.nutriCoins, greaterThanOrEqualTo(100));
  });

  test('a zero-point week at tier 1 does not demote', () async {
    await storage.saveLeagueState(
        LeagueState(tier: 1, weekStart: '2026-8-31').toJson());
    await gami.persist();
    final s = await league.sync(at: DateTime(2026, 9, 7));
    expect(s.tier, 1);
    expect(s.lastResult, anyOf('stay', 'promote'));
    expect(s.lastResult, isNot('demote'));
  });

  test('a settled week is not settled again within the same week', () async {
    await storage.saveLeagueState(
        LeagueState(tier: 1, weekStart: '2026-8-31').toJson());
    await gami.persist();
    await league.sync(at: DateTime(2026, 9, 7));
    final again = await league.sync(at: DateTime(2026, 9, 8));
    expect(again.weeksPlayed, 1);
  });
}
