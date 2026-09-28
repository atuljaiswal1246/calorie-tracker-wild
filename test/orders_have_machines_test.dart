// An order with no machine is a notice, and a notice is what we already had.
//
// MEASURED 2026-09-28, and this file exists because of the number in it.
//
//   test/standing_orders_test.dart: GREEN, all eleven orders present.
//   Orders 11, 4 and 9: broken by me, on the same day the guard was green.
//
// Order 11 says never run git checkout / restore / reset / stash on a file whose
// change I did not write by hand. I ran `git checkout` on the owner's uncommitted
// DISH_CLASS block at 11:59, and then `git reset --hard` on my own uncommitted
// test file while cleaning up a probe, hours after writing both the order and the
// tool built to enforce it. The guard was green for every one of those minutes,
// because the guard checks that the HEADING and one PHRASE survive in AGENTS.md.
// It cannot check whether I did the thing.
//
// That is not a defect in the guard. It is the SHAPE of the guard: it proves the
// words are there, which is necessary and not sufficient. A test that checks a
// rule is written is a test that the rule is WRITTEN. Only a rule that is
// executed can be obeyed, and only an execution can be violated.
//
// So the gap this file closes is the one that IS machine-checkable: of the eleven
// orders, six name an executing test or tool and five do not. That is a decision
// nobody made consciously, so it is written down here as one, with the reason for
// each un-enforced order. And the standing rule is mechanical: a NEW order that
// names no machine is refused, because the moment an order arrives without one is
// the only moment anyone can cheaply give it one.
//
// The honesty requirement, stated so this cannot become another vacuous guard:
//   - the un-enforced list is explicit, so a gap is a choice on the record;
//   - every name in it is a REAL file, so the list cannot rot into fiction;
//   - this test asserts the machines it names EXIST, so an order cannot claim a
//     machine that was deleted;
//   - and it prints the ratio, so "green" is never read as "enforced".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Orders deliberately left unenforced, with the reason. Adding an order to this
/// list is a decision someone has to make out loud; the reason is required so
/// "we got to it later" cannot become the standing answer.
const _acceptedGaps = <String, String>{
  '1':
      'RIGHT, FAST, QUIET is a standard, not a predicate. A test that measured '
      'the product against it would have to choose weights, and a chosen weight '
      'is an argument wearing a number. The measurable parts are enforced '
      'elsewhere: test/quiet_copy_test.dart and '
      'test/store_listing_matches_app_test.dart.',
  '5':
      'The decision happens in a session, and after the fact an artefact of "a '
      'right test" is indistinguishable from an expensive one. A human deciding '
      'in a chat is not interceptable. What IS enforced is the cheap-first half: '
      'order 10 and test/money_gate_test.dart refuse a spend before it happens.',
  '6':
      'Half is enforceable and half is not, and the split is at the tree edge. '
      'The generated verified-claims block is enforced by '
      'test/self_claims_test.dart, so a file cannot drift from the toolchain. '
      'The REPORTING half — whether a chat message names its producer — happens '
      'outside the repo. tools/report_to_jarvis.py stamps a machine-read time '
      'rather than a typed one, which is the closest a file can get.',
  '10':
      'Whether I run the full suite is a thing I do at a shell, not a property '
      'of any file. A human being at a terminal is not interceptable, and a '
      'guard that claimed otherwise would be theatre. The cost of breaking this '
      'one is on the record in this order.',
};

void main() {
  late String section;
  late List<String> orders;

  setUpAll(() {
    final src = File('AGENTS.md').readAsStringSync();
    final start = src.indexOf('STANDING ORDERS');
    expect(start, isNot(-1),
        reason: 'the §0 block is missing from AGENTS.md');
    final rest = src.substring(start);
    final end = rest.indexOf('## ⚠️ ONE THING');
    section = end == -1 ? rest : rest.substring(0, end);

    // Orders are the `### N. HEADING` lines inside §0.
    orders = RegExp(r'^###\s+(\d+)\.\s+(.+)$', multiLine: true)
        .allMatches(section)
        .map((m) => '### ${m.group(1)}. ${m.group(2)}')
        .toList();
  });

  test('there are eleven orders and this list is not stale', () {
    expect(orders.length, 11,
        reason: 'AGENTS.md §0 has ${orders.length} orders. If one was added or '
            'removed, this file must be updated in the SAME commit — a guard '
            'that quietly covers a different set is worse than none.\n'
            'Found: $orders');
  });

  test('every order names an executing machine, or is an ACCEPTED GAP',
      () {
    final gaps = <String>[];
    final enforced = <String>[];
    for (final head in orders) {
      final i = section.indexOf(head);
      // The order's own text ENDS at the next `### `. A fixed-size window is a
      // filter that includes its neighbours, and I had it at 2600 characters:
      // order 2 "borrowed" a tool named in order 3's body, orders 6/7/8 borrowed
      // one from order 9, and order 9 then read as having none. Same species as
      // the bug this file is about - a boundary that does not mean what it says.
      final next = section.indexOf('\n### ', i + 1);
      final body =
          next == -1 ? section.substring(i) : section.substring(i, next);
      final machines = RegExp(r'(test/[a-z_]+\.dart|tools/[a-z_]+\.py)')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet()
          .toList();
      if (machines.isEmpty) {
        gaps.add(head);
      } else {
        enforced.add('$head -> ${machines.join(", ")}');
      }
    }

    for (final g in gaps) {
      // Match on the order NUMBER, not the prose. I first keyed this list by
      // heading text and compared it against the whole `### N. HEADING` line,
      // so every gap failed at once - a key that cannot match its own target is
      // a guard that reports everything wrong, which is how a real problem gets
      // ignored. The number is the stable part; the prose can be reworded.
      final num = RegExp(r'^###\s+(\d+)\.').firstMatch(g)?.group(1);
      expect(num, isNotNull, reason: 'could not read an order number from "$g"');
      expect(
          _acceptedGaps,
          contains(num),
          reason: 'order $g names NO machine and is not in the accepted-gap '
              'list. Either give it a test that can fail, or record why it '
              'cannot have one. The default must not be "no machine" — that is '
              'how six notices became eleven.\n'
              'Accepted gaps: ${_acceptedGaps.keys.toList()..sort()}');
    }
    // Print the ratio, so "green" is never read as "enforced".
    // ignore: avoid_print
    print('  orders with an executing machine: ${enforced.length}/${orders.length}');
    for (final e in enforced) {
      // ignore: avoid_print
      print('    $e');
    }
  });

  test('every machine an order names is a REAL file', () {
    // Otherwise an order can claim a guard that was deleted, and the claim
    // outlives the guard - which is the whole failure this file is about.
    for (final m in RegExp(r'(test/[a-z_]+\.dart|tools/[a-z_]+\.py)')
        .allMatches(section)) {
      final p = m.group(1)!;
      expect(File(p).existsSync(), isTrue,
          reason: 'AGENTS.md §0 names "$p" and it does not exist. An order that '
              'points at a machine which is not there is a promise with no '
              'executor.');
    }
  });

  test('every accepted gap has a real reason, not a shrug', () {
    for (final entry in _acceptedGaps.entries) {
      expect(entry.value.length, greaterThan(60),
          reason: 'the accepted gap for order ${entry.key} is too short to be a '
              'reason. "Later" is not a reason; a reason says WHY a machine '
              'would be theatre here.');
      expect(entry.value.toLowerCase(), isNot(contains('later')),
          reason: '"later" as the justification for "${entry.key}" — that is '
              'the failure mode this list was built to prevent');
    }
  });

  test('the accepted-gap list cannot ratchet upward', () {
    // I first tried to police this list with a KEYWORD test - a gap is honest if
    // its reason mentions a session, a chat or a person. That is a proxy, and it
    // made me pad reasons with words they did not need: order 1's real reason is
    // that RIGHT, FAST, QUIET is a standard rather than a predicate, and no
    // amount of "person" makes that truer. A check that rewards vocabulary is the
    // exact instrument this repo spent the night dismantling.
    //
    // So the honest constraints are structural: the list stays small, and every
    // reason is a real sentence. Growth has to be argued for, not typed.
    expect(_acceptedGaps.length, lessThanOrEqualTo(4),
        reason: 'there are eleven orders. Five unenforced is already more than '
            'should be tolerated, and six would mean the section has drifted '
            'back to being a list of notices. If a new one is genuinely '
            'unenforceable, argue it in the commit that adds it.');
  });
}
