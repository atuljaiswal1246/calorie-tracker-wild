import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/food_entry.dart';
import '../services/storage_service.dart';

class MealDetailScreen extends StatefulWidget {
  final FoodEntry entry;
  final StorageService? storage;

  /// Called after the user confirms deletion (parent pops + refreshes).
  final Future<void> Function()? onDeleted;

  const MealDetailScreen({
    super.key,
    required this.entry,
    this.storage,
    this.onDeleted,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late final List<FoodItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.entry.items.map((e) => e).toList();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text(
          widget.entry.items.isEmpty
              ? 'This will remove the meal from your log.'
              : '"${widget.entry.items.first.name}" and '
                  '${widget.entry.items.length - 1} other item(s) will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE03131))),
          ),
        ],
      ),
    );
    if (confirmed == true && widget.onDeleted != null) {
      await widget.onDeleted!();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final storage = widget.storage;
    if (storage == null) {
      Navigator.pop(context);
      return;
    }
    final updated = FoodEntry(
      id: widget.entry.id,
      dateTime: widget.entry.dateTime,
      mealType: widget.entry.mealType,
      items: List<FoodItem>.from(_items),
      imagePath: widget.entry.imagePath,
    );
    await storage.updateEntry(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meal updated'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a, MMM d').format(widget.entry.dateTime);
    final mealLabel = widget.entry.mealType[0].toUpperCase() +
        widget.entry.mealType.substring(1);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          mealLabel,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.storage != null) ...[
            IconButton(
              icon: const Icon(Icons.save_outlined, color: Colors.black),
              tooltip: 'Save changes',
              onPressed: _save,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE03131)),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (widget.entry.imagePath.isNotEmpty &&
                File(widget.entry.imagePath).existsSync())
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    File(widget.entry.imagePath),
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ...List.generate(_items.length, (i) => _itemCard(i)),

            const SizedBox(height: 24),

            // Totals (live from current quantities)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _totalStat('🔥', '${_totalCalories}', 'kcal',
                            Colors.white),
                        _totalStat('🥩',
                            '${_totalProtein.toStringAsFixed(1)}g', 'protein',
                            Colors.white),
                        _totalStat('🌾', '${_totalCarbs.toStringAsFixed(1)}g',
                            'carbs', Colors.white),
                        _totalStat('🧈', '${_totalFat.toStringAsFixed(1)}g',
                            'fat', Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  int get _totalCalories =>
      _items.fold(0, (sum, item) => sum + item.calories);

  double get _totalProtein =>
      _items.fold(0.0, (sum, item) => sum + item.protein);

  double get _totalCarbs =>
      _items.fold(0.0, (sum, item) => sum + item.carbs);

  double get _totalFat => _items.fold(0.0, (sum, item) => sum + item.fat);

  Widget _itemCard(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  '${item.calories} kcal',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _macroTag('Protein', '${item.protein.toStringAsFixed(1)}g', const Color(0xFFFF6B6B)),
                const SizedBox(width: 8),
                _macroTag('Carbs', '${item.carbs.toStringAsFixed(1)}g', const Color(0xFFFFA94D)),
                const SizedBox(width: 8),
                _macroTag('Fat', '${item.fat.toStringAsFixed(1)}g', const Color(0xFF4DABF7)),
              ],
            ),
            if (item.fiber > 0 || item.sugar > 0 || item.sodium > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (item.fiber > 0) ...[
                    _macroTag('Fiber', '${item.fiber.toStringAsFixed(1)}g', const Color(0xFF8D6E63)),
                    const SizedBox(width: 8),
                  ],
                  if (item.sugar > 0) ...[
                    _macroTag('Sugar', '${item.sugar.toStringAsFixed(1)}g', const Color(0xFFE91E63)),
                    const SizedBox(width: 8),
                  ],
                  if (item.sodium > 0)
                    _macroTag('Sodium', '${item.sodium.toStringAsFixed(0)}mg', const Color(0xFF78909C)),
                ],
              ),
            ],
            if (widget.storage != null) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.grey[200], height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Servings',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (item.quantity > 0.5) {
                          item.quantity = double.parse(
                              (item.quantity - 0.5).toStringAsFixed(1));
                        }
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                  ),
                  Container(
                    width: 56,
                    alignment: Alignment.center,
                    child: Text(
                      item.quantity.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        item.quantity = double.parse(
                            (item.quantity + 0.5).toStringAsFixed(1));
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _totalStat(String emoji, String value, String label, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
