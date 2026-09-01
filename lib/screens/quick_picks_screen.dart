import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/food_entry.dart';
import '../services/food_search_service.dart';
import '../services/quick_pick_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

/// One-tap logging of popular Indian dishes (Poha, Idli, Dal, Bhindi…).
/// Every pick resolves to an exact DB entry, so macros are precise without
/// an AI call — no "generic vegetable curry" problem here.
class QuickPicksScreen extends StatefulWidget {
  final StorageService storage;

  const QuickPicksScreen({super.key, required this.storage});

  @override
  State<QuickPicksScreen> createState() => _QuickPicksScreenState();
}

class _QuickPicksScreenState extends State<QuickPicksScreen> {
  List<QuickPick> _picks = [];
  String _query = '';
  bool _loading = true;
  String _mealType = _autoMealType();

  static String _autoMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'breakfast';
    if (hour < 16) return 'lunch';
    if (hour < 21) return 'dinner';
    return 'snack';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final picks = await QuickPickService.load();
    if (!mounted) return;
    setState(() {
      _picks = picks;
      _loading = false;
    });
  }

  List<QuickPick> get _filtered => _picks
      .where((p) =>
          _query.isEmpty || p.label.toLowerCase().contains(_query))
      .toList();

  Future<void> _logPick(QuickPick pick) async {
    final food = await QuickPickService.byName(pick.dbName);
    if (!mounted) return;
    if (food == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This dish is unavailable right now.')),
      );
      return;
    }
    if (!mounted) return;
    final logged = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _PickConfirmSheet(
        food: food,
        mealType: _mealType,
        onMealTypeChanged: (v) => setState(() => _mealType = v),
        onLog: () => _logLocalFood(food),
      ),
    );
    if (logged == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _logLocalFood(FoodDBItem food) async {
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: [
        FoodItem(
          name: food.name,
          servingSizeGrams: 100,
          calories: food.calories,
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
          fiber: food.fiber,
          sugar: food.sugar,
          sodium: food.sodium,
          calcium: food.calcium,
          iron: food.iron,
          vitaminC: food.vitaminC,
          quantity: 1,
        ),
      ],
      imagePath: '',
    );

    await widget.storage.addEntry(entry);
    await widget.storage.addRecentFood({
      'name': food.name,
      'calories': food.calories,
      'protein': food.protein,
      'carbs': food.carbs,
      'fat': food.fat,
    });
    if (!mounted) return;
    HapticFeedback.lightImpact();
    // Close the bottom sheet with success.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Popular Indian dishes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search dishes (poha, idli, dal…)',
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.ink, strokeWidth: 2))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No dishes match "$_query"',
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.muted),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            const Text(
                              'Tap a dish, pick your portion, log it — no AI needed.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted, height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            ..._filtered.map((p) => _PickTile(
                                  pick: p,
                                  onTap: () => _logPick(p),
                                )),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final QuickPick pick;
  final VoidCallback onTap;

  const _PickTile({required this.pick, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.chipBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant,
                  size: 17, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pick.label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink),
              ),
            ),
            const Icon(Icons.add_circle_outline,
                size: 20, color: AppColors.protein),
          ],
        ),
      ),
    );
  }
}

class _PickConfirmSheet extends StatefulWidget {
  final FoodDBItem food;
  final String mealType;
  final ValueChanged<String> onMealTypeChanged;
  final VoidCallback onLog;

  const _PickConfirmSheet({
    required this.food,
    required this.mealType,
    required this.onMealTypeChanged,
    required this.onLog,
  });

  @override
  State<_PickConfirmSheet> createState() => _PickConfirmSheetState();
}

class _PickConfirmSheetState extends State<_PickConfirmSheet> {
  double _grams = 100;
  static const _portions = [
    (100.0, 'Small'),
    (150.0, 'Medium'),
    (200.0, 'Large'),
  ];

  int get _calories => (widget.food.calories * _grams / 100).round();
  double get _protein => widget.food.protein * _grams / 100;
  double get _carbs => widget.food.carbs * _grams / 100;
  double get _fat => widget.food.fat * _grams / 100;

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              food.name,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Per 100 g: ${food.calories} kcal · ${food.protein.toStringAsFixed(1)}g P · ${food.carbs.toStringAsFixed(1)}g C · ${food.fat.toStringAsFixed(1)}g F',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            // Portion presets
            Row(
              children: [
                for (final (g, label) in _portions) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _grams = g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _grams == g
                              ? AppColors.ink
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _grams == g
                                  ? AppColors.ink
                                  : Colors.black12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _grams == g
                                    ? Colors.white
                                    : AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${g.toStringAsFixed(0)} g',
                              style: TextStyle(
                                fontSize: 11,
                                color: _grams == g
                                    ? Colors.white70
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'g',
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) => setState(() {
                      final g = double.tryParse(v.trim());
                      if (g != null && g > 0) _grams = g;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Meal type pills
            Row(
              children: [
                _mealPill('Breakfast', 'breakfast'),
                const SizedBox(width: 6),
                _mealPill('Lunch', 'lunch'),
                const SizedBox(width: 6),
                _mealPill('Dinner', 'dinner'),
                const SizedBox(width: 6),
                _mealPill('Snack', 'snack'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  widget.onLog();
                },
                child: Text(
                  'Log — $_calories kcal',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealPill(String label, String value) {
    final selected = widget.mealType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onMealTypeChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: selected ? AppColors.ink : Colors.black12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
