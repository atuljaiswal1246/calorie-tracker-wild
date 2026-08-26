import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../models/food_entry.dart';
import '../models/profile.dart';
import '../services/storage_service.dart';

class ProgressScreen extends StatefulWidget {
  final StorageService storage;

  const ProgressScreen({super.key, required this.storage});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _green = Color(0xFF34C759);
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);

  Profile? _profile;
  List<FoodEntry> _entries = [];
  List<WeightEntry> _weightEntries = [];
  DateTime _selectedWeekStart = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  bool _isMonthly = false;
  int _periodIndex = 0; // 0=week, 1=month, 2=custom
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _load();
    // Default to start of current week (Sunday)
    final now = DateTime.now();
    _selectedWeekStart = now.subtract(Duration(days: now.weekday % 7));
  }

  void _load() {
    _profile = widget.storage.profile;
    _entries = widget.storage.entries;
    _weightEntries = widget.storage.weightEntries;
    setState(() {});
  }

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

  List<DateTime> get _displayDays {
    final earliest = _earliestDate;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (_periodIndex == 2 && _customStart != null && _customEnd != null) {
      var start = _customStart!;
      if (earliest != null && start.isBefore(earliest)) {
        start = DateTime(earliest.year, earliest.month, earliest.day);
      }
      var end = _customEnd!;
      if (end.isAfter(today)) end = today;
      final diff = end.difference(start).inDays + 1;
      if (diff <= 0) return [];
      return List.generate(diff, (i) => start.add(Duration(days: i)));
    }
    if (_periodIndex == 1) {
      final isFirstMonth = _selectedMonth.year == today.year && _selectedMonth.month == today.month;
      var firstOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      if (earliest != null && firstOfMonth.isBefore(earliest)) {
        firstOfMonth = DateTime(earliest.year, earliest.month, earliest.day);
      }
      final daysInMonth = isFirstMonth ? today.day : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      final lastDay = isFirstMonth ? today.day : daysInMonth;
      final filteredDays = List.generate(lastDay, (i) => DateTime(_selectedMonth.year, _selectedMonth.month, i + 1))
          .where((d) => !d.isBefore(firstOfMonth))
          .toList();
      return filteredDays;
    }
    // Week view — clamp start to earliest date, end to today
    final weekStart = DateTime(_selectedWeekStart.year, _selectedWeekStart.month, _selectedWeekStart.day);
    var start = weekStart;
    if (earliest != null && start.isBefore(DateTime(earliest.year, earliest.month, earliest.day))) {
      start = DateTime(earliest.year, earliest.month, earliest.day);
    }
    return List.generate(7, (i) => weekStart.add(Duration(days: i)))
        .where((d) => !d.isBefore(start) && !d.isAfter(today))
        .toList();
  }

  int get _totalCalories =>
      _displayDays.fold(0, (s, d) => s + _caloriesForDay(d));

  double get _avgCalories => _totalCalories / _displayDays.length;

  int get _daysOnTarget {
    final goal = _profile?.calorieGoal ?? 1500;
    return _displayDays.where((d) => _caloriesForDay(d) >= goal * 0.8).length;
  }

  double get _totalProtein => _displayDays.fold(0.0, (s, d) => s + _proteinForDay(d));
  double get _totalCarbs => _displayDays.fold(0.0, (s, d) => s + _carbsForDay(d));
  double get _totalFat => _displayDays.fold(0.0, (s, d) => s + _fatForDay(d));

  int get _totalDaysInPeriod => _displayDays.length;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('No profile'));
    }

    final periodLabel = _periodIndex == 2
        ? 'for selected period'
        : _periodIndex == 1
            ? 'this month'
            : 'this week';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
      children: [
        _header(),
        const SizedBox(height: 16),
        _weightCard(profile),
        const SizedBox(height: 16),
        _periodToggle(),
        const SizedBox(height: 16),
        if (_periodIndex == 0) ...[
          _weekNavigator(),
          const SizedBox(height: 20),
        ] else if (_periodIndex == 1) ...[
          _monthNavigator(),
          const SizedBox(height: 20),
        ] else ...[
          _customRangeNavigator(context),
          const SizedBox(height: 20),
        ],
        _caloriesChart(profile),
        const SizedBox(height: 16),
        _statsRow(profile),
        const SizedBox(height: 20),
        _sectionTitle('Macros $periodLabel'),
        const SizedBox(height: 12),
        _macroOverview(),
        const SizedBox(height: 20),
        _sectionTitle('Daily breakdown'),
        const SizedBox(height: 12),
        ..._displayDays.reversed.map((day) => _dayRow(day, profile)),
      ],
    );
  }

  Widget _header() {
    return const Row(
      children: [
        Text(
          'Progress',
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

  Widget _weightCard(Profile profile) {
    final latest = _weightEntries.isNotEmpty ? _weightEntries.last.weightKg : profile.weightKg;
    final target = profile.targetWeightKg;
    final startWeight = _weightEntries.isNotEmpty ? _weightEntries.first.weightKg : profile.weightKg;
    final change = latest - startWeight;
    final goal = profile.goal;

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
                'Weight',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              GestureDetector(
                onTap: () => _showLogWeightSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Log',
                        style: TextStyle(
                          fontSize: 12,
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
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${latest.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (change != 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (goal == 'lose'
                        ? (change < 0 ? _green : const Color(0xFFFF3B30))
                        : goal == 'gain'
                            ? (change > 0 ? _green : const Color(0xFFFF3B30))
                            : _ink.withOpacity(0.08)).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: goal == 'lose'
                            ? (change < 0 ? _green : const Color(0xFFFF3B30))
                            : goal == 'gain'
                                ? (change > 0 ? _green : const Color(0xFFFF3B30))
                                : _ink,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: goal == 'lose'
                              ? (change < 0 ? _green : const Color(0xFFFF3B30))
                              : goal == 'gain'
                                  ? (change > 0 ? _green : const Color(0xFFFF3B30))
                                  : _ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (target != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, size: 14, color: _muted),
                const SizedBox(width: 4),
                Text(
                  'Target: ${target.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(latest - target).abs().toStringAsFixed(1)} kg to go',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: latest == target ? _green : _ink,
                  ),
                ),
              ],
            ),
          ],
          if (_weightEntries.length >= 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: _weightChart(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightChart() {
    final entries = _weightEntries;
    if (entries.length < 2) return const SizedBox.shrink();

    final weights = entries.map((e) => e.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final range = maxW - minW;
    final padding = range > 0 ? range * 0.1 : 1.0;
    final yMin = minW - padding;
    final yMax = maxW + padding;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return CustomPaint(
          size: Size(w, h),
          painter: _WeightChartPainter(
            entries: entries,
            yMin: yMin,
            yMax: yMax,
          ),
        );
      },
    );
  }

  void _showLogWeightSheet(BuildContext context) {
    final current = _weightEntries.isNotEmpty
        ? _weightEntries.last.weightKg.toStringAsFixed(1)
        : (_profile?.weightKg ?? 60).toStringAsFixed(1);
    final controller = TextEditingController(text: current);

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
              'Log Weight',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
              ],
              autofocus: true,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
              decoration: InputDecoration(
                suffixText: 'kg',
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
                  final val = double.tryParse(controller.text);
                  if (val == null || val <= 0 || val > 300) return;
                  await widget.storage.addWeightEntry(val);
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

  void _showEditCalorieGoalSheet(BuildContext context) {
    final profile = _profile;
    if (profile == null) return;

    final currentGoal = profile.calorieGoal;
    final controller = TextEditingController(text: currentGoal.toString());

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
              'Edit Calorie Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.calorieGoalOverride != null
                  ? 'Custom goal set'
                  : 'Auto-calculated: $currentGoal kcal',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              autofocus: true,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
              decoration: InputDecoration(
                suffixText: 'kcal',
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
            const SizedBox(height: 16),
            if (profile.calorieGoalOverride != null)
              GestureDetector(
                onTap: () async {
                  final updated = profile.copyWith();
                  final resetProfile = Profile(
                    name: updated.name,
                    age: updated.age,
                    sex: updated.sex,
                    weightKg: updated.weightKg,
                    heightCm: updated.heightCm,
                    activityLevel: updated.activityLevel,
                    workoutFreq: updated.workoutFreq,
                    goal: updated.goal,
                    pace: updated.pace,
                    targetWeightKg: updated.targetWeightKg,
                  );
                  await widget.storage.saveProfile(resetProfile);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text(
                  'Reset to auto-calculated',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
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
                  if (val == null || val < 500 || val > 10000) return;
                  final updated = Profile(
                    name: profile.name,
                    age: profile.age,
                    sex: profile.sex,
                    weightKg: profile.weightKg,
                    heightCm: profile.heightCm,
                    activityLevel: profile.activityLevel,
                    workoutFreq: profile.workoutFreq,
                    goal: profile.goal,
                    pace: profile.pace,
                    targetWeightKg: profile.targetWeightKg,
                    calorieGoalOverride: val,
                  );
                  await widget.storage.saveProfile(updated);
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _periodToggle() {
    final labels = ['Week', 'Month', 'Custom'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final active = _periodIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _periodIndex = i;
                _isMonthly = i == 1;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : _muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _weekNavigator() {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    final label = '${DateFormat('MMM d').format(_selectedWeekStart)} – ${DateFormat('MMM d').format(end)}';
    final isCurrentWeek = _isSameDay(_selectedWeekStart, _currentWeekStart);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _canGoBackWeek ? () => setState(() {
              _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
            }) : null,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _canGoBackWeek ? const Color(0xFFF4F4F1) : const Color(0xFFF4F4F1).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_left, color: _canGoBackWeek ? _ink : _muted.withValues(alpha: 0.4), size: 20),
            ),
          ),
          Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              if (isCurrentWeek)
                const Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: isCurrentWeek ? null : () => setState(() {
              _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isCurrentWeek ? const Color(0xFFF4F4F1).withOpacity(0.5) : const Color(0xFFF4F4F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_right, color: isCurrentWeek ? _muted.withOpacity(0.4) : _ink, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  DateTime get _currentWeekStart {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday % 7));
  }

  DateTime? get _earliestDate {
    if (_entries.isEmpty) return null;
    return _entries
        .map((e) => e.dateTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  bool get _canGoBackWeek {
    final earliest = _earliestDate;
    if (earliest == null) return true;
    final prevWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    final weekEnd = prevWeekStart.add(const Duration(days: 6));
    return !weekEnd.isBefore(DateTime(earliest.year, earliest.month, earliest.day));
  }

  bool get _canGoBackMonth {
    final earliest = _earliestDate;
    if (earliest == null) return true;
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    return !(prevMonth.year < earliest.year ||
        (prevMonth.year == earliest.year && prevMonth.month < earliest.month));
  }

  Widget _monthNavigator() {
    final label = DateFormat('MMMM yyyy').format(_selectedMonth);
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _canGoBackMonth ? () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
            }) : null,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _canGoBackMonth ? const Color(0xFFF4F4F1) : const Color(0xFFF4F4F1).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_left, color: _canGoBackMonth ? _ink : _muted.withValues(alpha: 0.4), size: 20),
            ),
          ),
          Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              if (isCurrentMonth)
                const Text(
                  'This month',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: isCurrentMonth ? null : () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isCurrentMonth ? const Color(0xFFF4F4F1).withOpacity(0.5) : const Color(0xFFF4F4F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_right, color: isCurrentMonth ? _muted.withOpacity(0.4) : _ink, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customRangeNavigator(BuildContext context) {
    final hasRange = _customStart != null && _customEnd != null;
    final label = hasRange
        ? '${DateFormat('MMM d').format(_customStart!)} – ${DateFormat('MMM d').format(_customEnd!)}'
        : 'Select date range';

    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: now,
          initialDateRange: _customStart != null && _customEnd != null
              ? DateTimeRange(start: _customStart!, end: _customEnd!)
              : DateTimeRange(
                  start: now.subtract(const Duration(days: 6)),
                  end: now,
                ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: _ink,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: _ink,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _customStart = picked.start;
            _customEnd = picked.end;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.date_range,
              color: hasRange ? _ink : _muted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: hasRange ? FontWeight.w700 : FontWeight.w500,
                color: hasRange ? _ink : _muted,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit_calendar_outlined,
              color: hasRange ? _ink : _muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _caloriesChart(Profile profile) {
    final goal = profile.calorieGoal;
    final days = _displayDays;
    final maxCal = [goal, ...days.map((d) => _caloriesForDay(d))].reduce((a, b) => a > b ? a : b);
    final useCompact = days.length > 14;

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
                'Calories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              GestureDetector(
                onTap: () => _showEditCalorieGoalSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Goal: $goal kcal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: useCompact
                ? _compactChart(days, goal, maxCal)
                : _weeklyChart(days, goal, maxCal),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _weeklyChart(List<DateTime> days, int goal, int maxCal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((day) {
        final cal = _caloriesForDay(day);
        final ratio = maxCal > 0 ? cal / maxCal : 0.0;
        final hitTarget = cal >= goal * 0.8;
        final isToday = _isSameDay(day, DateTime.now());
        final isFuture = day.isAfter(DateTime.now());

        Color barColor;
        if (isFuture || cal == 0) {
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
                if (cal > 0 && !isFuture)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '$cal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: barColor,
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: (ratio * 120).clamp(4.0, 120.0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('E').format(day)[0],
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
      }).toList(),
    );
  }

  Widget _compactChart(List<DateTime> days, int goal, int maxCal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((day) {
        final cal = _caloriesForDay(day);
        final ratio = maxCal > 0 ? cal / maxCal : 0.0;
        final hitTarget = cal >= goal * 0.8;
        final isToday = _isSameDay(day, DateTime.now());

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

        // Show every 5th date label to avoid crowding
        final showLabel = day.day == 1 || day.day % 5 == 0 || isToday;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: (ratio * 120).clamp(4.0, 120.0),
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  showLabel ? '${day.day}' : '',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? _ink : _muted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statsRow(Profile profile) {
    final goal = profile.calorieGoal;
    final periodGoal = goal * _totalDaysInPeriod;

    return Row(
      children: [
        _statCard(
          'Avg/day',
          '${_avgCalories.round()}',
          'kcal',
          _ink,
          Icons.local_fire_department,
        ),
        const SizedBox(width: 10),
        _statCard(
          'On target',
          '$_daysOnTarget',
          '/$_totalDaysInPeriod days',
          _green,
          Icons.check_circle_outline,
        ),
        const SizedBox(width: 10),
        _statCard(
          'Remaining',
          '${(periodGoal - _totalCalories).clamp(0, 999999)}',
          'kcal',
          periodGoal > _totalCalories ? _green : _missedRed,
          Icons.hourglass_bottom_rounded,
        ),
      ],
    );
  }

  static const _missedRed = Color(0xFFFF3B30);

  Widget _statCard(String label, String value, String unit, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
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
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _ink,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _macroOverview() {
    final total = _totalProtein + _totalCarbs + _totalFat;
    final proteinPct = total > 0 ? _totalProtein / total : 0.0;
    final carbsPct = total > 0 ? _totalCarbs / total : 0.0;
    final fatPct = total > 0 ? _totalFat / total : 0.0;

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
        children: [
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroStat('Protein', _totalProtein, 'g', _proteinColor, '${(proteinPct * 100).round()}%'),
              _macroStat('Carbs', _totalCarbs, 'g', _carbsColor, '${(carbsPct * 100).round()}%'),
              _macroStat('Fat', _totalFat, 'g', _fatColor, '${(fatPct * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroStat(String label, double value, String unit, Color color, String pct) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          '${value.round()}$unit',
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
    );
  }

  Widget _dayRow(DateTime day, Profile profile) {
    final cal = _caloriesForDay(day);
    final goal = profile.calorieGoal;
    final isToday = _isSameDay(day, DateTime.now());
    final isFuture = day.isAfter(DateTime.now());
    final hitTarget = cal >= goal * 0.8;
    final entries = _entriesForDay(day);

    Color dotColor;
    if (isFuture) {
      dotColor = const Color(0xFFE3E3DE);
    } else if (hitTarget) {
      dotColor = _green;
    } else if (cal > 0) {
      dotColor = const Color(0xFFFFA726);
    } else {
      dotColor = const Color(0xFFE3E3DE);
    }

    final mealNames = entries.expand((e) => e.items.map((i) => i.name)).take(3).join(', ');
    final progress = goal > 0 ? (cal / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Day indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dotColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('E').format(day).substring(0, 2),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: dotColor,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: dotColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isFuture ? '—' : '$cal kcal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isFuture ? _muted : _ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _ink.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (!isFuture && mealNames.isNotEmpty)
                  Text(
                    mealNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                    ),
                  )
                else if (!isFuture)
                  const Text(
                    'No meals logged',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
              ],
            ),
          ),

          // Mini progress ring
          if (!isFuture)
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFECECE7),
                    valueColor: AlwaysStoppedAnimation<Color>(dotColor),
                    strokeWidth: 3,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: dotColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightEntry> entries;
  final double yMin;
  final double yMax;

  _WeightChartPainter({
    required this.entries,
    required this.yMin,
    required this.yMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1C1C1E).withOpacity(0.15),
          const Color(0xFF1C1C1E).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final yRange = yMax - yMin;
    if (yRange <= 0) return;

    final points = <Offset>[];
    for (int i = 0; i < entries.length; i++) {
      final x = entries.length == 1
          ? size.width / 2
          : (i / (entries.length - 1)) * size.width;
      final y = size.height - ((entries[i].weightKg - yMin) / yRange) * size.height;
      points.add(Offset(x, y));
    }

    path.moveTo(points.first.dx, points.first.dy);
    fillPath.moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
      fillPath.lineTo(points[i].dx, points[i].dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }

    final last = points.last;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${entries.last.weightKg.toStringAsFixed(1)}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1C1C1E),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final labelX = last.dx - textPainter.width / 2;
    final labelY = last.dy - textPainter.height - 8;
    textPainter.paint(canvas, Offset(labelX, labelY));
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      entries != oldDelegate.entries ||
      yMin != oldDelegate.yMin ||
      yMax != oldDelegate.yMax;
}
