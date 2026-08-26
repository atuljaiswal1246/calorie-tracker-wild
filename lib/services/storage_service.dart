import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';

class WaterEntry {
  final DateTime date;
  final int ml;

  const WaterEntry({required this.date, required this.ml});

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

  const WeightEntry({required this.date, required this.weightKg});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weightKg': weightKg,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        date: DateTime.parse(json['date'] as String),
        weightKg: (json['weightKg'] as num).toDouble(),
      );
}

class StorageService {
  static const _profileKey = 'user_profile';
  static const _entriesKey = 'food_entries';
  static const _apiKey = 'openai_api_key';
  static const _geminiKey = 'gemini_api_key';
  static const _providerKey = 'ai_provider'; // 'openai' | 'gemini'

  final SharedPreferences _prefs;
  String? _userId;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
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

  Future<void> addEntry(FoodEntry entry) async {
    final all = [...entries, entry];
    await _saveEntries(all);

    final ref = _profileRef();
    if (ref != null) {
      await ref.collection('entries').doc(entry.id).set(entry.toJson());
    }
  }

  Future<void> deleteEntry(String id) async {
    final all = entries.where((e) => e.id != id).toList();
    await _saveEntries(all);

    final ref = _profileRef();
    if (ref != null) {
      await ref.collection('entries').doc(id).delete();
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

  // ---- Keys (kept local to device) ----

  String? get apiKey => _prefs.getString(_apiKey);

  Future<void> saveApiKey(String key) async {
    await _prefs.setString(_apiKey, key.trim());
  }

  String? get geminiKey => _prefs.getString(_geminiKey);

  Future<void> saveGeminiKey(String key) async {
    await _prefs.setString(_geminiKey, key.trim());
  }

  String get provider => _prefs.getString(_providerKey) ?? 'openai';

  Future<void> saveProvider(String provider) async {
    await _prefs.setString(_providerKey, provider);
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
  static const int defaultWaterGoalMl = 2500;

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

  // ---- Payment state ----

  static const _paidKey = 'has_paid';

  bool get isPaid => _prefs.getBool(_paidKey) ?? false;

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
    if (ref == null) return false;
    final doc = await ref.get();
    if (!doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    final paid = data?['paid'] as bool? ?? false;
    await _prefs.setBool(_paidKey, paid);
    return paid;
  }
}