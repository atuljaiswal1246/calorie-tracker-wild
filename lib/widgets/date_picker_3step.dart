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

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _year = widget.initial!.year;
      _month = widget.initial!.month;
      _step = 2;
    }
  }

  int get _daysInMonth =>
      DateTime(_year ?? 2000, _month ?? 1, 0).day;

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
            const SizedBox(height: 4),
            Expanded(child: _grid()),
          ],
        ),
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
      final years = [
        for (var y = widget.lastYear; y >= widget.firstYear; y--) y
      ];
      return GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          for (final y in years)
            _cell('$y', y == _year, () => _pick(y)),
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
