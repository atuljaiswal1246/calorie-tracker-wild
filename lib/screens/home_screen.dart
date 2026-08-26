import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'achievements_screen.dart';
import 'barcode_scanner_screen.dart';
import 'insights_screen.dart';
import 'capture_screen.dart';
import 'manual_entry_screen.dart';
import 'meal_detail_screen.dart';
import 'macro_breakdown_screen.dart';
import 'meal_plan_screen.dart';
import 'groups_screen.dart';
import 'api_key_setup_screen.dart';
import 'progress_screen.dart';
import 'all_entries_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;
  final VoidCallback onSignedOut;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.auth,
    required this.onSignedOut,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Design tokens — premium, minimal, warm-white background, black primary.
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _track = Color(0xFFECECE7);
  static const _proteinColor = Color(0xFFE53935); // coral/red
  static const _carbsColor = Color(0xFFFF9500); // warm orange
  static const _fatColor = Color(0xFF007AFF); // blue
  static const _green = Color(0xFF34C759); // completed day
  static const _missedRed = Color(0xFFFF3B30); // missed day
  static const _avatarBlue = Color(0xFFEAF3FF); // profile avatar bg
  static const _cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  Profile? _profile;
  List<FoodEntry> _entries = [];
  int _waterMl = 0;
  int _waterGoalMl = 2500;
  DateTime _selected = DateTime.now();
  int _navIndex = 0; // 0 home, 1 progress, 2 groups, 3 profile
  int _macroPageIndex = 0;
  final PageController _macroPageController = PageController();
  bool _isOnline = true;
  late final Stream<List<ConnectivityResult>> _connectivityStream;

  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.profile;
    _load();
    _connectivityStream = Connectivity().onConnectivityChanged;
    _connectivityStream.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && online != _isOnline) {
        setState(() => _isOnline = online);
      }
    });
  }

  @override
  void dispose() {
    _macroPageController.dispose();
    super.dispose();
  }

  void _load() {
    _entries = widget.storage.entries;
    _waterMl = widget.storage.waterMlForDay(DateTime.now());
    _waterGoalMl = widget.storage.waterGoalMl;
    setState(() {});
  }

  // ---- Data helpers (selected day) ----

  List<FoodEntry> _on(DateTime day) =>
      _entries.where((e) => e.isOn(day)).toList();

  int _calories(DateTime day) =>
      _on(day).fold(0, (s, e) => s + e.totalCalories);

  double _protein(DateTime day) =>
      _on(day).fold(0.0, (s, e) => s + e.totalProtein);

  double _carbs(DateTime day) =>
      _on(day).fold(0.0, (s, e) => s + e.totalCarbs);

  double _fat(DateTime day) =>
      _on(day).fold(0.0, (s, e) => s + e.totalFat);

  int get _streak {
    final goal = _profile?.calorieGoal ?? 1500;
    var streak = 0;
    var day = DateTime.now();

    // Find the start of this Sun-Sat week
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday % 7));

    while (!day.isBefore(weekStart)) {
      final logged = _calories(day);
      final hitTarget = goal > 0 && logged >= goal * 0.8;
      if (hitTarget) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // Week starting Sunday, matching the reference calendar strip.
  List<DateTime> get _week {
    final sunday = _selected.subtract(Duration(days: _selected.weekday % 7));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  int get _fiberTarget => 30;
  int get _sugarTarget => (_profile?.calorieGoal ?? 2000) ~/ 200; // ~10% of kcal/4g
  int get _sodiumTarget => 2300;

  String get _initials {
    final name = _profile?.name.trim() ?? 'U';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---- Actions ----

  Future<void> _openCapture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
    );
    if (picked == null) return;
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          storage: widget.storage,
          initialImage: File(picked.path),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) return;
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          storage: widget.storage,
          initialImage: File(picked.path),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your meals are saved to your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.auth.signOut();
      if (!mounted) return;
      widget.onSignedOut();
    }
  }

  Future<void> _toggleReminders() async {
    final enabled = widget.storage.remindersEnabled;
    if (!enabled) {
      await NotificationService.requestPermissions();
    }
    await widget.storage.saveRemindersEnabled(!enabled);
    if (enabled) {
      await NotificationService.cancelAll();
    } else {
      await NotificationService.scheduleWaterReminder();
      await NotificationService.scheduleMealReminder();
    }
    _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!enabled
            ? 'Reminders on: water at 4:30pm, meal at 12:30pm'
            : 'Reminders off'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportData() async {
    final data = widget.storage.exportJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cal_matters_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(data);
    if (file.existsSync()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    }
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text(
          entry.items.isEmpty
              ? 'This will remove the meal from your log.'
              : '"${entry.items.first.name}" and ${entry.items.length - 1} other item(s) will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.storage.deleteEntry(entry.id);
      _load();
    }
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('No profile found')));
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: switch (_navIndex) {
                1 => _progressPage(),
                2 => _groupsPage(),
                3 => _profilePage(profile),
                _ => _homePage(profile),
              },
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 14,
              child: _floatingNav(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= Home =================

  Widget _homePage(Profile profile) {
    final goal = profile.calorieGoal;
    final logged = _calories(_selected);
    final proteinGoal = profile.proteinGrams;
    final carbsGoal = profile.carbsGrams;
    final fatGoal = profile.fatGrams;
    final recent = _entries.take(4).toList();

    return RefreshIndicator(
      color: _ink,
      onRefresh: () async => _load(),
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        _greeting(profile),
        const SizedBox(height: 14),
        _header(),
        if (!_isOnline) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFFF9500)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You\'re offline. AI features unavailable.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        _weekSelector(calorieGoal: goal),
        const SizedBox(height: 20),
        _caloriesCard(
          goal: goal,
          logged: logged,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MacroBreakdownScreen(
                macroType: MacroType.calories,
                entries: _on(_selected),
                total: logged.toDouble(),
                target: goal.toDouble(),
                color: _ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: PageView(
            controller: _macroPageController,
            onPageChanged: (i) => setState(() => _macroPageIndex = i),
            children: [
              // Page 1: Protein, Carbs, Fat
              Row(
                children: [
                  Expanded(
                    child: _macroCard(
                      label: 'Protein eaten',
                      value: _protein(_selected),
                      target: proteinGoal.toDouble(),
                      color: _proteinColor,
                      icon: Symbols.egg,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.protein,
                            entries: _on(_selected),
                            total: _protein(_selected),
                            target: proteinGoal.toDouble(),
                            color: _proteinColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _macroCard(
                      label: 'Carbs eaten',
                      value: _carbs(_selected),
                      target: carbsGoal.toDouble(),
                      color: _carbsColor,
                      icon: Symbols.rice_bowl,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.carbs,
                            entries: _on(_selected),
                            total: _carbs(_selected),
                            target: carbsGoal.toDouble(),
                            color: _carbsColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _macroCard(
                      label: 'Fat eaten',
                      value: _fat(_selected),
                      target: fatGoal.toDouble(),
                      color: _fatColor,
                      icon: Symbols.avocado_bean,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.fat,
                            entries: _on(_selected),
                            total: _fat(_selected),
                            target: fatGoal.toDouble(),
                            color: _fatColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Page 2: Fiber, Sugar, Sodium
              Row(
                children: [
                  Expanded(
                    child: _macroCard(
                      label: 'Fiber eaten',
                      value: _on(_selected).fold(0.0, (s, e) => s + e.totalFiber),
                      target: _fiberTarget.toDouble(),
                      color: const Color(0xFF8D6E63),
                      icon: Symbols.eco,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.fiber,
                            entries: _on(_selected),
                            total: _on(_selected).fold(0.0, (s, e) => s + e.totalFiber),
                            target: _fiberTarget.toDouble(),
                            color: const Color(0xFF8D6E63),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _macroCard(
                      label: 'Sugar eaten',
                      value: _on(_selected).fold(0.0, (s, e) => s + e.totalSugar),
                      target: _sugarTarget.toDouble(),
                      color: const Color(0xFFE91E63),
                      icon: Symbols.cookie,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.sugar,
                            entries: _on(_selected),
                            total: _on(_selected).fold(0.0, (s, e) => s + e.totalSugar),
                            target: _sugarTarget.toDouble(),
                            color: const Color(0xFFE91E63),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _macroCard(
                      label: 'Sodium eaten',
                      value: _on(_selected).fold(0.0, (s, e) => s + e.totalSodium),
                      target: _sodiumTarget.toDouble(),
                      color: const Color(0xFF78909C),
                      icon: Symbols.emoji_food_beverage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.sodium,
                            entries: _on(_selected),
                            total: _on(_selected).fold(0.0, (s, e) => s + e.totalSodium),
                            target: _sodiumTarget.toDouble(),
                            color: const Color(0xFF78909C),
                          ),
                        ),
                      ),
                      unit: 'mg',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _paginationDots(),
        const SizedBox(height: 22),
        _logMealSection(),
        const SizedBox(height: 22),
        _waterCard(),
        const SizedBox(height: 16),
        _fastingCard(),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recently uploaded',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.4,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AllEntriesScreen(storage: widget.storage),
                  ),
                );
              },
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _emptyCard()
        else
          ...recent.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _mealCard(e),
              )),
      ],
      ),
    );
  }

  String get _greetingText {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  Widget _greeting(Profile profile) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _muted,
        ),
        children: [
          TextSpan(text: '$_greetingText, '),
          TextSpan(
            text: profile.name.split(' ').first,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _ink,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'Cal Matters',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        // Insights button
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InsightsScreen(storage: widget.storage),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _cardShadow,
            ),
            child: const Icon(Icons.insights_rounded, size: 17, color: Color(0xFF1C1C1E)),
          ),
        ),
        const SizedBox(width: 6),
        // Achievements badge
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AchievementsScreen(storage: widget.storage),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _cardShadow,
            ),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '${AchievementsService(widget.storage).unlockedCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Streak pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow,
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                '$_streak',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekSelector({required int calorieGoal}) {
    final today = DateTime.now();
    final canGoNext = _selected.isBefore(today);
    final weekLabel = _weekLabel();
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() =>
                  _selected = _selected.subtract(const Duration(days: 7))),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _cardShadow,
                ),
                child: const Icon(Icons.chevron_left,
                    size: 18, color: Color(0xFF8E8E93)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                weekLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canGoNext
                  ? () => setState(() =>
                      _selected = _selected.add(const Duration(days: 7)))
                  : null,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _cardShadow,
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: canGoNext
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFFE3E3DE),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _cardShadow,
          ),
          child: Row(
        children: _week.map((day) {
          final isSelected = _isSameDay(day, _selected);
          final isFuture = day.isAfter(today);
          final dayCalories = _calories(day);
          final progress = calorieGoal > 0 ? (dayCalories / calorieGoal).clamp(0.0, 1.0) : 0.0;
          final hasLog = _on(day).isNotEmpty;

          // Progress ring color: black < 50%, orange 50-79%, green 80+
          Color ringColor;
          if (isFuture) {
            ringColor = const Color(0xFFE3E3DE);
          } else if (progress >= 0.8) {
            ringColor = _green;
          } else if (progress >= 0.5) {
            ringColor = const Color(0xFFFFA726);
          } else if (progress > 0) {
            ringColor = _ink;
          } else {
            ringColor = const Color(0xFFE3E3DE);
          }

          Color textColor = const Color(0xFFB0B0AA);
          FontWeight weight = FontWeight.w500;
          if (isSelected) {
            textColor = _ink;
            weight = FontWeight.w800;
          } else if (!isFuture && hasLog) {
            textColor = _ink;
            weight = FontWeight.w600;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selected = day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF4F4F1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E').format(day),
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: isFuture ? 0 : progress,
                          color: ringColor,
                          strokeWidth: 2.5,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: weight,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
          ),
        ),
      ],
    );
  }

  String _weekLabel() {
    final days = _week;
    final start = DateFormat('d MMM').format(days.first);
    final end = DateFormat('d MMM').format(days.last);
    return '$start – $end';
  }

  Widget _caloriesCard({required int goal, required int logged, VoidCallback? onTap}) {
    final progress = goal == 0 ? 0.0 : (logged / goal).clamp(0.0, 1.0);
    final over = logged > goal;

    // Color logic: black < 50%, orange 50-79%, green 80-100%, red if over
    Color accentColor;
    if (over) {
      accentColor = _missedRed;
    } else if (progress >= 0.8) {
      accentColor = _green;
    } else if (progress >= 0.5) {
      accentColor = const Color(0xFFFFA726);
    } else {
      accentColor = _ink;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$logged',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/$goal',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  over ? 'Calories over target' : 'Calories eaten',
                  style: TextStyle(
                    fontSize: 13,
                    color: over ? _missedRed : _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _ring(
            progress: progress,
            color: accentColor,
            size: 104,
            stroke: 11,
            child: Icon(
              over ? Icons.warning_rounded : Icons.local_fire_department,
              color: accentColor,
              size: 36,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _macroCard({
    required String label,
    required double value,
    required double target,
    required Color color,
    required IconData icon,
    String unit = 'g',
    VoidCallback? onTap,
  }) {
    final progress = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '/${target.toStringAsFixed(0)}$unit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _ring(
            progress: progress,
            color: color,
            size: 52,
            stroke: 5,
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
      ),
    );
  }

  Widget _ring({
    required double progress,
    required Color color,
    required double size,
    required double stroke,
    required Widget child,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: stroke,
            strokeCap: StrokeCap.round,
            backgroundColor: _track,
            color: color,
          ),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _waterCard() {
    final progress = _waterGoalMl > 0 ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;
    final glasses = (_waterMl / 250).round();
    final goalGlasses = (_waterGoalMl / 250).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('💧', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'Water',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              Text(
                '${(_waterMl / 1000).toStringAsFixed(1)}L / ${(_waterGoalMl / 1000).toStringAsFixed(1)}L',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFECECE7),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$glasses / $goalGlasses glasses',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          // Quick add buttons
          Row(
            children: [
              _waterButton(250, Icons.water_drop_outlined),
              const SizedBox(width: 8),
              _waterButton(500, Icons.water_drop),
              const SizedBox(width: 8),
              _waterButtonCustom(),
              const Spacer(),
              if (_waterMl > 0)
                GestureDetector(
                  onTap: () async {
                    await widget.storage.undoLastWater();
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Undo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterButton(int ml, IconData icon) {
    return GestureDetector(
      onTap: () async {
        await widget.storage.addWater(ml);
        HapticFeedback.lightImpact();
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF007AFF)),
            const SizedBox(width: 4),
            Text(
              '+${ml}ml',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF007AFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waterButtonCustom() {
    return GestureDetector(
      onTap: () {
        final controller = TextEditingController(text: '250');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Add water'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                suffixText: 'ml',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final ml = int.tryParse(controller.text);
                  if (ml != null && ml > 0 && ml <= 2000) {
                    await widget.storage.addWater(ml);
                    _load();
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F0EC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: Color(0xFF1C1C1E)),
            SizedBox(width: 4),
            Text(
              'Custom',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fastingCard() {
    final isFasting = widget.storage.isFasting;
    final start = widget.storage.fastingStart;
    final goalHours = widget.storage.fastingGoalHours;
    final elapsedH = widget.storage.fastingElapsedHours;
    final elapsedM = widget.storage.fastingElapsedMinutes;
    final progress = isFasting ? (elapsedH / goalHours).clamp(0.0, 1.0) : 0.0;
    final completed = isFasting && elapsedH >= goalHours;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('⏰', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'Fasting',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              if (isFasting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFF34C759).withOpacity(0.12)
                        : const Color(0xFFFF9500).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    completed ? 'Complete' : '$goalHours:00 goal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: completed ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isFasting) ...[
            // Timer display
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${elapsedH.toString().padLeft(2, '0')}:${elapsedM.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -1,
                    fontFamily: 'monospace',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4, left: 6),
                  child: Text(
                    'elapsed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFECECE7),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Started at ${start != null ? TimeOfDay.fromDateTime(start).format(context) : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await widget.storage.stopFasting();
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'End fast',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF3B30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showFastingGoalSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F0EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings, size: 18, color: Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Not fasting — show start options
            Row(
              children: [
                _fastingPreset('14:10', 14),
                const SizedBox(width: 8),
                _fastingPreset('16:8', 16),
                const SizedBox(width: 8),
                _fastingPreset('18:6', 18),
                const SizedBox(width: 8),
                _fastingPreset('20:4', 20),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await widget.storage.startFasting();
                _load();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Start fasting',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fastingPreset(String label, int hours) {
    return GestureDetector(
      onTap: () async {
        await widget.storage.saveFastingGoalHours(hours);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.storage.fastingGoalHours == hours
              ? _ink
              : const Color(0xFFF1F0EC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: widget.storage.fastingGoalHours == hours
                ? Colors.white
                : _ink,
          ),
        ),
      ),
    );
  }

  void _showFastingGoalSheet(BuildContext context) {
    final controller = TextEditingController(
      text: widget.storage.fastingGoalHours.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fasting Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set your fasting duration in hours',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
              decoration: InputDecoration(
                suffixText: 'hours',
                suffixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8E8E93),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                      color: Color(0xFF1C1C1E), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  final val = int.tryParse(controller.text);
                  if (val == null || val < 8 || val > 24) return;
                  await widget.storage.saveFastingGoalHours(val);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _macroPageIndex == 0 ? _ink : const Color(0xFFE3E3DE),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _macroPageIndex == 1 ? _ink : const Color(0xFFE3E3DE),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _logMealSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _logOption(
                icon: Symbols.egg_alt,
                label: 'Scan food',
                onTap: _openCapture,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _logOption(
                icon: Icons.photo_library_outlined,
                label: 'Upload photo',
                onTap: _openGallery,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _logOption(
                icon: Icons.qr_code_scanner,
                label: 'Barcode',
                onTap: _openBarcodeScanner,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _logOption(
                icon: Symbols.restaurant_menu,
                label: 'Add manually',
                onTap: _openManualEntry,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MealPlanScreen(storage: widget.storage),
              ),
            );
            if (result == true) _load();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _cardShadow,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_outline, size: 18, color: _ink),
                SizedBox(width: 8),
                Text(
                  'Meal plans',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _logOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: _ink),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManualEntry() async {
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(storage: widget.storage),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _openBarcodeScanner() async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(storage: widget.storage),
      ),
    );
    _load();
  }

  Widget _mealCard(FoodEntry entry) {
    final name = entry.items.isEmpty
        ? 'Meal'
        : entry.items.first.name +
            (entry.items.length > 1 ? ' +${entry.items.length - 1} more' : '');
    final time =
        DateFormat('h:mm a').format(entry.dateTime).toLowerCase();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MealDetailScreen(entry: entry),
          ),
        );
      },
      onLongPress: () => _deleteEntry(entry),
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _thumbnail(entry, width: 84, height: 84),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '🔥 ${entry.totalCalories} Calories',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _macroPill(Icons.egg_alt, _proteinColor,
                        '${entry.totalProtein.toStringAsFixed(0)}g'),
                    const SizedBox(width: 8),
                    _macroPill(Icons.grain, _carbsColor,
                        '${entry.totalCarbs.toStringAsFixed(0)}g'),
                    const SizedBox(width: 8),
                    _macroPill(Icons.water_drop, _fatColor,
                        '${entry.totalFat.toStringAsFixed(0)}g'),
                  ],
                ),
                if (entry.totalFiber > 0 || entry.totalSugar > 0 || entry.totalSodium > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (entry.totalFiber > 0) ...[
                        _macroPill(Icons.grass, const Color(0xFF8D6E63),
                            '${entry.totalFiber.toStringAsFixed(0)}g'),
                        const SizedBox(width: 8),
                      ],
                      if (entry.totalSugar > 0) ...[
                        _macroPill(Icons.cake, const Color(0xFFE91E63),
                            '${entry.totalSugar.toStringAsFixed(0)}g'),
                        const SizedBox(width: 8),
                      ],
                      if (entry.totalSodium > 0)
                        _macroPill(Icons.water_drop_outlined, const Color(0xFF78909C),
                            '${entry.totalSodium.toStringAsFixed(0)}mg'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _thumbnail(FoodEntry entry, {required double width, required double height}) {
    final hasImage = entry.imagePath.isNotEmpty;
    return SizedBox(
      width: width,
      height: height,
      child: hasImage
          ? Image.file(
              File(entry.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _thumbPlaceholder(),
            )
          : _thumbPlaceholder(),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFF1F0EC),
      child: const Center(
        child: Text('🍛', style: TextStyle(fontSize: 30)),
      ),
    );
  }

  Widget _macroPill(IconData icon, Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 10, color: color),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 10),
          const Text(
            'No meals logged yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan your first meal to get started',
            style: TextStyle(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _openCapture,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Scan a meal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= Placeholder tabs =================

  Widget _placeholderPage(String title, IconData icon, String subtitle) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _cardShadow,
          ),
          child: Column(
            children: [
              Icon(icon, size: 40, color: _muted),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressPage() =>
      ProgressScreen(storage: widget.storage);

  Widget _groupsPage() {
    if (_uid == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 56, color: _muted.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text(
              'Sign in to use groups',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Share your progress with friends and family.',
              style: TextStyle(fontSize: 14, color: _muted),
            ),
          ],
        ),
      );
    }
    return _GroupsPageContent(storage: widget.storage);
  }

  // ================= Profile tab =================

  Widget _profilePage(Profile profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _avatarBlue,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${profile.calorieGoal} kcal/day goal',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow,
          ),
          child: Column(
            children: [
              _profileRow('Goal', profile.goal == 'lose'
                  ? 'Lose weight'
                  : profile.goal == 'gain'
                      ? 'Gain weight'
                      : 'Maintain'),
              _profileRow('Workouts', switch (profile.workoutFreq) {
                '3to5' => '3–5 times / week',
                '6plus' => '6+ times / week',
                '1to2' => '1–2 times / week',
                'none' => 'No workouts',
                _ => '0–2 times / week',
              }),
              _profileRow('Height', '${profile.heightCm.round()} cm'),
              _profileRow(
                  'Weight', '${profile.weightKg.round()} kg'),
              _profileRow(
                  'Target', profile.targetWeightKg == null
                      ? '—'
                      : '${profile.targetWeightKg!.round()} kg'),
              _profileRow('Daily calories', '${profile.calorieGoal} kcal'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow,
          ),
          child: Column(
            children: [
              _settingsRow(
                icon: Icons.key,
                label: 'API key',
                subtitle: widget.storage.apiKey?.isNotEmpty == true ||
                        widget.storage.geminiKey?.isNotEmpty == true
                    ? 'Configured'
                    : 'Not set',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApiKeySetupScreen(storage: widget.storage),
                    ),
                  );
                  if (result == true) _load();
                },
              ),
              const Divider(height: 1, color: Color(0xFFECECE7)),
              _settingsRow(
                icon: Icons.notifications_active_outlined,
                label: 'Reminders',
                subtitle: widget.storage.remindersEnabled
                    ? 'Water & meal reminders on'
                    : 'Off',
                onTap: () async {
                  await _toggleReminders();
                },
              ),
              const Divider(height: 1, color: Color(0xFFECECE7)),
              _settingsRow(
                icon: Icons.share_outlined,
                label: 'Export data',
                subtitle: 'Download your logs as JSON',
                onTap: _exportData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _signOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: _missedRed,
            side: BorderSide(color: _missedRed.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: _muted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink)),
        ],
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _ink.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _muted),
          ],
        ),
      ),
    );
  }

  // ================= Floating navigation =================

  Widget _floatingNav() {
    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          Expanded(child: _navItem(index: 0, icon: Icons.home_rounded, label: 'Home')),
          Expanded(child: _navItem(index: 1, icon: Icons.bar_chart_rounded, label: 'Progress')),
          Expanded(
            child: GestureDetector(
              onTap: _openCapture,
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: _ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.center_focus_strong, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          Expanded(child: _navItem(index: 2, icon: Icons.group_outlined, label: 'Groups')),
          Expanded(child: _navAvatar(index: 3)),
        ],
      ),
    );
  }

  Widget _navItem({required int index, required IconData icon, required String label}) {
    final active = _navIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF0F0EC) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon,
                size: 22,
                color: active ? _ink : const Color(0xFFB0B0AA)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _ink : const Color(0xFFB0B0AA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navAvatar({required int index}) {
    final active = _navIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _avatarBlue,
              shape: BoxShape.circle,
              border: active ? Border.all(color: _ink, width: 1.6) : null,
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _ink : const Color(0xFFB0B0AA),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -3.14159 / 2, // Start from top
        2 * 3.14159 * progress.clamp(0.0, 1.0),
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _GroupsPageContent extends StatefulWidget {
  final StorageService storage;
  const _GroupsPageContent({required this.storage});

  @override
  State<_GroupsPageContent> createState() => _GroupsPageContentState();
}

class _GroupsPageContentState extends State<_GroupsPageContent> {
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 56, color: _muted.withOpacity(0.4)),
            const SizedBox(height: 14),
            const Text(
              'Sign in to use groups',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(
            children: [
              const Text(
                'Groups',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showJoinGroupSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _ink.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add, size: 16, color: _ink),
                      SizedBox(width: 4),
                      Text(
                        'Join',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showCreateGroupSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .where('members', arrayContains: _uid)
                .snapshots()
                .handleError((_) {}),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined, size: 56, color: _muted.withOpacity(0.4)),
                      const SizedBox(height: 14),
                      const Text(
                        'No groups yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Create a group to share progress\nwith friends and family.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: _muted, height: 1.4),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? 'Group';
                  final members = (data['members'] as List?)?.length ?? 0;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(
                          groupId: docs[i].id,
                          groupName: name,
                          storage: widget.storage,
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _cardShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _ink.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.group, color: _ink, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$members member${members == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 13, color: _muted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: _muted),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showJoinGroupSheet(BuildContext context) {
    final controller = TextEditingController();
    bool joining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join a group',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the 6-character invite code from a friend',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'ABC123',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    color: _muted.withOpacity(0.4),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _ink, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: joining || controller.text.trim().length < 6
                      ? null
                      : () async {
                          setSheet(() => joining = true);
                          final code = controller.text.trim().toUpperCase();
                          final snap = await FirebaseFirestore.instance
                              .collection('groups')
                              .where('code', isEqualTo: code)
                              .limit(1)
                              .get();
                          if (snap.docs.isEmpty) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('No group found with that code.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            setSheet(() => joining = false);
                            return;
                          }
                          final doc = snap.docs.first;
                          final uid = _uid;
                          if (uid != null) {
                            await FirebaseFirestore.instance
                                .collection('groups')
                                .doc(doc.id)
                                .update({
                              'members': FieldValue.arrayUnion([uid]),
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          setState(() {});
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  child: joining
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Join',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a group',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _ink),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: const TextStyle(color: _muted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _ink, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty || _uid == null) return;
                  await FirebaseFirestore.instance.collection('groups').add({
                    'name': name,
                    'createdBy': _uid,
                    'members': [_uid],
                    'code': _generateGroupCode(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
String _generateGroupCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random();
  return String.fromCharCodes(
    List.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
  );
}
