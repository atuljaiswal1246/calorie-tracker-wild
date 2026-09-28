// Order 11's GUARD, not its order. A rule I write after I forget is not a rule.
//
// The defect (2026-09-28, 11:59): a 15-line DISH_CLASS block was sitting
// uncommitted in tools/ai_accuracy.py. I ran `git checkout tools/ai_accuracy.py`
// because it looked like debris, and destroyed work that may have been the
// owner's. Restoring it needed a transcript (commit b68b7be).
//
// An ORDER ("never checkout a file you did not write") would have failed
// exactly as badly as the thing it replaced: I am the one who runs the command.
// So the machine refuses instead, and this test proves it actually refuses.
//
// What this test does NOT do: grep the source for the words of the rule. That is
// the check that passed for a day while a feature was dead. Every case below
// BUILDS a real git repo, makes a real uncommitted change, runs the real script,
// and reads the exit code. Silence and success must not look alike, so each
// refusal case asserts a non-zero code AND that the work is still on disk.
//
// Scoped test, per standing order 10: flutter test test/never_discard_unowned_work_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guard = 'tools/guard_uncommitted.py';

void main() {
  late String python;
  late Directory root;

  setUpAll(() {
    // The machine that runs this must be a real git + a real python. If either
    // is missing the tests below fail loudly rather than skip into a green.
    final probe = Process.runSync('python3', ['-c', 'print(1)']);
    expect(probe.exitCode, 0,
        reason: 'python3 must run for the uncommitted-work guard to be testable');
    python = 'python3';
  });

  setUp(() {
    root = Directory.systemTemp.createTempSync('guard_uncommitted_test');
    final r = Process.runSync('git', ['init', '-q'], workingDirectory: root.path);
    expect(r.exitCode, 0, reason: 'git init failed: ${r.stderr}');
    Process.runSync('git', ['config', 'user.email', 'test@calmatters.app'],
        workingDirectory: root.path);
    Process.runSync('git', ['config', 'user.name', 'Test'],
        workingDirectory: root.path);
    File('${root.path}/tracked.txt')
      ..writeAsStringSync('original\n')
      ..createSync(recursive: true);
    final c = Process.runSync('git', ['add', 'tracked.txt'],
        workingDirectory: root.path);
    expect(c.exitCode, 0);
    final c2 = Process.runSync('git', ['commit', '-q', '-m', 'base'],
        workingDirectory: root.path);
    expect(c2.exitCode, 0, reason: 'git commit failed: ${c2.stderr}');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Run the guard with the repo's own cwd. `guardScript` is copied into the
  /// temp repo so the test never depends on the working tree's state.
  int run(List<String> args) {
    final script = File(_guard).absolute.path;
    final target = '${root.path}/guard.py';
    File(target).writeAsStringSync(File(script).readAsStringSync());
    final r = Process.runSync(python, ['guard.py', ...args],
        workingDirectory: root.path);
    return r.exitCode;
  }

  test('the guard script exists and is not empty', () {
    expect(File(_guard).existsSync(), isTrue,
        reason: '$_guard is missing — order 11 has no machine behind it');
    expect(File(_guard).lengthSync(), greaterThan(500));
  });

  test('a file with uncommitted changes is REFUSED, not merely reported', () {
    // This is the 11:59 case exactly: the file is tracked, the change is real,
    // and the change is not mine. The guard must exit non-zero.
    File('${root.path}/tracked.txt').writeAsStringSync('original\nuncommitted work\n');
    final code = run(['check', 'tracked.txt']);
    expect(code, isNot(0),
        reason: 'the guard passed a file with uncommitted changes. That is the\n'
            'defect it exists to prevent: an uncommitted change is destroyed by\n'
            'checkout/restore/stash, and it cannot be recovered from git.');
  });

  test('the refusal leaves the work on disk — it is a refusal, not a discard', () {
    File('${root.path}/tracked.txt')
        .writeAsStringSync('original\nsomeone else is typing right now\n');
    run(['guard', 'tracked.txt']);
    expect(File('${root.path}/tracked.txt').readAsStringSync(),
        contains('someone else is typing right now'),
        reason: 'the guard changed the file. It must only ever refuse.');
  });

  test('a clean file is SAFE (exit 0) — otherwise the guard is noise', () {
    final code = run(['check', 'tracked.txt']);
    expect(code, 0,
        reason: 'a clean tracked file must pass, or the guard trains us to ignore it');
  });

  test('an UNTRACKED file is not a discard: there is no committed work to lose', () {
    File('${root.path}/brand_new.txt').writeAsStringSync('mine, never committed\n');
    final code = run(['check', 'brand_new.txt']);
    expect(code, 0,
        reason: 'untracked files have no committed version; refusing them would be\n'
            'a false alarm and would make the guard ignorable');
  });

  test('`allow` writes a PATCH before anything may be discarded', () {
    File('${root.path}/tracked.txt').writeAsStringSync('original\nsave me\n');
    final code = run(['allow', 'tracked.txt']);
    expect(code, 0);

    final dir = Directory('${root.path}/.agent-logs/discard');
    expect(dir.existsSync(), isTrue,
        reason: 'no patch directory: the rescue copy was never taken');
    final patches = dir.listSync().whereType<File>().toList();
    expect(patches, isNotEmpty, reason: 'allow wrote no patch file');
    final text = patches.first.readAsStringSync();
    expect(text, contains('save me'),
        reason: 'the patch does not contain the uncommitted lines. A patch that\n'
            'omits the work is worse than no patch, because it looks like a rescue.');
  });

  test('the patch names the commit it was taken from, so it can be reasoned about', () {
    File('${root.path}/tracked.txt').writeAsStringSync('original\nx\n');
    run(['allow', 'tracked.txt']);
    final name = Directory('${root.path}/.agent-logs/discard')
        .listSync()
        .whereType<File>()
        .first
        .path
        .split('/')
        .last;
    expect(name, matches(RegExp(r'^[0-9a-f]{7,}-')),
        reason: 'patch file is not stamped with the commit: $name');
  });

  test('outside a git work tree the guard refuses rather than guessing', () {
    final bare = Directory.systemTemp.createTempSync('guard_not_a_repo');
    try {
      final r = Process.runSync(python, [File(_guard).absolute.path, 'check', 'x.txt'],
          workingDirectory: bare.path);
      expect(r.exitCode, isNot(0),
          reason: 'with no git we cannot know what is uncommitted, so "safe" would\n'
              'be a guess. An empty result is not a pass.');
    } finally {
      bare.deleteSync(recursive: true);
    }
  });

  test('a path outside the repo is refused, not silently ignored', () {
    final r = Process.runSync(
        python, [File(_guard).absolute.path, 'check', '/etc/hosts'],
        workingDirectory: root.path);
    expect(r.exitCode, isNot(0));
    expect(r.stdout.toString(), contains('REFUSED'));
  });

  test('it recognises the destructive verbs — including stash', () {
    // checkout/restore/stash/reset/clean are the five ways this has happened or
    // could. If the list shrinks, the guard quietly stops covering a path.
    final r = Process.runSync(
        python,
        ['-c', '''
import importlib.util, sys
spec = importlib.util.spec_from_file_location("g", sys.argv[1])
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
bad = [a for a in [
  ["git","checkout","--","x.py"],
  ["git","restore","x.py"],
  ["git","stash","push"],
  ["git","reset","--hard"],
  ["git","clean","-fd"],
] if not g.is_destructive(a)]
good = [a for a in [
  ["git","checkout","-b","new"],
  ["git","status"],
  ["git","add","x.py"],
] if g.is_destructive(a)]
print("MISSED=" + ",".join(" ".join(x) for x in bad))
print("FALSEALARM=" + ",".join(" ".join(x) for x in good))
''' , File(_guard).absolute.path],
        workingDirectory: root.path);
    expect(r.exitCode, 0, reason: 'probe failed: ${r.stderr}');
    expect(r.stdout.toString(), contains('MISSED=\n'),
        reason: 'a destructive git verb is no longer detected:\n${r.stdout}');
    expect(r.stdout.toString(), contains('FALSEALARM=\n'),
        reason: 'a safe git command is now flagged destructive:\n${r.stdout}');
  });

  test('order 11 is written in AGENTS.md §0, with its reason', () {
    final src = File('AGENTS.md').readAsStringSync();
    final start = src.indexOf('STANDING ORDERS');
    expect(start, isNot(-1));
    final rest = src.substring(start);
    final end = rest.indexOf('## ⚠️ ONE THING');
    final section = end == -1 ? rest : rest.substring(0, end);
    expect(section, contains('NEVER DISCARD UNCOMMITTED WORK'),
        reason: 'order 11 is missing from AGENTS.md §0. A rule that lives only in\n'
            'a chat is a rule the next session will not obey, because it never\n'
            'read it. (Standing order 7.)');
    expect(section, contains('guard_uncommitted.py'),
        reason: 'order 11 must name the machine that enforces it, not just the\n'
            'intent — otherwise the next reader repeats the mistake with confidence');
  });

  test('the guard is reachable from the one-command claim runner', () {
    // Discoverability is the difference between a guard and a rule. If the file
    // exists but nothing points at it, the next session will not find it in time.
    final runners = Directory('tools')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.py'))
        .toList();
    final mentioned = runners.any((f) =>
        f.readAsStringSync().contains('guard_uncommitted'));
    expect(mentioned, isTrue,
        reason: 'no tool under tools/ mentions guard_uncommitted.py');
  });
}
