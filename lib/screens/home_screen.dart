import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'capture_screen.dart';

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
  DateTime _selected = DateTime.now();
  int _navIndex = 0; // 0 home, 1 progress, 2 groups, 3 profile

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
    super.dispose();
  }

  void _load() {
    setState(() => _entries = widget.storage.entries);
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
    var streak = 0;
    var day = DateTime.now();
    while (_on(day).isNotEmpty) {
      streak++;
      day = day.subtract(const Duration(days: 1));
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
      maxWidth: 1600,
      imageQuality: 85,
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
      maxWidth: 1600,
      imageQuality: 85,
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
        _weekSelector(),
        const SizedBox(height: 20),
        _caloriesCard(goal: goal, logged: logged),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _macroCard(
                label: 'Protein eaten',
                value: _protein(_selected),
                target: proteinGoal.toDouble(),
                color: _proteinColor,
                icon: Icons.egg_alt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _macroCard(
                label: 'Carbs eaten',
                value: _carbs(_selected),
                target: carbsGoal.toDouble(),
                color: _carbsColor,
                icon: Icons.grain,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _macroCard(
                label: 'Fat eaten',
                value: _fat(_selected),
                target: fatGoal.toDouble(),
                color: _fatColor,
                icon: Icons.water_drop,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _paginationDots(),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recently uploaded',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: _openGallery,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _cardShadow,
                ),
                child: const Icon(Icons.photo_library_outlined, size: 20, color: _muted),
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

  Widget _weekSelector() {
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
          final hasLog = _on(day).isNotEmpty;

          Color borderColor = const Color(0xFFE3E3DE);
          Color textColor = const Color(0xFFB0B0AA);
          FontWeight weight = FontWeight.w500;
          if (isSelected) {
            borderColor = _ink;
            textColor = _ink;
            weight = FontWeight.w800;
          } else if (isFuture) {
            borderColor = const Color(0xFFE3E3DE);
            textColor = const Color(0xFFB0B0AA);
          } else if (hasLog) {
            borderColor = _green;
            textColor = _green;
            weight = FontWeight.w600;
          } else {
            borderColor = _missedRed;
            textColor = _missedRed;
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
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderColor,
                          width: isSelected ? 2 : 1.4,
                        ),
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: weight,
                          color: textColor,
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

  Widget _caloriesCard({required int goal, required int logged}) {
    final progress = goal == 0 ? 0.0 : (logged / goal).clamp(0.0, 1.0);
    return Container(
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
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: _ink,
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
                const Text(
                  'Calories eaten',
                  style: TextStyle(
                    fontSize: 13,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _ring(
            progress: progress,
            color: _ink,
            size: 104,
            stroke: 11,
            child: const Icon(
              Icons.local_fire_department,
              color: _ink,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCard({
    required String label,
    required double value,
    required double target,
    required Color color,
    required IconData icon,
  }) {
    final progress = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '/${target.toStringAsFixed(0)}g',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _ring(
            progress: progress,
            color: color,
            size: 56,
            stroke: 6,
            child: Icon(icon, color: color, size: 18),
          ),
        ],
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

  Widget _paginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: _ink,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E3DE),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E3DE),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _mealCard(FoodEntry entry) {
    final name = entry.items.isEmpty
        ? 'Meal'
        : entry.items.first.name;
    final time =
        DateFormat('h:mm a').format(entry.dateTime).toLowerCase();
    return Container(
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
      _placeholderPage('Progress', Icons.bar_chart_rounded, 'Charts coming soon');

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