// Every case must have its photo ON DISK, and the photo must be the one the
// manifest recorded.
//
// Found 2026-09-28, by checking rather than assuming. I added 5 cases from a
// second fetch run and shipped a corpus where THREE of them pointed at files
// that were not on disk. The cause was in my own fetcher: the download path is a
// digest of the source URL, so re-fetching a photo we already had wrote the same
// path, and the near-duplicate branch - which deletes a file to keep the repo
// small - removed the file the manifest pointed at. Deleting is the dangerous
// half of a duplicate check.
//
// This is the THIRD integrity fault in that one script (filename collisions, a
// mis-stated truth, and now this), and all three were found by a check, never by
// the script being careful. So the check is the deliverable, not the fix.
//
// A case whose photo is missing is not a small problem: the harness scores the
// image, so a missing file either fails the run or, worse, is quietly skipped
// and the corpus count stays flattering while the evidence is gone.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> corpus;
  late Map<String, dynamic> manifest;
  late List<dynamic> cases;
  late List<dynamic> photos;

  setUpAll(() {
    corpus = json.decode(
        File('tools/ai_accuracy/cases.json').readAsStringSync()) as Map<String, dynamic>;
    manifest = json.decode(
        File('tools/ai_accuracy/photos.json').readAsStringSync()) as Map<String, dynamic>;
    cases = corpus['cases'] as List<dynamic>;
    photos = manifest['photos'] as List<dynamic>;
  });

  test('every case points at a photo that exists on disk', () {
    // OWNERHIP: existence is asserted HERE and nowhere else. A python module briefly
    // asserted it too (tools/ai_accuracy/test_the_corpus_photographs_are_distinct.py);
    // that was removed on 2026-09-28 because two owners for one check is how they
    // drift. That module now owns only what is NOT here: undecodable/zero-byte,
    // byte-identical duplicates, perceptual duplicates, and the reported margin.
    final missing = <String>[];
    final empty = <String>[];
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final image = c['image'] as String;
      final f = File(image);
      if (!f.existsSync()) {
        missing.add('${c['id']} -> $image');
      } else if (f.lengthSync() == 0) {
        // A truncated download, or a file emptied by a bad merge. existsSync is
        // TRUE for both, so before this line a zero-byte photograph passed this
        // guard and the corpus counted it as evidence.
        empty.add('${c['id']} -> $image (0 bytes)');
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'A case in the corpus has no photo on disk. The harness scores an '
          'IMAGE, so this case cannot be measured - it is decoration in a file '
          'that is supposed to be evidence.\n\n'
          'The cause on 2026-09-28 was fetch_commons.py re-downloading a photo '
          'to the same URL-digest path and the near-duplicate branch then '
          'deleting the file the manifest pointed at.\n\n'
          '${missing.join('\n')}\n',
    );
    expect(
      empty,
      isEmpty,
      reason: 'A case points at a ZERO-BYTE file. It exists, so the check above '
          'passes it, and it is not a photograph of anything - the scorer gets '
          'nothing and the corpus count stays flattering.\n\n'
          '${empty.join('\n')}\n',
    );
  });

  test('every case has a manifest record, with licence, author and hash', () {
    final byFile = <String, Map<String, dynamic>>{};
    for (final raw in photos) {
      final p = raw as Map<String, dynamic>;
      byFile[p['file'] as String] = p;
    }
    final bad = <String>[];
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final p = byFile[c['image']];
      if (p == null) {
        bad.add('${c['id']}: no photos.json record');
        continue;
      }
      if (p['origin'] == 'in-repo') {
        // A DECLARED in-repo original: our own file, so there is no third-party
        // author or licence to attribute. The declaration is what matters - an
        // undeclared exception is indistinguishable from a missing record.
        if (p['sha256'] == null) {
          bad.add('${c['id']}: declared in-repo but has no sha256');
        }
        continue;
      }
      for (final field in const ['author', 'licence', 'licence_url', 'sha256']) {
        final v = p[field];
        if (v == null || (v is String && v.trim().isEmpty)) {
          bad.add('${c['id']}: photos.json record has no $field');
        }
      }
      if (p['reviewed'] != true) {
        bad.add('${c['id']}: the photo is marked not-reviewed, so nobody looked '
            'at it. An unseen photo is not evidence.');
      }
    }
    expect(bad, isEmpty,
        reason: 'A case is missing provenance. Unattributed or unseen photos '
            'must not enter the corpus.\n\n${bad.join('\n')}\n');
  });

  test('a rejected photo is kept in the manifest with its reason, and removed '
      'from disk', () {
    // Rejections are part of the record: the next batch must not re-propose them,
    // and a future session must be able to see WHY something was turned down.
    final bad = <String>[];
    for (final raw in photos) {
      final p = raw as Map<String, dynamic>;
      if (p['rejected'] != true) continue;
      final reason = p['reject_reason'];
      if (reason == null || (reason is String && reason.trim().isEmpty)) {
        bad.add('${p['file']}: rejected with no reason');
      }
      if (File(p['file'] as String).existsSync()) {
        bad.add('${p['file']}: rejected but still on disk, wasting repo size');
      }
    }
    expect(bad, isEmpty,
        reason: 'A rejection must carry its reason and free its file.\n'
            '${bad.join('\n')}');
  });

  test('no photo is left undecided', () {
    // 14 photos sat in the manifest fetched-but-never-reviewed, and an undecided
    // photo is indistinguishable from an accepted one. A photo is now either used
    // by a case, rejected with a reason, or DECLARED not-used with a reason.
    // Deleting the limbo silently would have been the same mistake in reverse:
    // the next batch would re-propose them with no memory of why.
    final used = cases
        .map((raw) => (raw as Map<String, dynamic>)['image'] as String)
        .toSet();
    final limbo = <String>[];
    for (final raw in photos) {
      final p = raw as Map<String, dynamic>;
      final file = p['file'] as String;
      if (used.contains(file)) continue;
      if (p['rejected'] == true || p['not_used'] == true) {
        final reason = (p['reject_reason'] ?? p['not_used_reason']) as String?;
        if (reason == null || reason.trim().isEmpty) {
          limbo.add('$file: set aside with no reason');
        }
        continue;
      }
      limbo.add('$file: fetched, never accepted, never rejected, never declared '
          'not-used. An undecided photo is not evidence and not a decision.');
    }
    expect(limbo, isEmpty,
        reason: 'Every manifest photo must be used, rejected with a reason, or '
            'declared not-used with a reason.\n\n${limbo.join('\n')}\n');
  });

  test('the fetcher cannot delete a file a record depends on', () {
    // The exact line that caused three cases to point at nothing. If this ever
    // goes back to an unconditional os.remove, the next batch is a broken corpus.
    final src = File('tools/ai_accuracy/fetch_commons.py').readAsStringSync();
    final removeAt = src.indexOf('os.remove(os.path.join(ROOT, got["file"]))');
    expect(removeAt, isNot(-1),
        reason: 'The near-duplicate branch no longer deletes at all. That is '
            'safer than it sounds, but it means duplicates stay on disk - check '
            'what the branch does now and update this test to match reality.');
    final window = src.substring(maxOf(0, removeAt - 700), removeAt);
    expect(
      window.contains('not any(') && window.contains('p.get("file") == got["file"]'),
      isTrue,
      reason: 'The delete is unconditional again. It must first confirm that no '
          'manifest record points at the file, or a re-fetch will delete the '
          'photo the manifest depends on.',
    );
    expect(
      src.contains('p.get("title") == cand["title"]'),
      isTrue,
      reason: 'Dedupe must compare TITLES. Comparing a file path to a title '
          'never matches, which is how the same URL was downloaded twice.',
    );
  });

  test('every case id is unique and every case has a truth', () {
    final seen = <String, int>{};
    final bad = <String>[];
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final id = c['id'] as String;
      seen[id] = (seen[id] ?? 0) + 1;
      final truth = c['truth'];
      if (truth is! List || truth.isEmpty) {
        bad.add('$id: no truth. An unlabelled case cannot be scored.');
      }
    }
    final dupes = seen.entries.where((e) => e.value > 1).map((e) => e.key);
    expect(dupes, isEmpty,
        reason: 'Duplicate case ids mean one case is silently measured twice.\n'
            '${dupes.join('\n')}');
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}

int maxOf(int a, int b) => a > b ? a : b;
