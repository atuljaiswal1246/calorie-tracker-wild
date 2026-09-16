import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// The app's sound identity — one approve-able sound per kind of moment.
///
/// Files live in `assets/sounds/`. The notification sound has its own copy in
/// `android/app/src/main/res/raw/cal_notify.wav` because Android plays that one
/// from the notification channel, not from Flutter.
///
/// Sound is best-effort: a device with no audio, a codec failure or a muted
/// stream must never break a logging flow.
class SoundService {
  SoundService._();

  static StorageService? _storage;

  /// Called once from main().
  static void init(StorageService storage) => _storage = storage;

  static bool get enabled => _storage?.soundsEnabled ?? true;

  // One player per sound, kept warm: creating a player per play adds audible
  // latency to a 0.18s tick.
  static final _pip = AudioPlayer(playerId: 'cal_pip');
  static final _success = AudioPlayer(playerId: 'cal_success');
  static bool _warmed = false;

  static Future<void> _warm() async {
    if (_warmed) return;
    _warmed = true;
    for (final p in [_pip, _success]) {
      try {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }
  }

  /// Small confirmation: a meal logged, a glass of water added.
  static Future<void> pip() => _play(_pip, 'sounds/cal_pip.wav');

  /// A moment worth marking: streak milestone, goal reached.
  static Future<void> success() => _play(_success, 'sounds/cal_success.wav');

  static Future<void> _play(AudioPlayer player, String asset) async {
    if (!enabled) return;
    try {
      await _warm();
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.6);
    } catch (e) {
      debugPrint('Sound failed ($asset): $e');
    }
  }
}
