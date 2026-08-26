import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/storage_service.dart';

class InsightsScreen extends StatefulWidget {
  final StorageService storage;

  const InsightsScreen({super.key, required this.storage});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _green = Color(0xFF34C759);
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);

  Profile? _profile;
  List<FoodEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profile = widget.storage.profile;
    _entries = widget.storage.entries;
    setState(() {});
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

  // ---- Last 7 days data ----

  List<DateTime> get _last7Days {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  List<DateTime> get _last30Days {
    final today = DateTime.now();
    return List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));
  }

  int get _totalCalories7d =>
      _last7Days.fold(0, (s, d) => s + _caloriesForDay(d));

  double get _avgCalories7d => _totalCalories7d / 7;

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
    while (_caloriesForDay(day) > 0) {
      streak++;
      day = day.subtract(const Duration(days: 1));
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
  DateTime get _bestDay7d => _last7Days
      .reduce((a, b) => _caloriesForDay(a) > _caloriesForDay(b) ? a : b);

  DateTime get _worstDay7d => _last7Days
      .where((d) => _caloriesForDay(d) > 0)
      .fold(_last7Days.first, (a, b) => _caloriesForDay(a) < _caloriesForDay(b) ? a : b);

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('No profile'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _header(),
        const SizedBox(height: 20),
        _summaryCard(profile),
        const SizedBox(height: 16),
        _calorieTrendCard(profile),
        const SizedBox(height: 16),
        _macroDistributionCard(),
        const SizedBox(height: 16),
        _streaksCard(),
        const SizedBox(height: 16),
        _bestWorstCard(profile),
      ],
    );
  }

  Widget _header() {
    return const Row(
      children: [
        Text(
          'Insights',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ---- Summary card ----

  Widget _summaryCard(Profile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _summaryStat('Avg/day', '${_avgCalories7d.round()}', 'kcal', _ink),
              _summaryStat('On target', '$_daysOnTarget7d', '/7 days', _green),
              _summaryStat('Total', '${(_totalCalories7d / 1000).toStringAsFixed(1)}', 'kcal', _ink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '7-Day Trend',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Goal: $goal',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: _trendChart(days, cals, goal, maxCal),
          ),
        ],
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
          barColor = const Color(0xFFECECE7);
        } else if (hitTarget) {
          barColor = _green;
        } else if (ratio >= 0.5) {
          barColor = const Color(0xFFFFA726);
        } else {
          barColor = _ink;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (cal > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$cal',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: barColor,
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: (ratio * 90).clamp(4.0, 90.0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('E').format(days[i])[0],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? _ink : _muted,
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

    final avgP = totalP / 7;
    final avgC = totalC / 7;
    final avgF = totalF / 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Macro Split (7-day avg)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  if (proteinPct > 0)
                    Expanded(
                      flex: (proteinPct * 1000).round(),
                      child: Container(color: _proteinColor),
                    ),
                  if (carbsPct > 0)
                    Expanded(
                      flex: (carbsPct * 1000).round(),
                      child: Container(color: _carbsColor),
                    ),
                  if (fatPct > 0)
                    Expanded(
                      flex: (fatPct * 1000).round(),
                      child: Container(color: _fatColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _macroStat('Protein', '${avgP.round()}g', '${(proteinPct * 100).round()}%', _proteinColor),
              _macroStat('Carbs', '${avgC.round()}g', '${(carbsPct * 100).round()}%', _carbsColor),
              _macroStat('Fat', '${avgF.round()}g', '${(fatPct * 100).round()}%', _fatColor),
            ],
          ),
        ],
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
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label · $pct',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Streaks card ----

  Widget _streaksCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Logging Stats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _streakStat('🔥', 'Current', '$_currentStreak days', _ink),
              _streakStat('⚡', 'Longest', '$_longestStreak days', _green),
              _streakStat('📝', 'Total logged', '$_totalDaysLogged days', _ink),
            ],
          ),
        ],
      ),
    );
  }

  Widget _streakStat(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Best/worst day ----

  Widget _bestWorstCard(Profile profile) {
    final bestCal = _caloriesForDay(_bestDay7d);
    final worstCal = _caloriesForDay(_worstDay7d);
    final goal = profile.calorieGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dayCard(
                  'Best day',
                  DateFormat('E, MMM d').format(_bestDay7d),
                  '$bestCal kcal',
                  bestCal >= goal * 0.8 ? _green : _ink,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dayCard(
                  'Lowest day',
                  DateFormat('E, MMM d').format(_worstDay7d),
                  '$worstCal kcal',
                  _muted,
                  Icons.trending_down,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCard(String label, String date, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
