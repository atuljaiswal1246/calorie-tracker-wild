import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/features.dart';
import '../models/food_entry.dart';
import '../models/profile.dart';
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
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/widgets.dart';
import 'achievements_screen.dart';
import 'barcode_scanner_screen.dart';
import 'gamification_hub_screen.dart';
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
  DateTime _selected = clock.now();
  int _navIndex = 0; // 0 home, 1 progress, 2 trophy, 3 profile
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
  StreamSubscription<Uri?>? _widgetSub;
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
    // The home-screen widget opens the app straight into logging a meal.
    try {
      _widgetSub = HomeWidget.widgetClicked.listen(
        (uri) {
          if (mounted && uri != null) _openLogFromWidget(uri);
        },
        onError: (_) {}, // plugin unavailable — never break Home for it
      );
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (mounted && uri != null) _openLogFromWidget(uri);
      } catch (_) {}
    });
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
    _widgetSub?.cancel();
    _activity.dispose();
    _billing?.dispose();
    _weekScrollController.dispose();
    super.dispose();
  }

  void _load() {
    _profile = widget.storage.profile;
    _entries = widget.storage.entries;
    _waterMl = widget.storage.waterMlForDay(clock.now());
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Symbols.camera_alt_rounded, color: AppColors.ink),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Symbols.photo_library_rounded, color: AppColors.ink),
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
          'avatar_${clock.now().millisecondsSinceEpoch}.jpg';
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
    var day = clock.now();

    if (_calories(day) == 0) {
      day = day.subtract(Duration(days: 1));
    }

    while (_calories(day) > 0) {
      streak++;
      day = day.subtract(Duration(days: 1));
    }
    return streak;
  }

  String get _initials {
    final name = _profile?.name.trim() ?? 'U';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  // ---- Actions ----

  /// Straight into the log surface — the widget's promise is one tap.
  ///
  /// The widget's deep link carries which state was on screen, so we can
  /// measure taps-per-trigger and delete the states that do not earn theirs.
  void _openLogFromWidget([Uri? uri]) {
    if (!mounted) return;
    final mood = uri?.queryParameters['mood'];
    if (mood != null && mood.isNotEmpty) {
      AnalyticsService.log('widget_tap', {
        'state': uri?.queryParameters['state'] ?? '',
        'mood': mood,
      });
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => CaptureScreen(storage: widget.storage),
        ))
        .then((saved) {
      if (saved == true) _load();
    });
  }

  Future<void> _openCapture() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Log a meal',
                style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Column(
                          children: [
                            Icon(Symbols.photo_camera_rounded, size: 28, color: AppColors.ink),
                            SizedBox(height: 8),
                            Text('Camera', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w600, color: AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Column(
                          children: [
                            Icon(Symbols.photo_library_rounded, size: 28, color: AppColors.ink),
                            SizedBox(height: 8),
                            Text('Gallery', style: TextStyle(fontSize: AppType.body, fontWeight: FontWeight.w600, color: AppColors.ink)),
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
      if (!mounted) return;
      // Undo, because deleting a logged meal is easy to do by accident
      // (long-press) and there was no way back.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Meal deleted'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 92),
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await widget.storage.restoreEntry(entry);
                _load();
              },
            ),
          ),
        );
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
                  if (i == 2) {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AchievementsScreen(storage: widget.storage),
                      ),
                    );
                    return;
                  }
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
              borderRadius: BorderRadius.circular(AppRadius.sheet),
            ),
            child: Center(
              child: Icon(Symbols.lock_rounded, size: 34, color: AppColors.ink),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Your free trial has ended',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppType.hero,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: AppSpace.md),
          Text(
            'Unlock unlimited food analysis and all features with a subscription.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: AppType.bodyStrong, color: AppColors.muted, height: 1.5),
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
                  fontSize: AppType.title,
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
              style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  // ================= Home =================

  String get _greetingText {
    final hour = clock.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
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
  Widget _streakPill() {
    return Semantics(
      label: '$_displayStreak day streak. Tap for details.',
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showStreakInfo(context);
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
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
                  fontSize: AppType.body,
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
              q.completed ? Symbols.check_rounded : Symbols.circle_rounded,
              size: 14,
              color: q.completed ? Colors.white : AppColors.faint,
            ),
          ),
          SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.template.title,
                  style: TextStyle(
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w600,
                    color: q.completed ? AppColors.muted : AppColors.ink,
                    decoration:
                        q.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.bar),
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
          SizedBox(width: AppSpace.md),
          Text(
            '+${q.calPoints}',
            style: TextStyle(
              fontSize: AppType.small,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Asha concierge card — time-aware openers, tap straight into chat.
  Widget _ashaConcierge() {
    final h = clock.now().hour;
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFF7043)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Icon(Symbols.auto_awesome_rounded, size: 21, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asha',
                    style: TextStyle(
                      fontSize: AppType.bodyStrong,
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
                      fontSize: AppType.small,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  SizedBox(height: 2),
                  _AshaTicker(),
                ],
              ),
            ),
            Icon(Symbols.chevron_right_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  /// Big hero: day ring, streak, carbs/fat, macro pills (fiber/sugar/sodium).
  Future<void> _openWaterSheet() async {
    final ml = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
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
                  fontSize: AppType.title,
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.chipBlue,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '+${ml}ml',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppType.body,
              fontWeight: FontWeight.w700,
              color: AppColors.water,
            ),
          ),
        ),
      ),
    );
  }

  /// Connect step tracking (or fall back to manual entry on devices
  /// without a step sensor).
  Future<void> _enableSteps() async {
    if (_enablingSteps) return;
    setState(() => _enablingSteps = true);
    try {
      final source = await _activity.enableTracking();
      if (!mounted) return;
      setState(() {
        _stepsSource = source;
        _stepsToday = widget.storage.getStepsFor(clock.now());
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
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

  Widget _homePage(Profile profile) {
    final goal = profile.calorieGoal;
    final logged = _calories(_selected);
    final remaining = (goal - logged).clamp(0, goal);

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () async => _load(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 118),
        children: [
          _header(profile),
          if (!_isOnline) ...[
            SizedBox(height: AppSpace.md),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                children: [
                  Icon(Symbols.wifi_off_rounded,
                      size: 18, color: AppColors.accentOrange),
                  SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Text(
                      "You're offline. AI features unavailable.",
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: AppSpace.lg),
          _heroCard(profile, goal, logged, remaining),
          SizedBox(height: AppSpace.md),
          _equationLine(goal, logged),
          SizedBox(height: AppSpace.lg),
          _scanCta(),
          SizedBox(height: AppSpace.md),
          _logTiles(),
          SizedBox(height: AppSpace.md),
          _logLinks(),
          SizedBox(height: AppSpace.xl),
          _sectionTitle("Today's habits"),
          SizedBox(height: AppSpace.md),
          _habitsCard(),
          SizedBox(height: AppSpace.xl),
          _questCard(),
          SizedBox(height: AppSpace.xl),
          _sectionTitle('Recently logged',
              trailing: 'View all', onTrailing: _openAllEntries),
          SizedBox(height: AppSpace.md),
          _recentRow(),
          if (Features.asha) ...[
            SizedBox(height: AppSpace.xl),
            _ashaConcierge(),
          ],
        ],
      ),
    );
  }

  void _openAllEntries() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllEntriesScreen(storage: widget.storage),
      ),
    );
  }

  Widget _header(Profile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _greetingBlock(profile)),
        SizedBox(width: AppSpace.sm),
        _streakPill(),
      ],
    );
  }

  Widget _greetingBlock(Profile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greetingText, ${profile.name.split(' ').first}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppType.headline,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 3),
        InkWell(
          onTap: _openDayPicker,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dateLabel,
                style: TextStyle(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w600,
                  color: AppColors.faint,
                ),
              ),
              SizedBox(width: 3),
              Icon(Symbols.keyboard_arrow_down_rounded,
                  size: 15, color: AppColors.faint),
            ],
          ),
        ),
      ],
    );
  }

  String get _dateLabel {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final d = _selected;
    return '${days[d.weekday - 1]} · ${d.day} ${months[d.month - 1]}';
  }

  Future<void> _openDayPicker() async {
    final now = clock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Pick a day',
    );
    if (picked != null && mounted) {
      setState(
          () => _selected = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Widget _heroCard(Profile profile, int goal, int logged, int remaining) {
    final progress = goal > 0 ? (remaining / goal).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () => _openMacro(MacroType.calories, logged.toDouble(),
          goal.toDouble(), AppColors.ink),
      borderRadius: BorderRadius.circular(AppRadius.sheet),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: AppColors.track,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$remaining',
                          style: TextStyle(
                            fontSize: AppType.hero,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -1.2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'KCAL LEFT',
                          style: TextStyle(
                            fontSize: AppType.micro,
                            fontWeight: FontWeight.w700,
                            color: AppColors.faint,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                children: [
                  _macroRow('Protein', _protein(_selected),
                      profile.proteinGrams.toDouble(), AppColors.protein,
                      MacroType.protein),
                  SizedBox(height: 13),
                  _macroRow('Carbs', _carbs(_selected),
                      profile.carbsGrams.toDouble(), AppColors.carbs,
                      MacroType.carbs),
                  SizedBox(height: 13),
                  _macroRow('Fat', _fat(_selected),
                      profile.fatGrams.toDouble(), AppColors.fat,
                      MacroType.fat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroRow(
      String name, double value, double target, Color color, MacroType type) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () => _openMacro(type, value, target, color),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '${value.round()} / ${target.round()}g',
                style: TextStyle(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w700,
                  color: AppColors.faint,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.bar),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: AppColors.cardAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _equationLine(int goal, int logged) {
    final left = goal - logged;
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: AppType.small,
          fontWeight: FontWeight.w600,
          color: AppColors.faint,
        ),
        children: [
          TextSpan(
              text: '$goal',
              style: TextStyle(
                  color: AppColors.ink, fontWeight: FontWeight.w800)),
          TextSpan(text: ' goal · '),
          TextSpan(
              text: '$logged',
              style: TextStyle(
                  color: AppColors.ink, fontWeight: FontWeight.w800)),
          TextSpan(text: ' eaten · '),
          TextSpan(text: left > 0 ? '$left left' : 'goal reached'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _scanCta() {
    return InkWell(
      onTap: _openCapture,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.inkButton,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.center_focus_strong_rounded,
                size: 20, color: Colors.white),
            SizedBox(width: 9),
            Text(
              'Scan food',
              style: TextStyle(
                fontSize: AppType.title,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logTiles() {
    return Row(
      children: [
        Expanded(
          child: _logTile(
              Symbols.photo_library_rounded, 'Gallery', _openGallery),
        ),
        SizedBox(width: AppSpace.md),
        Expanded(
          child: _logTile(Symbols.restaurant_menu_rounded, 'Quick picks',
              _openQuickPicks),
        ),
      ],
    );
  }

  Widget _logTile(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.ink),
            SizedBox(width: AppSpace.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: AppType.body,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _logLink('Add manually', _openManualEntry),
        SizedBox(width: AppSpace.xl),
        _logLink('Barcode scan', _openBarcodeScanner),
      ],
    );
  }

  Widget _logLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppType.body,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title,
      {String? trailing, VoidCallback? onTrailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppType.title,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.4,
          ),
        ),
        if (trailing != null)
          InkWell(
            onTap: onTrailing,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.sm, vertical: AppSpace.xs),
              child: Text(
                trailing,
                style: TextStyle(
                  fontSize: AppType.small,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _habitsCard() {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _habitRow(
            icon: Symbols.water_drop_rounded,
            iconColor: AppColors.water,
            label: 'Water',
            value: (_waterMl / 1000).toStringAsFixed(1),
            unit: '/ ${(_waterGoalMl / 1000).toStringAsFixed(1)} L',
            pct: _waterGoalMl > 0
                ? (_waterMl / _waterGoalMl).clamp(0.0, 1.0)
                : 0.0,
            color: AppColors.water,
            actionIcon: Symbols.add_rounded,
            actionLabel: 'Glass',
            onAction: _openWaterSheet,
          ),
          Divider(height: 1, color: AppColors.divider),
          _habitRow(
            icon: Symbols.directions_run_rounded,
            iconColor: AppColors.green,
            label: 'Steps',
            value: '$_stepsToday',
            unit: '/ 8,000',
            pct: (_stepsToday / 8000).clamp(0.0, 1.0),
            color: AppColors.green,
            actionIcon: Symbols.directions_run_rounded,
            actionLabel: 'Exercise',
            onAction: _addExerciseSheet,
            onTap: _stepsEnabled ? _manualStepsDialog : _enableSteps,
          ),
        ],
      ),
    );
  }

  Widget _habitRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required double pct,
    required Color color,
    required IconData actionIcon,
    required String actionLabel,
    required VoidCallback onAction,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: AppType.small,
                          fontWeight: FontWeight.w700,
                          color: AppColors.faint,
                        ),
                        children: [
                          TextSpan(
                            text: value,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(text: ' $unit'),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.bar),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: AppColors.cardAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpace.md),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, size: 14, color: AppColors.ink),
                  SizedBox(width: 4),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: AppType.small,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
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

  Widget _questCard() {
    final gami = _gami;
    if (gami == null || gami.activeQuests.isEmpty) {
      return const SizedBox.shrink();
    }
    final quests = gami.activeQuests;
    final pct = (gami.questsCompleted / quests.length).clamp(0.0, 1.0);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GamificationHubScreen()),
        );
      },
      borderRadius: BorderRadius.circular(AppRadius.sheet),
      child: Container(
        padding: EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sheet),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.checklist_rounded,
                    size: 17, color: AppColors.accentOrange),
                SizedBox(width: 8),
                Text(
                  "Today's quests",
                  style: TextStyle(
                    fontSize: AppType.bodyStrong,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Spacer(),
                Text(
                  'Level ${gami.level} · +${gami.todayPoints} pts',
                  style: TextStyle(
                    fontSize: AppType.small,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentOrange,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.bar),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.cardAlt,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.accentOrange),
              ),
            ),
            SizedBox(height: AppSpace.md),
            ...quests.take(3).map(_questRow),
          ],
        ),
      ),
    );
  }

  Widget _recentRow() {
    final recent = _on(_selected).take(6).toList();
    if (recent.isEmpty) return EmptyCard(onScanTap: _openCapture);
    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpace.md),
        itemBuilder: (_, i) => _recentCard(recent[i]),
      ),
    );
  }

  Widget _recentCard(FoodEntry entry) {
    final kcal = entry.totalCalories;
    final names = entry.items.map((i) => i.name).take(2).join(', ');
    final time = DateFormat.jm().format(entry.dateTime);
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
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SizedBox(
                width: 150,
                height: 104,
                child: (entry.imagePath.isNotEmpty &&
                        File(entry.imagePath).existsSync())
                    ? Image.file(File(entry.imagePath), fit: BoxFit.cover)
                    : Container(
                        color: AppColors.cardAlt,
                        child: Center(
                          child: Icon(Symbols.restaurant_rounded,
                              size: 24, color: AppColors.faint),
                        ),
                      ),
              ),
            ),
            SizedBox(height: AppSpace.sm),
            Text(
              names.isEmpty ? 'Meal' : names,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppType.body,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '$kcal kcal · $time',
              style: TextStyle(
                fontSize: AppType.small,
                fontWeight: FontWeight.w600,
                color: AppColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            fontSize: AppType.hero,
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
                          fontSize: AppType.headline,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
              ),
            ),
            SizedBox(width: AppSpace.lg),
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
                            fontSize: AppType.title,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showNameEdit(profile),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          constraints: BoxConstraints(minWidth: 44, minHeight: 44),
                          child: Icon(Symbols.edit_rounded, size: 14, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    '${profile.calorieGoal} kcal/day goal',
                    style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
                  ),
                  if (_signedInEmail != null) ...[
                    SizedBox(height: 3),
                    Text(
                      _signedInEmail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
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
          padding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
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
              _profileRow(
                'Daily calories',
                '${profile.calorieGoal} kcal',
                onTap: () => _showCalorieGoalEdit(profile),
                trailing: Symbols.edit_rounded,
              ),
            ],
          ),
        ),
        SizedBox(height: 12),

        SizedBox(height: 20),

        // BMI card
        Container(
          padding: EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bmiColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(Symbols.monitor_weight_rounded, size: 24, color: bmiColor),
              ),
              SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BMI',
                      style: TextStyle(
                        fontSize: AppType.body,
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
                            fontSize: AppType.headline,
                            fontWeight: FontWeight.w800,
                            color: bmiColor,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          bmiLabel,
                          style: TextStyle(
                            fontSize: AppType.body,
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
              fontSize: AppType.title,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: AppSpace.md),
          Container(
            padding: EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                // Mini chart
                SizedBox(
                  height: 60,
                  child: _MiniWeightChart(entries: recentWeights),
                ),
                SizedBox(height: AppSpace.md),
                // Latest entries
                ...recentWeights.reversed.take(5).map((e) {
                  final idx = recentWeights.indexOf(e);
                  final prev = idx > 0 ? recentWeights[idx - 1] : null;
                  final diff = prev != null ? e.weightKg - prev.weightKg : 0.0;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpace.xs),
                    child: Row(
                      children: [
                        Text(
                          '${e.date.day}/${e.date.month}',
                          style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '${e.weightKg.round()} kg',
                          style: TextStyle(
                            fontSize: AppType.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        Spacer(),
                        if (diff != 0)
                          Text(
                            '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: AppType.small,
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
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(Symbols.settings_rounded,
                      size: 20, color: AppColors.ink),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: AppType.bodyStrong,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Icon(Symbols.chevron_right_rounded,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Edit calorie goal',
          style: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.w700),
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

  Widget _profileRow(String label, String value,
      {VoidCallback? onTap, IconData? trailing}) {
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: AppType.body, color: AppColors.muted)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: AppSpace.sm),
                Icon(trailing, size: 13, color: AppColors.muted),
              ],
            ],
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: row,
    );
  }

  Future<void> _showNameEdit(Profile profile) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(
          'Edit name',
          style: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: AppType.headline, fontWeight: FontWeight.w700),
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

class _MiniWeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  _MiniWeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Center(
        child: Text('Need 2+ entries for a trend', style: TextStyle(fontSize: AppType.small, color: AppColors.muted)),
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
          fontSize: AppType.body,
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
                  fontSize: AppType.title,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: AppSpace.lg),
              SizedBox(
                height: 230,
                child: ListView.separated(
                  itemCount: ActivityService.activities.length,
                  separatorBuilder: (_, __) => SizedBox(height: AppSpace.sm),
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
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          children: [
                            Text(a.emoji, style: TextStyle(fontSize: AppType.title)),
                            SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Text(
                                a.name,
                                style: TextStyle(
                                  fontSize: AppType.body,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                            if (active)
                              Icon(Symbols.check_rounded,
                                  size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: AppSpace.lg),
              Text(
                'Duration',
                style: TextStyle(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [15, 30, 45, 60].map((m) {
                  final active = m == _minutes;
                  return Padding(
                    padding: EdgeInsets.only(right: AppSpace.sm),
                    child: GestureDetector(
                      onTap: () => setState(() => _minutes = m),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: AppSpace.sm),
                        decoration: BoxDecoration(
                          color: active ? AppColors.inkButton : AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '$m min',
                          style: TextStyle(
                            fontSize: AppType.body,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '≈ $_kcal kcal burned',
                      style: TextStyle(
                        fontSize: AppType.body,
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
                          borderRadius: BorderRadius.circular(AppRadius.pill)),
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
