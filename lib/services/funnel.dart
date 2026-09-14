/// Onboarding → first-log funnel instrumentation (analytics only).
///
/// Centralises the funnel event names/params so the baseline is consistent and
/// one place changes if the flow does. All events carry `since_open_ms` so we
/// can compute time-to-first-log without a backend.
library;

import 'analytics_service.dart';

class Funnel {
  Funnel._();

  static void appOpen() => AnalyticsService.markSessionStart();

  static void onboardingStart(int step) =>
      AnalyticsService.log('onboarding_start', _p({'step': step}));

  static void stepComplete(int step, String name, int msOnStep) =>
      AnalyticsService.log('onboarding_step', _p({
        'step': step,
        'name': name,
        'ms': msOnStep,
      }));

  static void questionsComplete() =>
      AnalyticsService.log('onboarding_questions_complete', _p({}));

  static void planView() => AnalyticsService.log('plan_view', _p({}));

  static void signup(String method) =>
      AnalyticsService.log('signup', _p({'method': method}));

  static void paywallView() => AnalyticsService.log('paywall_view', _p({}));

  static void purchaseComplete() =>
      AnalyticsService.log('purchase_complete', _p({}));

  static void homeReached() => AnalyticsService.log('home_reached', _p({}));

  static void firstLog({required String method}) =>
      AnalyticsService.log('first_log', _p({'method': method}));

  static Map<String, Object?> _p(Map<String, Object?> extra) => {
        ...extra,
        'since_open_ms': AnalyticsService.sinceStartMs,
      };
}
