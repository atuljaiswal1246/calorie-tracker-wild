import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/screens/onboarding_flow.dart';
import 'package:calorie_tracker/services/auth_service.dart';
import 'package:calorie_tracker/services/funnel.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _materialIcons =
    '/opt/homebrew/Caskroom/flutter/3.47.1/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  final icons = FontLoader('MaterialIcons');
  final bytes = await File(_materialIcons).readAsBytes();
  icons.addFont(Future.value(ByteData.view(bytes.buffer)));
  await Future.wait([inter.load(), icons.load()]);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  Future<void> pumpBodyStep(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    Funnel.appOpen();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      home: OnboardingFlow(
        storage: StorageService(prefs),
        auth: AuthService(),
        onComplete: () {},
        onBack: () {},
        startAtStep: 2,
      ),
    ));
    await tester.pump();
  }

  testWidgets('height & weight: unit pills switch and the value updates',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpBodyStep(tester);

    // Default imperial height + metric weight.
    expect(find.text('5 ft 5 in'), findsOneWidget);
    expect(find.text('70 kg'), findsOneWidget);
    expect(find.textContaining('BMI '), findsOneWidget);

    // Switch height to cm and weight to lbs.
    await tester.tap(find.text('cm'));
    await tester.pumpAndSettle();
    expect(find.text('165 cm'), findsOneWidget);

    await tester.tap(find.text('lbs'));
    await tester.pumpAndSettle();
    expect(find.text('154 lbs'), findsOneWidget);
  });

  testWidgets('height & weight: dragging a ruler changes the value',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpBodyStep(tester);
    expect(find.text('70 kg'), findsOneWidget);

    // Drag the weight ruler upward (negative dx increases the value).
    final ruler = find.byType(CustomPaint).last;
    await tester.drag(ruler, const Offset(-60, 0));
    await tester.pumpAndSettle();

    expect(find.text('70 kg'), findsNothing);
  });
}
