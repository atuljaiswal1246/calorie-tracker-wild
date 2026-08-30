import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../services/barcode_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'barcode_scanner_screen.dart';

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

    final scanAnother = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              const Text(
                'Logged!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Added to your day.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Scan another', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Done', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (scanAnother == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeScannerScreen(storage: widget.storage),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                      color: AppColors.ink,
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
                  if (_r.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _r.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _r.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (_r.brand.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _r.brand,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
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
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quantity presets
                  Row(
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_quantity.round()}g',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _qtyPreset('50g', 50),
                      const SizedBox(width: 8),
                      _qtyPreset('100g', 100),
                      const SizedBox(width: 8),
                      _qtyPreset('150g', 150),
                      const SizedBox(width: 8),
                      _qtyPreset('200g', 200),
                      const SizedBox(width: 8),
                      _qtyPreset('Custom', _quantity),
                    ],
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
                          color: AppColors.ink,
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
                            color: AppColors.muted,
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
                      _macroPill('Fi', '${_fiber.round()}g', AppColors.green),
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
                        color: selected ? AppColors.ink : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: selected ? null : Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Center(
                        child: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.ink,
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
                      backgroundColor: AppColors.ink,
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

  Widget _qtyPreset(String label, double grams) {
    final selected = _quantity == grams;
    return GestureDetector(
      onTap: () async {
        if (label == 'Custom') {
          final controller = TextEditingController(text: _quantity.round().toString());
          final result = await showDialog<double>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Enter amount (g)'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    final v = double.tryParse(controller.text);
                    if (v != null && v > 0) Navigator.pop(ctx, v);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (result != null) setState(() => _quantity = result.clamp(10, 1000));
        } else {
          setState(() => _quantity = grams);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : const Color(0xFFF1F0EC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
