// The abstain card, RENDERED — and a golden, so somebody's eyes can see it.
//
// This closes the gap I named when I found the self-cancelling flag: "the card has
// still never been rendered in a test". A card nobody has ever seen rendered is a
// card nobody has ever looked at, and the previous guard checked the COPY
// EXISTED in a source file, which is how a dead feature passed for weeks.
//
// So: three things are checked, in increasing order of how much they can fail.
//   1. the card renders, with both ways forward, and both actually fire
//   2. it renders at iPhone AND Android widths with no overflow - the lesson from
//      the golden harness, where a low-res whole-page view hid real defects
//   3. a golden PNG with the REAL font, so a visual change has to be looked at
//      and accepted rather than regenerated and forgotten

import 'package:calorie_tracker/theme/app_colors.dart';
import 'package:calorie_tracker/widgets/abstain_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real font, loaded. Without it the first golden came out as a field of
/// black boxes: the default test font is far wider than Inter, so the words
/// rendered as solid rectangles and the card was clipped. A golden nobody can
/// read is not a guard, it is a file - and it would have let a visual regression
/// through while looking like a passing test.
///
/// No icon font here: this card is text and two buttons. The whole-screen preview
/// harness needs MaterialIcons and the symbol families because whole screens do;
/// loading a font this widget never uses is a second thing to break for nothing.
Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
  await inter.load();
}

Widget _host({required VoidCallback onName, required VoidCallback onAgain}) {
  return MaterialApp(
    // Inter on EVERY textTheme entry. A bare DropdownButton-style otherwise falls
    // back to the test font, which is the harness artefact this repo has already
    // been bitten by once.
    theme: ThemeData(
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontFamily: 'Inter'),
        bodySmall: TextStyle(fontFamily: 'Inter'),
        titleLarge: TextStyle(fontFamily: 'Inter'),
        titleMedium: TextStyle(fontFamily: 'Inter'),
        titleSmall: TextStyle(fontFamily: 'Inter'),
      ),
      // The family has to be on the BUTTON themes too, not only the text theme.
      // I looked at the first legible golden and the two button labels were
      // solid white and purple boxes: FilledButton and OutlinedButton take their
      // label style from the button theme, and with nothing set there they fell
      // back to the test font. A golden that renders labels as rectangles looks
      // exactly like a designed button until you read the words.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'Inter')),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'Inter')),
        ),
      ),
    ),
    home: Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stand-in for the result block above it, so the card is seen in the
            // company it ships in rather than floating on a blank page.
            const Text(
              'Here is what I read from your photo',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            AbstainCard(onNameDish: onName, onScanAgain: onAgain),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('the abstain card renders and both ways forward work', () {
    testWidgets('it says plainly that the dish was not recognised',
        (tester) async {
      await tester.pumpWidget(_host(onName: () {}, onAgain: () {}));
      expect(find.text("I don't recognise this dish"), findsOneWidget);
      expect(
        find.textContaining('Better an honest'),
        findsOneWidget,
        reason: 'The reason the app is abstaining must be shown, not just the '
            'verdict. A user who does not know why the app refused will assume '
            'it broke.',
      );
    });

    testWidgets('"Name the dish" is offered, and it fires', (tester) async {
      var named = 0;
      await tester.pumpWidget(_host(onName: () => named++, onAgain: () {}));
      expect(find.text('Name the dish'), findsOneWidget);
      await tester.tap(find.text('Name the dish'));
      await tester.pump();
      expect(named, 1,
          reason: 'The whole point of the feature is the keyboard. A button that '
              'does nothing is a promise the app cannot keep.');
    });

    testWidgets('"Scan again" is offered, and it fires', (tester) async {
      var again = 0;
      await tester.pumpWidget(_host(onName: () {}, onAgain: () => again++));
      expect(find.text('Scan again'), findsOneWidget);
      await tester.tap(find.text('Scan again'));
      await tester.pump();
      expect(again, 1,
          reason: 'A user who took the photo by mistake needs a way back to the '
              'camera without logging anything.');
    });

    testWidgets('it is NOT dressed up as an error', (tester) async {
      // The quiet rule, enforced: refusing to name a dish is the app behaving
      // correctly, and a red box would teach the user it is broken. Asserted
      // rather than left in a comment, because comments are how this class of
      // rule quietly stops being true.
      await tester.pumpWidget(_host(onName: () {}, onAgain: () {}));
      final card = tester.widget<Container>(find
          .ancestor(
            of: find.text("I don't recognise this dish"),
            matching: find.byType(Container),
          )
          .first);
      final colour = (card.decoration! as BoxDecoration).color;
      expect(
        colour,
        isNot(anyOf(
          const Color(0xFFFFEBEE),
          const Color(0xFFFDECEA),
          const Color(0xFFFFCDD2),
        )),
        reason: 'The abstain card is using an error background ($colour). '
            'Abstaining is a normal outcome.',
      );
      expect(colour, AppColors.card);
    });
  });

  group('it fits the phones people actually use', () {
    // Overflow is not cosmetic: a RenderFlex overflow in production shows up as
    // the yellow-and-black stripes, and this repo learned that a downscaled
    // whole-page screenshot hides exactly that.
    for (final size in const [
      Size(393, 852), // iPhone 15 class
      Size(360, 800), // the small Android that is still everywhere
    ]) {
      testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(onName: () {}, onAgain: () {}));
        expect(tester.takeException(), isNull,
            reason: 'The abstain card overflowed at ${size.width} - someone '
                'with that phone would see the stripes.');
      });
    }
  });

  group('a golden, so the card gets looked at', () {
    testWidgets('abstain card', (tester) async {
      await _loadFonts();
      // devicePixelRatio 1.0, not 2.0: at 2.0 the PNG came out 197x260 - the
      // ratio applied twice, so the golden was half the size I asked for and the
      // text was unreadable in the review. A golden you cannot read is a file
      // that only fails to be helpful.
      tester.view.physicalSize = const Size(393, 520);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(onName: () {}, onAgain: () {}));
      // Capture the Scaffold, not the card: capturing the card clipped the
      // bottom off - the buttons were missing from the very first golden, and a
      // golden that shows neither button is worse than no golden, because it
      // looks like the card is just a paragraph of text.
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/abstain_card.png'),
      );
    });
  });
}
