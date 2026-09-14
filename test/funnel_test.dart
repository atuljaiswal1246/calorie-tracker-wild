import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/services/analytics_service.dart';
import 'package:calorie_tracker/services/funnel.dart';
import 'package:calorie_tracker/services/storage_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    AnalyticsService.init(storage);
    await AnalyticsService.clear();
  });

  test('records each funnel step in order', () async {
    Funnel.appOpen();
    Funnel.onboardingStart(0);
    Funnel.stepComplete(0, 'name_sex', 4200);
    Funnel.stepComplete(1, 'goal', 1800);
    Funnel.questionsComplete();
    Funnel.signup('google');
    Funnel.paywallView();
    Funnel.purchaseComplete();
    Funnel.homeReached();
    Funnel.firstLog(method: 'scan');

    final events =
        AnalyticsService.recent().map((e) => e['event'] as String).toList();
    expect(
        events,
        [
          'app_open',
          'onboarding_start',
          'onboarding_step',
          'onboarding_step',
          'onboarding_questions_complete',
          'signup',
          'paywall_view',
          'purchase_complete',
          'home_reached',
          'first_log',
        ]);
  });

  test('funnel events carry time since app open', () async {
    Funnel.appOpen();
    Funnel.firstLog(method: 'manual');
    final firstLog = AnalyticsService.recent()
        .lastWhere((e) => e['event'] == 'first_log');
    final params = (firstLog['params'] as Map).cast<String, Object?>();
    expect(params['method'], 'manual');
    expect(params['since_open_ms'], isA<int>());
    expect(params['since_open_ms'] as int, greaterThanOrEqualTo(0));
  });

  test('step timing is captured', () async {
    Funnel.appOpen();
    Funnel.stepComplete(2, 'weight', 9500);
    final step = AnalyticsService.recent()
        .lastWhere((e) => e['event'] == 'onboarding_step');
    final params = (step['params'] as Map).cast<String, Object?>();
    expect(params['step'], 2);
    expect(params['name'], 'weight');
    expect(params['ms'], 9500);
  });
}
