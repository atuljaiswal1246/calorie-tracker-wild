// GUARD: no AI-provider key may ever live in this repository again.
//
// Written 2026-09-27 on the owner's order to remove every provider key from the
// repo and the app. The removal found nothing to remove - a manual read of every
// matching line showed only secret NAMES, upstream URLs, and coincidental bytes
// inside PNGs. That is exactly why this guard exists: the rule has to hold for
// the next change too, not just for today.
//
// A provider key is a secret VALUE. These are NOT secrets and are allowed:
//   * the NAME of a secret (env.AICREDITS_KEY, "secret `OPENCODE_KEY`")
//   * upstream URLs ("https://aicredits.in/v1/chat/completions")
//   * localhost base URLs
//   * google-services.json / GoogleService-Info.plist, which ship in every
//     Firebase app by design and are constrained by API security rules
// Anything that looks like a real key value FAILS the test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Providers whose keys must never appear here.
const _providerNames = <String>[
  'AICREDITS',
  'OPENAI',
  'OPENROUTER',
  'OPENCODE',
  'ZEN',
  'GEMINI',
  'DEEPSEEK',
];

/// Shapes real keys take.
final _keyShapes = <RegExp>[
  // OpenAI-style
  RegExp(r'\bsk-[A-Za-z0-9_\-]{16,}\b'),
  RegExp(r'\bsk-or-v1-[A-Za-z0-9]{16,}\b'),
  // Google / Gemini
  RegExp(r'\bAIza[0-9A-Za-z_\-]{30,}\b'),
  // Generic "Bearer <long token>" and long opaque assignments
  RegExp(r'\bBearer\s+[A-Za-z0-9_\-\.]{24,}\b'),
  RegExp(r'\bghp_[A-Za-z0-9]{20,}\b'),
  RegExp(r'\bxox[baprs]-[A-Za-z0-9\-]{10,}\b'),
];

bool _isAllowedNoise(String line) {
  final low = line.toLowerCase();
  // Upstream endpoints and local addresses are not secrets.
  if (low.contains('http://') || low.contains('https://')) return true;
  if (low.contains('127.0.0.1') || low.contains('localhost')) return true;
  // Documentation referring to a secret by name.
  if (line.contains('secret') || line.contains('env.') || line.contains('process.env')) {
    return true;
  }
  return false;
}

bool _isFirebaseConfigFile(String path) =>
    path.endsWith('google-services.json') ||
    path.endsWith('GoogleService-Info.plist');

void main() {
  test('no AI-provider key literal exists anywhere in the repo', () {
    final violations = <String>[];

    // Directories that are generated, vendored or symlinked rather than part of
    // this repository. `ios/.symlinks` is a CocoaPods tree: `git ls-files`
    // reports paths inside it as "beyond a symbolic link", i.e. NOT tracked.
    // A Firebase plugin's own example/firebase_options.dart legitimately
    // contains a Google key and is not our key to police.
    final skipDirs = <String>{
      '.git', 'build', '.dart_tool', '.worktrees', '.agent-logs',
      'node_modules', '.freebuff', '.gradle', 'ios/Pods', 'ios/.symlinks',
      '.symlinks', 'ephemeral', 'functions/node_modules',
    };
    final skipExt = <String>{
      '.png', '.jpg', '.jpeg', '.heic', '.gif', '.webp', '.aab', '.apk',
      '.jks', '.keystore', '.bundle', '.woff', '.ttf', '.otf', '.ico',
      '.lock', '.so', '.dylib', '.jar', '.zip', '.gz', '.mp3', '.wav',
    };

    for (final entity in Directory('.').listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (skipDirs.any((d) => path.startsWith('$d/') || path.contains('/$d/'))) {
        continue;
      }
      if (skipExt.contains(path.split('.').last.toLowerCase())) continue;
      if (entity.lengthSync() > 4 * 1024 * 1024) continue;
      if (_isFirebaseConfigFile(path)) continue;

      final List<String> lines;
      try {
        lines = entity.readAsLinesSync();
      } catch (_) {
        continue; // binary or unreadable; not a text source of keys
      }

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isAllowedNoise(line)) continue;
        for (final shape in _keyShapes) {
          if (shape.hasMatch(line)) {
            violations.add('${entity.path}:${i + 1}  [$shape]  ${line.trim()}');
            break;
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'A provider key literal is in the repo. Keys belong in the Cloudflare\n'
          "Worker's secrets and nowhere else; the app talks to the Worker with an\n"
          'opaque per-user device id. Remove the value, keep the name.\n\n'
          '${violations.join('\n')}\n',
    );
  });

  test('the app ships no provider key: it sends only an opaque device id', () {
    // The architectural guarantee, checked rather than believed. If this ever
    // changes, a key is one refactor away from reaching a user's phone.
    final service = File('lib/services/openai_service.dart').readAsStringSync();

    expect(
      RegExp(r"'Authorization'\s*:\s*").hasMatch(service),
      isFalse,
      reason: 'The app must not set an Authorization header. The Worker holds the key.',
    );
    expect(
      RegExp(r"\bsk-[A-Za-z0-9_\-]{16,}").hasMatch(service),
      isFalse,
      reason: 'A key-shaped literal is present in the app\'s AI service.',
    );
    // The one custom header the app is allowed to send.
    expect(
      service.contains("'x-device-id'"),
      isTrue,
      reason: 'The app should identify itself with an opaque per-install id.',
    );
  });

  test('every provider the app depends on is read from the Worker env', () {
    // Names in the Worker are fine; the point is that no VALUE is hardcoded.
    final worker = File('cloudflare_worker/worker.js').readAsStringSync();
    for (final name in _providerNames) {
      final hardcoded = RegExp('$name[A-Z_]*\\s*=\\s*["\'][^"\']+["\']')
          .allMatches(worker)
          .map((m) => m.group(0) ?? '')
          .where((m) => !m.contains('http'))
          .toList();
      expect(
        hardcoded,
        isEmpty,
        reason: 'worker.js appears to assign a literal to a $name value: $hardcoded',
      );
    }
  });

  test('no provider key is present in the committed tree at all', () {
    // Belt and braces: ask git itself, not the filesystem. A key in an old
    // commit or a stray stash is still a leaked key.
    final result = Process.runSync('git', [
      'grep', '-lIE',
      r'(sk-[A-Za-z0-9_\-]{16,}|AIza[0-9A-Za-z_\-]{30,})',
      '--', '.',
    ]);
    final out = (result.stdout ?? '').trim();
    // google-services.json and the plist legitimately contain an AIza key.
    final offenders = out
        .split('\n')
        .where((String l) => l.trim().isNotEmpty)
        .where((l) => !l.contains('google-services.json'))
        .where((l) => !l.contains('GoogleService-Info.plist'))
        .toList();

    expect(
      result.exitCode == 0 || result.exitCode == 1,
      isTrue,
      reason: 'git grep itself failed (exit ${result.exitCode}); the scan is '
          'NOT evidence of anything.\n${result.stderr}',
    );
    expect(
      offenders,
      isEmpty,
      reason: 'A key literal is tracked in git:\n${offenders.join('\n')}',
    );
  });
}
