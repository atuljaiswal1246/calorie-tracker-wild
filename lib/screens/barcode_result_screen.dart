import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../services/barcode_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'barcode_scanner_screen.dart';

class BarcodeResultScreen extends StatefulWidget {
  final BarcodeResult result;
  final StorageService storage;

  BarcodeResultScreen({
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
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✅', style: TextStyle(fontSize: 32)),
              SizedBox(height: 10),
              Text(
                'Logged!',
                style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              SizedBox(height: 8),
              Text(
                'Added to your day.',
                style: TextStyle(fontSize: AppType.body, color: AppColors.muted),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.inkButton,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppSpace.md),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Scan another', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Done', style: TextStyle(color: AppColors.muted)),
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
          padding: EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(AppSpace.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
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
            SizedBox(height: 24),

            // Product card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sheet),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_r.imageUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Image.network(
                        _r.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  Text(
                    _r.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (_r.brand.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      _r.brand,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F0EC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _r.barcode,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Quantity presets
                  Row(
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${_quantity.round()}g',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _qtyPreset('50g', 50),
                      SizedBox(width: 8),
                      _qtyPreset('100g', 100),
                      SizedBox(width: 8),
                      _qtyPreset('150g', 150),
                      SizedBox(width: 8),
                      _qtyPreset('200g', 200),
                      SizedBox(width: 8),
                      _qtyPreset('Custom', _quantity),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Calories
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_calories',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -1,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 6, left: AppSpace.xs),
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
                  SizedBox(height: 16),

                  // Macros
                  Row(
                    children: [
                      _macroPill('P', '${_protein.round()}g', Color(0xFFE53935)),
                      SizedBox(width: 8),
                      _macroPill('C', '${_carbs.round()}g', Color(0xFFFF9500)),
                      SizedBox(width: 8),
                      _macroPill('F', '${_fat.round()}g', Color(0xFF007AFF)),
                      SizedBox(width: 8),
                      _macroPill('Fi', '${_fiber.round()}g', AppColors.green),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Meal type
            Row(
              children: ['breakfast', 'lunch', 'dinner', 'snack'].map((type) {
                final selected = _mealType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = type),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 3),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.ink : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: selected ? null : Border.all(color: Color(0xFFE5E5EA)),
                      ),
                      child: Center(
                        child: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            fontSize: AppType.body,
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
                padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _log,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkButton,
                      foregroundColor: Colors.white,
                      shape: StadiumBorder(),
                    ),
                    child: Text('Log this meal',
                        style: TextStyle(
                            fontSize: AppType.title,
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
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppType.bodyStrong,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            SizedBox(height: 2),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
              title: Text('Enter amount (g)'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                TextButton(
                  onPressed: () {
                    final v = double.tryParse(controller.text);
                    if (v != null && v > 0) Navigator.pop(ctx, v);
                  },
                  child: Text('OK'),
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Color(0xFFF1F0EC),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppType.body,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
