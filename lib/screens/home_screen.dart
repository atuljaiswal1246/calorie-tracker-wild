import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/achievements_service.dart';
import '../services/activity_service.dart';
import '../services/asha_prompts.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
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
import 'asha_screen.dart';
import 'quick_picks_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final AuthService auth;
  final VoidCallback onSignedOut;
  final VoidCallback onResetGoals;

  HomeScreen({
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
  late ActivityService _activity;
  String? _profilePhotoPath;
  final _picker = ImagePicker();
  int _stepsToday = 0;
  StepsSource _stepsSource = StepsSource.manual;
  StreamSubscription<int>? _activitySub;
  List<ExerciseEntry> _todayExercises = [];
  bool _enablingSteps = false;

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
    _activity = ActivityService(widget.storage);
    _activitySub = _activity.changes.listen((steps) {
      if (mounted) setState(() => _stepsToday = steps);
    });
    _todayExercises = _activity.todayExercises();
    // NO auto init: step-tracking permissions are opt-in (see card button).
    // Water reminders default ON: ensure they're scheduled any app start.
    if (widget.storage.remindersEnabled) {
      NotificationService.requestPermissions();
      NotificationService.scheduleAll(
        water: true,
        meal: widget.storage.mealRemindersEnabled,
      );
    }
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
    _activitySub?.cancel();
    _activity.dispose();
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
    _profilePhotoPath = widget.storage.photoPath;
    setState(() {});
    WidgetService.push(widget.storage);
  }

  Future<void> _changeProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppColors.ink),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppColors.ink),
              title: Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = '${appDir.path}/$fileName';
      final saved = await File(picked.path).copy(dest);
      await widget.storage.savePhotoPath(saved.path);
      if (mounted) setState(() => _profilePhotoPath = saved.path);
    } catch (_) {
      // Keep initials if the copy fails.
    }
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
      day = day.subtract(Duration(days: 1));
    }

    while (_calories(day) > 0) {
      streak++;
      day = day.subtract(Duration(days: 1));
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Log a meal',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.photo_camera, size: 28, color: AppColors.ink),
                            SizedBox(height: 8),
                            Text('Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
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
    final picked = await picker.pickMultiImage(
      maxWidth: 800,
      imageQuality: 70,
      limit: 5,
    );
    if (picked.isEmpty) return;
    if (!mounted) return;
    final files = picked.map((x) => File(x.path)).toList();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          storage: widget.storage,
          initialImage: files.length == 1 ? files.first : null,
          initialImages: files.length > 1 ? files : null,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete meal?'),
        content: Text(
          entry.items.isEmpty
              ? 'This will remove the meal from your log.'
              : '"${entry.items.first.name}" and ${entry.items.length - 1} other item(s) will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.missedRed)),
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
      return Scaffold(body: Center(child: Text('No profile found')));
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
                avatarPhotoPath: _profilePhotoPath,
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
      padding: EdgeInsets.symmetric(horizontal: 28),
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
            child: Center(
              child: Text('🔒', style: TextStyle(fontSize: 40)),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Your free trial has ended',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Unlock unlimited food analysis and all features with a subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.5),
          ),
          SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _openPricing,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkButton,
                foregroundColor: Colors.white,
                shape: StadiumBorder(),
              ),
              child: Text(
                'Unlock — ₹100/mo or ₹1,000/yr',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: () => _billing?.restore(),
            child: Text(
              'Restore purchase',
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
        padding: EdgeInsets.fromLTRB(20, 20, 20, 150),
        children: [
          _greeting(profile),
          SizedBox(height: 14),
          _header(),
          if (!_isOnline) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
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
          SizedBox(height: 22),
          // Asha — always visible, chat-style prompt on Home
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AshaScreen(storage: widget.storage),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome,
                        size: 21, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Asha',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        _AshaTicker(),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          _weekSelector(calorieGoal: goal),
          SizedBox(height: 20),
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
          SizedBox(height: 14),
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
                    SizedBox(width: 10),
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
                    SizedBox(width: 10),
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
                    SizedBox(width: 10),
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
                    SizedBox(width: 10),
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
          SizedBox(height: 14),
          PaginationDots(count: 2, current: _macroPageIndex),
          SizedBox(height: 22),
          _activityCard(),
          SizedBox(height: 14),
          _logMealSection(),
          SizedBox(height: 22),
          _waterCard(),
          SizedBox(height: 16),
          _fastingCard(),
          SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
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
                child: Padding(
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
          SizedBox(height: 12),
          if (recent.isEmpty)
            EmptyCard(onScanTap: _openCapture)
          else
            ...recent.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: MealCard(
                    entry: e,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MealDetailScreen(
                            entry: e,
                            storage: widget.storage,
                            onDeleted: () => _deleteEntry(e),
                          ),
                        ),
                      );
                      _load();
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.muted,
        ),
        children: [
          TextSpan(text: '$_greetingText, '),
          TextSpan(
            text: profile.name.split(' ').first,
            style: TextStyle(
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
            color: AppColors.inkButton,
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
        SizedBox(width: 10),
        Text(
          'Cal Matters',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        Spacer(),
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
            padding: EdgeInsets.all(10),
            constraints: BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(Icons.insights_rounded, size: 17, color: AppColors.ink),
          ),
        ),
        SizedBox(width: 6),
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AchievementsScreen(storage: widget.storage),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Text('🏆', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Text(
                  '${AchievementsService(widget.storage).unlockedCount}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 6),
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
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Text('🔥', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 4),
                  Text(
                    '$_streak',
                    style: TextStyle(
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
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
          physics: BouncingScrollPhysics(),
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
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selected = day),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    padding: EdgeInsets.symmetric(vertical: 4),
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
                        SizedBox(height: 2),
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

  Widget _activityCard() {
    const stepGoal = 8000;
    final steps = _stepsToday;
    final progress = (steps / stepGoal).clamp(0.0, 1.0);
    final kcals = _todayExercises.fold(0, (s, e) => s + e.calories);
    final minutes = _todayExercises.fold(0, (s, e) => s + e.minutes);

    return Container(
      padding: EdgeInsets.all(16),
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
              Text(
                'Activity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _stepsEnabled ? _activity.sourceLabel : 'Tap to track',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: AppColors.green.withValues(alpha: 0.15),
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.green),
                    ),
                    Center(
                      child: Icon(Icons.directions_walk,
                          size: 17, color: AppColors.green),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${steps.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')} / $stepGoal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'steps today',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (_enablingSteps)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.ink,
                    ),
                  ),
                )
              else if (!_stepsEnabled)
                TextButton.icon(
                  onPressed: _enableSteps,
                  icon: Icon(Icons.auto_awesome, size: 15),
                  label: Text('Track'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.green,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: _stepsSource == StepsSource.healthConnect
                      ? null
                      : _manualStepsDialog,
                  icon: Icon(Icons.edit, size: 15),
                  label: Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    disabledForegroundColor: AppColors.muted,
                  ),
                ),
            ],
          ),
          Divider(height: 22, color: AppColors.divider),
          Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  kcals > 0
                      ? '$kcals kcal burned · $minutes min today'
                      : 'No workouts logged today',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addExerciseSheet,
                icon: Icon(Icons.add, size: 17),
                label: Text('Exercise'),
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              ),
            ],
          ),
          if (_todayExercises.isNotEmpty) ...[
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _todayExercises
                  .map(
                    (e) => GestureDetector(
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: Text(e.name),
                            content: Text(
                                '${e.minutes} min · ${e.calories} kcal\nRemove this workout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Keep'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Remove',
                                    style:
                                        TextStyle(color: AppColors.missedRed)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && mounted) {
                          await _activity.deleteExercise(e.id);
                          setState(() {
                            _todayExercises = _activity.todayExercises();
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${e.name.split(' ').first} · ${e.minutes}m · ${e.calories}k',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// True once the user opted into step tracking (or it degraded to manual).
  bool get _stepsEnabled =>
      _stepsSource != StepsSource.manual || _stepsToday > 0;

  Future<void> _enableSteps() async {
    if (_enablingSteps) return;
    setState(() => _enablingSteps = true);
    try {
      final source = await _activity.enableTracking();
      if (!mounted) return;
      setState(() {
        _stepsSource = source;
        _stepsToday = widget.storage.getStepsFor(DateTime.now());
      });
      if (source == StepsSource.manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No step sensor found — use "Add" to log steps manually.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enablingSteps = false);
    }
  }

  Future<void> _manualStepsDialog() async {
    final ctrl = TextEditingController();
    final val = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add steps'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'e.g. 2500'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 0),
            child: Text('Add'),
          ),
        ],
      ),
    );
    if (val != null && val > 0 && mounted) {
      await _activity.addManualSteps(val);
    }
  }

  Future<void> _addExerciseSheet() async {
    final result = await showModalBottomSheet<ExerciseEntry>(
      context: context,
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _ExerciseSheet(activity: _activity),
    );
    if (result != null && mounted) {
      setState(() {
        _todayExercises = _activity.todayExercises();
      });
    }
  }

  Widget _waterCard() {
    final progress = _waterGoalMl > 0 ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.all(16),
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
              Row(
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  if (_waterMl > 0) ...[
                    SizedBox(width: 6),
                    GestureDetector(
                      onTap: () async {
                        await widget.storage.undoLastWater();
                        _load();
                      },
                      child: Icon(Icons.undo, size: 14, color: AppColors.missedRed),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.track,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.fat),
              ),
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              _waterButton(250, Icons.water_drop),
              SizedBox(width: 8),
              _waterButton(500, Icons.water_drop),
              SizedBox(width: 8),
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
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: AppColors.chipBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.fat),
              SizedBox(width: 4),
              Text(
                '+${ml}ml',
                style: TextStyle(
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
              title: Text('Add water'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  suffixText: 'ml',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel'),
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
                        SnackBar(
                          content: Text('Enter a value between 1–2000 ml'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text('Add'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: AppColors.chipNeutral,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
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
      padding: EdgeInsets.all(16),
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
              Row(
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          SizedBox(height: 12),
          if (isFasting) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${elapsedH.toString().padLeft(2, '0')}:${elapsedM.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -1,
                    fontFamily: 'monospace',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
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
            SizedBox(height: 10),
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
            SizedBox(height: 4),
            Text(
              'Started at ${start != null ? TimeOfDay.fromDateTime(start).format(context) : ''}',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('End fast?'),
                          content: Text('This will stop your current fast early.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Cancel'),
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
                              child: Text('End fast'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(minHeight: 36),
                      decoration: BoxDecoration(
                        color: AppColors.undoRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
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
                SizedBox(width: 10),
                InkWell(
                  onTap: () => _showFastingGoalSheet(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    constraints: BoxConstraints(minWidth: 44, minHeight: 44),
                    decoration: BoxDecoration(
                      color: AppColors.chipNeutral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.settings, size: 18, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(child: _fastingPreset('14:10', 14)),
                SizedBox(width: 8),
                Expanded(child: _fastingPreset('16:8', 16)),
                SizedBox(width: 8),
                Expanded(child: _fastingPreset('18:6', 18)),
                SizedBox(width: 8),
                Expanded(child: _fastingPreset('20:4', 20)),
              ],
            ),
            SizedBox(height: 4),
            Center(
              child: Text(
                '${goalHours}h fast / ${24 - goalHours}h eating window',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await widget.storage.startFasting();
                  _load();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.inkButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
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
        padding: EdgeInsets.symmetric(vertical: 10),
        constraints: BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.inkButton : AppColors.chipNeutral,
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
        insetPadding: EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔥', style: TextStyle(fontSize: 32)),
              SizedBox(height: 10),
              Text(
                streak > 0 ? '$streak day streak' : 'No active streak',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: streak > 0 ? AppColors.ink : AppColors.muted,
                ),
              ),
              SizedBox(height: 14),
              Text(
                streak > 0
                    ? 'Log a meal every day to keep it going.\nMiss a day and it resets to zero.'
                    : 'Log any meal today to start a streak.\nKeep logging daily to build it up.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.inkButton,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
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
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fasting Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Set your fasting duration in hours',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                suffixText: 'hours',
                suffixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.ink, width: 2),
                ),
              ),
            ),
            SizedBox(height: 20),
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
                  backgroundColor: AppColors.inkButton,
                  foregroundColor: Colors.white,
                  shape: StadiumBorder(),
                ),
                child: Text(
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
      (Icons.edit_note, 'Add manually', _openManualEntry),
      (Icons.qr_code_2, 'Barcode', _openBarcodeScanner),
      (Icons.restaurant_menu, 'Popular dishes', _openQuickPicks),
    ];

    return Container(
      padding: EdgeInsets.all(16),
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
                      if (i > 0) SizedBox(width: 10),
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
                // Page 2: Barcode + Popular dishes — SAME 1/3 width as page-1 tiles
                Row(
                  children: [
                    Expanded(
                      child: _logOption(
                        icon: actions[3].$1,
                        label: actions[3].$2,
                        onTap: actions[3].$3,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _logOption(
                        icon: actions[4].$1,
                        label: actions[4].$2,
                        onTap: actions[4].$3,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: SizedBox()),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          PaginationDots(count: 2, current: _logPageIndex),
          SizedBox(height: 12),
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
              padding: EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.ink),
            SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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

  Future<void> _openQuickPicks() async {
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickPicksScreen(storage: widget.storage),
      ),
    );
    if (saved == true) _load();
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
      padding: EdgeInsets.fromLTRB(20, 24, 20, 150),
      children: [
        Text(
          'Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 20),

        // Avatar + name + email
        Row(
          children: [
            GestureDetector(
              onTap: _changeProfilePhoto,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.cardSelected,
                  shape: BoxShape.circle,
                ),
                child: _profilePhotoPath != null &&
                        File(_profilePhotoPath!).existsSync()
                    ? Image.file(
                        File(_profilePhotoPath!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      )
                    : Text(
                        _initials,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 14),
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
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showNameEdit(profile),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          constraints: BoxConstraints(minWidth: 44, minHeight: 44),
                          child: Icon(Icons.edit, size: 14, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    '${profile.calorieGoal} kcal/day goal',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  if (_signedInEmail != null) ...[
                    SizedBox(height: 3),
                    Text(
                      _signedInEmail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 24),

        // Profile details card
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              _profileRow('Sex', profile.sex == 'male' ? 'Male' : profile.sex == 'female' ? 'Female' : 'Other'),
              Divider(height: 1, color: AppColors.divider),
              _profileRow('Age', '${profile.age} years'),
              Divider(height: 1, color: AppColors.divider),
              _profileRow('Height', '${profile.heightCm.round()} cm'),
              Divider(height: 1, color: AppColors.divider),
              _profileRow('Weight', '${profile.weightKg.round()} kg'),
              Divider(height: 1, color: AppColors.divider),
              _profileRow(
                  'Target', profile.targetWeightKg == null ? '—' : '${profile.targetWeightKg!.round()} kg'),
              Divider(height: 1, color: AppColors.divider),
              _profileRow('Goal', profile.goal == 'lose'
                  ? 'Lose weight'
                  : profile.goal == 'gain'
                      ? 'Gain weight'
                      : 'Maintain'),
              Divider(height: 1, color: AppColors.divider),
              _profileRow('Workouts', switch (profile.workoutFreq) {
                '3to5' => '3–5 times / week',
                '6plus' => '6+ times / week',
                '1to2' => '1–2 times / week',
                'none' => 'No workouts',
                _ => '0–2 times / week',
              }),
              Divider(height: 1, color: AppColors.divider),
              _profileRow('Daily calories', '${profile.calorieGoal} kcal'),
            ],
          ),
        ),
        SizedBox(height: 12),

        // Edit calorie goal button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCalorieGoalEdit(profile),
            icon: Icon(Icons.edit, size: 16),
            label: Text('Edit calorie goal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        SizedBox(height: 24),

        // BMI card
        Container(
          padding: EdgeInsets.all(16),
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
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    SizedBox(height: 2),
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
                        SizedBox(width: 8),
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
        SizedBox(height: 24),

        // Weight history
        if (recentWeights.isNotEmpty) ...[
          Text(
            'Weight history',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(16),
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
                SizedBox(height: 10),
                // Latest entries
                ...recentWeights.reversed.take(5).map((e) {
                  final idx = recentWeights.indexOf(e);
                  final prev = idx > 0 ? recentWeights[idx - 1] : null;
                  final diff = prev != null ? e.weightKg - prev.weightKg : 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${e.date.day}/${e.date.month}',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '${e.weightKg.round()} kg',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Spacer(),
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
        SizedBox(height: 24),

        // Settings — single entry into the dedicated Settings screen
        InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  storage: widget.storage,
                  onResetGoals: () {
                    Navigator.of(context).pop();
                    widget.onResetGoals();
                  },
                  onSignOut: () async {
                    await widget.auth.signOut();
                    if (!mounted) return;
                    widget.onSignedOut();
                  },
                ),
              ),
            );
            _load();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.settings_outlined,
                      size: 20, color: AppColors.ink),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: AppColors.muted),
              ],
            ),
          ),
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
        title: Text(
          'Edit calorie goal',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
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
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) Navigator.pop(ctx, val);
            },
            child: Text('Save'),
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
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.muted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNameEdit(Profile profile) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit name',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: 'Your name',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save'),
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
  _MiniWeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Center(
        child: Text('Need 2+ entries for a trend', style: TextStyle(fontSize: 12, color: AppColors.muted)),
      );
    }

    final weights = entries.map((e) => e.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;

    return CustomPaint(
      size: Size(double.infinity, 60),
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

/// Rotating Asha prompt on the Home card — a new wild question every
/// few seconds so it always feels alive. Changes call attention to her
/// ("wait, what?") — screenshot/Reel bait.
class _AshaTicker extends StatefulWidget {
  @override
  State<_AshaTicker> createState() => _AshaTickerState();
}

class _AshaTickerState extends State<_AshaTicker> {
  String _text = AshaPrompts.next();
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 8), (_) {
      setState(() {
        _tick++;
        _text = AshaPrompts.next(tick: _tick);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 400),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 0.35),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        _text,
        key: ValueKey(_text),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: Colors.white.withValues(alpha: 0.9),
          height: 1.3,
        ),
      ),
    );
  }
}

/// Bottom sheet: pick an activity, duration; logs with MET-based kcal.
class _ExerciseSheet extends StatefulWidget {
  final ActivityService activity;

  _ExerciseSheet({required this.activity});

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  String _selected = ActivityService.activities.first.name;
  int _minutes = 30;

  int get _kcal {
    final weight = widget.activity.storage.profile?.weightKg ?? 70.0;
    double met = 5.0;
    for (final a in ActivityService.activities) {
      if (a.name == _selected) met = a.met;
    }
    return (met * weight * (_minutes / 60)).round();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log exercise',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 14),
              SizedBox(
                height: 230,
                child: ListView.separated(
                  itemCount: ActivityService.activities.length,
                  separatorBuilder: (_, __) => SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final a = ActivityService.activities[i];
                    final active = a.name == _selected;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = a.name),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: active ? AppColors.inkButton : AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(a.emoji, style: TextStyle(fontSize: 18)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                a.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                            if (active)
                              Icon(Icons.check,
                                  size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Duration',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [15, 30, 45, 60].map((m) {
                  final active = m == _minutes;
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _minutes = m),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.inkButton : AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$m min',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '≈ $_kcal kcal burned',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkButton,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final entry =
                          await widget.activity.logExercise(_selected, _minutes);
                      if (context.mounted) Navigator.pop(context, entry);
                    },
                    child: Text('Log'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
