import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// Friends + weekly leaderboard. Shares ONLY weekly kcal totals (privacy:
/// no meal details ever leave our own cloud doc). Codes = Firebase uid.
class SocialService {
  final StorageService storage;

  SocialService(this.storage);

  String? get myCode => storage.userId;

  String? get myName => storage.profile?.name;

  /// Friend uid -> validated cloud display name.
  Future<Map<String, dynamic>?> lookupUser(String code) async {
    final uid = code.trim();
    if (uid.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      final profile = data?['profile'] as Map<String, dynamic>?;
      return {
        'uid': uid,
        'name': (profile?['name'] as String?)?.trim() ??
            (profile?['name'] as String?) ??
            uid.substring(0, 8),
      };
    } catch (_) {
      return null;
    }
  }

  static const _friendLimit = 10;

  /// Weekly (Mon..now) total kcal for self + friends, sorted descending.
  /// Only the aggregate is shown — never individual meals.
  Future<List<({String uid, String name, int kcal})>> weeklyLeaderboard() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final entries = <({String uid, String name, int kcal})>[];

    final myKcal = storage.entries
        .where((e) => !e.dateTime.isBefore(monday))
        .fold(0, (s, e) => s + e.totalCalories);
    entries.add((uid: storage.userId ?? '', name: 'You', kcal: myKcal));

    // Friends (capped, sequential; failures skipped silently)
    var count = 0;
    for (final f in storage.friends) {
      if (count >= _friendLimit) break;
      count++;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(f.uid)
            .collection('entries')
            .get();
        var kcal = 0;
        for (final d in snapshot.docs) {
          final dt = DateTime.tryParse(d.data()['dateTime'] as String? ?? '');
          if (dt != null && !dt.isBefore(monday)) {
            final items = (d.data()['items'] as List?) ?? [];
            for (final i in items) {
              final m = i as Map<String, dynamic>;
              final qty = (m['quantity'] as num?)?.toDouble() ?? 1;
              kcal += (((m['calories'] as num?)?.toInt() ?? 0) * qty).round();
            }
          }
        }
        entries.add((uid: f.uid, name: f.name.isEmpty ? 'Friend' : f.name, kcal: kcal));
      } catch (_) {
        // Friend's cloud unavailable — skip this week.
      }
    }

    entries.sort((a, b) => b.kcal.compareTo(a.kcal));
    return entries;
  }
}
