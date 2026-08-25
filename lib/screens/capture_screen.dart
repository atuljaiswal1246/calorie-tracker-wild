import 'dart:io';

import 'package:flutter/material.dart';
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
                      ..._items!.map((item) {
                        return _FoodItemCard(
                          item: item,
                          onChanged: () => setState(() {}),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _log,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Log this meal',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
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

class _FoodItemCard extends StatefulWidget {
  final FoodItem item;
  final VoidCallback onChanged;

  const _FoodItemCard({required this.item, required this.onChanged});

  @override
  State<_FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<_FoodItemCard> {
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);
  static const _fiberColor = Color(0xFF8D6E63);
  static const _sugarColor = Color(0xFFE91E63);
  static const _sodiumColor = Color(0xFF78909C);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasSecondary = item.fiber > 0 || item.sugar > 0 || item.sodium > 0;

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
                child: Text(item.name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E))),
              ),
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
                              color: Color(0xFF1C1C1E))),
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

          // Calories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${item.calories} kcal',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E))),
            ],
          ),
          const SizedBox(height: 12),

          // Macro pills row 1
          Row(
            children: [
              _macroPill('Protein ${item.protein.toStringAsFixed(1)}g', _proteinColor),
              const SizedBox(width: 8),
              _macroPill('Carbs ${item.carbs.toStringAsFixed(1)}g', _carbsColor),
              const SizedBox(width: 8),
              _macroPill('Fat ${item.fat.toStringAsFixed(1)}g', _fatColor),
            ],
          ),

          // Macro pills row 2
          if (hasSecondary) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.fiber > 0)
                  _macroPill('Fiber ${item.fiber.toStringAsFixed(1)}g', _fiberColor),
                if (item.fiber > 0 && item.sugar > 0) const SizedBox(width: 8),
                if (item.sugar > 0)
                  _macroPill('Sugar ${item.sugar.toStringAsFixed(1)}g', _sugarColor),
                if ((item.fiber > 0 || item.sugar > 0) && item.sodium > 0)
                  const SizedBox(width: 8),
                if (item.sodium > 0)
                  _macroPill('Sodium ${item.sodium.toStringAsFixed(0)}mg', _sodiumColor),
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
}

// ---- Total Summary Card ----

class _TotalCard extends StatelessWidget {
  static const _ink = Color(0xFF1C1C1E);
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
        color: _ink,
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
