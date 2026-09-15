import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/screens/achievements_screen.dart';
import 'package:calorie_tracker/screens/all_entries_screen.dart';
import 'package:calorie_tracker/screens/capture_screen.dart';
import 'package:calorie_tracker/screens/gamification_hub_screen.dart';
import 'package:calorie_tracker/screens/home_screen.dart';
import 'package:calorie_tracker/screens/insights_screen.dart';
import 'package:calorie_tracker/screens/league_screen.dart';
import 'package:calorie_tracker/screens/manual_entry_screen.dart';
import 'package:calorie_tracker/screens/quick_picks_screen.dart';
import 'package:calorie_tracker/screens/settings_screen.dart';
import 'package:calorie_tracker/screens/shop_screen.dart';
import 'package:calorie_tracker/services/auth_service.dart';
import 'package:calorie_tracker/services/funnel.dart';
import 'package:calorie_tracker/services/gamification_controller.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Golden harness for the main (unlocked) app screens: Home, Progress and the
/// Profile tab. Renders with realistic seeded data so layout regressions are
/// caught without a device. Run:
///   flutter test --update-goldens test/app_screens_preview_test.dart
const _materialIcons =
    '/opt/homebrew/Caskroom/flutter/3.47.1/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';

const _images = [
  'assets/onboarding/hero_bowl.jpg',
  'assets/onboarding/food_palak_paneer.jpg',
  'assets/onboarding/food_scan.jpg',
  'assets/onboarding/feature_exercise.jpg',
  'assets/onboarding/feature_water.jpg',
  'assets/onboarding/avatar_male.png',
  'assets/icons/app_icon.png',
];

/// AuthService without a live Firebase app (the real one needs Firebase).
class _FakeAuth extends AuthService {
  @override
  User? get currentUser => null;
  @override
  bool get isSignedIn => false;
}

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  final icons = FontLoader('MaterialIcons');
  icons.addFont(Future.value(
      ByteData.view((await File(_materialIcons).readAsBytes()).buffer)));
  // Real emoji so the screens that use emoji glyphs render truthfully.
  final emoji = FontLoader('Emoji');
  emoji.addFont(Future.value(ByteData.view(
      (await File('/System/Library/Fonts/Apple Color Emoji.ttc')
              .readAsBytes())
          .buffer)));
  // The app uses the `material_symbols_icons` package; without its fonts the
  // icons render as blank boxes in goldens.
  final symbolsDir =
      '/Users/neharohilla/.pub-cache/hosted/pub.dev/material_symbols_icons-4.2960.0/lib/fonts';
  final symbols = <Future<void>>[];
  for (final family in const [
    'MaterialSymbolsRounded',
    'MaterialSymbolsOutlined',
    'MaterialSymbolsSharp',
  ]) {
    // Package fonts are namespaced by Flutter.
    final loader =
        FontLoader('packages/material_symbols_icons/$family');
    loader.addFont(Future.value(ByteData.view(
        (await File('$symbolsDir/$family.ttf').readAsBytes()).buffer)));
    symbols.add(loader.load());
  }
  await Future.wait([inter.load(), icons.load(), emoji.load(), ...symbols]);
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Emoji'],
      ),
      home: child,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Full-page capture: a very tall viewport so the whole scrollable page is
/// laid out at once and can be reviewed in a single image.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 12600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void _tallAndroid(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 12600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void _android(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _precache(WidgetTester tester) async {
  final ctx = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final path in _images) {
      try {
        await precacheImage(AssetImage(path), ctx);
      } catch (_) {}
    }
  });
  await tester.pumpAndSettle();
}

Profile _profile() => Profile(      name: 'Atul',
      age: 30,
      sex: 'male',
      weightKg: 75,
      heightCm: 175,
      activityLevel: 'moderate',
      workoutFreq: '3to5',
      goal: 'lose',
      pace: 'recommended',
      targetWeightKg: 70,
    );

FoodItem _item(String name, int kcal, double p, double c, double f) => FoodItem(
      name: name,
      servingSizeGrams: 150,
      calories: kcal,
      protein: p,
      carbs: c,
      fat: f,
    );

List<FoodEntry> _entries() {
  final now = DateTime.now();
  DateTime at(int daysAgo, int h, int m) =>
      DateTime(now.year, now.month, now.day - daysAgo, h, m);
  return [
    FoodEntry(
      id: 'e1',
      dateTime: at(0, 8, 30),
      mealType: 'breakfast',
      imagePath: 'assets/onboarding/food_palak_paneer.jpg',
      items: [
        _item('Poha', 270, 5, 48, 6),
        _item('Masala Chai', 90, 2, 12, 3),
      ],
    ),
    FoodEntry(
      id: 'e2',
      dateTime: at(0, 13, 15),
      mealType: 'lunch',
      imagePath: 'assets/onboarding/food_palak_paneer.jpg',
      items: [
        _item('Palak Paneer', 265, 14, 9, 19),
        _item('Roti', 104, 3, 20, 2),
        _item('Dal Tadka', 180, 9, 22, 6),
      ],
    ),
    FoodEntry(
      id: 'e3',
      dateTime: at(0, 17, 40),
      mealType: 'snack',
      imagePath: '',
      items: [_item('Besan Sev', 185, 6, 18, 10)],
    ),
    FoodEntry(
      id: 'e4',
      dateTime: at(1, 20, 10),
      mealType: 'dinner',
      imagePath: '',
      items: [
        _item('Chicken Biryani', 480, 26, 55, 18),
      ],
    ),
  ];
}

Future<SharedPreferences> _seed({bool withEntries = true}) async {  SharedPreferences.setMockInitialValues({
    'user_profile': jsonEncode(_profile().toJson()),
    // Treat the harness user as a paying subscriber so Home renders its
    // real content instead of the trial-ended gate.
    'has_paid': true,
    if (withEntries)
      'food_entries': jsonEncode(_entries().map((e) => e.toJson()).toList()),
    'water_goal_ml': 2500,
    'water_entries': jsonEncode([
      {'date': DateTime.now().toIso8601String(), 'ml': 1200}
    ]),
  });
  final prefs = await SharedPreferences.getInstance();
  return prefs;
}

/// Seeded storage with the gamification controller live, so quests, the hub,
/// the shop and the league render their real content instead of an off-state.
Future<StorageService> _storage({bool withEntries = true}) async {
  final prefs = await _seed(withEntries: withEntries);
  final storage = StorageService(prefs);
  final gami = GamificationController(storage);
  await gami.init();
  return storage;
}

Future<void> _shot(
  WidgetTester tester,
  Widget screen,
  String name, {
  bool android = false,
}) async {
  if (android) {
    _android(tester);
  } else {
    _phone(tester);
  }
  await tester.pumpWidget(_wrap(screen));
  await _precache(tester);
  await tester.pump(const Duration(milliseconds: 600));
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

/// Stub the platform plugins the main screens touch so the harness can render
/// them offline. Every stub is a no-op; the screens must tolerate their
/// absence (that is part of what this harness asserts).
void _mockPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['wifi'] : null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
    MockStreamHandler.inline(onListen: (args, sink) => sink.success(['wifi'])),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  setUp(() {
    _mockPlugins();
    Funnel.appOpen();
  });

  testWidgets('home (seeded)', (tester) async {
    final storage = await _storage();
    await _shot(
      tester,
      HomeScreen(
        storage: storage,
        auth: _FakeAuth(),
        onSignedOut: () {},
        onResetGoals: () {},
      ),
      'app_home',
    );
  });

  testWidgets('home full page', (tester) async {
    final storage = await _storage();
    _tallPhone(tester);
    await tester.pumpWidget(_wrap(HomeScreen(
      storage: storage,
      auth: _FakeAuth(),
      onSignedOut: () {},
      onResetGoals: () {},
    )));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/app_home_full.png'));
  });

  testWidgets('progress and profile tabs (full page)', (tester) async {
    final storage = await _storage();
    _tallPhone(tester);
    await tester.pumpWidget(_wrap(HomeScreen(
      storage: storage,
      auth: _FakeAuth(),
      onSignedOut: () {},
      onResetGoals: () {},
    )));
    await _precache(tester);
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_progress_full.png'));
    await tester.tap(find.text('AT'));
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_profile_full.png'));
  });

  testWidgets('home full page (android width)', (tester) async {
    final storage = await _storage();
    _tallAndroid(tester);
    await tester.pumpWidget(_wrap(HomeScreen(
      storage: storage,
      auth: _FakeAuth(),
      onSignedOut: () {},
      onResetGoals: () {},
    )));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_home_full_android.png'));
  });

  testWidgets('first run: empty home and progress', (tester) async {
    final storage = await _storage(withEntries: false);
    _tallPhone(tester);
    await tester.pumpWidget(_wrap(HomeScreen(
      storage: storage,
      auth: _FakeAuth(),
      onSignedOut: () {},
      onResetGoals: () {},
    )));
    await _precache(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_first_run_home.png'));
    await tester.tap(find.byIcon(Icons.bar_chart_rounded));
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/app_first_run_progress.png'));
  });

  testWidgets('secondary screens render (full page)', (tester) async {
    final storage = await _storage();
    final screens = <String, Widget>{
      'insights': InsightsScreen(storage: storage),
      'history': AllEntriesScreen(storage: storage),
      'achievements': AchievementsScreen(storage: storage),
      'hub': const GamificationHubScreen(),
      'shop': const ShopScreen(),
      'league': const LeagueScreen(),
      'settings': SettingsScreen(
        storage: storage,
        onResetGoals: () {},
        onSignOut: () {},
      ),
      'quick_picks': QuickPicksScreen(storage: storage),
      'manual_entry': ManualEntryScreen(storage: storage),
      'capture': CaptureScreen(storage: storage),
    };
    for (final entry in screens.entries) {
      _tallPhone(tester);
      await tester.pumpWidget(_wrap(entry.value));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull,
          reason: '${entry.key} threw while rendering');
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/app_${entry.key}_full.png'));

      // The same screen on a narrower Android phone — the width where the
      // Home header overflow went unnoticed.
      _tallAndroid(tester);
      await tester.pumpWidget(_wrap(entry.value));
      await tester.pump(const Duration(milliseconds: 700));
      final ex = tester.takeException();
      if (ex != null) {
        debugPrint('ANDROID OVERFLOW [${entry.key}]: '
            '${ex is FlutterError ? ex.diagnostics.map((d) => d.toString()).join(' | ') : ex}');
      }
      expect(ex, isNull,
          reason: '${entry.key} overflowed at Android width');
    }
  });

  testWidgets('home and tabs overflow-free at Android width', (tester) async {
    final storage = await _storage();
    for (final tab in [
      Icons.home_rounded,
      Icons.bar_chart_rounded,
    ]) {
      _tallAndroid(tester);
      await tester.pumpWidget(_wrap(HomeScreen(
        storage: storage,
        auth: _FakeAuth(),
        onSignedOut: () {},
        onResetGoals: () {},
      )));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byIcon(tab));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull,
          reason: 'Home tab $tab overflowed at Android width');
    }
  });
}
