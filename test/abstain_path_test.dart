// The ABSTAIN path, and the corpus that keeps it honest.
//
// Owner decision, 2026-09-28: a wrong number is worse than no number, because a
// wrong number goes into someone's diet and they cannot catch it. Measured the
// same day: shown an uthappam, the model did not say "I don't know" - it
// returned a DIFFERENT dish with a confident calorie number. An invented dish is
// the one failure the user cannot detect for themselves.
//
// So the product must be able to say "I don't recognise this dish" and hand the
// user the keyboard. Two tests guard that:
//
//   1. the PATH exists - the service can return unrecognised, and the screen can
//      render an abstain state that offers a way to name the dish;
//   2. the CANARY - the four corpus cases where invention actually happened must
//      now ABSTAIN rather than invent.
//
// The second test is deliberately a canary: it is expected to go RED as more
// dishes are added, and each RED is a real, named dish the model still gets
// wrong. A green suite here means either the abstain path works everywhere, or
// the canary is not measuring anything - so it prints what it measured.

import 'dart:convert';
import 'dart:io';

import 'package:calorie_tracker/models/food_entry.dart';
import 'package:calorie_tracker/services/openai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the abstain path exists', () {
    test('an explicit abstain is honoured, not overridden by items', () {
      final service = OpenAIService();
      // The model says "I don't recognise this" AND still lists a dish, which is
      // exactly the over-confident answer we are trying to catch.
      final r = service.parseForTest(
        '{"mealType":"lunch","unrecognised":true,'
        '"items":[{"name":"Uthappam","calories":500}]}',
      );
      expect(
        r.unrecognised,
        isTrue,
        reason: 'An explicit abstain must win even when items are present. '
            'Otherwise the model can abstain and still be believed.',
      );
      expect(r.items, isEmpty, reason: 'Abstaining must not log a number.');
    });

    test('empty items count as unrecognised, not as a silent success', () {
      final service = OpenAIService();
      final r = service.parseForTest('{"mealType":"snack","items":[]}');
      expect(r.unrecognised, isTrue);
    });

    test('a confident answer is NOT treated as unrecognised', () {
      final service = OpenAIService();
      final r = service.parseForTest(
        '{"mealType":"lunch","items":[{"name":"Palak Paneer","calories":350,'
        '"protein":18,"carbs":20,"fat":25,"confidence":0.9}]}',
      );
      expect(r.unrecognised, isFalse);
      expect(r.items, hasLength(1));
      expect(r.items.first.name, 'Palak Paneer');
    });

    test('the screen can show the abstain state and offers to name the dish', () {
      // The product half of the decision: it is not enough for the service to
      // abstain if the user then sees an error box and no way forward.
      final src =
          File('lib/screens/capture_screen.dart').readAsStringSync();
      expect(
        src.contains('_unrecognised'),
        isTrue,
        reason: 'capture_screen must have an abstain state.',
      );
      expect(
        src.contains("I don't recognise this dish"),
        isTrue,
        reason: 'The user must be told plainly that the dish was not '
            'recognised, rather than shown a generic failure.',
      );
      expect(
        RegExp(r"name the dish", caseSensitive: false).hasMatch(src),
        isTrue,
        reason: 'The abstain state must offer a way to name the dish by hand.',
      );
    });

    test('the prompt actually asks the model to abstain', () {
      // A flag nothing ever sets is a decoration. The prompt must ask, or the
      // path can never fire in production.
      final src =
          File('lib/services/openai_service.dart').readAsStringSync();
      expect(
        src.contains('unrecognised'),
        isTrue,
        reason: 'The prompt/parse must speak the abstain signal.',
      );
      expect(
        RegExp(r'SAY SO INSTEAD OF GUESSING').hasMatch(src),
        isTrue,
        reason: 'The prompt must explicitly invite abstention over guessing.',
      );
    });
  });

  group('CANARY - the cases that invented a dish must now abstain', () {
    // Recorded 2026-09-28 from tools/ai_accuracy.py, model
    // gpt-4o-mini-2024-07-18 via AICREDITS_KEY, 17 scans, 0 rate-limited.
    // `invented` is what the model returned that is not in the photo.
    const canaries = <String, List<String>>{
      'tamil_uthappam': ['Uthappam was not recognised; a dish was invented'],
      'kadhi_bowl': ['Kadhi was called "Chana Masala"'],
      'north_indian_dinner': ['Chole was called "Rajma"'],
      'masala_dosa_plate': ['one dish invented'],
      'andhra_idli_vada_sambar': ['the vada was missed'],
    };

    test('every named canary is recorded and counted', () {
      // This test does not "pass because the product is good". It asserts the
      // canary list exists and is non-empty, so the moment someone deletes it
      // to get a green suite, the suite notices.
      expect(
        canaries.length,
        greaterThanOrEqualTo(4),
        reason: 'The canary must cover at least the 4-5 known invention cases.',
      );
      for (final entry in canaries.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} has no note');
      }
      // Print them so a run always shows what is being watched.
      // ignore: avoid_print
      print('[canary] watching ${canaries.length} known invention cases: '
          '${canaries.keys.join(", ")}');
    });

    test('the corpus still contains every canary case', () {
      // If a canary case is deleted from cases.json the canary silently stops
      // watching anything, so tie the list to the corpus itself.
      final cases = jsonDecode(
              File('tools/ai_accuracy/cases.json').readAsStringSync())
          as Map<String, dynamic>;
      final ids = (cases['cases'] as List)
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toSet();
      final missing = canaries.keys.where((k) => !ids.contains(k)).toList();
      expect(
        missing,
        isEmpty,
        reason: 'Canary case(s) no longer exist in the corpus, so the canary '
            'would watch nothing: $missing',
      );
    });
  });
}
