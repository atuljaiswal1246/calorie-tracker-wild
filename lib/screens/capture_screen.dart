import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/food_entry.dart';
import '../services/gemini_service.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';

class CaptureScreen extends StatefulWidget {
  final StorageService storage;
  final File? initialImage;

  const CaptureScreen({super.key, required this.storage, this.initialImage});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);

  final _picker = ImagePicker();
  File? _image;
  bool _analyzing = false;
  String? _error;
  List<FoodItem>? _items;
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
    if (widget.initialImage != null) {
      _copyToPermanent(widget.initialImage!);
    }
  }

  Future<void> _copyToPermanent(File source) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final ext = source.path.split('.').last;
      final fileName = 'meal_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final dest = '${appDir.path}/$fileName';
      final permanentFile = await source.copy(dest);
      final exists = await permanentFile.exists();
      setState(() {
        _image = exists ? permanentFile : source;
      });
    } catch (e) {
      setState(() => _image = source);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 70,
    );
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _items = null;
        _error = null;
      });
      _analyze();
    }
  }

  Future<void> _analyze() async {
    final provider = widget.storage.provider;
    String? apiKey;
    String providerLabel = provider;

    if (provider == 'gemini') {
      apiKey = widget.storage.geminiKey;
      providerLabel = 'Gemini';
    } else {
      apiKey = widget.storage.apiKey;
      providerLabel = 'OpenAI';
    }

    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _error = 'Add your $providerLabel API key in Settings first.');
      return;
    }
    final image = _image;
    if (image == null) return;

    setState(() {
      _analyzing = true;
      _error = null;
      _items = null;
    });

    try {
      ({List<FoodItem> items, String? mealType}) result;
      if (provider == 'gemini') {
        result = await GeminiService(apiKey: apiKey).analyzeImage(image.path);
      } else {
        result = await OpenAIService(apiKey: apiKey).analyzeImage(image.path);
      }
      if (!mounted) return;
      setState(() {
        _items = result.items.isNotEmpty ? result.items : null;
        _analyzing = false;
        if (result.mealType != null) _mealType = result.mealType!;
        if (result.items.isEmpty) _error = 'No food detected. Try another photo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = _friendlyError(e.toString());
      });
    }
  }

  static String _friendlyError(String raw) {
    var s = raw.replaceAll(RegExp(r'key=[^&\s]+'), 'key=***');
    if (s.contains('SocketException') || s.contains('Connection reset')) {
      return 'Network error. Check your connection.';
    }
    if (s.contains('429') || s.contains('quota')) {
      return 'Too many requests. Wait a moment.';
    }
    if (s.contains('403') || s.contains('API key')) {
      return 'API key error. Check Settings.';
    }
    return 'Analysis failed. Please try again.';
  }

  Future<void> _log() async {
    final items = _items;
    if (items == null || items.isEmpty) return;

    String savedPath = _image!.path;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final ext = _image!.path.split('.').last;
      final fileName = 'meal_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final dest = '${appDir.path}/$fileName';
      final permanentFile = await _image!.copy(dest);
      if (await permanentFile.exists()) savedPath = permanentFile.path;
    } catch (e) {
      debugPrint('Image copy failed: $e');
    }

    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: items,
      imagePath: savedPath,
    );

    await widget.storage.addEntry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged! Added to your day.')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Nutrition',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _ink),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image
                    if (_image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child:
                            Image.file(_image!, height: 240, fit: BoxFit.cover),
                      ),
                    const SizedBox(height: 16),

                    // Camera / Gallery
                    if (widget.initialImage == null && _items == null)
                      Row(
                        children: [
                          Expanded(
                            child: _outlineBtn(
                                icon: Icons.photo_camera,
                                label: 'Camera',
                                onTap: () => _pickImage(ImageSource.camera)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _outlineBtn(
                                icon: Icons.photo_library,
                                label: 'Gallery',
                                onTap: () => _pickImage(ImageSource.gallery)),
                          ),
                        ],
                      ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(_error!,
                                style: const TextStyle(
                                    color: Color(0xFFD32F2F), fontSize: 14)),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _analyze,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Retry'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Analyzing
                    if (_analyzing) ...[
                      const SizedBox(height: 32),
                      const Center(
                          child:
                              CircularProgressIndicator(color: _ink, strokeWidth: 2)),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text('Analyzing your food...',
                            style: TextStyle(color: _muted, fontSize: 14)),
                      ),
                    ],

                    // Results
                    if (_items != null && !_analyzing) ...[
                      const SizedBox(height: 16),

                      // Meal type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButton<String>(
                          value: _mealType,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _ink),
                          items: const [
                            DropdownMenuItem(
                                value: 'breakfast', child: Text('Breakfast')),
                            DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                            DropdownMenuItem(
                                value: 'dinner', child: Text('Dinner')),
                            DropdownMenuItem(value: 'snack', child: Text('Snack')),
                          ],
                          onChanged: (v) => setState(() => _mealType = v!),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Food items
                      ..._items!.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return _FoodItemCard(
                          item: item,
                          onQuantityChanged: (oldQty, newQty) {
                            setState(() {
                              item.rescaleEdits(oldQty, newQty);
                              item.quantity = newQty;
                            });
                          },
                          onEditServing: (newGrams) {
                            setState(() {
                              final oldServing = item.servingSizeGrams;
                              if (oldServing > 0) {
                                final ratio = newGrams / oldServing;
                                item.servingSizeGrams = newGrams;
                                item.baseCalories =
                                    (item.baseCalories * ratio).round();
                                item.baseProtein = item.baseProtein * ratio;
                                item.baseCarbs = item.baseCarbs * ratio;
                                item.baseFat = item.baseFat * ratio;
                                item.baseFiber = item.baseFiber * ratio;
                                item.baseSugar = item.baseSugar * ratio;
                                item.baseSodium = item.baseSodium * ratio;
                                // Clear edits since base changed
                                item.editedCalories = null;
                                item.editedProtein = null;
                                item.editedCarbs = null;
                                item.editedFat = null;
                              } else {
                                item.servingSizeGrams = newGrams;
                              }
                            });
                          },
                          onEditField: (field, value) {
                            setState(() {
                              switch (field) {
                                case 'calories':
                                  item.editedCalories = value as int;
                                  break;
                                case 'protein':
                                  item.editedProtein = value as double;
                                  break;
                                case 'carbs':
                                  item.editedCarbs = value as double;
                                  break;
                                case 'fat':
                                  item.editedFat = value as double;
                                  break;
                              }
                            });
                          },
                          onClearEdit: (field) {
                            setState(() {
                              switch (field) {
                                case 'calories':
                                  item.editedCalories = null;
                                  break;
                                case 'protein':
                                  item.editedProtein = null;
                                  break;
                                case 'carbs':
                                  item.editedCarbs = null;
                                  break;
                                case 'fat':
                                  item.editedFat = null;
                                  break;
                              }
                            });
                          },
                        );
                      }),

                      const SizedBox(height: 12),

                      // Total
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: _ink)),
                            Text(
                              '${_items!.fold(0, (s, i) => s + i.calories)} kcal',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Log button
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _log,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Done',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: _ink),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
          ],
        ),
      ),
    );
  }
}

// ---- Food Item Card ----

class _FoodItemCard extends StatelessWidget {
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);

  final FoodItem item;
  final void Function(double oldQty, double newQty) onQuantityChanged;
  final void Function(double newGrams) onEditServing;
  final void Function(String field, dynamic value) onEditField;
  final void Function(String field) onClearEdit;

  const _FoodItemCard({
    required this.item,
    required this.onQuantityChanged,
    required this.onEditServing,
    required this.onEditField,
    required this.onClearEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + quantity counter
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E))),
                    if (item.servingSizeGrams > 0)
                      GestureDetector(
                        onTap: () => _showEditServingSheet(context),
                        child: Text(
                          '${item.servingSizeGrams.round()}g',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8E8E93)),
                        ),
                      ),
                  ],
                ),
              ),
              // Quantity counter
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF9F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyBtn(
                      icon: Icons.remove,
                      onTap: item.quantity > 1
                          ? () => onQuantityChanged(
                              item.quantity, item.quantity - 1)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity.round()}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1C1C1E))),
                    ),
                    _qtyBtn(
                      icon: Icons.add,
                      onTap: () => onQuantityChanged(
                          item.quantity, item.quantity + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calories (big)
          GestureDetector(
            onTap: () => _showEditNumberSheet(
                context, 'Calories', item.calories.toDouble(), (v) {
              onEditField('calories', v.round());
            }, unit: 'kcal'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: item.hasEdits && item.editedCalories != null
                    ? const Color(0xFFF0F7FF)
                    : const Color(0xFFFAF9F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Calories',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93))),
                  const SizedBox(height: 4),
                  Text('${item.calories}',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E))),
                  if (item.hasEdits && item.editedCalories != null)
                    GestureDetector(
                      onTap: () => onClearEdit('calories'),
                      child: const Text('Tap to reset',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF007AFF))),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Macro cards
          Row(
            children: [
              _macroCard(
                  context, 'Protein', item.protein, 'g', _proteinColor,
                  hasEdit: item.editedProtein != null,
                  onTap: () => _showEditNumberSheet(
                      context, 'Protein', item.protein, (v) {
                    onEditField('protein', v);
                  }, unit: 'g'),
                  onClear: () => onClearEdit('protein')),
              const SizedBox(width: 8),
              _macroCard(context, 'Carbs', item.carbs, 'g', _carbsColor,
                  hasEdit: item.editedCarbs != null,
                  onTap: () => _showEditNumberSheet(
                      context, 'Carbs', item.carbs, (v) {
                    onEditField('carbs', v);
                  }, unit: 'g'),
                  onClear: () => onClearEdit('carbs')),
              const SizedBox(width: 8),
              _macroCard(context, 'Fats', item.fat, 'g', _fatColor,
                  hasEdit: item.editedFat != null,
                  onTap: () => _showEditNumberSheet(
                      context, 'Fats', item.fat, (v) {
                    onEditField('fat', v);
                  }, unit: 'g'),
                  onClear: () => onClearEdit('fat')),
            ],
          ),

          // Ingredients
          if (item.ingredients.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ingredients',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E))),
              ],
            ),
            const SizedBox(height: 8),
            ...item.ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(ing.name,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1C1C1E))),
                      ),
                      if (ing.servingSizeGrams > 0)
                        Text('${ing.servingSizeGrams.round()}g',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF8E8E93))),
                      const SizedBox(width: 8),
                      Text('${ing.calories} cal',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1C1C1E))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _qtyBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white : const Color(0xFFECECE7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null
                ? const Color(0xFF1C1C1E)
                : const Color(0xFF8E8E93)),
      ),
    );
  }

  Widget _macroCard(
      BuildContext context, String label, double value, String unit, Color color,
      {required bool hasEdit,
      required VoidCallback onTap,
      required VoidCallback onClear}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: hasEdit
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('${value.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color.withValues(alpha: 0.7))),
              if (hasEdit)
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('reset',
                        style: TextStyle(fontSize: 10, color: color)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditServingSheet(BuildContext context) {
    final controller =
        TextEditingController(text: item.servingSizeGrams.round().toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFECECE7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit serving size',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E))),
            const SizedBox(height: 4),
            Text('${item.name} — all values will recalculate',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                suffixText: 'grams',
                filled: true,
                fillColor: const Color(0xFFFAF9F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final grams = double.tryParse(controller.text) ?? 0;
                  if (grams > 0) {
                    onEditServing(grams);
                    Navigator.of(ctx).pop();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Update',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNumberSheet(BuildContext context, String label, double current,
      ValueChanged<dynamic> onSave,
      {String unit = ''}) {
    final controller =
        TextEditingController(text: current.toStringAsFixed(1));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFECECE7),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit $label',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                suffixText: unit,
                filled: true,
                fillColor: const Color(0xFFFAF9F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final val = double.tryParse(controller.text);
                  if (val != null) {
                    onSave(val);
                    Navigator.of(ctx).pop();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Update',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
