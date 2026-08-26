import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'achievements_screen.dart';
import 'barcode_scanner_screen.dart';
import 'insights_screen.dart';
import 'capture_screen.dart';
import 'manual_entry_screen.dart';
import 'meal_detail_screen.dart';
import 'macro_breakdown_screen.dart';
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

  final _apiKeyController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  String _provider = 'openai';

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.profile;
    _provider = widget.storage.provider;
    _apiKeyController.text = widget.storage.apiKey ?? '';
    _geminiKeyController.text = widget.storage.geminiKey ?? '';
    _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _geminiKeyController.dispose();
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

  Future<void> _saveSettings() async {
    await widget.storage.saveProvider(_provider);
    if (_apiKeyController.text.trim().isNotEmpty) {
      await widget.storage.saveApiKey(_apiKeyController.text);
    }
    if (_geminiKeyController.text.trim().isNotEmpty) {
      await widget.storage.saveGeminiKey(_geminiKeyController.text);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        _header(),
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
                      target: 30,
                      color: const Color(0xFF8D6E63),
                      icon: Symbols.eco,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.fiber,
                            entries: _on(_selected),
                            total: _on(_selected).fold(0.0, (s, e) => s + e.totalFiber),
                            target: 30,
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
                      target: 50,
                      color: const Color(0xFFE91E63),
                      icon: Symbols.cookie,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.sugar,
                            entries: _on(_selected),
                            total: _on(_selected).fold(0.0, (s, e) => s + e.totalSugar),
                            target: 50,
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
                      target: 2300,
                      color: const Color(0xFF78909C),
                      icon: Symbols.emoji_food_beverage,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MacroBreakdownScreen(
                            macroType: MacroType.sodium,
                            entries: _on(_selected),
                            total: _on(_selected).fold(0.0, (s, e) => s + e.totalSodium),
                            target: 2300,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _cardShadow,
            ),
            child: const Row(
              children: [
                Icon(Icons.insights_rounded, size: 16, color: Color(0xFF1C1C1E)),
                SizedBox(width: 5),
                Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
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
                const SizedBox(width: 5),
                Text(
                  '${AchievementsService(widget.storage).unlockedCount}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Streak pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _cardShadow,
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                '$_streak',
                style: const TextStyle(
                  fontSize: 14,
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
    return Container(
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
    );
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
    return Row(
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
        : entry.items.first.name;
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
      child: const Column(
        children: [
          Text('🍽️', style: TextStyle(fontSize: 34)),
          SizedBox(height: 10),
          Text(
            'No meals logged yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          ),
          SizedBox(height: 4),
          Text(
            'Tap + to log your first meal',
            style: TextStyle(fontSize: 13, color: _muted),
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

  Widget _groupsPage() =>
      _placeholderPage('Groups', Icons.group_outlined, 'Coming soon');

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('AI provider',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'openai', label: Text('OpenAI')),
                  ButtonSegment(value: 'gemini', label: Text('Gemini')),
                ],
                selected: {_provider},
                onSelectionChanged: (s) =>
                    setState(() => _provider = s.first),
              ),
              const SizedBox(height: 14),
              if (_provider == 'gemini') ...[
                const Text('Gemini API key',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _geminiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'AIza...',
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ] else ...[
                const Text('OpenAI API key',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'sk-...',
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saveSettings,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save settings'),
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