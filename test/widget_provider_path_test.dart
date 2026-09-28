// A widget that updates nothing looks exactly like a widget that is working.
//
// THE BUG THIS EXISTS TO PREVENT, and it shipped once. AGENTS.md, 2026-09-16:
//
//   "Widget updates went nowhere (FIXED). WidgetService pushed to
//    com.calorietracker.calorie_tracker.* — the old scaffold package — while the
//    applicationId is com.neharohilla.calorietracker. HomeWidget.updateWidget
//    silently updated a non-existent provider, so no widget ever received real
//    data; they showed their placeholder layouts."
//
// The worst part, recorded at the time: "The preview images in the launcher are
// static drawables, so they looked correct while the live widgets were empty —
// that is what hid it." A widget is the ONE surface where the picture a user sees
// is a lie by construction: the launcher preview is a drawable, not a render.
//
// So the fix was a one-line constant, and one-line constants rot silently. There
// was no test tying that constant to the real applicationId, which is why I can
// find, right now, that:
//   - `_pkg` in lib/services/widget_service.dart is a hardcoded string, and
//   - nothing in test/ reads android/app/build.gradle.kts at all.
// Change the applicationId for a Play rename, a flavour, or an org change, and
// every widget goes quiet again with no error anywhere.
//
// WHAT IS DERIVED AND WHY. Nothing here is a hand-copied expected value, because
// a hand-copied expected value is a second place to be wrong. The providers are
// read out of the real files: the applicationId out of build.gradle.kts, the
// package out of the Kotlin source directory, and the declared receivers out of
// the AndroidManifest. The test then asserts the Dart side addresses exactly the
// providers the app can actually deliver.
//
// THE SECOND FINDING, which is why this is not a one-liner. android/.../
// CalWaterWidgetProvider.kt EXISTS. Its receiver is NOT in the manifest — the
// water widget was pulled for 0.9.6 because its one-tap background action does
// not run on a real device. An undeclared provider class is dead code that looks
// alive, and it is exactly what gets re-declared by a merge, a revert, or
// someone tidying the manifest. It is reported as its own verdict, DISTINCT from
// "declared and reachable", because conflating them is how a pulled feature comes
// back as a dead button.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final gradle = File('android/app/build.gradle.kts');
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final service = File('lib/services/widget_service.dart');
  final kotlinDir =
      Directory('android/app/src/main/kotlin/com/neharohilla/calorietracker');

  /// The one applicationId, read out of the build file — never from the Dart
  /// side, because the Dart side is the thing under test.
  String readApplicationId() {
    final m = RegExp(r'applicationId\s*=\s*"([^"]+)"')
        .firstMatch(gradle.readAsStringSync());
    expect(m, isNotNull,
        reason: 'no applicationId in ${gradle.path} — if Gradle moved, this '
            'test must be taught the new place, not deleted');
    return m!.group(1)!;
  }

  List<String> declaredReceivers() {
    return RegExp(r'android:name="\.([A-Za-z0-9_]*Widget[A-Za-z0-9_]*)"')
        .allMatches(manifest.readAsStringSync())
        .map((m) => m.group(1)!)
        .toList();
  }

  List<String> kotlinWidgetClasses() {
    if (!kotlinDir.existsSync()) return [];
    return kotlinDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .where((n) => n.endsWith('.kt'))
        .toList();
  }

  test('the files this test depends on are all still where it expects', () {
    expect(gradle.existsSync(), isTrue);
    expect(manifest.existsSync(), isTrue);
    expect(service.existsSync(), isTrue);
    expect(kotlinDir.existsSync(), isTrue,
        reason: 'the Kotlin source directory moved; this test must be taught '
            'the new path rather than skipped');
  });

  test('the Dart widget service addresses the REAL applicationId', () {
    // The shipped bug, as a standing check.
    final appId = readApplicationId();
    final src = service.readAsStringSync();
    final pkg = RegExp(r"_pkg\s*=\s*'([^']+)'").firstMatch(src);
    expect(pkg, isNotNull,
        reason: 'widget_service.dart no longer declares _pkg; if the address '
            'moved, this test must follow it, not be deleted');
    expect(pkg!.group(1), appId,
        reason: 'THE BUG OF 2026-09-16. The app pushes widget updates to '
            '"${pkg.group(1)}" while the real applicationId is "$appId". '
            'HomeWidget.updateWidget updates a provider that does not exist, '
            'silently. The launcher preview is a static drawable, so every '
            'widget keeps showing its placeholder and nothing looks broken.\n'
            'The fix is to make _pkg derive from the real applicationId, not '
            'to re-copy the string.');
  });

  test('every provider it addresses is one the app can actually deliver', () {
    // Direction matters: a name in Dart that no manifest receiver matches is a
    // silent no-op. This is the direction that produced the bug.
    final declared = declaredReceivers();
    expect(declared, isNotEmpty,
        reason: 'no widget receivers found in the manifest — the regex or the '
            'manifest changed and this test would otherwise pass on nothing');
    final src = service.readAsStringSync();
    for (final m in RegExp(r"'([A-Za-z0-9_]*Widget[A-Za-z0-9_]*)'")
        .allMatches(src)) {
      final name = m.group(1)!;
      // Skip the class name of a type annotation if one ever appears; only a
      // bare provider string is an address.
      expect(declared, contains(name),
          reason: 'Dart addresses "$name" but no receiver by that name is '
              'declared in the manifest. Declared: $declared. That update goes '
              'nowhere, and nothing will report it.');
    }
  });

  test('a provider class that is not declared is reported, not ignored', () {
    // The water widget. Pulled for 0.9.6 because its one-tap background action
    // does not run on a real device (verified on the iQOO, Android 15). The
    // Kotlin class survives; the receiver does not.
    //
    // It is named here on purpose. An undeclared provider is not harmless: it is
    // the exact thing a revert, a merge or a tidy re-declares, and then a dead
    // button is on a user's home screen again. If CalWaterWidgetProvider is
    // ever deliberately brought back, this line is where that decision is
    // recorded - and it must come with a real interaction, because the reason it
    // was pulled was that the interaction did not work on a device.
    final declared = declaredReceivers();
    final classes = kotlinWidgetClasses();
    final orphan = classes
        .where((f) => !declared.contains(f.replaceAll('.kt', '')))
        .toList();
    expect(
        orphan,
        contains('CalWaterWidgetProvider.kt'),
        reason: 'the water widget is gone from the manifest on purpose. If this '
            'test now fails, someone re-declared the receiver — and the reason '
            'it was pulled is a one-tap that does not run on a real device. '
            'Do not re-add it without a working interaction. Undeclared '
            'providers: $orphan');
  });

  test('the two widgets we DO ship are both declared', () {
    // AGENTS.md 0.9.6: ring and meal ship, water does not. The launcher must
    // offer exactly the two.
    final declared = declaredReceivers();
    expect(declared, contains('CalRingWidgetProvider'),
        reason: 'the ring widget ships in 0.9.6 and must be offerable');
    expect(declared, contains('CalWidgetProvider'),
        reason: 'the meal widget ships in 0.9.6 and must be offerable');
  });

  test('the launcher cannot offer a widget with no drawable', () {
    // A receiver with a meta-data pointing at a layout that does not exist
    // renders nothing and reports nothing. The meta-data resource is the thing
    // that has to resolve, so it is read and checked against res/.
    final xml = manifest.readAsStringSync();
    final resources = RegExp(r'android:resource="@xml/([a-z_]+)"')
        .allMatches(xml)
        .map((m) => m.group(1)!)
        .toList();
    expect(resources, isNotEmpty);
    for (final r in resources) {
      expect(File('android/app/src/main/res/xml/$r.xml').existsSync(), isTrue,
          reason: 'the manifest points a receiver at @xml/$r and that file does '
              'not exist. The widget offers nothing and fails silently.');
    }
  });
}
