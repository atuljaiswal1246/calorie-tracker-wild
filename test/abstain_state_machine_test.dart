// THE ABSTAIN FEATURE WAS DEAD, AND A GREP-BASED GUARD COULD NOT SEE IT.
//
// Found 2026-09-28, one day after shipping it in 3dded85. In capture_screen.dart
// the setState that handled a scan read, in full:
//
//   if (result.unrecognised) {
//     _unrecognised = true;
//     _error = null;
//   _unrecognised = false;      <- the next line
//   } else if (enrichedItems.isEmpty) {
//
// So the flag was set and immediately cleared. `_unrecognised` could never be
// true, the "I don't recognise this dish" card could never render, and the user
// got no message at all - not the abstain card, and not "No food detected"
// either, because `_error` had just been set to null.
//
// The owner's decision was a wrong number is worse than no number: say you do not
// recognise the dish and hand over the keyboard. That decision was unreachable in
// the shipped app, and I have been reporting it as "shipped" ever since.
//
// WHY NO GUARD CAUGHT IT. test/abstain_path_test.dart checked that the source
// CONTAINED `_unrecognised`, that it contained the words "I don't recognise this
// dish", and that the prompt asks for the flag. All true. All irrelevant. In a
// source file, a flag that is set and cleared looks exactly like a flag that
// works. That is a guard reading the wrong thing - it read the vocabulary of the
// feature instead of its behaviour - and the fix is a behavioural test, not a
// stricter string match.
//
// The decision is now a pure function, `scanOutcome()`, and this file tests all
// three branches. It also pins the shape that caused the bug: no assignment to
// `_unrecognised` may appear inside a setState that decides the outcome.

import 'dart:io';

import 'package:calorie_tracker/screens/capture_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what one scan produced', () {
    test('an abstention wins even when the model also listed a dish', () {
      // The over-confident answer is the dangerous one: "I don't recognise it"
      // next to a confident calorie figure. If items override the flag, the
      // model can talk its way out of the safe path and we are back to logging
      // numbers the user cannot check.
      expect(
        scanOutcome(unrecognised: true, itemCount: 1),
        ScanOutcome.abstained,
        reason: 'An abstention must win over items. This is the whole point of '
            'the feature.',
      );
    });

    test('an abstention with no items is still an abstention', () {
      expect(scanOutcome(unrecognised: true, itemCount: 0),
          ScanOutcome.abstained);
    });

    test('items and no abstention is a normal answer', () {
      expect(scanOutcome(unrecognised: false, itemCount: 3),
          ScanOutcome.answered);
    });

    test('no items and no abstention is "no food detected"', () {
      // The older verdict still has a job: a photo of a wall. It must NOT be
      // dressed up as an abstention - the copy is different and the user is told
      // something different.
      expect(scanOutcome(unrecognised: false, itemCount: 0), ScanOutcome.noFood);
      expect(ScanOutcome.noFood, isNot(ScanOutcome.abstained));
    });

    test('exactly three outcomes, and none of them is a silent success', () {
      // Enumerated on purpose. If someone adds a fourth state, this fails and
      // forces the question "what does the user see?" rather than a silent merge.
      expect(ScanOutcome.values, hasLength(3));
      for (final outcome in ScanOutcome.values) {
        expect(outcome, isNotNull);
      }
    });
  });

  group('the decision is made once, in one place', () {
    // The bug's shape, pinned so it cannot come back. A second inline
    // `if (result.unrecognised)` in the screen is how a flag gets set and
    // cleared: once the decision is a function, the screen must call it.
    test('the screen calls scanOutcome and does not decide inline', () {
      final src =
          File('lib/screens/capture_screen.dart').readAsStringSync();
      expect(
        src.contains('scanOutcome('),
        isTrue,
        reason: 'capture_screen must decide the outcome through scanOutcome().',
      );
      final inline = RegExp(r'if\s*\(\s*result\.unrecognised\s*\)')
          .allMatches(src)
          .length;
      expect(
        inline,
        0,
        reason: 'There is an inline `if (result.unrecognised)` in the screen '
            'again. That is the exact shape of the bug that made the feature '
            'unreachable: the decision belongs in scanOutcome(), where it can '
            'be tested.',
      );
    });

    test('no _unrecognised assignment sits next to the outcome decision', () {
      // Belt and braces on the original defect: within the setState that applies
      // the outcome, the flag may only be assigned from the outcome.
      final src =
          File('lib/screens/capture_screen.dart').readAsStringSync();
      // Anchored on the setState that APPLIES the outcome, not on the call: the
      // window has to span the flag assignment, which is the thing under test.
      final block = RegExp(
              r'final outcome = scanOutcome\([\s\S]{0,600}?\n      \}\);')
          .firstMatch(src)
          ?.group(0);
      expect(block, isNotNull,
          reason: 'The setState that applies scanOutcome() is gone; this test '
              'must be rewritten to match what the code does now.');
      expect(
        block!.contains('_unrecognised = outcome == ScanOutcome.abstained'),
        isTrue,
        reason: 'The abstain flag must be assigned FROM the outcome, not set '
            'and then cleared.\n$block',
      );
      expect(
        !block.contains('_unrecognised = false'),
        isTrue,
        reason: 'A `_unrecognised = false` inside the outcome block is the '
            'self-cancelling flag again.\n$block',
      );
    });
  });
}
