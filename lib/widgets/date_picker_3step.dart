import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// A 3-step date picker: **year → month → day**.
/// Better than a wheel for birth dates: you pick the year first (fast),
/// then the month, then the day.
Future<DateTime?> showDatePicker3Step(
  BuildContext context, {
  DateTime? initial,
  int? lastYear,
  int? firstYear,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _Date3StepSheet(
      initial: initial,
      firstYear: firstYear ?? now.year - 100,
      lastYear: lastYear ?? now.year,
    ),
  );
}

class _Date3StepSheet extends StatefulWidget {
  final DateTime? initial;
  final int firstYear;
  final int lastYear;
  const _Date3StepSheet({
    this.initial,
    required this.firstYear,
    required this.lastYear,
  });

  @override
  State<_Date3StepSheet> createState() => _Date3StepSheetState();
}

class _Date3StepSheetState extends State<_Date3StepSheet> {
  int _step = 0; // 0 = year, 1 = month, 2 = day
  int? _year;
  int? _month;
  late int _pageStart;

  /// Default page: 1990–2010 (21 years, 3x7). Arrows page by a full screen.
  static const _firstPageStart = 1990;
  static const _yearsPerPage = 21;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final y = widget.initial!.year;
      _pageStart = _firstPageStart +
          (((y - _firstPageStart) ~/ _yearsPerPage) * _yearsPerPage);
      _year = y;
      _month = widget.initial!.month;
      _step = 2;
    } else {
      _pageStart = _firstPageStart;
    }
  }

  int get _pageEnd => _pageStart + _yearsPerPage - 1;

  bool get _canPrevPage =>
      _pageStart - _yearsPerPage + _yearsPerPage - 1 >= widget.firstYear &&
      _pageStart > widget.firstYear;
  bool get _canNextPage => _pageStart + _yearsPerPage <= widget.lastYear;

  List<int> get _pageYears => [
        for (var y = _pageStart; y <= _pageEnd; y++)
          if (y >= widget.firstYear && y <= widget.lastYear) y,
      ];

  int get _daysInMonth =>
      DateTime(_year ?? 2000, _month ?? 1, 0).day;

  void _shiftPage(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _pageStart += delta);
  }

  void _pick(int v) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_step == 0) {
        _year = v;
        _step = 1;
      } else if (_step == 1) {
        _month = v;
        _step = 2;
      }
    });
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 14, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _step == 0 ? () => Navigator.pop(context) : _back,
                    icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back,
                        color: AppColors.ink),
                  ),
                  Expanded(
                    child: Text(
                      _title(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text('${_step + 1}/3',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted)),
                ],
              ),
            ),
            if (_step == 0) _decadeNav(),
            const SizedBox(height: 4),
            Expanded(child: _grid()),
          ],
        ),
      ),
    );
  }

  Widget _decadeNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          _navArrow(Icons.chevron_left_rounded, _canPrevPage,
              () => _shiftPage(-_yearsPerPage)),
          Expanded(
            child: Text(
              '$_pageStart – $_pageEnd',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _navArrow(Icons.chevron_right_rounded, _canNextPage,
              () => _shiftPage(_yearsPerPage)),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled ? AppColors.chipNeutral : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            size: 22,
            color: enabled ? AppColors.ink : AppColors.divider),
      ),
    );
  }

  String _title() {
    if (_step == 0) return 'Select year';
    if (_step == 1) return 'Select month';
    return 'Select day';
  }

  Widget _grid() {
    if (_step == 0) {
      return GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        crossAxisCount: 3,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 2.2,
        children: [
          for (final y in _pageYears) _cell('$y', y == _year, () => _pick(y)),
        ],
      );
    }
    if (_step == 1) {
      return GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          for (var m = 1; m <= 12; m++)
            _cell(_months[m - 1], m == _month, () => _pick(m)),
        ],
      );
    }
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        for (var d = 1; d <= _daysInMonth; d++)
          _cell('$d', false, () {
            HapticFeedback.lightImpact();
            Navigator.pop(context, DateTime(_year!, _month!, d));
          }),
      ],
    );
  }

  Widget _cell(String label, bool selected, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.inkButton : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.divider,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
