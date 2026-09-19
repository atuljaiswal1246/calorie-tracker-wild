import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/achievements_service.dart';
import '../services/storage_service.dart';
import '../services/weekly_summary_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_illustration.dart';
import 'achievements_screen.dart';

class InsightsScreen extends StatefulWidget {
  final StorageService storage;

  InsightsScreen({super.key, required this.storage});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Profile? _profile;
  List<FoodEntry> _entries = [];
  List<Achievement> _achievements = [];
  late WeeklySummaryService _summaryService;
  String? _summaryText;
  bool _summaryLoading = false;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _summaryService = WeeklySummaryService(widget.storage);
    _load();
  }

  void _load() {
    _profile = widget.storage.profile;
    _entries = widget.storage.entries;
    _achievements = AchievementsService(widget.storage).getAll();
    _summaryText = _summaryService.cached();
    if (_summaryText == null || _summaryText!.isEmpty) _summaryText = null;
    setState(() {});
  }

  Future<void> _generateSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final text = await _summaryService.generate();
      if (mounted) {
        setState(() => _summaryText = text);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _summaryError = 'Couldn\'t generate right now. Try again in a bit.';
        });
      }
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  // ---- Data helpers ----

  List<FoodEntry> _entriesForDay(DateTime day) {
    return _entries.where((e) => e.isOn(day)).toList();
  }

  int _caloriesForDay(DateTime day) =>
      _entriesForDay(day).fold(0, (s, e) => s + e.totalCalories);

  double _proteinForDay(DateTime day) =>
      _entriesForDay(day).fold(0.0, (s, e) => s + e.totalProtein);

  double _carbsForDay(DateTime day) =>
      _entriesForDay(day).fold(0.0, (s, e) => s + e.totalCarbs);

  double _fatForDay(DateTime day) =>
      _entriesForDay(day).fold(0.0, (s, e) => s + e.totalFat);

  DateTime? get _earliestDate {
    if (_entries.isEmpty) return null;
    return _entries
        .map((e) => e.dateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  bool get _hasAnyData => _entries.isNotEmpty;

  // ---- Last 7 days data ----

  List<DateTime> get _last7Days {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  int get _totalCalories7d =>
      _last7Days.fold(0, (s, d) => s + _caloriesForDay(d));

  int get _daysWithData7d =>
      _last7Days.where((d) => _caloriesForDay(d) > 0).length;

  double get _avgCalories7d {
    final days = _daysWithData7d;
    return days > 0 ? _totalCalories7d / days : 0;
  }

  int get _daysOnTarget7d {
    final goal = _profile?.calorieGoal ?? 1500;
    return _last7Days.where((d) {
      final cal = _caloriesForDay(d);
      return cal >= goal * 0.8 && cal <= goal * 1.2;
    }).length;
  }

  int get _totalDaysLogged {
    final earliest = _earliestDate;
    if (earliest == null) return 0;
    final today = DateTime.now();
    final days = today.difference(earliest).inDays + 1;
    int logged = 0;
    for (int i = 0; i < days; i++) {
      final day = today.subtract(Duration(days: i));
      if (_caloriesForDay(day) > 0) logged++;
    }
    return logged;
  }

  int get _currentStreak {
    final today = DateTime.now();
    int streak = 0;
    var day = DateTime(today.year, today.month, today.day);
    // If today has no entries, start counting from yesterday
    if (_caloriesForDay(day) == 0) {
      day = day.subtract(Duration(days: 1));
    }
    while (_caloriesForDay(day) > 0) {
      streak++;
      day = day.subtract(Duration(days: 1));
    }
    return streak;
  }

  int get _longestStreak {
    final earliest = _earliestDate;
    if (earliest == null) return 0;
    final today = DateTime.now();
    int longest = 0;
    int current = 0;
    final days = today.difference(earliest).inDays + 1;
    for (int i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      if (_caloriesForDay(day) > 0) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  // Best/worst day in last 7
  DateTime? get _bestDay7d {
    final daysWithEntries = _last7Days.where((d) => _caloriesForDay(d) > 0);
    if (daysWithEntries.isEmpty) return null;
    return daysWithEntries
        .reduce((a, b) => _caloriesForDay(a) > _caloriesForDay(b) ? a : b);
  }

  DateTime? get _worstDay7d {
    final daysWithEntries = _last7Days.where((d) => _caloriesForDay(d) > 0);
    if (daysWithEntries.isEmpty) return null;
    return daysWithEntries
        .reduce((a, b) => _caloriesForDay(a) < _caloriesForDay(b) ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return Center(child: Text('No profile'));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () async => _load(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              _header(),
              SizedBox(height: 20),
              if (!_hasAnyData) ...[
                _emptyState(),
              ] else ...[
                _summaryCard(profile),
                SizedBox(height: 16),
                _aiSummaryCard(),
                SizedBox(height: 16),
                _calorieTrendCard(profile),
                SizedBox(height: 16),
                _macroDistributionCard(),
                SizedBox(height: 16),
                _streaksCard(),
                SizedBox(height: 16),
                _bestWorstCard(profile),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final all = _achievements;
    final unlocked = all.where((a) => a.unlocked).length;

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.cardShadowLight,
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        SizedBox(width: 12),
        Text(
          'Insights',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        Spacer(),
        Semantics(
          label: '$_currentStreak day streak. Tap for details.',
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
                    '$_currentStreak',
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
        ),
        SizedBox(width: 8),
        Semantics(
          label: '$unlocked of ${all.length} achievements unlocked. Tap to view.',
          button: true,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
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
                    '$unlocked/${all.length}',
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
        ),
      ],
    );
  }

  void _showStreakInfo(BuildContext context) {
    final streak = _currentStreak;
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
              Icon(Symbols.local_fire_department_rounded,
                  size: 34, color: AppColors.accentOrange),
              SizedBox(height: 12),
              Text(
                streak == 1 ? '1 day streak' : '$streak day streak',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Log at least one meal every day to keep your streak alive.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inkButton,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Empty state ----

  Widget _emptyState() {
    return Padding(
      padding: EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const EmptyIllustration(
            asset: 'assets/illustrations/empty_progress.jpg',
            size: 132,
          ),
          SizedBox(height: 16),
          Text(
            'No data yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start logging meals to see your insights here.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---- Summary card ----

  Widget _summaryCard(Profile profile) {
    return Semantics(
      label: 'Weekly summary',
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _summaryStat(
                  'Avg/day',
                  '${_avgCalories7d.round()}',
                  'kcal',
                  AppColors.ink,
                ),
                _summaryStat(
                  'On target',
                  '$_daysOnTarget7d',
                  '/7 days',
                  AppColors.green,
                ),
                _summaryStat(
                  'Total',
                  '${_totalCalories7d}',
                  'kcal',
                  AppColors.ink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// AI-written weekly review (Asha) — cached per week, regenerable.
  Widget _aiSummaryCard() {
    final range = DateFormat('MMM d').format(DateTime.now()
            .subtract(Duration(days: 6))) +
        ' – ' +
        DateFormat('MMM d').format(DateTime.now());

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.35)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.auto_awesome_rounded,
                  size: 16, color: AppColors.accentOrange),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Your week in review',
                  style: TextStyle(
                    fontSize: AppType.bodyStrong,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                range,
                style: TextStyle(
                  fontSize: AppType.small,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (_summaryLoading) ...[
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Reading your week…',
                  style: TextStyle(
                    fontSize: AppType.body,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else if (_summaryText != null)
            Text(
              _summaryText!,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            Text(
              'Tap to get a personal recap — what went right, '
              'what to fix this week.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.inkButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
                onPressed: _generateSummary,
                icon: Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  'Generate my week',
                  style: TextStyle(
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (_summaryError != null) ...[
            SizedBox(height: 8),
            Text(
              _summaryError!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.missedRed,
              ),
            ),
          ],
          if (_summaryText != null) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Regenerate',
                  style: TextStyle(
                    fontSize: AppType.small,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                SizedBox(width: 4),
                InkWell(
                  onTap: _generateSummary,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.refresh,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          // Label first, then the number (same reading order as Progress/Home).
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Calorie trend chart (last 7 days) ----

  Widget _calorieTrendCard(Profile profile) {
    final goal = profile.calorieGoal;
    final days = _last7Days;
    final cals = days.map((d) => _caloriesForDay(d)).toList();
    final maxCal = [goal, ...cals].reduce((a, b) => a > b ? a : b);

    return Semantics(
      label: '7-day calorie trend',
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '7-Day Trend',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.inkButton,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Goal: $goal',
                    style: TextStyle(
                      fontSize: AppType.micro,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: _trendChart(days, cals, goal, maxCal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendChart(List<DateTime> days, List<int> cals, int goal, int maxCal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final cal = cals[i];
        final ratio = maxCal > 0 ? cal / maxCal : 0.0;
        final hitTarget = cal >= goal * 0.8;
        final isToday = _isSameDay(days[i], DateTime.now());

        Color barColor;
        if (cal == 0) {
          barColor = AppColors.track;
        } else if (hitTarget) {
          barColor = AppColors.green;
        } else if (ratio >= 0.5) {
          barColor = AppColors.warningOrange;
        } else {
          barColor = AppColors.ink;
        }

        final dayLabel = DateFormat('E').format(days[i]);
        // Use first 2 letters for ambiguous single-letter days (Sat/Sun, Thu/Tue)
        final shortLabel = (dayLabel == 'Saturday' || dayLabel == 'Sunday')
            ? dayLabel.substring(0, 2)
            : dayLabel[0];

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cal > 0)
                  Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$cal',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: barColor,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: (ratio * 90).clamp(4.0, 90.0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ---- Macro distribution ----

  Widget _macroDistributionCard() {
    final totalP = _last7Days.fold(0.0, (s, d) => s + _proteinForDay(d));
    final totalC = _last7Days.fold(0.0, (s, d) => s + _carbsForDay(d));
    final totalF = _last7Days.fold(0.0, (s, d) => s + _fatForDay(d));
    final total = totalP + totalC + totalF;

    final proteinPct = total > 0 ? totalP / total : 0.0;
    final carbsPct = total > 0 ? totalC / total : 0.0;
    final fatPct = total > 0 ? totalF / total : 0.0;

    final avgP = _daysWithData7d > 0 ? totalP / _daysWithData7d : 0.0;
    final avgC = _daysWithData7d > 0 ? totalC / _daysWithData7d : 0.0;
    final avgF = _daysWithData7d > 0 ? totalF / _daysWithData7d : 0.0;

    return Semantics(
      label: 'Macro distribution',
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Macro Split (7-day avg)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 16),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 16,
                child: total > 0
                    ? Row(
                        children: [
                          if (proteinPct > 0)
                            Expanded(
                              flex: (proteinPct * 1000).round(),
                              child: Container(color: AppColors.protein),
                            ),
                          if (carbsPct > 0)
                            Expanded(
                              flex: (carbsPct * 1000).round(),
                              child: Container(color: AppColors.carbs),
                            ),
                          if (fatPct > 0)
                            Expanded(
                              flex: (fatPct * 1000).round(),
                              child: Container(color: AppColors.fat),
                            ),
                        ],
                      )
                    : Container(color: AppColors.track),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _macroStat('Protein', '${avgP.round()}g', '${(proteinPct * 100).round()}%', AppColors.protein),
                _macroStat('Carbs', '${avgC.round()}g', '${(carbsPct * 100).round()}%', AppColors.carbs),
                _macroStat('Fat', '${avgF.round()}g', '${(fatPct * 100).round()}%', AppColors.fat),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroStat(String label, String value, String pct, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 2),
          Text(
            '$label · $pct',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Streaks card ----

  Widget _streaksCard() {
    return Semantics(
      label: 'Logging stats',
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logging Stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _streakBox(
                    Icons.local_fire_department,
                    _currentStreak > 0 ? '$_currentStreak days' : '—',
                    'Current streak',
                    _currentStreak > 0 ? AppColors.ink : AppColors.muted,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _streakBox(
                    Icons.bolt,
                    _longestStreak > 0 ? '$_longestStreak days' : '—',
                    'Best streak',
                    _longestStreak > 0 ? AppColors.green : AppColors.muted,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _streakBox(
                    Icons.edit_note,
                    '$_totalDaysLogged days',
                    'Days logged',
                    _totalDaysLogged > 0 ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _streakBox(IconData icon, String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppType.micro,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---- Best/worst day ----

  Widget _bestWorstCard(Profile profile) {
    final bestDay = _bestDay7d;
    final worstDay = _worstDay7d;
    if (bestDay == null || worstDay == null) return SizedBox.shrink();

    final bestCal = _caloriesForDay(bestDay);
    final worstCal = _caloriesForDay(worstDay);
    final goal = profile.calorieGoal;

    return Semantics(
      label: 'Best and lowest days',
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Highlights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _dayCard(
                    'Most food',
                    DateFormat('E, MMM d').format(bestDay),
                    '$bestCal kcal',
                    bestCal >= goal * 0.8 ? AppColors.green : AppColors.ink,
                    Icons.check_circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _dayCard(
                    'Least food',
                    DateFormat('E, MMM d').format(worstDay),
                    '$worstCal kcal',
                    AppColors.muted,
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(String label, String date, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 2),
          Text(
            date,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
