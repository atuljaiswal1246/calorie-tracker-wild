import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/screens/onboarding_flow.dart';
import 'package:calorie_tracker/screens/welcome_screen.dart';
import 'package:calorie_tracker/services/auth_service.dart';
import 'package:calorie_tracker/services/funnel.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the real screens at iPhone size with the real Inter + Material icons
/// fonts and real image assets, saving PNGs to `test/goldens/`. Any
/// RenderFlex overflow fails the test. Run:
///   flutter test --update-goldens test/screen_preview_test.dart
const _materialIcons =
    '/opt/homebrew/Caskroom/flutter/3.47.1/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

const _images = [
  'assets/onboarding/hero_bowl.jpg',
  'assets/onboarding/avatar_male.png',
  'assets/onboarding/avatar_female.png',
  'assets/onboarding/avatar_other.png',
  'assets/onboarding/bowl_illustration.png',
  'assets/onboarding/feature_scan.jpg',
  'assets/onboarding/feature_macros.jpg',
  'assets/onboarding/feature_exercise.jpg',
  'assets/onboarding/feature_water.jpg',
  'assets/icons/app_icon.png',
];

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  final icons = FontLoader('MaterialIcons');
  final bytes = await File(_materialIcons).readAsBytes();
  icons.addFont(Future.value(ByteData.view(bytes.buffer)));
  await Future.wait([inter.load(), icons.load()]);
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      home: child,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556); // iPhone 15/16 class
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Decode the real asset images so they actually paint in the golden.
Future<void> _precache(WidgetTester tester) async {
  final ctx = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final path in _images) {
      await precacheImage(AssetImage(path), ctx);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Funnel.appOpen();
  });

  testWidgets('welcome', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(WelcomeScreen(
      onGetStarted: () {},
      onSignIn: () {},
    )));
    await _precache(tester);
    for (var i = 0; i < 4; i++) {
      if (i > 0) {
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      }
      await expectLater(find.byType(WelcomeScreen),
          matchesGoldenFile('goldens/welcome_$i.png'));
    }
  });

  for (var step = 0; step < 7; step++) {
    testWidgets('onboarding step $step', (tester) async {
      _phone(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      await tester.pumpWidget(_wrap(OnboardingFlow(
        storage: storage,
        auth: AuthService(),
        onComplete: () {},
        onBack: () {},
        startAtStep: step == 0 ? null : step,
      )));
      await _precache(tester);
      await expectLater(find.byType(OnboardingFlow),
          matchesGoldenFile('goldens/onboarding_$step.png'));
    });
  }
}
