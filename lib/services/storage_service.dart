import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_measurement_entry.dart';
import '../models/food_entry.dart';
import '../models/exercise_entry.dart';
import '../models/gamification_state.dart';
import '../models/profile.dart';

/// EMail address that bypasses the paywall — SANDBOX ONLY (iOS dev builds).
/// Used because iOS has no Play Billing; without this the app is unusable on
/// the iPhone while testing.
String kSandboxEmail = 'atuljaiswal1246@gmail.com';

class WaterEntry {
  final DateTime date;
  final int ml;

  WaterEntry({required this.date, required this.ml});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'ml': ml,
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        date: DateTime.parse(json['date'] as String),
        ml: (json['ml'] as num).toInt(),
      );
}

class WeightEntry {
  final DateTime date;
  final double weightKg;

  WeightEntry({required this.date, required this.weightKg});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weightKg': weightKg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        date: DateTime.parse(json['date'] as String),
        weightKg: (json['weightKg'] as num).toDouble(),
      );
}

/// Real user activity the gamification layer reacts to. StorageService emits
/// these so every logging path earns rewards without touching each screen.
enum StorageActivity {
  mealLogged,
  mealScanned,
  waterLogged,
  weightLogged,
  exerciseLogged,
}

class StorageService {
  static const _profileKey = 'user_profile';
  static const _entriesKey = 'food_entries';
  static const _onboardingDraftKey = 'onboarding_draft';

  /// Version key for the payment state. Bumped when the payment model
  /// changes so stale flags (e.g. old test-stub "paid=true") are wiped.
  /// Only real Play purchases (BillingService) may set has_paid afterward.
  static const _paidVersionKey = 'paid_state_version';
  static const _paidVersion = 2;

  final SharedPreferences _prefs;
  String? _userId;

  /// Set by the gamification controller (GamificationController.init). Null in
  /// tests and before init, in which case logging behaves exactly as before.
  void Function(StorageActivity activity)? activityListener;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final svc = StorageService(prefs);
    await svc._migratePaymentState();
    return svc;
  }

  /// Wipe stale payment flags written by older builds (the old test stub
  /// set has_paid=true locally). Real purchases come from BillingService
  /// which writes the fresh flag AFTER this version check.
  Future<void> _migratePaymentState() async {
    final version = _prefs.getInt(_paidVersionKey) ?? 0;
    if (version < _paidVersion) {
      await _prefs.setBool(_paidKey, false);
      await _prefs.setInt(_paidVersionKey, _paidVersion);
    }
  }

  String? get userId => _userId;

  void setUserId(String? userId) {
    _userId = userId;
  }

  DocumentReference? _profileRef() {
    final uid = _userId;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  // ---- Profile ----

  Profile? get profile {
    final raw = _prefs.getString(_profileKey);
    if (raw == null) return null;
    return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveProfile(Profile profile) async {
    await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    final ref = _profileRef();
    if (ref != null) {
      await ref.set({'profile': profile.toJson()});
    }
  }

  Future<Profile?> loadProfileFromCloud() async {
    final ref = _profileRef();
    if (ref == null) return null;
    final doc = await ref.get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null || data['profile'] == null) return null;
    final profile = Profile.fromJson(
        (data['profile'] as Map).cast<String, dynamic>());
    await _prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    return profile;
  }

  /// Clears the profile (local + cloud) but KEEPS payment state so
  /// paid users never get re-prompted.
  Future<void> resetProfile() async {
    await _prefs.remove(_profileKey);
    final ref = _profileRef();
    if (ref != null) {
      try {
        await ref.update({'profile': FieldValue.delete()});
      } catch (_) {
        // Cloud not reachable — local clear is enough for the reset flow.
      }
    }
  }

  // ---- Onboarding draft (journey save at goal / sign-up / payment) ----

  /// Answers + step saved as the user moves through the questionnaire so
  /// a relaunch resumes exactly where they left off (goal page, sign-up
  /// screen or payment page) instead of restarting the journey.
  Map<String, dynamic>? get onboardingDraft {
    final raw = _prefs.getString(_onboardingDraftKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveOnboardingDraft(Map<String, dynamic> draft) async {
    await _prefs.setString(_onboardingDraftKey, jsonEncode(draft));
  }

  /// Removes the saved journey (called on completion / full reset).
  Future<void> clearOnboardingDraft() async {
    await _prefs.remove(_onboardingDraftKey);
  }

  // ---- Entries ----

  List<FoodEntry> get entries {
    final raw = _prefs.getString(_entriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => FoodEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  // ---- Steps (per day) ----

  String _stepsKey(DateTime day) =>
      'steps_${day.year}-${day.month}-${day.day}';

  int getStepsFor(DateTime day) {
    return _prefs.getInt(_stepsKey(day)) ?? 0;
  }

  Future<void> setStepsFor(DateTime day, int steps) async {
    await _prefs.setInt(_stepsKey(day), steps);
  }

  Future<void> addStepsFor(DateTime day, int steps) async {
    await _prefs.setInt(_stepsKey(day), getStepsFor(day) + steps);
  }

  /// Persisted sensor baseline (last see cumulative step-counter value) so
  /// steps taken while the app was closed are counted after re-launch.
  static const _sensorBaselineKey = 'sensor_step_baseline';

  int? get sensorBaseline => _prefs.getInt(_sensorBaselineKey);

  Future<void> setSensorBaseline(int value) async {
    await _prefs.setInt(_sensorBaselineKey, value);
  }

  // ---- Exercise logs ----

  static const _exerciseKey = 'exercise_logs';

  List<ExerciseEntry> get exercises {
    final raw = _prefs.getString(_exerciseKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> addExercise(ExerciseEntry entry) async {
    final all = [...exercises, entry];
    await _prefs.setString(_exerciseKey, jsonEncode(all.map((e) => e.toJson()).toList()));
    activityListener?.call(StorageActivity.exerciseLogged);
  }

  Future<void> deleteExercise(String id) async {
    final all = exercises.where((e) => e.id != id).toList();
    await _prefs.setString(_exerciseKey, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  // ---- Body measurements ----

  static const _bodyKitsKey = 'body_measurements';

  List<BodyMeasurementEntry> get bodyMeasurements {
    final raw = _prefs.getString(_bodyKitsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => BodyMeasurementEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addBodyMeasurement(BodyMeasurementEntry entry) async {
    final all = [...bodyMeasurements, entry];
    await _prefs.setString(
        _bodyKitsKey, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteBodyMeasurement(String id) async {
    final all = bodyMeasurements.where((e) => e.id != id).toList();
    await _prefs.setString(
        _bodyKitsKey, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  // ---- Weekly AI summary (cached per ISO week) ----

  /// Calendar week key (Monday-based) so the cache resets every week.
  static String weekKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  String? getWeeklySummary(String key) =>
      _prefs.getString('weekly_summary_$key');

  Future<void> saveWeeklySummary(String key, String text) async {
    await _prefs.setString('weekly_summary_$key', text);
  }

  // ---- Friends (social) ----

  static const _friendsKey = 'friends';

  List<({String uid, String name})> get friends {
    final raw = _prefs.getString(_friendsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return (uid: m['uid'] as String, name: m['name'] as String? ?? '');
        })
        .toList();
  }

  Future<void> addFriend(String uid, String name) async {
    final all = [...friends, (uid: uid, name: name)];
    await _prefs.setString(
        _friendsKey, jsonEncode(all.map((f) => {'uid': f.uid, 'name': f.name}).toList()));
  }

  Future<void> removeFriend(String uid) async {
    final all = friends.where((f) => f.uid != uid).toList();
    await _prefs.setString(
        _friendsKey, jsonEncode(all.map((f) => {'uid': f.uid, 'name': f.name}).toList()));
  }

  // ---- Profile photo ----

  static const _photoKey = 'profile_photo_path';

  String? get photoPath => _prefs.getString(_photoKey);

  Future<void> savePhotoPath(String path) async {
    await _prefs.setString(_photoKey, path);
  }

  // ---- Dark mode ----

  static const _darkModeKey = 'dark_mode';

  bool get darkMode => _prefs.getBool(_darkModeKey) ?? false;

  Future<void> saveDarkMode(bool value) async {
    await _prefs.setBool(_darkModeKey, value);
  }

  int get entryCount => entries.length;

  Future<void> addEntry(FoodEntry entry) async {
    final all = [...entries, entry];
    await _saveEntries(all);

    final ref = _profileRef();
    if (ref != null) {
      await ref.collection('entries').doc(entry.id).set(entry.toJson());
    }
    activityListener?.call(entry.imagePath.isNotEmpty
        ? StorageActivity.mealScanned
        : StorageActivity.mealLogged);
  }

  Future<void> deleteEntry(String id) async {
    final all = entries.where((e) => e.id != id).toList();
    await _saveEntries(all);

    final ref = _profileRef();
    if (ref != null) {
      await ref.collection('entries').doc(id).delete();
    }
  }

  Future<void> updateEntry(FoodEntry entry) async {
    final all = entries.map((e) => e.id == entry.id ? entry : e).toList();
    await _saveEntries(all);

    final ref = _profileRef();
    if (ref != null) {
      await ref.collection('entries').doc(entry.id).set(entry.toJson());
    }
  }

  Future<List<FoodEntry>> loadEntriesFromCloud() async {
    final ref = _profileRef();
    if (ref == null) return [];
    final snapshot = await ref.collection('entries').get();
    final cloud = snapshot.docs
        .map((d) => FoodEntry.fromJson(d.data()))
        .toList();
    await _prefs.setString(
      _entriesKey,
      jsonEncode(cloud.map((e) => e.toJson()).toList()),
    );
    return cloud;
  }

  Future<void> _saveEntries(List<FoodEntry> all) async {
    await _prefs.setString(
      _entriesKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  // ---- Weight Entries ----

  static const _weightEntriesKey = 'weight_entries';

  List<WeightEntry> get weightEntries {
    final raw = _prefs.getString(_weightEntriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => WeightEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> addWeightEntry(double weightKg) async {
    final all = [...weightEntries];
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Replace if already logged today
    final existingIdx = all.indexWhere((e) =>
        e.date.year == todayNormalized.year &&
        e.date.month == todayNormalized.month &&
        e.date.day == todayNormalized.day);
    if (existingIdx >= 0) {
      all[existingIdx] = WeightEntry(date: todayNormalized, weightKg: weightKg);
    } else {
      all.add(WeightEntry(date: todayNormalized, weightKg: weightKg));
    }
    all.sort((a, b) => a.date.compareTo(b.date));
    await _prefs.setString(
      _weightEntriesKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
    activityListener?.call(StorageActivity.weightLogged);
  }

  Future<void> deleteWeightEntry(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final all = weightEntries.where((e) =>
        !(e.date.year == normalized.year &&
          e.date.month == normalized.month &&
          e.date.day == normalized.day)).toList();
    await _prefs.setString(
      _weightEntriesKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  // ---- Water Entries ----

  static const _waterEntriesKey = 'water_entries';
  static const _waterGoalKey = 'water_goal_ml';
  static int defaultWaterGoalMl = 2500;

  int get waterGoalMl => _prefs.getInt(_waterGoalKey) ?? defaultWaterGoalMl;

  Future<void> saveWaterGoalMl(int ml) async {
    await _prefs.setInt(_waterGoalKey, ml);
  }

  List<WaterEntry> get waterEntries {
    final raw = _prefs.getString(_waterEntriesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  int waterMlForDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    return waterEntries
        .where((e) =>
            e.date.year == normalized.year &&
            e.date.month == normalized.month &&
            e.date.day == normalized.day)
        .fold(0, (sum, e) => sum + e.ml);
  }

  Future<void> addWater(int ml) async {
    final all = [...waterEntries];
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Check if there's already an entry today and merge
    final todayEntries = all.where((e) =>
        e.date.year == todayNormalized.year &&
        e.date.month == todayNormalized.month &&
        e.date.day == todayNormalized.day).toList();

    // Remove old entries for today
    all.removeWhere((e) =>
        e.date.year == todayNormalized.year &&
        e.date.month == todayNormalized.month &&
        e.date.day == todayNormalized.day);

    // Add merged entry
    final existingMl = todayEntries.fold(0, (sum, e) => sum + e.ml);
    all.add(WaterEntry(date: todayNormalized, ml: existingMl + ml));
    all.sort((a, b) => a.date.compareTo(b.date));
    await _prefs.setString(
      _waterEntriesKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
    if (waterMlForDay(todayNormalized) >= waterGoalMl) {
      activityListener?.call(StorageActivity.waterLogged);
    }
  }

  Future<void> undoLastWater() async {
    final all = [...waterEntries];
    if (all.isEmpty) return;

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    final todayEntries = all.where((e) =>
        e.date.year == todayNormalized.year &&
        e.date.month == todayNormalized.month &&
        e.date.day == todayNormalized.day).toList();

    if (todayEntries.isEmpty) return;

    all.removeWhere((e) =>
        e.date.year == todayNormalized.year &&
        e.date.month == todayNormalized.month &&
        e.date.day == todayNormalized.day);

    final totalMl = todayEntries.fold(0, (sum, e) => sum + e.ml);
    if (totalMl > 250) {
      all.add(WaterEntry(date: todayNormalized, ml: totalMl - 250));
    }
    all.sort((a, b) => a.date.compareTo(b.date));
    await _prefs.setString(
      _waterEntriesKey,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  // ---- Achievements ----

  static const _achievementsKey = 'unlocked_achievements';

  Map<String, dynamic>? getAchievementsRaw() {
    final raw = _prefs.getString(_achievementsKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> saveAchievements(Map<String, String> achievements) async {
    await _prefs.setString(_achievementsKey, jsonEncode(achievements));
  }

  // ---- Gamification (Cal Points, level, streak, NutriCoins) ----

  static const _gamificationKey = 'gamification_state';

  /// The persisted gamification state (a fresh one if never written).
  GamificationState get gamification {
    final raw = _prefs.getString(_gamificationKey);
    if (raw == null) return GamificationState();
    return GamificationState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Persist the gamification state locally, and mirror it to the user's
  /// Firestore doc (`users/{uid}/gamification/state`) when signed in.
  Future<void> saveGamification(GamificationState state) async {
    await _prefs.setString(_gamificationKey, jsonEncode(state.toJson()));
    final ref = _profileRef();
    if (ref != null) {
      await ref
          .collection('gamification')
          .doc('state')
          .set(state.toJson(), SetOptions(merge: true));
    }
  }

  // ---- Daily quests (cached board for today) ----

  static const _questBoardKey = 'daily_quests';

  /// Raw {"day", "quests": [...]} board, or null if never generated.
  Map<String, dynamic>? getQuestBoardRaw() {
    final raw = _prefs.getString(_questBoardKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveQuestBoard(Map<String, dynamic> board) async {
    await _prefs.setString(_questBoardKey, jsonEncode(board));
  }

  // ---- Shop inventory ----

  static const _shopKey = 'shop_inventory';

  Map<String, dynamic>? get shopInventoryRaw {
    final raw = _prefs.getString(_shopKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveShopInventory(Map<String, dynamic> inv) async {
    await _prefs.setString(_shopKey, jsonEncode(inv));
  }

  // ---- League state ----

  static const _leagueKey = 'league_state';

  Map<String, dynamic>? get leagueStateRaw {
    final raw = _prefs.getString(_leagueKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveLeagueState(Map<String, dynamic> state) async {
    await _prefs.setString(_leagueKey, jsonEncode(state));
  }

  // ---- Notification engine state ----

  static const _notifKey = 'notification_state';

  Map<String, dynamic>? get notificationStateRaw {
    final raw = _prefs.getString(_notifKey);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> saveNotificationState(Map<String, dynamic> state) async {
    await _prefs.setString(_notifKey, jsonEncode(state));
  }

  // ---- Fasting ----

  static const _fastingStartKey = 'fasting_start';
  static const _fastingGoalKey = 'fasting_goal_hours';

  int get fastingGoalHours => _prefs.getInt(_fastingGoalKey) ?? 16;

  Future<void> saveFastingGoalHours(int hours) async {
    await _prefs.setInt(_fastingGoalKey, hours);
  }

  DateTime? get fastingStart {
    final raw = _prefs.getString(_fastingStartKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get isFasting => fastingStart != null;

  Future<void> startFasting() async {
    await _prefs.setString(_fastingStartKey, DateTime.now().toIso8601String());
  }

  Future<void> stopFasting() async {
    await _prefs.remove(_fastingStartKey);
  }

  int get fastingElapsedHours {
    final start = fastingStart;
    if (start == null) return 0;
    return DateTime.now().difference(start).inHours;
  }

  int get fastingElapsedMinutes {
    final start = fastingStart;
    if (start == null) return 0;
    return DateTime.now().difference(start).inMinutes % 60;
  }

  // ---- Meal Plans ----

  static const _mealPlansKey = 'meal_plans';

  List<MealPlan> get mealPlans {
    final raw = _prefs.getString(_mealPlansKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => MealPlan.fromJson(e)).toList();
  }

  Future<void> saveMealPlan(MealPlan plan) async {
    final plans = mealPlans;
    plans.add(plan);
    await _prefs.setString(_mealPlansKey, jsonEncode(plans.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteMealPlan(String id) async {
    final plans = mealPlans.where((p) => p.id != id).toList();
    await _prefs.setString(_mealPlansKey, jsonEncode(plans.map((e) => e.toJson()).toList()));
  }

  Future<void> updateMealPlan(MealPlan plan) async {
    final plans = mealPlans.map((p) => p.id == plan.id ? plan : p).toList();
    await _prefs.setString(_mealPlansKey, jsonEncode(plans.map((e) => e.toJson()).toList()));
  }

  Future<void> logMealPlan(MealPlan plan) async {
    final now = DateTime.now();
    final entry = FoodEntry(
      id: now.millisecondsSinceEpoch.toString(),
      dateTime: now,
      mealType: 'meal',
      imagePath: '',
      items: plan.items,
    );
    await addEntry(entry);
  }

  // ---- Reminders ----

  static const _remindersKey = 'reminders_enabled';
  static const _mealRemindersKey = 'meal_reminders_enabled';

  /// Water reminders default ON. Meal prompts default OFF (opt-in).
  bool get remindersEnabled => _prefs.getBool(_remindersKey) ?? true;

  Future<void> saveRemindersEnabled(bool enabled) async {
    await _prefs.setBool(_remindersKey, enabled);
  }

  bool get mealRemindersEnabled => _prefs.getBool(_mealRemindersKey) ?? false;

  Future<void> saveMealRemindersEnabled(bool enabled) async {
    await _prefs.setBool(_mealRemindersKey, enabled);
  }

  /// Meal-reminder re-prompt bookkeeping: fires at most TWICE ever —
  /// first log, then once more ~4 logs later, then never again.
  static const _mealPromptSentKey = 'meal_prompt_sent';
  static const _mealPromptLogCountKey = 'meal_prompt_log_count';

  int get _mealPromptSentCount => _prefs.getInt(_mealPromptSentKey) ?? 0;

  Future<void> recordMealPrompt() async {
    await _prefs.setInt(_mealPromptSentKey, _mealPromptSentCount + 1);
    await _prefs.setInt(_mealPromptLogCountKey, entryCount);
  }

  /// Show prompt after a meal when: not opted in, shown <2 times, and
  /// (never shown before) OR (>=4 meals logged since the last prompt).
  bool shouldRePromptMealPromptsNow() {
    if (mealRemindersEnabled) return false;
    final sent = _mealPromptSentCount;
    if (sent >= 2) return false;
    if (sent == 0) return true;
    final lastShownAt = _prefs.getInt(_mealPromptLogCountKey) ?? 0;
    return entryCount >= lastShownAt + 4;
  }

  // ---- Export ----

  String exportJson() {
    return jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile?.toJson(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'weightEntries': weightEntries.map((e) => e.toJson()).toList(),
      'waterEntries': waterEntries.map((e) => e.toJson()).toList(),
    });
  }

  // ---- Payment state ----
  // Trial is handled ENTIRELY by Google Play (subscription offer).
  // The app only tracks: is the user subscribed?

  static const _paidKey = 'has_paid';
  static const _planKey = 'subscription_plan'; // 'monthly' | 'yearly'

  bool get isPaid => _prefs.getBool(_paidKey) ?? false;

  String get subscriptionPlan => _prefs.getString(_planKey) ?? 'monthly';

  Future<void> setSubscriptionPlan(String plan) =>
      _prefs.setString(_planKey, plan);

  /// Sandbox bypass — iOS only, dev builds ONLY (kDebugMode).
  /// iOS has no Play Billing, so a signed-in dev user is treated as paid to
  /// keep the app testable during development.
  /// GUARANTEED compiled out of release builds: kReleaseMode is checked and
  /// the flow short-circuits to the real gate, so no user can bypass the
  /// paywall in a shipping build.
  bool isPaidOrSandbox({String? authEmail}) {
    // Release builds always follow the real gate — no sandbox, ever.
    if (kReleaseMode) return isPaid;
    if (!Platform.isIOS) return isPaid;
    // iOS dev build: local flag is historic test stub data (unreliable),
    // only the dev email unlocks.
    return authEmail == kSandboxEmail;
  }

  /// True while the current account is the sandbox email (for messaging).
  bool isSandboxUser({String? authEmail}) =>
      !kReleaseMode && Platform.isIOS && authEmail == kSandboxEmail;

  // ---- Recently Logged Foods ----

  static const _recentFoodsKey = 'recent_foods';
  static const _maxRecent = 10;

  List<Map<String, dynamic>> get recentFoods {
    final raw = _prefs.getString(_recentFoodsKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> addRecentFood(Map<String, dynamic> food) async {
    final list = recentFoods;
    // Remove if already exists (by name)
    list.removeWhere((f) => f['name'] == food['name']);
    // Add to front
    list.insert(0, food);
    // Trim to max
    if (list.length > _maxRecent) list.removeRange(_maxRecent, list.length);
    await _prefs.setString(_recentFoodsKey, jsonEncode(list));
  }

  // ---- Favorite Foods ----

  static const _favoriteFoodsKey = 'favorite_foods';

  List<Map<String, dynamic>> get favoriteFoods {
    final raw = _prefs.getString(_favoriteFoodsKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> toggleFavorite(Map<String, dynamic> food) async {
    final list = favoriteFoods;
    final idx = list.indexWhere((f) => f['name'] == food['name']);
    if (idx >= 0) {
      list.removeAt(idx);
    } else {
      list.insert(0, food);
    }
    await _prefs.setString(_favoriteFoodsKey, jsonEncode(list));
  }

  bool isFavorite(String name) {
    return favoriteFoods.any((f) => f['name'] == name);
  }

  Future<void> savePaid(bool paid) async {
    await _prefs.setBool(_paidKey, paid);
    final ref = _profileRef();
    if (ref != null) {
      await ref.set({'paid': paid}, SetOptions(merge: true));
    }
  }

  Future<bool> loadPaidFromCloud() async {
    final ref = _profileRef();
    if (ref == null) return isPaid;
    final doc = await ref.get();
    if (!doc.exists) {
      // No cloud record — stale local flag must not survive.
      await _prefs.setBool(_paidKey, false);
      return false;
    }
    final data = doc.data() as Map<String, dynamic>?;
    final paid = data?['paid'] as bool? ?? false;
    await _prefs.setBool(_paidKey, paid);
    return paid;
  }
}