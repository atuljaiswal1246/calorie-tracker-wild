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

  testWidgets('target & pace: projection reacts to the chosen pace',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

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
        startAtStep: 4,
      ),
    ));
    await tester.pump();

    // Projection card + controls are present.
    expect(find.text('Your projected progress'), findsOneWidget);
    expect(find.text('Target weight'), findsOneWidget);

    // Moderate is the default, so the projection shows its weekly rate.
    expect(find.text('0.5'), findsOneWidget);

    // Switching to Slow must re-derive the projection.
    await tester.tap(find.text('Slow'));
    await tester.pumpAndSettle();
    expect(find.text('0.1'), findsOneWidget);
    expect(find.text('0.5'), findsNothing);

    // And the kcal/day figure is present.
    expect(find.text('kcal / day'), findsOneWidget);
  });
}
