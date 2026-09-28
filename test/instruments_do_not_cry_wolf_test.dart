// The two instruments that watch other roles must be able to be wrong SAFELY.
//
// WHY THIS FILE EXISTS. In one afternoon I wrote tools/watch_drift.py and
// tools/check_landings.py and BOTH were wrong, in the same direction: each
// reported a working role as broken.
//
//   check_landings, 14:08: "Research Lead NO HASH, Engineering Lead NO HASH".
//   Engineering Lead had landed 37d4f3c twenty minutes earlier and the repo took
//   eight commits after 13:45. The cause: `data` is newest-first and MOST TURNS
//   HAVE NO TEXT - a tool call, a read, a plan step - so it graded the newest
//   message, which was the empty string.
//
//   check_landings, 14:09: I "fixed" it by asking git instead of the role, and
//   got
//     Research Lead      LANDED 4179fd45
//     Engineering Lead   LANDED 4179fd45   <- the same commit, to two roles
//   because every role commits into ONE shared branch, so `git log --since`
//   counts the company, not the role. A shared history cannot attribute a commit
//   to an author unless the author says so.
//
// A monitor that cries wolf gets switched off. A monitor that credits the wrong
// role is worse than one that reports nothing. So both faults are pinned here as
// executable cases against the REAL script, not as prose in a commit message the
// next session will read and agree with.
//
// HERMETIC BY CONSTRUCTION. Everything runs in a TEMP git repo. The only thing
// stubbed is the tool's network read, by importing the real module and replacing
// that one function - so the verdict logic under test is the shipped logic, not
// a re-implementation of it. No test touches the other company's repo, and none
// sends a message to anyone's session: a test that posts real orders into a real
// company is not a test.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _landings = 'tools/check_landings.py';
const _drift = 'tools/watch_drift.py';

/// Imports the real tool with its constants pointed at a temp world, stubs only
/// `last_reply`, and runs its own `main`. An in-process HttpServer cannot make
/// progress under flutter_test's fake-async zone, so the network read is stubbed
/// rather than served.
const _driver = r'''
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("cl", sys.argv[1])
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)
turns = json.loads(sys.argv[2])
def fake_last_reply(sid, timeout=20.0):
    said = next((t["_text"] for t in turns if t.get("_text")), None)
    return said, 1790584000, "space-bunny-free"
cl.last_reply = fake_last_reply
sys.argv = ["check_landings.py"]
sys.exit(cl.main())
''';

void main() {
  late Directory root;
  late String otherRepo;

  setUp(() {
    root = Directory.systemTemp.createTempSync('instruments_test');
    otherRepo = '${root.path}/other';
    Directory(otherRepo).createSync(recursive: true);

    expect(
        Process.runSync('git', ['init', '-q', '-b', 'main'],
                workingDirectory: otherRepo)
            .exitCode,
        0);

    File('$otherRepo/a.txt').writeAsStringSync('one\n');
    Process.runSync('git', ['add', '-A'], workingDirectory: otherRepo);
    expect(Process.runSync('git', ['commit', '-q', '-m', 'base'],
            workingDirectory: otherRepo)
        .exitCode, 0);

    final state = File('${root.path}/drift_orders.json');
    state.writeAsStringSync(jsonEncode({
      'Research Lead': {'at': 1000000000, 'session': 'ses_r', 'order_id': 'm1'},
      'Engineering Lead': {'at': 1000000000, 'session': 'ses_e', 'order_id': 'm2'},
    }));

    for (final tool in [_landings, _drift]) {
      var src = File(tool).readAsStringSync();
      src = src
          .replaceAll('Path.home() / "Desktop" / "Jarvis"', "Path(r'$otherRepo')")
          .replaceAll('Path.home() / "Desktop" / "Jarvis";', "Path(r'$otherRepo');")
          .replaceAll(
              'STATE = Path(__file__).resolve().parent.parent / ".agent-logs" / "drift_orders.json"',
              "STATE = Path(r'${root.path}/drift_orders.json')")
          .replaceAll(
              'STATE = Path(__file__).resolve().parent.parent / ".agent-logs" / "drift_orders.json";',
              "STATE = Path(r'${root.path}/drift_orders.json');");
      File('${root.path}/${tool.split('/').last}').writeAsStringSync(src);
    }
    File('${root.path}/driver.py').writeAsStringSync(_driver);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Run the real check_landings with a canned conversation.
  String landings(List<String?> turns) {
    final payload = jsonEncode([
      for (final t in turns) {'_text': t}
    ]);
    final r = Process.runSync(
        'python3', ['${root.path}/driver.py', '${root.path}/check_landings.py', payload],
        workingDirectory: root.path);
    return '${r.stdout}${r.stderr}';
  }

  String commit(String msg) {
    File('$otherRepo/a.txt').writeAsStringSync('${msg.hashCode}\n');
    Process.runSync('git', ['add', '-A'], workingDirectory: otherRepo);
    expect(Process.runSync('git', ['commit', '-q', '-m', msg],
            workingDirectory: otherRepo)
        .exitCode, 0);
    return Process.runSync('git', ['rev-parse', '--short', 'HEAD'],
            workingDirectory: otherRepo)
        .stdout
        .trim();
  }

  test('a turn with NO text is not graded as "no hash" — the 14:08 false alarm',
      () {
    // The newest turns said nothing (tool calls). The answer is underneath them.
    // Grading the newest turn is what reported two working roles as broken.
    final h = commit('Research Lead: real work');
    final out = landings([null, null, null, 'LANDED $h — 3 files, scoped test ok']);
    expect(out, contains('LANDED'),
        reason: 'the reader graded an empty tool-call turn instead of the '
            'spoken answer underneath it:\n$out');
    expect(out, contains(h), reason: 'the real hash was not found:\n$out');
  });

  test('a hash that is not an object is still NOT A COMMIT', () {
    // The fix above must not have become "accept any hex token".
    final out = landings([null, 'done: 581620f']);
    expect(out, contains('NOT A COMMIT'),
        reason: 'a fabricated hash passed as a landing:\n$out');
    expect(out, contains('581620f'));
  });

  test('a shared repo must NOT let a commit be attributed to a role', () {
    // The 14:09 mistake. One branch, two roles, one commit. `git log --since`
    // would credit both roles with the same commit.
    commit('Toolsmith: work nobody attributed to a role');
    final out = landings(['I finished the plan and here is the reasoning']);
    expect(out, isNot(matches(RegExp(r'Research Lead\s+LANDED'))),
        reason: 'a role was credited with a commit it never named. In a shared '
            'repo that is not evidence of anything:\n$out');
    expect(out, contains('shared'),
        reason: 'the reason a commit cannot be attributed must be in the '
            'output, so a reader is not left guessing:\n$out');
  });

  test('a real commit named by the role is credited WITH git\'s own subject', () {
    final h = commit('Research Lead: the thing');
    final out = landings(['landed $h']);
    expect(out, contains('LANDED'));
    expect(out, contains('the thing'),
        reason: 'git\'s subject is the proof. A bare hash sends the reader off '
            'to look for it:\n$out');
  });

  test('a role that has said nothing at all is NOT VERIFIED, never a pass', () {
    // Standing order 4, in a file whose entire output is a verdict about people.
    final out = landings([null]);
    expect(out, isNot(contains('PASS')),
        reason: 'an unreadable/absent session was reported as a pass:\n$out');
  });

  test('both tools exist', () {
    for (final t in [_landings, _drift]) {
      expect(File(t).existsSync(), isTrue, reason: '$t is missing');
    }
  });

  test('neither tool may WRITE into the other company', () {
    // The boundary is a standing instruction, so it is executable rather than
    // a promise in a commit message. Read verbs are fine; write verbs are not.
    for (final tool in [_landings, _drift]) {
      final src = File(tool).readAsStringSync();
      for (final verb in ['commit', 'push', 'checkout', 'reset', 'clean']) {
        expect(RegExp('"git",[^\\]]*\\b"$verb"').hasMatch(src), isFalse,
            reason: '$tool appears to run `git $verb` in the other company. '
                'Read-only is the line.');
      }
      expect(
          src.contains('read-only') || src.contains('Read-only'), isTrue,
          reason: '$tool must state its read-only boundary in the file');
    }
  });

  test('the drift watcher can FAIL — a watch that cannot fail is a note', () {
    final src = File(_drift).readAsStringSync();
    expect(src, contains('return 1'),
        reason: 'the watcher must be able to exit non-zero on a drift');
    expect(src, contains('who_is_drifting.py'),
        reason: 'the watcher must name the instrument it reads');
  });

  test('an empty drifting list is calm ONLY if the instrument stamped a time', () {
    final src = File(_drift).readAsStringSync();
    expect(src, contains('checked_at'),
        reason: 'without the instrument\'s own stamp, an empty drifting list is '
            'indistinguishable from a read that never happened. The failure mode '
            'of a drift watch is reporting quiet.');
  });

  test('the orders carry the 800-line cap that every dispatch now carries', () {
    // It is in every doorbell, so it belongs in the order this tool composes.
    final src = File(_drift).readAsStringSync();
    expect(src, contains('800'),
        reason: 'the composed order must state the line cap, or a role is told '
            'to land something nobody can review');
    expect(src, contains('hash'),
        reason: 'the order must demand a hash, because a hash is the only '
            'attributable landing signal in a shared repo');
  });
}
