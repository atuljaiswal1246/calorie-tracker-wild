import 'package:flutter/material.dart';

import '../../services/food_search_service.dart';
import '../../theme/app_colors.dart';
import 'demo_common.dart';

/// Try-before-you-buy demo: search the real, offline Indian food database and
/// see the full calorie + macro breakdown of any food. No account needed.
class DemoSearchScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const DemoSearchScreen({super.key, required this.onGetStarted});

  @override
  State<DemoSearchScreen> createState() => _DemoSearchScreenState();
}

class _DemoSearchScreenState extends State<DemoSearchScreen> {
  final _controller = TextEditingController();
  List<FoodDBItem> _results = const [];
  bool _searched = false;
  int? _dbSize;

  static const _suggestions = [
    'Paneer',
    'Dal',
    'Roti',
    'Biryani',
    'Idli',
    'Chicken',
    'Banana',
    'Milk',
  ];

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final all = await FoodSearchService.search('a', limit: 100000);
    if (mounted) setState(() => _dbSize = all.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    _controller.text = q;
    _controller.selection =
        TextSelection.collapsed(offset: q.length);
    final r = await FoodSearchService.search(q);
    if (!mounted) return;
    setState(() {
      _results = r;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: DemoHeader(
                title: 'Food search',
                onBack: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                _dbSize == null
                    ? 'Search thousands of Indian foods — works offline.'
                    : '$_dbSize Indian foods · works offline, no account needed.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Try "paneer" or "dal"',
                          hintStyle: TextStyle(
                              fontSize: 15, color: AppColors.faint),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onChanged: (q) => _run(q),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() {
                            _results = const [];
                            _searched = false;
                          });
                        },
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.faint),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _body()),
            DemoCta(label: 'Get started', onTap: widget.onGetStarted),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (!_searched) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        children: [
          Text('Popular searches',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _suggestions)
                GestureDetector(
                  onTap: () => _run(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.chipNeutral,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                  ),
                ),
            ],
          ),
        ],
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('No match. Try "paneer", "dal" or "rice".',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = _results[i];
        return GestureDetector(
          onTap: () => _showDetail(f),
          child: DemoCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      if (f.nameHindi.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(f.nameHindi,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ],
                  ),
                ),
                Text('${f.calories}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(width: 3),
                Text('kcal',
                    style:
                        TextStyle(fontSize: 10.5, color: AppColors.muted)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.faint),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetail(FoodDBItem f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(f.name,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.4)),
            if (f.nameHindi.isNotEmpty)
              Text(f.nameHindi,
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                RingStat(
                  pct: (f.calories / 600).clamp(0, 1),
                  color: AppColors.green,
                  size: 92,
                  stroke: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CountUp(
                        value: f.calories,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink),
                      ),
                      Text('kcal',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      MacroBar(
                          label: 'Protein',
                          value: '${f.protein.toStringAsFixed(0)}g',
                          pct: f.protein / 40,
                          color: AppColors.green),
                      MacroBar(
                          label: 'Carbs',
                          value: '${f.carbs.toStringAsFixed(0)}g',
                          pct: f.carbs / 80,
                          color: AppColors.carbs),
                      MacroBar(
                          label: 'Fats',
                          value: '${f.fat.toStringAsFixed(0)}g',
                          pct: f.fat / 40,
                          color: const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DemoCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  _kv('Fiber', '${f.fiber.toStringAsFixed(1)} g'),
                  _kv('Sugar', '${f.sugar.toStringAsFixed(1)} g'),
                  _kv('Sodium', '${f.sodium.toStringAsFixed(0)} mg'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DemoCta(
              label: 'Get started to log this',
              onTap: () {
                Navigator.pop(context);
                widget.onGetStarted();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(k, style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const Spacer(),
          Text(v,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}
