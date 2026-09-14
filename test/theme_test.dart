import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calorie_tracker/theme/app_colors.dart';

void main() {
  tearDown(() => AppColors.themeNotifier.value = 'default');

  test('default theme keeps the blue accent', () {
    AppColors.themeNotifier.value = 'default';
    expect(AppColors.accent, const Color(0xFF007AFF));
  });

  test('forest and midnight themes change the accent and primary button', () {
    AppColors.themeNotifier.value = 'theme_forest';
    expect(AppColors.accent, const Color(0xFF2E7D32));
    final forestButton = AppColors.inkButton;

    AppColors.themeNotifier.value = 'theme_midnight';
    expect(AppColors.accent, const Color(0xFF6C5CE7));
    expect(AppColors.inkButton, isNot(forestButton));
  });

  test('unknown theme id falls back to the default accent', () {
    AppColors.themeNotifier.value = 'nonsense';
    expect(AppColors.accent, const Color(0xFF007AFF));
  });
}
