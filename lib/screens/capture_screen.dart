import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/food_entry.dart';
import '../services/food_search_service.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'manual_entry_screen.dart';

class CaptureScreen extends StatefulWidget {
  final StorageService storage;
  final File? initialImage;

  const CaptureScreen({super.key, required this.storage, this.initialImage});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {

  final _picker = ImagePicker();
  File? _image;
  bool _analyzing = false;
  String? _error;
  String? _qualityWarning;
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
      final file = File(picked.path);
      final size = await file.length();
      setState(() {
        _image = file;
        _items = null;
        _error = null;
        _qualityWarning = size < 20000 ? 'Image looks small or dark. Result may be less accurate.' : null;
      });
      _analyze();
    }
  }

  Future<void> _analyze() async {
    // AI runs through the Cloudflare proxy — no key needed client-side.
    final image = _image;
    if (image == null) return;

    setState(() {
      _analyzing = true;
      _error = null;
      _items = null;
    });

    try {
      ({List<FoodItem> items, String? mealType}) result;
      result = await OpenAIService().analyzeImage(image.path);
      if (!mounted) return;

      // Attach database match for comparison
      final List<FoodItem> enrichedItems = [];
      for (final item in result.items) {
        final dbResults = await FoodSearchService.search(item.name);
        final match = dbResults.isNotEmpty ? dbResults.first : null;
        if (match != null) {
          enrichedItems.add(FoodItem(
            name: item.name,
            servingSizeGrams: item.servingSizeGrams,
            calories: (item.calories / (item.quantity > 0 ? item.quantity : 1)).round(),
            protein: item.protein / (item.quantity > 0 ? item.quantity : 1),
            carbs: item.carbs / (item.quantity > 0 ? item.quantity : 1),
            fat: item.fat / (item.quantity > 0 ? item.quantity : 1),
            fiber: item.fiber / (item.quantity > 0 ? item.quantity : 1),
            sugar: item.sugar / (item.quantity > 0 ? item.quantity : 1),
            sodium: item.sodium / (item.quantity > 0 ? item.quantity : 1),
            quantity: item.quantity,
            dbMatchedName: match.name,
            dbSource: match.source,
            dbCaloriesPer100g: match.calories.toDouble(),
            dbProteinPer100g: match.protein,
            dbCarbsPer100g: match.carbs,
            dbFatPer100g: match.fat,
            dbFiberPer100g: match.fiber,
            dbSugarPer100g: match.sugar,
            dbSodiumPer100g: match.sodium,
          ));
        } else {
          enrichedItems.add(item);
        }
      }

      setState(() {
        _items = enrichedItems.isNotEmpty ? enrichedItems : null;
        _analyzing = false;
        if (result.mealType != null) _mealType = result.mealType!;
        if (enrichedItems.isEmpty) _error = 'No food detected. Try another photo.';
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
    if (s.contains('SocketException') || s.contains('Connection reset') || s.contains('Connection refused')) {
      return 'No internet connection. Check your WiFi or mobile data.';
    }
    if (s.contains('429') || s.contains('quota') || s.contains('rate')) {
      return 'AI service is busy. Please wait a minute and try again.';
    }
    if (s.contains('403') || s.contains('API key') || s.contains('invalid_key')) {
      return 'Invalid API key. Go to Settings and check your key.';
    }
    if (s.contains('500') || s.contains('502') || s.contains('503')) {
      return 'AI service is temporarily down. Please try again later.';
    }
    if (s.contains('timeout') || s.contains('Timeout')) {
      return 'Request timed out. Try again or check your connection.';
    }
    if (s.contains('Could not find')) {
      return 'Could not identify the food. Try a clearer photo.';
    }
    return 'Something went wrong. Please try again.';
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
    HapticFeedback.lightImpact();
    if (!mounted) return;

    final scanAnother = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
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
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
      setState(() {
        _image = null;
        _items = null;
        _error = null;
        _analyzing = false;
      });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDiscard() async {
    if (_items == null && _image == null) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗑️', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 10),
              const Text(
                'Discard this meal?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your analysis will be lost.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.missedRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep editing', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
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
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: _confirmDiscard,
                  ),
                  const Expanded(
                    child: Text(
                      'Nutrition',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink),
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
                    // Image with retake button
                    if (_image != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(_image!, width: double.infinity, height: 240, fit: BoxFit.cover),
                          ),
                          if (!_analyzing && _items == null)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _image = null;
                                    _error = null;
                                    _qualityWarning = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),

                    // Quality warning
                    if (_qualityWarning != null && !_analyzing) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warningOrange),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _qualityWarning!,
                                style: const TextStyle(fontSize: 12, color: AppColors.warningOrange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Camera / Gallery
                    if (widget.initialImage == null && _items == null)
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lightbulb_outline, size: 16, color: AppColors.muted),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Show the full plate for better accuracy',
                                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
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
                        ],
                      ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.missedRed, fontSize: 14)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ManualEntryScreen(storage: widget.storage),
                                        ),
                                      ).then((v) {
                                        if (v == true) Navigator.pop(context, true);
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.missedRed,
                                      side: const BorderSide(color: AppColors.missedRed),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Enter manually'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _analyze,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.missedRed,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ),
                              ],
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
                              CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2)),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text('Analyzing your food...',
                            style: TextStyle(color: AppColors.muted, fontSize: 14)),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _analyzing = false;
                              _error = null;
                            });
                          },
                          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
                        ),
                      ),
                    ],

                    // Results
                    if (_items != null && !_analyzing) ...[
                      const SizedBox(height: 16),

                      // Meal type pills
                      Row(
                        children: [
                          _mealPill('Breakfast', 'breakfast'),
                          const SizedBox(width: 8),
                          _mealPill('Lunch', 'lunch'),
                          const SizedBox(width: 8),
                          _mealPill('Dinner', 'dinner'),
                          const SizedBox(width: 8),
                          _mealPill('Snack', 'snack'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Food items
                      ..._items!.map((item) {
                        return _FoodItemCard(
                          item: item,
                          onChanged: () => setState(() {}),
                          onDelete: () {
                            setState(() => _items!.remove(item));
                            if (_items!.isEmpty) {
                              setState(() => _items = null);
                            }
                          },
                        );
                      }),

                      const SizedBox(height: 12),

                      // Total summary card (black)
                      _TotalCard(items: _items!),
                    ],
                  ],
                ),
              ),
            ),

            // Sticky Log button at bottom
            if (_items != null && !_analyzing)
              ColoredBox(
                color: AppColors.card,
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _mealPill(String label, String value) {
    final selected = _mealType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mealType = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Food Item Card ----

class _FoodItemCard extends StatefulWidget {
  final FoodItem item;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const _FoodItemCard({required this.item, required this.onChanged, this.onDelete});

  @override
  State<_FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<_FoodItemCard> {

  String _intuitiveServing(double grams) {
    if (grams <= 0) return '';
    if (grams < 30) return 'a bite';
    if (grams < 80) return 'a small serving';
    if (grams < 150) return 'a cup';
    if (grams < 250) return 'a bowl';
    if (grams < 400) return 'a plate';
    return 'a large plate';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasSecondary = item.fiber > 0 || item.sugar > 0 || item.sodium > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + quantity counter + delete
          Row(
            children: [
              Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyBtn(
                      icon: Icons.remove,
                      onTap: item.quantity > 1
                          ? () {
                              setState(() => item.quantity -= 1);
                              widget.onChanged();
                            }
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity.round()}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                    ),
                    _qtyBtn(
                      icon: Icons.add,
                      onTap: () {
                        setState(() => item.quantity += 1);
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Serving size + Calories
          Row(
            children: [
              if (item.servingSizeGrams > 0)
                Text(
                  '${_intuitiveServing(item.servingSizeGrams)} · ${item.servingSizeGrams.round()}g',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted),
                ),
              const Spacer(),
              Text('${item.calories} kcal',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 12),

          // Macro pills row 1
          Row(
            children: [
              _macroPill('Protein ${item.protein.toStringAsFixed(1)}g', AppColors.protein),
              const SizedBox(width: 8),
              _macroPill('Carbs ${item.carbs.toStringAsFixed(1)}g', AppColors.carbs),
              const SizedBox(width: 8),
              _macroPill('Fat ${item.fat.toStringAsFixed(1)}g', AppColors.fat),
            ],
          ),

          // Macro pills row 2
          if (hasSecondary) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.fiber > 0)
                  _macroPill('Fiber ${item.fiber.toStringAsFixed(1)}g', AppColors.fiber),
                if (item.fiber > 0 && item.sugar > 0) const SizedBox(width: 8),
                if (item.sugar > 0)
                  _macroPill('Sugar ${item.sugar.toStringAsFixed(1)}g', AppColors.sugar),
                if ((item.fiber > 0 || item.sugar > 0) && item.sodium > 0)
                  const SizedBox(width: 8),
                if (item.sodium > 0)
                  _macroPill('Sodium ${item.sodium.toStringAsFixed(0)}mg', AppColors.sodium),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _qtyBtn({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.card : AppColors.track,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? AppColors.ink : AppColors.muted),
      ),
    );
  }
}

// ---- Total Summary Card ----

class _TotalCard extends StatelessWidget {
  final List<FoodItem> items;

  const _TotalCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final totalCal = items.fold(0, (s, i) => s + i.calories);
    final totalP = items.fold(0.0, (s, i) => s + i.protein);
    final totalC = items.fold(0.0, (s, i) => s + i.carbs);
    final totalF = items.fold(0.0, (s, i) => s + i.fat);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _totalStat('🔥', '$totalCal', 'kcal'),
              _totalStat('🥩', '${totalP.toStringAsFixed(1)}g', 'protein'),
              _totalStat('🌾', '${totalC.toStringAsFixed(1)}g', 'carbs'),
              _totalStat('🧈', '${totalF.toStringAsFixed(1)}g', 'fat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }
}
