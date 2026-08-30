import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/achievements_service.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import 'achievements_screen.dart';
import 'barcode_scanner_screen.dart';
import 'insights_screen.dart';
import 'capture_screen.dart';
import 'discover_screen.dart';
import 'manual_entry_screen.dart';
import 'meal_detail_screen.dart';
import 'macro_breakdown_screen.dart';
import 'meal_plan_screen.dart';
import 'onboarding_screen.dart';
import 'progress_screen.dart';
import 'all_entries_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;
  final VoidCallback onSignedOut;
  final VoidCallback onResetGoals;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.auth,
    required this.onSignedOut,
    required this.onResetGoals,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Profile? _profile;
  List<FoodEntry> _entries = [];
  int _waterMl = 0;
  int _waterGoalMl = 2500;
  DateTime _selected = DateTime.now();
  int _navIndex = 0; // 0 home, 1 progress, 2 groups, 3 profile
  int _macroPageIndex = 0;
  final PageController _macroPageController = PageController();
  int _logPageIndex = 0;
  final PageController _logPageController = PageController();
  late final ScrollController _weekScrollController;
  bool _isOnline = true;
  late final Stream<List<ConnectivityResult>> _connectivityStream;
  BillingService? _billing;

  String? get _signedInEmail {
    try {
      return widget.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.profile;
    _weekScrollController = ScrollController(
      initialScrollOffset: 59 * 60.0,
    );
    _load();
    _billing = BillingService(widget.storage);
    _billing!.onStatusChanged = () {
      if (!mounted) return;
      _load();
    };
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
    _billing?.dispose();
    _macroPageController.dispose();
    _logPageController.dispose();
    _weekScrollController.dispose();
    super.dispose();
  }

  void _load() {
    _profile = widget.storage.profile;
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
    var streak = 0;
    var day = DateTime.now();

    if (_calories(day) == 0) {
      day = day.subtract(const Duration(days: 1));
    }

    while (_calories(day) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get _fiberTarget => 30;
  int get _sugarTarget => (_profile?.calorieGoal ?? 2000) ~/ 200;
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Log a meal',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.photo_camera, size: 28, color: AppColors.ink),
                            SizedBox(height: 8),
                            Text('Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.photo_library, size: 28, color: AppColors.ink),
                            SizedBox(height: 8),
                            Text('Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
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
    final picked = await picker.pickImage(source: ImageSource.gallery);
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

  Future<void> _confirmResetGoals() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset goals?'),
        content: const Text(
          'This clears your profile and takes you back to the '
          'questionnaire to set new goals.\n\n'
          'Your meal logs, water, weight and fasting history are kept. '
          'Payment and trial status are NOT affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: AppColors.missedRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.storage.resetProfile();
      if (!mounted) return;
      widget.onResetGoals();
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
            child: const Text('Delete', style: TextStyle(color: AppColors.missedRed)),
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
      backgroundColor: AppColors.bg,
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
              child: FloatingNav(
                currentIndex: _navIndex,
                onTap: (i) {
                  setState(() => _navIndex = i);
                  if (i == 0) _load();
                },
                onCenterTap: _openCapture,
                avatarInitials: _initials,
              ),
            ),
            if (!widget.storage.isPaidOrSandbox(
                authEmail: widget.auth.currentUser?.email))
              Positioned.fill(child: _paywallOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _paywallOverlay() {
    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text('🔒', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your free trial has ended',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Unlock unlimited food analysis and all features with a subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _openPricing,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Unlock — ₹100/mo or ₹1,100/yr',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _billing?.restore(),
            child: const Text(
              'Restore purchase',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Maybe later',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
        ],
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
    final recent = _on(_selected).take(4).toList();

    return RefreshIndicator(
      color: AppColors.ink,
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
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.accentOrange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You\'re offline. AI features unavailable.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
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
          CaloriesCard(
            goal: goal,
            logged: logged,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MacroBreakdownScreen(
                  macroType: MacroType.calories,
                  entries: _on(_selected),
                  total: logged.toDouble(),
                  target: goal.toDouble(),
                  color: AppColors.ink,
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
                Row(
                  children: [
                    Expanded(
                      child: MacroCard(
                        label: 'Protein eaten',
                        value: _protein(_selected),
                        target: proteinGoal.toDouble(),
                        color: AppColors.protein,
                        icon: Symbols.egg,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MacroBreakdownScreen(
                              macroType: MacroType.protein,
                              entries: _on(_selected),
                              total: _protein(_selected),
                              target: proteinGoal.toDouble(),
                              color: AppColors.protein,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MacroCard(
                        label: 'Carbs eaten',
                        value: _carbs(_selected),
                        target: carbsGoal.toDouble(),
                        color: AppColors.carbs,
                        icon: Symbols.rice_bowl,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MacroBreakdownScreen(
                              macroType: MacroType.carbs,
                              entries: _on(_selected),
                              total: _carbs(_selected),
                              target: carbsGoal.toDouble(),
                              color: AppColors.carbs,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MacroCard(
                        label: 'Fat eaten',
                        value: _fat(_selected),
                        target: fatGoal.toDouble(),
                        color: AppColors.fat,
                        icon: Symbols.avocado_bean,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MacroBreakdownScreen(
                              macroType: MacroType.fat,
                              entries: _on(_selected),
                              total: _fat(_selected),
                              target: fatGoal.toDouble(),
                              color: AppColors.fat,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: MacroCard(
                        label: 'Fiber eaten',
                        value: _on(_selected).fold(0.0, (s, e) => s + e.totalFiber),
                        target: _fiberTarget.toDouble(),
                        color: AppColors.fiber,
                        icon: Symbols.eco,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MacroBreakdownScreen(
                              macroType: MacroType.fiber,
                              entries: _on(_selected),
                              total: _on(_selected).fold(0.0, (s, e) => s + e.totalFiber),
                              target: _fiberTarget.toDouble(),
                              color: AppColors.fiber,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MacroCard(
                        label: 'Sugar eaten',
                        value: _on(_selected).fold(0.0, (s, e) => s + e.totalSugar),
                        target: _sugarTarget.toDouble(),
                        color: AppColors.sugar,
                        icon: Symbols.cookie,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MacroBreakdownScreen(
                              macroType: MacroType.sugar,
                              entries: _on(_selected),
                              total: _on(_selected).fold(0.0, (s, e) => s + e.totalSugar),
                              target: _sugarTarget.toDouble(),
                              color: AppColors.sugar,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MacroCard(
                        label: 'Sodium eaten',
                        value: _on(_selected).fold(0.0, (s, e) => s + e.totalSodium),
                        target: _sodiumTarget.toDouble(),
                        color: AppColors.sodium,
                        icon: Symbols.emoji_food_beverage,
                        unit: 'mg',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MacroBreakdownScreen(
                              macroType: MacroType.sodium,
                              entries: _on(_selected),
                              total: _on(_selected).fold(0.0, (s, e) => s + e.totalSodium),
                              target: _sodiumTarget.toDouble(),
                              color: AppColors.sodium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PaginationDots(count: 2, current: _macroPageIndex),
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
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllEntriesScreen(storage: widget.storage),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(onScanTap: _openCapture)
          else
            ...recent.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MealCard(
                    entry: e,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MealDetailScreen(entry: e),
                        ),
                      );
                    },
                    onLongPress: () => _deleteEntry(e),
                  ),
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
          color: AppColors.muted,
        ),
        children: [
          TextSpan(text: '$_greetingText, '),
          TextSpan(
            text: profile.name.split(' ').first,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPricing() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PricingScreen(
          storage: widget.storage,
          onPaid: _load,
        ),
      ),
    );
    _load();
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(11),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Cal Matters',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InsightsScreen(storage: widget.storage),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: const Icon(Icons.insights_rounded, size: 17, color: AppColors.ink),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
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
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          label: '$_streak day streak. Tap for details.',
          button: true,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showStreakInfo(context);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
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
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _weekSelector({required int calorieGoal}) {
    final today = DateTime.now();
    final dates = List<DateTime>.generate(
      60,
      (i) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 59 - i)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: SizedBox(
        height: 64,
        child: SingleChildScrollView(
          controller: _weekScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: dates.map((day) {
              final isSelected = _isSameDay(day, _selected);
              final isFuture = day.isAfter(today);
              final dayCalories = _calories(day);
              final progress = calorieGoal > 0
                  ? (dayCalories / calorieGoal).clamp(0.0, 1.0)
                  : 0.0;
              final hasLog = _on(day).isNotEmpty;

              Color ringColor;
              if (isFuture) {
                ringColor = AppColors.weekRing;
              } else if (progress >= 0.8) {
                ringColor = AppColors.green;
              } else if (progress >= 0.5) {
                ringColor = AppColors.warningOrange;
              } else if (progress > 0) {
                ringColor = AppColors.ink;
              } else {
                ringColor = AppColors.weekRing;
              }

              Color textColor = AppColors.faint;
              FontWeight weight = FontWeight.w500;
              if (isSelected) {
                textColor = AppColors.ink;
                weight = FontWeight.w800;
              } else if (!isFuture && hasLog) {
                textColor = AppColors.ink;
                weight = FontWeight.w600;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selected = day),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.cardSelected : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 16,
                          child: Center(
                            child: Text(
                              day.isAfter(today) ? '—' : DateFormat('E').format(day),
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CustomPaint(
                            painter: _RingPainter(
                              progress: isFuture ? 0 : progress,
                              color: ringColor,
                              strokeWidth: 2.5,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _waterCard() {
    final progress = _waterGoalMl > 0 ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('💧', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'Water',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${(_waterMl / 1000).toStringAsFixed(1)} / ${(_waterGoalMl / 1000).toStringAsFixed(1)} L',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  if (_waterMl > 0) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        await widget.storage.undoLastWater();
                        _load();
                      },
                      child: const Icon(Icons.undo, size: 14, color: AppColors.missedRed),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.track,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.fat),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _waterButton(250, Icons.water_drop),
              const SizedBox(width: 8),
              _waterButton(500, Icons.water_drop),
              const SizedBox(width: 8),
              _waterButtonCustom(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterButton(int ml, IconData icon) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          await widget.storage.addWater(ml);
          HapticFeedback.lightImpact();
          _load();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: AppColors.chipBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.fat),
              const SizedBox(width: 4),
              Text(
                '+${ml}ml',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.fat,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waterButtonCustom() {
    return Expanded(
      child: InkWell(
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
                      if (ctx.mounted) Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a value between 1–2000 ml'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: AppColors.chipNeutral,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: AppColors.ink),
              SizedBox(width: 4),
              Text(
                'Custom',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('⏰', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Fasting',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (isFasting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.green.withValues(alpha: 0.12)
                        : AppColors.accentOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    completed ? 'Complete' : '$goalHours:00 goal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: completed ? AppColors.green : AppColors.accentOrange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isFasting) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${elapsedH.toString().padLeft(2, '0')}:${elapsedM.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -1,
                    fontFamily: 'monospace',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4, left: 6),
                  child: Text(
                    'elapsed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.track,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed ? AppColors.green : AppColors.accentOrange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Started at ${start != null ? TimeOfDay.fromDateTime(start).format(context) : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('End fast?'),
                          content: const Text('This will stop your current fast early.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await widget.storage.stopFasting();
                                _load();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.missedRed,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('End fast'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(minHeight: 36),
                      decoration: BoxDecoration(
                        color: AppColors.undoRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'End fast',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.missedRed,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _showFastingGoalSheet(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    decoration: BoxDecoration(
                      color: AppColors.chipNeutral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings, size: 18, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: _fastingPreset('14:10', 14)),
                const SizedBox(width: 8),
                Expanded(child: _fastingPreset('16:8', 16)),
                const SizedBox(width: 8),
                Expanded(child: _fastingPreset('18:6', 18)),
                const SizedBox(width: 8),
                Expanded(child: _fastingPreset('20:4', 20)),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${goalHours}h fast / ${24 - goalHours}h eating window',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await widget.storage.startFasting();
                  _load();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start fasting',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
    final isSelected = widget.storage.fastingGoalHours == hours;
    return InkWell(
      onTap: () async {
        await widget.storage.saveFastingGoalHours(hours);
        HapticFeedback.lightImpact();
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : AppColors.chipNeutral,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  void _showStreakInfo(BuildContext context) {
    final streak = _streak;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              Text(
                streak > 0 ? '$streak day streak' : 'No active streak',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: streak > 0 ? AppColors.ink : AppColors.muted,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                streak > 0
                    ? 'Log a meal every day to keep it going.\nMiss a day and it resets to zero.'
                    : 'Log any meal today to start a streak.\nKeep logging daily to build it up.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
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
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set your fasting duration in hours',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                suffixText: 'hours',
                suffixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
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
                  backgroundColor: AppColors.ink,
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

  Widget _logMealSection() {
    final actions = [
      (Icons.center_focus_strong, 'Scan food', _openCapture),
      (Icons.photo_library_outlined, 'Upload photo', _openGallery),
      (Icons.qr_code_scanner, 'Barcode', _openBarcodeScanner),
      (Icons.edit_note, 'Add manually', _openManualEntry),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: PageView(
              controller: _logPageController,
              onPageChanged: (i) => setState(() => _logPageIndex = i),
              children: [
                // Page 1: first 3 actions
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _logOption(
                          icon: actions[i].$1,
                          label: actions[i].$2,
                          onTap: actions[i].$3,
                        ),
                      ),
                    ],
                  ],
                ),
                // Page 2: 4th action centered
                Center(
                  child: _logOption(
                    icon: actions[3].$1,
                    label: actions[3].$2,
                    onTap: actions[3].$3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          PaginationDots(count: 2, current: _logPageIndex),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MealPlanScreen(storage: widget.storage),
                ),
              );
              if (result == true) _load();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline, size: 18, color: AppColors.ink),
                  SizedBox(width: 8),
                  Text(
                    'Meal plans',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
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

  Widget _logOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.ink),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
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

  // ================= Placeholder tabs =================

  Widget _progressPage() => ProgressScreen(storage: widget.storage);

  Widget _groupsPage() => DiscoverScreen(storage: widget.storage);

  Widget _profilePage(Profile profile) {
    final bmi = profile.weightKg / ((profile.heightCm / 100) * (profile.heightCm / 100));
    final bmiLabel = bmi < 18.5
        ? 'Underweight'
        : bmi < 25
            ? 'Normal'
            : bmi < 30
                ? 'Overweight'
                : 'Obese';
    final bmiColor = bmi < 18.5
        ? AppColors.fat
        : bmi < 25
            ? AppColors.green
            : bmi < 30
                ? AppColors.accentOrange
                : AppColors.missedRed;

    final weightEntries = widget.storage.weightEntries;
    final recentWeights = weightEntries.length > 7
        ? weightEntries.sublist(weightEntries.length - 7)
        : weightEntries;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),

        // Avatar + name + email
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.chipBlue,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showNameEdit(profile),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          child: const Icon(Icons.edit, size: 14, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${profile.calorieGoal} kcal/day goal',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  if (_signedInEmail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _signedInEmail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Profile details card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              _profileRow('Sex', profile.sex == 'male' ? 'Male' : profile.sex == 'female' ? 'Female' : 'Other'),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow('Age', '${profile.age} years'),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow('Height', '${profile.heightCm.round()} cm'),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow('Weight', '${profile.weightKg.round()} kg'),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow(
                  'Target', profile.targetWeightKg == null ? '—' : '${profile.targetWeightKg!.round()} kg'),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow('Goal', profile.goal == 'lose'
                  ? 'Lose weight'
                  : profile.goal == 'gain'
                      ? 'Gain weight'
                      : 'Maintain'),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow('Workouts', switch (profile.workoutFreq) {
                '3to5' => '3–5 times / week',
                '6plus' => '6+ times / week',
                '1to2' => '1–2 times / week',
                'none' => 'No workouts',
                _ => '0–2 times / week',
              }),
              const Divider(height: 1, color: AppColors.divider),
              _profileRow('Daily calories', '${profile.calorieGoal} kcal'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Edit calorie goal button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCalorieGoalEdit(profile),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit calorie goal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // BMI card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bmiColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.monitor_weight_outlined, size: 24, color: bmiColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          bmi.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: bmiColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bmiLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: bmiColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Weight history
        if (recentWeights.isNotEmpty) ...[
          const Text(
            'Weight history',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                // Mini chart
                SizedBox(
                  height: 60,
                  child: _MiniWeightChart(entries: recentWeights),
                ),
                const SizedBox(height: 10),
                // Latest entries
                ...recentWeights.reversed.take(5).map((e) {
                  final idx = recentWeights.indexOf(e);
                  final prev = idx > 0 ? recentWeights[idx - 1] : null;
                  final diff = prev != null ? e.weightKg - prev.weightKg : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${e.date.day}/${e.date.month}',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${e.weightKg.round()} kg',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const Spacer(),
                        if (diff != 0)
                          Text(
                            '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: diff < 0 ? AppColors.green : AppColors.missedRed,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Settings
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              _settingsRow(
                icon: Icons.notifications_active_outlined,
                label: 'Reminders',
                subtitle: widget.storage.remindersEnabled
                    ? 'Water & meal reminders on'
                    : 'Off',
                onTap: () async => _toggleReminders(),
              ),
              const Divider(height: 1, color: AppColors.divider),
              _settingsRow(
                icon: Icons.share_outlined,
                label: 'Export data',
                subtitle: 'Download your logs as JSON',
                onTap: _exportData,
              ),
              const Divider(height: 1, color: AppColors.divider),
              _settingsRow(
                icon: Icons.restart_alt,
                label: 'Reset goals',
                subtitle: 'Start the questionnaire over',
                onTap: _confirmResetGoals,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Calorie Tracker v0.9.0',
            style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _signOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.missedRed,
            side: BorderSide(color: AppColors.missedRed.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Future<void> _showCalorieGoalEdit(Profile profile) async {
    final controller = TextEditingController(text: '${profile.calorieGoal}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit calorie goal',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            suffixText: 'kcal/day',
            hintText: '1500',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final val = int.tryParse(v.trim());
            if (val != null && val > 0) Navigator.pop(ctx, val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      final updated = profile.copyWith(calorieGoalOverride: result);
      await widget.storage.saveProfile(updated);
      _load();
    }
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.ink),
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
                      color: AppColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _showNameEdit(Profile profile) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit name',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'Your name',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != profile.name) {
      final updated = profile.copyWith(name: result);
      await widget.storage.saveProfile(updated);
      _load();
    }
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

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -3.14159 / 2,
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

class _MiniWeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  const _MiniWeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return const Center(
        child: Text('Need 2+ entries for a trend', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      );
    }

    final weights = entries.map((e) => e.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;

    return CustomPaint(
      size: const Size(double.infinity, 60),
      painter: _MiniWeightChartPainter(
        weights: weights,
        minWeight: minW,
        range: range,
      ),
    );
  }
}

class _MiniWeightChartPainter extends CustomPainter {
  final List<double> weights;
  final double minWeight;
  final double range;

  _MiniWeightChartPainter({
    required this.weights,
    required this.minWeight,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.length < 2 || range <= 0) return;

    final path = Path();
    final step = size.width / (weights.length - 1);

    for (int i = 0; i < weights.length; i++) {
      final x = i * step;
      final y = size.height - ((weights[i] - minWeight) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.accentOrange.withValues(alpha: 0.1),
    );

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accentOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    final dotPaint = Paint()..color = AppColors.accentOrange;
    for (int i = 0; i < weights.length; i++) {
      final x = i * step;
      final y = size.height - ((weights[i] - minWeight) / range * size.height);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniWeightChartPainter old) =>
      old.weights != weights || old.minWeight != minWeight || old.range != range;
}
