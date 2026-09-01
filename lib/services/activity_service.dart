import 'dart:async';

import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';

import '../models/exercise_entry.dart';
import 'storage_service.dart';

export '../models/exercise_entry.dart';

enum StepsSource { healthConnect, sensor, manual }

/// 3-tier step tracking — the same model popular apps use:
///  1. Health Connect (Android) — authoritative if granted
///  2. Phone sensor (Android step-counter / Apple CMPedometer) — no install
///  3. Manual entry — user adds steps when neither is available
class ActivityService {
  final StorageService storage;

  ActivityService(this.storage);

  final Health _health = Health();
  StreamSubscription<StepCount>? _sensorSub;
  int? _sensorBaseline;
  StepsSource _source = StepsSource.manual;
  bool _initialized = false;
  bool _healthReady = false;

  final _changes = StreamController<int>.broadcast();

  /// Fires with the new today-step total whenever it changes.
  Stream<int> get changes => _changes.stream;

  StepsSource get source => _source;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _health.configure();
      final ok = await _health.requestAuthorization([HealthDataType.STEPS]);
      if (ok) {
        _healthReady = true;
        _source = StepsSource.healthConnect;
        await _refreshFromHealth();
        return;
      }
    } catch (_) {
      // Not available (iOS without HealthKit entitlement, or Health Connect
      // not installed / user declined) — fall back to the sensor.
    }
    _startSensor();
  }

  /// Pull the latest count into storage (called on Home open and on resume).
  Future<void> refresh() async {
    if (!_initialized) await init();
    if (_healthReady) {
      await _refreshFromHealth();
    } else {
      // Sensor path: any pending deltas have already been persisted by the
      // stream — nothing extra to pull.
      final today = storage.getStepsFor(DateTime.now());
      if (_changes.hasListener) _changes.add(today);
    }
  }

  Future<void> _refreshFromHealth() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(start, now);
      final total = steps ?? 0;
      await storage.setStepsFor(now, total);
      if (_changes.hasListener) _changes.add(total);
    } catch (_) {
      // Health read hiccup — keep last known value.
    }
  }

  void _startSensor() {
    try {
      _sensorSub = Pedometer.stepCountStream.listen(
        (stepCount) {
          final v = stepCount.steps;
          if (_sensorBaseline == null) {
            // First reading after app start/app launch: baseline only.
            _sensorBaseline = v;
            return;
          }
          final delta = v - _sensorBaseline!;
          if (delta < 0) {
            // Phone rebooted — counter reset. Re-baseline, count nothing.
            _sensorBaseline = v;
            return;
          }
          if (delta == 0) return;
          _sensorBaseline = v;
          final now = DateTime.now();
          storage.addStepsFor(now, delta);
          final today = storage.getStepsFor(now);
          if (_changes.hasListener) _changes.add(today);
        },
        onError: (_) => _source = StepsSource.manual,
      );
      _source = StepsSource.sensor;
    } catch (_) {
      _source = StepsSource.manual;
    }
  }

  /// Manual entry: user-typed steps (last-resort source).
  Future<void> addManualSteps(int steps) async {
    if (steps <= 0) return;
    if (_source == StepsSource.healthConnect) {
      // Health Connect is live: manual additions are not merged because the
      // health source is authoritative and would be overwritten.
      return;
    }
    final now = DateTime.now();
    await storage.addStepsFor(now, steps);
    final today = storage.getStepsFor(now);
    if (_changes.hasListener) _changes.add(today);
  }

  Future<int> todaySteps() async => storage.getStepsFor(DateTime.now());

  // ---- Exercise ----

  List<ExerciseEntry> todayExercises() {
    final now = DateTime.now();
    return storage.exercises.where((e) => e.isOn(now)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  int todayExerciseCalories() {
    final weight = storage.profile?.weightKg ?? 70.0;
    return todayExercises().fold(
        0, (sum, e) => sum + e.calories);
  }

  Future<ExerciseEntry> logExercise(String name, int minutes) async {
    final weight = storage.profile?.weightKg ?? 70.0;
    final met = _metFor(name);
    final kcal = (met * weight * (minutes / 60)).round();
    final entry = ExerciseEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      name: name,
      minutes: minutes,
      calories: kcal,
    );
    await storage.addExercise(entry);
    return entry;
  }

  Future<void> deleteExercise(String id) => storage.deleteExercise(id);

  static const List<({String name, String emoji, double met})> activities = [
    (name: 'Walking', emoji: '🚶', met: 3.5),
    (name: 'Brisk walk', emoji: '🏃', met: 4.5),
    (name: 'Running', emoji: '🏃‍♂️', met: 9.0),
    (name: 'Cycling', emoji: '🚴', met: 6.8),
    (name: 'Gym / weights', emoji: '🏋️', met: 6.0),
    (name: 'Yoga', emoji: '🧘', met: 2.5),
    (name: 'Badminton', emoji: '🏸', met: 5.5),
    (name: 'Cricket', emoji: '🏏', met: 5.5),
    (name: 'Dance', emoji: '💃', met: 5.0),
    (name: 'Swimming', emoji: '🏊', met: 8.0),
    (name: 'Skipping', emoji: '🪢', met: 11.0),
  ];

  static double _metFor(String name) {
    for (final a in activities) {
      if (a.name == name) return a.met;
    }
    return 5.0; // moderate default
  }

  /// Human-readable source label for the UI.
  String get sourceLabel {
    switch (_source) {
      case StepsSource.healthConnect:
        return 'Health Connect';
      case StepsSource.sensor:
        return 'Sensor';
      case StepsSource.manual:
        return 'Manual';
    }
  }

  void dispose() {
    _sensorSub?.cancel();
    _changes.close();
  }
}
