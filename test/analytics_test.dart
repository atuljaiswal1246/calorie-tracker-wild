import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/services/analytics_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    AnalyticsService.init(storage);
    await AnalyticsService.clear();
  });

  test('records and counts events', () {
    AnalyticsService.log('gameplay_action', {'points': 10});
    AnalyticsService.log('gameplay_action', {'points': 15});
    AnalyticsService.log('shop_purchase', {'item': 'streak_freeze'});
    final counts = AnalyticsService.counts();
    expect(counts['gameplay_action'], 2);
    expect(counts['shop_purchase'], 1);
    expect(AnalyticsService.recent().first['event'], 'gameplay_action');
  });

  test('keeps a bounded ring buffer of the most recent events', () async {
    for (var i = 0; i < AnalyticsService.maxEvents + 20; i++) {
      AnalyticsService.log('e$i');
    }
    // persist() is fire-and-forget; force a flush via a fresh read.
    await storage.saveAnalyticsEvents([
      {'event': 'flush', 'params': {}, 'at': DateTime.now().toIso8601String()},
    ]);
    expect(AnalyticsService.recent().length, lessThanOrEqualTo(AnalyticsService.maxEvents + 1));
  });

  test('clear empties the log', () async {
    AnalyticsService.log('x');
    await AnalyticsService.clear();
    expect(AnalyticsService.recent(), isEmpty);
  });
}
