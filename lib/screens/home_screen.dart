import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/features.dart';
import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/achievements_service.dart';
import '../services/activity_service.dart';
import '../services/asha_prompts.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../models/quest.dart';
import '../models/shop.dart';
import '../services/analytics_service.dart';
import '../services/celebration_service.dart';
import '../services/experiment_service.dart';
import '../services/funnel.dart';
import '../services/gamification_controller.dart';
import '../services/notification_coordinator.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../services/weekly_summary_service.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';
import 'achievements_screen.dart';
import 'barcode_scanner_screen.dart';
import 'gamification_hub_screen.dart';
import 'insights_screen.dart';
import 'capture_screen.dart';
import 'manual_entry_screen.dart';
import 'meal_detail_screen.dart';
import 'macro_breakdown_screen.dart';
import 'pricing_screen.dart';
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
  int _navIndex = 0; // 0 home, 1 progress, 2 profile
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
  bool _enablingSteps = false;

  GamificationController? get _gami => GamificationController.instance;

  /// The shop frame the user has equipped (null = none).
  String? get _profileFrame => ShopInventory.fromJson(
        widget.storage.shopInventoryRaw ?? const {},
      ).profileFrame;

  Color? get _frameColor => switch (_profileFrame) {
        'frame_bronze' => const Color(0xFFCD7F32),
        'frame_silver' => const Color(0xFFB0B0B0),
        'frame_gold' => const Color(0xFFFFC107),
        'frame_seasonal' => AppColors.green,
        _ => null,
      };

  /// Streak shown in the UI: the multi-action gamification streak when the
  /// controller is live, otherwise the legacy meal-only count.
  int get _displayStreak => _gami?.streak ?? _streak;

  /// A/B variant for how the streak pill is labelled.
  String get _streakLabel => ExperimentService.verboseStreak
      ? '$_displayStreak days'
      : '$_displayStreak';

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
    Funnel.homeReached();
    _profile = widget.storage.profile;
    _weekScrollController = ScrollController(
      initialScrollOffset: 59 * 60.0,
    );
    _load();
    _activity = ActivityService(widget.storage);
    _activitySub = _activity.changes.listen((steps) {
      if (mounted) setState(() => _stepsToday = steps);
    });
    // NO auto init: step-tracking permissions are opt-in (see card button).
    // Water reminders default ON: ensure they're scheduled any app start.
    if (widget.storage.remindersEnabled) {
      NotificationService.requestPermissions();
      NotificationService.scheduleAll(
        water: true,
        meal: widget.storage.mealRemindersEnabled,
      );
      // State-based nudge from the notification engine (plan §5).
      NotificationCoordinator.refresh(widget.storage);
    }
    _billing = BillingService(widget.storage);
    _billing!.onStatusChanged = () {
      if (!mounted) return;
      _load();
    };
    // Best-effort: if the platform connectivity stream is unavailable (a
    // plugin failure, or a platform that doesn't implement it) the app must
    // still work — assume online and move on rather than surfacing an error.
    try {
      _connectivityStream = Connectivity().onConnectivityChanged;
      _connectivityStream.listen(
        (results) {
          final online = results.any((r) => r != ConnectivityResult.none);
          if (mounted && online != _isOnline) {
            setState(() => _isOnline = online);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}

    GamificationController.instance?.revision.addListener(_onGamificationChanged);
    AnalyticsService.log('experiment_exposure', {
      'experiment': ExperimentService.streakDisplay,
      'variant': ExperimentService.streakDisplayVariant(),
    });
  }

  void _onGamificationChanged() {
    if (!mounted) return;
    setState(() {});
    _drainCelebrations();
  }

  /// Surface queued reward moments: full-screen for level-ups and streak
  /// milestones, floating toasts for everything else (plan §4.8).
  void _drainCelebrations() {
    final gami = _gami;
    if (gami == null) return;
    CelebrationEvent? event;
    while ((event = gami.takeCelebration()) != null) {
      CelebrationService.celebrate(context, event!);
    }
  }

  @override
  void dispose() {
    GamificationController.instance?.revision
        .removeListener(_onGamificationChanged);
    _activitySub?.cancel();
    _activity.dispose();
    _billing?.dispose();
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

  /// True once the user opted into step tracking (or degraded to manual).
  bool get _stepsEnabled =>
      _stepsSource != StepsSource.manual || _stepsToday > 0;

  void _showStreakInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Your streak'),
        content: Text(
          '$_displayStreak day streak — keep the fire alive.\n\n'
          'Log a meal, water, weight or exercise on a day to keep it going.'
          '${(_gami?.freezes ?? 0) > 0 ? '\n\n❄️ ${_gami!.freezes} streak '
              'freeze${_gami!.freezes == 1 ? '' : 's'} will cover a rest day.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nice'),
          ),
        ],
      ),
    );
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
                2 => _profilePage(profile),
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
    final proteinGoal = profile.proteinGrams;

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () async => _load(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 150),
        children: [
          _header(profile),
          if (_entries.isEmpty) ...[
            SizedBox(height: 16),
            _firstLogCard(),
          ],
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
          // Asha — concierge (adaptive by time of day, tap = chat).
          // Parked behind Features.asha while the core loop is perfected.
          if (Features.asha) ...[
            _ashaConcierge(),
            SizedBox(height: 16),
          ],
          _weekSelector(calorieGoal: goal),
          SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _dayHeroTile(profile)),
              SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _smallTile(
                      icon: Symbols.egg,
                      iconColor: AppColors.protein,
                      label: 'Protein',
                      value:
                          '${_protein(_selected).round()} / ${proteinGoal.round()}g',
                      sub: 'log more protein today',
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
                    SizedBox(height: 10),
                    _stepsTile(),
                    SizedBox(height: 10),
                    _waterTile(),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          _questCard(),
          SizedBox(height: 22),
          _whatsCooking(),
          SizedBox(height: 22),
          _bodyStrip(),
          SizedBox(height: 14),
          _weeklyTeaser(),
          SizedBox(height: 22),
          _recentSection(),
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
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          letterSpacing: -0.3,
        ),
        children: [
          TextSpan(text: '$_greetingText, '),
          TextSpan(
            text: profile.name.split(' ').first,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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

  /// Home header: the greeting is the page title (the app name lives on the
  /// welcome screen — repeating it here squeezed the status pills off narrow
  /// Android phones), with the user's status pills on the right.
  Widget _header(Profile profile) {
    return Row(
      children: [
        Expanded(child: _greeting(profile)),
        SizedBox(width: 8),
        _insightsPill(),
        SizedBox(width: 6),
        _achievementsPill(),
        SizedBox(width: 6),
        _streakPill(),
      ],
    );
  }

  Widget _insightsPill() {
    return InkWell(
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
    );
  }

  Widget _achievementsPill() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AchievementsScreen(storage: widget.storage),
          ),
        );
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
            Icon(Symbols.emoji_events_rounded,
                size: 15, color: AppColors.accentOrange),
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
    );
  }

  Widget _streakPill() {
    return Semantics(
      label: '$_displayStreak day streak. Tap for details.',
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
              Icon(Symbols.local_fire_department_rounded,
                  size: 15, color: AppColors.accentOrange),
              SizedBox(width: 4),
              Text(
                _streakLabel,
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
    );
  }

  Widget _questCard() {
    final gami = _gami;
    if (gami == null || gami.activeQuests.isEmpty) return const SizedBox.shrink();
    final quests = gami.activeQuests;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GamificationHubScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
              children: [
                Text('📋', style: TextStyle(fontSize: 15)),
                SizedBox(width: 8),
                Text(
                   "Today's quests",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Spacer(),
                Text(
                  '${gami.questsCompleted}/${quests.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '🌱 Level ${gami.level} · ${gami.levelTitle}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                Spacer(),
                Text(
                  '+${gami.todayPoints} pts today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...quests.map(_questRow),
          ],
        ),
      ),
    );
  }

  Widget _questRow(ActiveQuest q) {
    return Semantics(
      label: '${q.template.title}, ${q.current} of ${q.target}'
          '${q.completed ? ', completed' : ''}, worth ${q.calPoints} Cal Points',
      child: Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: q.completed ? AppColors.green : AppColors.cardAlt,
            ),
            child: Icon(
              q.completed ? Icons.check_rounded : Icons.circle_outlined,
              size: 14,
              color: q.completed ? Colors.white : AppColors.faint,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.template.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: q.completed ? AppColors.muted : AppColors.ink,
                    decoration:
                        q.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: q.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.cardAlt,
                    valueColor: AlwaysStoppedAnimation(
                      q.completed ? AppColors.green : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Text(
            '+${q.calPoints}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
      ),
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

  Widget _firstLogCard() {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _openCapture();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.camera_alt_rounded,
                  size: 22, color: AppColors.ink),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log your first meal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Snap a photo — we estimate the calories and macros.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  /// Asha concierge card — time-aware openers, tap straight into chat.
  Widget _ashaConcierge() {
    final h = DateTime.now().hour;
    final opener = h < 11
        ? 'Subah-subah! What\'s on the plate today?'
        : h < 16
            ? 'Lunch o\'clock — kab kha rahe ho?'
            : h < 21
                ? 'Dinner call, or a midnight snack? 😏'
                : 'Night mode: chai? 2 roti? Tell me.';
    return InkWell(
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
              child: Icon(Icons.auto_awesome, size: 21, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asha',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    opener,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  SizedBox(height: 2),
                  _AshaTicker(),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  /// Big hero: day ring, streak, carbs/fat, macro pills (fiber/sugar/sodium).
  Widget _dayHeroTile(Profile profile) {
    final logged = _calories(_selected);
    final goal = profile.calorieGoal;
    final progress = goal > 0 ? (logged / goal).clamp(0.0, 1.0) : 0.0;

    return InkWell(
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 9,
                        backgroundColor: AppColors.track,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.ink),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 17)),
                            SizedBox(height: 2),
                            Text(
                              '$_streak',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$logged',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '/ $goal kcal',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '$_streak-day streak',
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Carbs ${_carbs(_selected).round()}g · '
              'Fat ${_fat(_selected).round()}g · '
              'Fiber ${_on(_selected).fold(0.0, (s, e) => s + e.totalFiber).round()}g',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _macroPill(
                  'Sugar',
                  '${_on(_selected).fold(0.0, (s, e) => s + e.totalSugar).round()}g',
                  AppColors.sugar,
                  () => _openMacro(MacroType.sugar,
                      _on(_selected).fold(0.0, (s, e) => s + e.totalSugar),
                      _sugarTarget.toDouble(), AppColors.sugar),
                ),
                SizedBox(width: 6),
                _macroPill(
                  'Sodium',
                  '${_sodiumKcal().round()}mg',
                  AppColors.sodium,
                  () => _openMacro(MacroType.sodium, _sodiumKcal(),
                      _sodiumTarget.toDouble(), AppColors.sodium),
                ),
                SizedBox(width: 6),
                _macroPill(
                  'Burn',
                  '${_activity.todayExercises().fold(0, (s, e) => s + e.calories)} kcal',
                  AppColors.accentOrange,
                  () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _sodiumKcal() =>
      _on(_selected).fold(0.0, (s, e) => s + e.totalSodium);

  void _openMacro(MacroType type, double total, double target, Color color) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MacroBreakdownScreen(
          macroType: type,
          entries: _on(_selected),
          total: total,
          target: target,
          color: color,
        ),
      ),
    );
  }

  Widget _macroPill(String label, String value, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: iconColor),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepsTile() {
    return InkWell(
      onTap: _stepsEnabled ? null : _enableSteps,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_walk, size: 15, color: AppColors.green),
                SizedBox(width: 6),
                Text(
                  'Steps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                Spacer(),
                if (!_stepsEnabled)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Track',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '${_stepsToday} / 8000',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: 2),
            Text(
              'steps today',
              style: TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                if (_stepsEnabled && _stepsSource != StepsSource.healthConnect)
                  InkWell(
                    onTap: _manualStepsDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+ Add',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                SizedBox(width: 6),
                InkWell(
                  onTap: () => _addExerciseSheet(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🏃 + Exercise',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _waterTile() {
    return InkWell(
      onTap: _openWaterSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, size: 15, color: AppColors.water),
                SizedBox(width: 6),
                Text(
                  'Water',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '${(_waterMl / 1000).toStringAsFixed(1)} / ${(_waterGoalMl / 1000).toStringAsFixed(1)} L',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: 2),
            Text(
              'tap to add glass',
              style: TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWaterSheet() async {
    final ml = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add water',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  _sheetWaterBtn(250),
                  SizedBox(width: 8),
                  _sheetWaterBtn(500),
                  SizedBox(width: 8),
                  _sheetWaterBtn(750),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ml != null && ml > 0) {
      await widget.storage.addWater(ml);
      HapticFeedback.lightImpact();
      _load();
    }
  }

  Widget _sheetWaterBtn(int ml) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.pop(context, ml),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.chipBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '+${ml}ml',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.water,
            ),
          ),
        ),
      ),
    );
  }

  /// What's Cooking — the frictionless log zone.
  Widget _whatsCooking() {
    final recent = widget.storage.recentFoods.take(4).toList();
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
            children: [
              Text('🍳', style: TextStyle(fontSize: 14)),
              SizedBox(width: 7),
              Text(
                'What\'s cooking?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _logCta(
                  icon: Icons.center_focus_strong,
                  label: 'Scan food',
                  primary: true,
                  onTap: _openCapture,
                ),
              ),
              SizedBox(width: 8),
              _logCta(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: _openGallery,
              ),
              SizedBox(width: 8),
              _logCta(
                icon: Icons.restaurant_menu,
                label: 'Quick picks',
                onTap: _openQuickPicks,
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: _openManualEntry,
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  'Add manually',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              SizedBox(width: 16),
              InkWell(
                onTap: _openBarcodeScanner,
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  'Barcode scan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'One-tap from your usuals:',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recent.map((f) {
                return InkWell(
                  onTap: () => _quickLog(f),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${f['name']} · ${f['calories']} kcal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _logCta({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: primary ? AppColors.inkButton : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: primary ? Colors.white : AppColors.ink),
            SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primary ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickLog(Map<String, dynamic> f) async {
    final item = FoodItem(
      name: f['name'] as String? ?? 'Food',
      calories: (f['calories'] as num?)?.toInt() ?? 100,
      protein: (f['protein'] as num?)?.toDouble() ?? 0,
      carbs: (f['carbs'] as num?)?.toDouble() ?? 0,
      fat: (f['fat'] as num?)?.toDouble() ?? 0,
      quantity: 1,
    );
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _autoMeal(),
      items: [item],
      imagePath: '',
    );
    await widget.storage.addEntry(entry);
    HapticFeedback.lightImpact();
    _load();
  }

  String _autoMeal() {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 21) return 'dinner';
    return 'snack';
  }

  /// Body story — weight/waist trendline nudge.
  Widget _bodyStrip() {
    final weights = widget.storage.weightEntries;
    final latestW = weights.isNotEmpty ? weights.last.weightKg : null;
    final firstW = weights.isNotEmpty ? weights.first.weightKg : null;
    final deltaW =
        (latestW != null && firstW != null) ? latestW - firstW : null;
    final bodies = widget.storage.bodyMeasurements;
    final latestWaist = bodies.isNotEmpty ? bodies.first.waist : null;

    return InkWell(
      onTap: () => setState(() => _navIndex = 1),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Text('📏', style: TextStyle(fontSize: 15)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                deltaW != null
                    ? '${deltaW <= 0 ? '▼' : '▲'} ${deltaW.abs().toStringAsFixed(1)}kg'
                        '${latestWaist != null ? ' · waist ${latestWaist.toStringAsFixed(1)}cm' : ''} — your story'
                    : 'Start tracking your body story',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  /// Weekly AI review teaser — 1 line, tap into Insights.
  Widget _weeklyTeaser() {
    final cached =
        WeeklySummaryService(widget.storage).cached()?.replaceAll('\n', ' ');
    final line = cached != null && cached.isNotEmpty
        ? (cached.length > 110 ? cached.substring(0, 110) : cached)
        : null;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InsightsScreen(storage: widget.storage),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFF4B4B).withValues(alpha: 0.14),
              Color(0xFFFF7A45).withValues(alpha: 0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.protein.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Text('💬', style: TextStyle(fontSize: 15)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                line != null ? '"$line…"' : 'Your week in Asha\'s words — read it',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  height: 1.35,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  /// Recently uploaded — 2-col photo grid.
  Widget _recentSection() {
    final recent = _on(_selected).take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recently uploaded',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AllEntriesScreen(storage: widget.storage),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 13,
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: recent.map((e) => _recentGridCard(e)).toList(),
          ),
      ],
    );
  }

  Widget _recentGridCard(FoodEntry entry) {
    final kcal = entry.totalCalories;
    final names =
        entry.items.map((i) => i.name).take(2).join(', ');
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MealDetailScreen(
              entry: entry,
              storage: widget.storage,
              onDeleted: () => _deleteEntry(entry),
            ),
          ),
        );
        _load();
      },
      onLongPress: () => _deleteEntry(entry),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (entry.imagePath.isNotEmpty &&
                File(entry.imagePath).existsSync())
              Image.file(
                File(entry.imagePath),
                fit: BoxFit.cover,
              )
            else
              Container(
                color: AppColors.cardAlt,
                child: Center(
                  child: Text('🍽️', style: TextStyle(fontSize: 26)),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$kcal kcal',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      _load();
    }
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
                width: 68,
                height: 68,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                padding: EdgeInsets.all(_frameColor != null ? 3 : 0),
                decoration: BoxDecoration(
                  color: AppColors.cardSelected,
                  shape: BoxShape.circle,
                  border: _frameColor != null
                      ? Border.all(color: _frameColor!, width: 3)
                      : null,
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
                    // Pop the pushed Settings route so the sign-out is visible
                    // (switching the root screen alone leaves it on top).
                    Navigator.of(context, rootNavigator: true)
                        .popUntil((r) => r.isFirst);
                    widget.onSignedOut();
                  },
                ),
              ),
            );
            if (mounted) _load();
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
