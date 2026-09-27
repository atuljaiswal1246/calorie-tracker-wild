// GUARD: one key, and only through the Worker.
//
// The owner's order (2026-09-27): every model call in this company goes through
// the Cloudflare Worker, and the key lives in the Worker's secrets and nowhere
// else. This test makes both halves mechanical rather than a habit.
//
// It also pins the thing that was nearly forgotten: the Worker must REPORT which
// key it used, on every request and in /health. A paid fallback that leaves no
// trace is how a budget disappears quietly.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _endpoint =
    'https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev';

void main() {
  test('the app never talks to a provider directly - only to the Worker', () {
    final offenders = <String>[];
    final skipDirs = <String>{'.git', 'build', '.dart_tool', '.worktrees'};
    final skipExt = <String>{'.png', '.jpg', '.jpeg', '.aab', '.apk', '.lock'};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (skipExt.contains(entity.path.split('.').last)) continue;
      final src = entity.readAsStringSync();
      for (final host in const [
        'aicredits.in',
        'openrouter.ai',
        'opencode.ai',
        'generativelanguage.googleapis.com',
        'api.openai.com',
      ]) {
        if (src.contains(host)) {
          offenders.add('${entity.path}: references $host directly');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The app must reach a model only through the Worker, which holds the\n'
          'key. A direct provider call from a user device puts a billable key in\n'
          'the hands of anyone who unzips the APK.\n\n'
          '${offenders.join('\n')}\n',
    );
  });

  test('the only model endpoint in the app is the Worker', () {
    final service = File('lib/services/openai_service.dart').readAsStringSync();
    expect(
      service.contains(_endpoint),
      isTrue,
      reason: 'The app should send model calls to our Worker.',
    );
    expect(
      RegExp(r"'Authorization'\s*:").hasMatch(service),
      isFalse,
      reason: 'The app must not send an Authorization header; it has no key.',
    );
  });

  test('the Worker reports which key answered, and what it cost', () async {
    // Live check against the deployed Worker. If this fails, paid spend is
    // happening invisibly, which is the failure this whole design prevents.
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse(_endpoint));
      req.headers.contentType = ContentType.json;
      req.write('{}');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();

      expect(res.statusCode, 200, reason: '/health must be readable: $body');
      final decoded = body;

      for (final field in const [
        '"secrets_configured"',
        '"breaker"',
        '"paid_usage"',
        '"requests_billed"',
        '"est_cost_usd_today"',
        '"last_billed_request"',
      ]) {
        expect(
          decoded.contains(field),
          isTrue,
          reason: '/health must expose $field so spend is never silent.\n$body',
        );
      }

      // A key VALUE must never appear in a public response.
      expect(
        RegExp(r'\bsk-[A-Za-z0-9_\-]{16,}').hasMatch(body),
        isFalse,
        reason: '/health leaked something key-shaped:\n$body',
      );
    } finally {
      client.close(force: true);
    }
  }, skip: 'network test - run with: flutter test --dart-define=RUN_NETWORK=1');
}
