// GUARD for §0 of AGENTS.md — the seven standing orders.
//
// The owner's lesson, 2026-09-27: "chat me bola hua order order nahi hota — file
// me pada hua rule hi rule hota hai." Six stale lines in AGENTS.md went on
// steering sessions for weeks, and every mistake tonight traced back to a rule
// that lived only in a conversation.
//
// So the seven are pinned here by a test. Delete or reword one of these and this
// fails. That is the point: the rules should be harder to lose than to keep.
//
// Each entry pairs a stable MARKER (the heading) with a REQUIRED IDEA (a phrase
// that must survive any rewording). Reformatting is allowed; deleting the rule
// is not.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// (marker that must exist, idea that must still be said, human name)
const _orders = <List<String>>[
  [
    'THE AIM',
    'RIGHT, FAST, QUIET',
    '1. the aim',
  ],
  [
    'ONE DOOR, ONE KEY',
    '/health',
    '2. one door, one key, model not chosen',
  ],
  [
    'CLOUDFLARE BOUNDARY',
    'calmatters-proxy',
    '3. Cloudflare boundary - Asha is not mine',
  ],
  [
    'AN EMPTY RESULT IS NOT A FINDING',
    'exit code',
    '4. empty result is not a finding',
  ],
  [
    "DON'T TAKE A BIG DECISION BEFORE A RIGHT TEST",
    'correct test',
    '5. no big decision before a right test',
  ],
  [
    'NAME THE PRODUCER OF EVERY NUMBER',
    'commit',
    '6. name the producer',
  ],
  [
    'EVERY STANDING ORDER GETS WRITTEN DOWN',
    'same sitting',
    '7. write it down in the same sitting',
  ],
];

void main() {
  final agents = File('AGENTS.md');
  final ceo = File('ceo.md');

  test('AGENTS.md exists and §0 is present', () {
    expect(agents.existsSync(), isTrue, reason: 'AGENTS.md is the project memory');
    final src = agents.readAsStringSync();
    expect(
      src.contains('STANDING ORDERS'),
      isTrue,
      reason: 'The §0 standing-orders block is missing from AGENTS.md.\n'
          'An order said in chat is not an order — a rule written in the file is\n'
          'the rule. Restore the block.',
    );
  });

  test('all seven standing orders survive in AGENTS.md §0', () {
    final src = agents.readAsStringSync();
    final start = src.indexOf('STANDING ORDERS');
    // Scope the check to §0 so a stray mention elsewhere cannot satisfy it.
    final rest = src.substring(start);
    final end = rest.indexOf('## ⚠️ ONE THING');
    final section = end == -1 ? rest : rest.substring(0, end);

    final missing = <String>[];
    for (final order in _orders) {
      final marker = order[0];
      final idea = order[1];
      final name = order[2];
      if (!section.contains(marker)) {
        missing.add('heading missing: "$marker"  ($name)');
      } else if (!section.contains(idea)) {
        missing.add('idea missing under "$marker": "$idea"  ($name)');
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Standing orders lost from AGENTS.md §0. Do not delete a rule to make a\n'
          'test pass — restore the rule.\n\n'
          '${missing.join('\n')}\n',
    );
  });

  test('ceo.md carries the same core rules, in one place', () {
    expect(ceo.existsSync(), isTrue, reason: 'ceo.md holds my constitution');
    final src = ceo.readAsStringSync();
    final missing = <String>[];
    for (final idea in const [
      'RIGHT, FAST, QUIET',
      'BLOCKED',
      'money',
      'exit code',
      'calmatters-proxy',
      'Asha',
    ]) {
      if (!src.contains(idea)) missing.add(idea);
    }
    expect(
      missing,
      isEmpty,
      reason: 'ceo.md is missing: ${missing.join(', ')}',
    );
  });

  test('the no-provider-key and one-door guards are both still in the repo', () {
    // §0 rule 2 is enforced by code as well as by prose. If these two tests
    // are deleted, the rule is only a promise again.
    for (final f in const [
      'test/no_provider_keys_test.dart',
      'test/one_key_path_test.dart',
    ]) {
      expect(
        File(f).existsSync(),
        isTrue,
        reason: '$f is the machine that enforces standing order 2. '
            'A prose rule with no machine behind it is how we got here.',
      );
    }
  });
}
