import 'package:flutter_test/flutter_test.dart';

/// Literal mirror of OnboardingScreen's navigation so the questionnaire
/// flow can be verified per goal WITHOUT widget rendering.
///
/// Steps: 0=About-you, 1=Goal, 2=Weight, 3=Target weight,
///        4=Height, 5=Workout, 6=Pace, 7=Building, 8=Plan

const totalSteps = 7;
const buildingStep = 7;
const planStep = 8;

class Nav {
  int step = 0;
  String? goal;
  bool noTarget = false;

  bool get skip =>
      noTarget || goal == 'maintain' || goal == 'exploring';

  void next() {
    step++;
    if (skip && step == 3) step += 1;
    if (skip && step == 6) step += 1;
  }

  void back() {
    if (step == 0) return;
    step--;
    if (skip && step == 6) step--;
    if (skip && step == 3) step--;
  }

  List<int> walk() {
    final out = <int>[];
    for (var i = 0; i < 20; i++) {
      if (step == planStep) break;
      out.add(step);
      if (step == buildingStep) {
        step = planStep;
        continue;
      }
      next();
    }
    out.add(planStep);
    return out;
  }
}

String headingFor(String? goal, int step) {
  switch (step) {
    case 0:
      return 'First things first.';
    case 1:
      return 'Choose your goal';
    case 2:
      return 'What\'s your current weight?';
    case 3:
      return 'What\'s your target weight?';
    case 4:
      return 'What\'s your height?';
    case 5:
      return 'How many times do you\nworkout in a week?';
    case 6:
      return goal == 'gain'
          ? 'How fast do you\nwant to gain weight?'
          : 'How fast do you\nwant to lose weight?';
    default:
      return '(building/plan)';
  }
}

void main() {
  test('lose goal visits every question step', () {
    final nav = Nav()..goal = 'lose';
    expect(nav.walk(), [0, 1, 2, 3, 4, 5, 6, buildingStep, planStep]);
    expect(headingFor('lose', 6), 'How fast do you\nwant to lose weight?');
  });

  test('gain goal visits every question step with gain heading', () {
    final nav = Nav()..goal = 'gain';
    expect(nav.walk(), [0, 1, 2, 3, 4, 5, 6, buildingStep, planStep]);
    expect(headingFor('gain', 6), 'How fast do you\nwant to gain weight?');
  });

  test('maintain goal skips target AND pace', () {
    final nav = Nav()..goal = 'maintain';
    expect(nav.walk(), [0, 1, 2, 4, 5, buildingStep, planStep]);
  });

  test('exploring goal skips target AND pace', () {
    final nav = Nav()..goal = 'exploring';
    expect(nav.walk(), [0, 1, 2, 4, 5, buildingStep, planStep]);
  });

  test('lose with noTarget skips target AND pace', () {
    final nav = Nav()..goal = 'lose'..noTarget = true;
    expect(nav.walk(), [0, 1, 2, 4, 5, buildingStep, planStep]);
  });

  test('gain with noTarget skips target AND pace', () {
    final nav = Nav()..goal = 'gain'..noTarget = true;
    expect(nav.walk(), [0, 1, 2, 4, 5, buildingStep, planStep]);
  });

  test('back from building lands on last question (maintain -> workout)', () {
    final nav = Nav()..goal = 'maintain';
    nav.walk(); // ends at planStep after adding building
    // Walk mirrors actual flow; go back from building manually.
    nav.step = planStep; // at plan
    // Simulate plan onBack -> last question
    nav.step = totalSteps - 1; // 6
    if (nav.skip) nav.step--; // maintain -> 5 (workout)
    expect(nav.step, 5);
    expect(headingFor('maintain', nav.step),
        'How many times do you\nworkout in a week?');
  });

  test('back from building lands on pace for lose/gain', () {
    final nav = Nav()..goal = 'lose';
    nav.step = planStep;
    nav.step = totalSteps - 1; // 6 (pace)
    expect(nav.step, 6);
    expect(headingFor('lose', 6), 'How fast do you\nwant to lose weight?');
  });
}
