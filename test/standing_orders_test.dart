// GUARD for §0 of AGENTS.md — the ten standing orders.
//
// The owner's lesson, 2026-09-27: "chat me bola hua order order nahi hota — file
// me pada hua rule hi rule hota hai." Six stale lines in AGENTS.md went on
// steering sessions for weeks, and every mistake tonight traced back to a rule
// that lived only in a conversation.
//
// So the ten are pinned here by a test. Delete or reword one of these and this
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
  [
    'PEHLE /HEALTH, PHIR SCAN',
    'PAISA NUMBER HAI, SCAN NUMBER NAHI',
    '8. read the budget before the scan; cap in money',
  ],
  [
    'A CLAIM ABOUT MY OWN WORK IS NOT EVIDENCE',
    'follow the real path',
    '9. a claim about my own work needs something that can disagree',
  ],
  [
    'SCOPED TESTS ONLY',
    'the full suite runs once, with the owner',
    '10. never run the full suite; scoped tests only',
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

  test('all ten standing orders survive in AGENTS.md §0', () {
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

  test('RULE 3 — ONE shared Worker: the rule survives, and no second door exists', () {
    // (i) the rule must be present in BOTH files, in the exact words that carry
    //     its meaning. The "one door" idea and the "both numbers" idea are
    //     separate obligations; losing either is a defect.
    final agents = File('AGENTS.md').readAsStringSync();
    final ceo = File('ceo.md').readAsStringSync();

    final files = {'AGENTS.md': agents, 'ceo.md': ceo};
    for (final MapEntry(key: file, value: pair) in {
      'AGENTS.md': {
        'one door': 'There is ONE door',
        'same key as Asha': 'the one Asha already uses',
        'never a second worker': 'Do **not** create a second Worker',
        'ask, do not act': 'ask — do not act',
        'before': '**Before:**',
        '3/3 probes': '**3/3 probes**',
        'after': '**After:**',
        'both numbers required': 'without both numbers',
      },
      'ceo.md': {
        // Pin the SENTENCE, not the heading. An earlier version of this guard
        // checked the bare phrase "ONE door", and I proved the hole by editing
        // the body while the heading still said it - the test went green on a
        // file that had lost the rule. A duplicate must never mask a removal.
        'one door': 'There is **ONE door**',
        'same worker': '**same** Cloudflare Worker',
        'same key': '**same** key',
        'ask, do not act': 'ask, do not act',
        'before': 'before',
        'after': 'again',
        'both numbers required': 'without both numbers',
      },
    }.entries) {
      final text = files[file]!;
      for (final req in pair.entries) {
        expect(
          text.contains(req.value),
          isTrue,
          reason: 'Standing order 3 is missing "${req.key}" in $file.\n'
              'Expected the phrase: "${req.value}"\n'
              'The owner lifted a BLOCKED to keep ONE shared Worker. Losing this '
              'sentence is how a second door gets built again.',
        );
      }
    }

    // (ii) NO second Worker name may exist anywhere in the repo. This is the
    //      thing I actually tried to build, so it is the thing to forbid by
    //      name, not merely in the abstract.
    for (final dir in const ['cloudflare_worker_calmatters', 'calmatters-proxy']) {
      expect(
        Directory(dir).existsSync(),
        isFalse,
        reason: '$dir exists. There is ONE Worker, shared with Asha. Delete it.\n'
            'The owner authorised no second worker and no second key.',
      );
    }
    final tracked = Process.runSync('git', ['grep', '-lIE', 'calmatters-proxy', '--', '.']);
    final hits = (tracked.stdout ?? '').trim();
    // AGENTS.md and ceo.md may NAME it, because naming what is forbidden is how
    // the next session recognises it. Nothing else may.
    final offenders = hits
        .split('\n')
        .where((String l) => l.trim().isNotEmpty)
        .where((String l) => !l.startsWith('AGENTS.md'))
        .where((String l) => !l.startsWith('ceo.md'))
        .where((l) => !l.contains('test/standing_orders_test.dart'))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'A second Worker name leaked outside the rules that forbid it:\n'
          '${offenders.join('\n')}',
    );

    // (iii) The other three provider secret NAMES must not be presented as MY
    //       own door. The shared Worker holds them and Asha's budget logic
    //       decides them; the order is that I do not claim them as mine.
    for (final secret in const ['OPENROUTER', 'ZEN', 'OPENCODE']) {
      final bad = RegExp('(my|our|cal matters)[^\\n]{0,40}$secret[_-]?KEY', caseSensitive: false);
      for (final entry in {'AGENTS.md': agents, 'ceo.md': ceo}.entries) {
        expect(
          bad.hasMatch(entry.value),
          isFalse,
          reason: '${secret}_KEY is being described as Cal Matters\' own door in '
              '${entry.key}. That secret belongs to the shared Worker and to '
              'Asha\'s budget logic. Ask before treating it as ours.',
        );
      }
    }
  });

  test('the shared-Worker protocol has a real recorded baseline', () {
    // A protocol that says "record before and after" is worthless if no
    // baseline was ever actually taken. Require the evidence to exist, so the
    // next change has something to compare against.
    final evidence = <String>[];
    for (final dir in Directory('notes').listSync()) {
      if (dir is File && dir.path.endsWith('.md')) {
        final t = dir.readAsStringSync();
        if (t.contains('x-cm-provider') || t.contains('aicredits') &&
            t.contains('probe')) {
          evidence.add(dir.path);
        }
      }
    }
    expect(
      evidence,
      isNotEmpty,
      reason: 'No note records an Asha-turn baseline. Standing order 3 requires '
          'a before-and-after number for every shared-Worker change; without a '
          'recorded baseline there is nothing to compare the next change to.',
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
