import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';
import 'meal_detail_screen.dart';

class AllEntriesScreen extends StatefulWidget {
  final StorageService storage;

  const AllEntriesScreen({super.key, required this.storage});

  @override
  State<AllEntriesScreen> createState() => _AllEntriesScreenState();
}

class _AllEntriesScreenState extends State<AllEntriesScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _green = Color(0xFF34C759);
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);
  static const _cardShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ];

  List<FoodEntry> _allEntries = [];
  int _periodIndex = 0; // 0=week, 1=month, 2=custom
  DateTime _selectedWeekStart = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = now.subtract(Duration(days: now.weekday % 7));
    _load();
  }

  void _load() {
    _allEntries = widget.storage.entries;
    setState(() {});
  }

  List<FoodEntry> get _filteredEntries {
    final now = DateTime.now();
    final earliest = _earliestDate;
    List<DateTime> days;

    if (_periodIndex == 2 && _customStart != null && _customEnd != null) {
      var start = _customStart!;
      if (earliest != null && start.isBefore(earliest)) {
        start = DateTime(earliest.year, earliest.month, earliest.day);
      }
      final diff = _customEnd!.difference(start).inDays + 1;
      if (diff <= 0) return [];
      days = List.generate(diff, (i) => start.add(Duration(days: i)));
    } else if (_periodIndex == 1) {
      final isFirstMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
      var firstOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      if (earliest != null && firstOfMonth.isBefore(earliest)) {
        firstOfMonth = DateTime(earliest.year, earliest.month, earliest.day);
      }
      final daysInMonth = isFirstMonth ? now.day : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      final lastDay = isFirstMonth ? now.day : daysInMonth;
      days = List.generate(lastDay, (i) => DateTime(_selectedMonth.year, _selectedMonth.month, i + 1))
          .where((d) => !d.isBefore(firstOfMonth))
          .toList();
    } else {
      var start = _selectedWeekStart;
      if (earliest != null && start.isBefore(DateTime(earliest.year, earliest.month, earliest.day))) {
        start = DateTime(earliest.year, earliest.month, earliest.day);
      }
      days = List.generate(7, (i) => _selectedWeekStart.add(Duration(days: i)))
          .where((d) => !d.isBefore(start))
          .toList();
    }

    // Collect entries that fall on any of the display days
    final filtered = <FoodEntry>[];
    for (final day in days) {
      for (final entry in _allEntries) {
        if (entry.isOn(day)) {
          filtered.add(entry);
        }
      }
    }

    // Sort newest first
    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? get _earliestDate {
    if (_allEntries.isEmpty) return null;
    return _allEntries
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

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    final periodLabel = _periodIndex == 2
        ? 'selected period'
        : _periodIndex == 1
            ? 'this month'
            : 'this week';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'All Meals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  Text(
                    '${entries.length} meals',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Period toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _periodToggle(),
            ),
            const SizedBox(height: 12),

            // Navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _periodIndex == 0
                  ? _weekNavigator()
                  : _periodIndex == 1
                      ? _monthNavigator()
                      : _customRangeNavigator(context),
            ),
            const SizedBox(height: 16),

            // Entries list
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🍽️', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text(
                            'No meals logged $periodLabel',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: entries.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _mealCard(entries[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= Filters =================

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
              onTap: () => setState(() => _periodIndex = i),
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
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday % 7));
    final isCurrentWeek = _isSameDay(_selectedWeekStart, currentWeekStart);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
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
                  style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
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

  Widget _monthNavigator() {
    final label = DateFormat('MMMM yyyy').format(_selectedMonth);
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
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
                  style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
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
              : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
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
          boxShadow: _cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.date_range, color: hasRange ? _ink : _muted, size: 20),
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
            Icon(Icons.edit_calendar_outlined, color: hasRange ? _ink : _muted, size: 16),
          ],
        ),
      ),
    );
  }

  // ================= Meal Card =================

  Widget _mealCard(FoodEntry entry) {
    final name = entry.items.isEmpty ? 'Meal' : entry.items.first.name;
    final time = DateFormat('h:mm a, MMM d').format(entry.dateTime).toLowerCase();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MealDetailScreen(entry: entry)),
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
                      _macroPill(Icons.egg_alt, _proteinColor, '${entry.totalProtein.toStringAsFixed(0)}g'),
                      const SizedBox(width: 8),
                      _macroPill(Icons.grain, _carbsColor, '${entry.totalCarbs.toStringAsFixed(0)}g'),
                      const SizedBox(width: 8),
                      _macroPill(Icons.water_drop, _fatColor, '${entry.totalFat.toStringAsFixed(0)}g'),
                    ],
                  ),
                  if (entry.totalFiber > 0 || entry.totalSugar > 0 || entry.totalSodium > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (entry.totalFiber > 0) ...[
                          _macroPill(Icons.grass, const Color(0xFF8D6E63), '${entry.totalFiber.toStringAsFixed(0)}g'),
                          const SizedBox(width: 8),
                        ],
                        if (entry.totalSugar > 0) ...[
                          _macroPill(Icons.cake, const Color(0xFFE91E63), '${entry.totalSugar.toStringAsFixed(0)}g'),
                          const SizedBox(width: 8),
                        ],
                        if (entry.totalSodium > 0)
                          _macroPill(Icons.water_drop_outlined, const Color(0xFF78909C), '${entry.totalSodium.toStringAsFixed(0)}mg'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
