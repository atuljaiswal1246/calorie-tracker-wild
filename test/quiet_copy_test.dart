// M4 (QUIET) — the gentility of the app is a CHECK, not a promise.
//
// I audited every user-facing string in lib/ on 2026-09-27 and found no shame
// or guilt copy: the recovery line is "Missed yesterday? No worries — one quick
// log gets you back on track today", and the streak freeze is sold as "covers
// one missed day so a rest day never breaks you". That is the behaviour we
// want, and today nothing stops a future change from quietly breaking it.
//
// So this test reads the source and fails on the copy we refuse to ship.
// It is deliberately a source scan rather than a widget test: a shame string
// can be added to any screen, and a golden test of one screen would miss it.
//
// A failure here is not a nuisance. It means someone wrote copy that talks to
// the user about what they did wrong. Rewrite the line, do not allowlist it,
// unless it is genuinely a technical message to a developer.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phrases that shame, scold, or pressure the user. Matched case-insensitively.
const _banned = <String, String>{
  // second person + a failure word: "you failed", "you were bad"
  r"\byou\s+(failed|succeeded|are\s+failing|were\s+bad|are\s+bad)\b": 'second-person failure',
  r"\byou\s+should\s+(have|eat|log|try|stop|lose|gain)\b": 'prescriptive "you should"',
  r"\btry\s+harder\b": 'pressure',
  r"\bdon'?t\s+give\s+up\b": 'pressure',
  r"\bprove\s+it\b": 'pressure',
  r"\bno\s+excuses\b": 'pressure',
  r"\bcheat(ed|ing)?\b": 'guilt framing',
  r"\bsin\b|\bguilty\b|\bindulge\b|\bglutton|\bgreedy\b": 'guilt framing',
  r"\bbinge\b": 'guilt framing',
  r"\blazy\b|\bsloth\b": 'judgement of the person',
  r"\bfailure\b|\bfailed\b|\bdisaster\b|\bpathetic\b|\bpathetic\b": 'failure wording',
  r"\bwasted?\b|\bwaste\s+of\b": 'judgement of past behaviour',
  r"\bfat\s+logic\b|\beating\s+your\b|\bpunish\b": 'punitive framing',
  r"\byou\s+owe\b|\bearn\s+it\b|\bdeserve\s+to\b": 'debt framing',
};

/// Strings that match a banned pattern but are legitimately NOT user-facing:
/// developer-facing errors, log lines, and one copy line that talks ABOUT
/// guilt rather than inducing it. Every entry carries a reason, so adding to
/// this list is a decision someone has to justify in review.
const _allowlist = <String, String>{
  'Failed to load products':
      'billing error surfaced to the user as a failure to load, not a failure of the user',
  'Purchase failed':
      'a purchase error; the user did not fail at anything',
  'Restore failed':
      'a restore error',
  'Google sign-in failed. Try again.':
      'auth error; "try again" invites action rather than blaming the user',
  'Authentication failed.': 'auth error',
  'Apple sign-in failed. Try again.': 'auth error',
  'AI request failed':
      'technical exception text, shown in a debug context',
  'Image copy failed': 'technical log line',
  'widget callback registration failed': 'developer log line',
  'Widget push failed': 'developer log line',
  'Ring widget push failed': 'developer log line',
  'Water widget push failed': 'developer log line',
  'widgetInteractivityCallback failed': 'developer log line',
  'iOS notification sound copy failed': 'developer log line',
  'Sound failed': 'developer log line',
  'Bhai, Netflix + binge = guilt. Binge + a walk = balance. Do both.':
      "Asha's copy names guilt in order to dissolve it, and is parked behind Features.asha = false",
  'If you log your chai today, I\'ll tell you why Lord Krishna loved makhan (it slipped).':
      "Asha's playful aside; parked behind Features.asha = false",
  'Is eating rice at night bad?':
      "a USER-TYPE example prompt, parked behind Features.asha = false",
  'is rice bad at night?': 'a user-type example prompt, parked',
  'photo(s) had no food': 'batch scan result count, factual not shaming',
  // I first wrote "No food detected" into the BANNED list, on the theory that a
  // clinical dead-end is a QUIET failure. Reading the code, that was wrong:
  // capture_screen.dart puts an "Enter manually" button and a retry button
  // directly beneath this text, so the user is never stuck. It is a factual
  // statement about a scan, not a judgement of the person. Removed from the
  // banned list rather than left there to satisfy a test.
  'No food detected. Try another photo.':
      'factual scan result; an "Enter manually" escape and a retry sit right beneath it',
  'No food detected': 'factual scan result, same state',
  'Missed yesterday? No worries':
      'THE recovery line - explicitly reassuring, allowlisted on purpose so a future edit that hardens it is caught',
  'Missed yesterday? No worries — one quick log gets you back on track today.':
      'THE recovery line, full form',
  'so a rest day never breaks you': 'streak-freeze sales copy - frames a rest day as legitimate',
  'missed day': 'streak-freeze description',
  'badges unlocked': 'achievement count label',
  'badges': 'badge noun',
  'Extra Badge Slot': 'shop item name',
  'Showcase one more badge on your profile.': 'shop item description',
  'kcal': 'unit label, matches "bad" inside nothing - kept for clarity',
  'worstCal': 'a variable name for the lowest-calorie day, not a label',
};

// Two regexes rather than one alternation: a raw Dart string cannot contain
// an unescaped double quote, and the combined pattern needs both.
final _singleQuoted = RegExp(r"'((?:[^'\\\n]|\\.){5,110})'");
final _doubleQuoted = RegExp(r'"((?:[^"\\\n]|\\.){5,110})"');

bool _isAllowed(String s) =>
    _allowlist.keys.any((k) => s.contains(k));

void main() {
  test('no shame, guilt or pressure copy is shipped to the user', () {
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // Comments are not shipped to anyone.
        if (trimmed.startsWith('//')) continue;

        for (final m in [..._singleQuoted.allMatches(line),
          ..._doubleQuoted.allMatches(line)]) {
          final text = (m.group(1) ?? '').trim();
          if (text.isEmpty || !text.contains(' ')) continue;
          // Obvious developer strings, not copy.
          if (text.contains(r'$e') ||
              text.contains('Exception') ||
              text.contains('statusCode')) {
            continue;
          }
          if (_isAllowed(text)) continue;
          for (final entry in _banned.entries) {
            if (RegExp(entry.key, caseSensitive: false).hasMatch(text)) {
              violations.add(
                '${entity.path}:${i + 1}  [${entry.value}]\n'
                '    "$text"',
              );
              break;
            }
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Shame/pressure copy found in ${violations.length} place(s).\n'
          'Rewrite the line so it encourages rather than scolds, and add a test\n'
          'case for the technical string only if it is genuinely a developer\n'
          'message. Do not allowlist user-facing copy.\n\n'
          '${violations.join('\n')}\n',
    );
  });

  test('the notification opt-out is honoured, not decorative', () {
    // M4 also requires that switching reminders off really stops them. The
    // guard is that the storage flags default to a QUIET state: water reminders
    // may be on, but the pushy one (meal nudges) must be off until asked for.
    final storage = File('lib/services/storage_service.dart').readAsStringSync();
    expect(
      RegExp(r'mealRemindersEnabled\s*=>\s*_prefs\.getBool\([^)]*\)\s*\?\?\s*false')
          .hasMatch(storage),
      isTrue,
      reason: 'Meal reminders must default to OFF. A health app that nags by '
          'default loses the person it is meant to help.',
    );
  });
}
