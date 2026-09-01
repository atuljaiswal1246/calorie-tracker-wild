import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/screens/welcome_screen.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:calorie_tracker/theme/app_colors.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WelcomeScreen builds and renders (light + dark)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: AppColors.darkNotifier,
          builder: (_, __, snapshot) => child ?? const SizedBox.shrink(),
        ),
        home: WelcomeScreen(onGetStarted: () {}, onSignIn: () {}),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    AppColors.darkNotifier.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
    AppColors.darkNotifier.value = false;
  });

  test('StorageService dark mode round-trip', () async {
    final storage = StorageService(await SharedPreferences.getInstance());
    expect(storage.darkMode, isFalse);
    await storage.saveDarkMode(true);
    expect(storage.darkMode, isTrue);
  });
}
