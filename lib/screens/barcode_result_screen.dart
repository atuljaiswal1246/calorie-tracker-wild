import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../services/barcode_service.dart';
import '../services/storage_service.dart';

class BarcodeResultScreen extends StatefulWidget {
  final BarcodeResult result;
  final StorageService storage;

  const BarcodeResultScreen({
    super.key,
    required this.result,
    required this.storage,
  });

  @override
  State<BarcodeResultScreen> createState() => _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends State<BarcodeResultScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _green = Color(0xFF34C759);

  double _quantity = 100;
  String _mealType = 'snack';

  BarcodeResult get _r => widget.result;

  int get _calories => (_r.calories * _quantity / 100).round();
  double get _protein => _r.protein * _quantity / 100;
  double get _carbs => _r.carbs * _quantity / 100;
  double get _fat => _r.fat * _quantity / 100;
  double get _fiber => _r.fiber * _quantity / 100;

  @override
  void initState() {
    super.initState();
    _detectMealType();
  }

  void _detectMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      _mealType = 'breakfast';
    } else if (hour < 15) {
      _mealType = 'lunch';
    } else if (hour < 20) {
      _mealType = 'dinner';
    } else {
      _mealType = 'snack';
    }
  }

  Future<void> _log() async {
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: [
        FoodItem(
          name: '${_r.name}${_r.brand.isNotEmpty ? ' (${_r.brand})' : ''}',
          servingSizeGrams: _quantity,
          calories: _r.calories,
          protein: _r.protein,
          carbs: _r.carbs,
          fat: _r.fat,
          fiber: _r.fiber,
          sugar: _r.sugar,
          sodium: _r.sodium,
          quantity: _quantity / 100,
        ),
      ],
      imagePath: '',
    );

    await widget.storage.addEntry(entry);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged!'),
        backgroundColor: Color(0xFF34C759),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Product Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Product card
            Container(
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
                  Text(
                    _r.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  if (_r.brand.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _r.brand,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F0EC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _r.barcode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quantity slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      Text(
                        '${_quantity.round()}g',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _ink,
                      inactiveTrackColor: const Color(0xFFECECE7),
                      thumbColor: _ink,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _quantity,
                      min: 10,
                      max: 500,
                      divisions: 49,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Calories
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_calories',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6, left: 4),
                        child: Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Macros
                  Row(
                    children: [
                      _macroPill('P', '${_protein.round()}g', const Color(0xFFE53935)),
                      const SizedBox(width: 8),
                      _macroPill('C', '${_carbs.round()}g', const Color(0xFFFF9500)),
                      const SizedBox(width: 8),
                      _macroPill('F', '${_fat.round()}g', const Color(0xFF007AFF)),
                      const SizedBox(width: 8),
                      _macroPill('Fi', '${_fiber.round()}g', _green),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Meal type
            Row(
              children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                final selected = _mealType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = type),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _ink : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: selected ? null : Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Center(
                        child: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : _ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomSheet: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 2, color: Colors.black12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _log,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Log this meal',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
