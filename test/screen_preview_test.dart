import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/screens/auth_screen.dart';
import 'package:calorie_tracker/screens/demo/demo_exercise_screen.dart';
import 'package:calorie_tracker/screens/demo/demo_scan_screen.dart';
import 'package:calorie_tracker/screens/demo/demo_search_screen.dart';
import 'package:calorie_tracker/screens/demo/demo_water_screen.dart';
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
  'assets/onboarding/food_palak_paneer.jpg',
  'assets/onboarding/food_scan.jpg',
  'assets/onboarding/goal_lose.jpg',
  'assets/onboarding/goal_maintain.jpg',
  'assets/onboarding/goal_gain.jpg',
  'assets/onboarding/goal_explore.jpg',
  'assets/onboarding/body_height.jpg',
  'assets/onboarding/body_weight.jpg',
  'assets/onboarding/act_none.jpg',
  'assets/onboarding/act_1to2.jpg',
  'assets/onboarding/act_3to5.jpg',
  'assets/onboarding/act_6plus.jpg',
  'assets/icons/app_icon.png',
];

const _faBrands =
    '/Users/neharohilla/.pub-cache/hosted/pub.dev/font_awesome_flutter-11.0.0/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  final icons = FontLoader('MaterialIcons');
  icons.addFont(Future.value(
      ByteData.view((await File(_materialIcons).readAsBytes()).buffer)));
  final brands = FontLoader('packages/font_awesome_flutter/FontAwesomeBrands');
  brands.addFont(Future.value(
      ByteData.view((await File(_faBrands).readAsBytes()).buffer)));
  await Future.wait([inter.load(), icons.load(), brands.load()]);
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

  testWidgets('dob picker', (tester) async {
    _phone(tester);
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    await tester.pumpWidget(_wrap(OnboardingFlow(
      storage: storage,
      auth: AuthService(),
      onComplete: () {},
      onBack: () {},
      startAtStep: 1,
    )));
    await _precache(tester);
    await tester.tap(find.text('Date of birth'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/dob_picker.png'));
  });

  testWidgets('signup', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(AuthScreen(
      auth: AuthService(),
      isSignUp: true,
      recap: const PlanRecap(
          kcal: '1945', goal: 'Lose 5 kg', workouts: '3–5×'),
      onAuthenticated: () {},
      onBack: () {},
    )));
    await _precache(tester);
    await expectLater(
        find.byType(AuthScreen), matchesGoldenFile('goldens/signup.png'));
  });

  testWidgets('demo scan', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(DemoScanScreen(onGetStarted: () {})));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(DemoScanScreen),
        matchesGoldenFile('goldens/demo_scan_scanning.png'));
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 1200));
    await expectLater(
        find.byType(DemoScanScreen), matchesGoldenFile('goldens/demo_scan_result.png'));
  });

  testWidgets('demo search', (tester) async {    _phone(tester);
    await tester.pumpWidget(_wrap(DemoSearchScreen(onGetStarted: () {})));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
        find.byType(DemoSearchScreen), matchesGoldenFile('goldens/demo_search.png'));
  });

  testWidgets('demo exercise', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(DemoExerciseScreen(onGetStarted: () {})));
    await tester.pump(const Duration(milliseconds: 1200));
    await expectLater(find.byType(DemoExerciseScreen),
        matchesGoldenFile('goldens/demo_exercise.png'));
  });

  testWidgets('demo water', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(DemoWaterScreen(onGetStarted: () {})));
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(
        find.byType(DemoWaterScreen), matchesGoldenFile('goldens/demo_water.png'));
  });
}
