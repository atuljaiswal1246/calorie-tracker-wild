import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/screens/demo/demo_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('scan demo plays the scan and reveals a dish', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      home: DemoScanScreen(onGetStarted: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Point at your plate'), findsOneWidget);

    // scanning -> analysing -> done
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Get started to log this'), findsOneWidget);
    expect(find.text('Paneer Butter Masala'), findsOneWidget);
  });
}
