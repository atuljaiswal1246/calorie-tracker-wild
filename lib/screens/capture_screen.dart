import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_entry.dart';
import '../services/gemini_service.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';

class CaptureScreen extends StatefulWidget {
  final StorageService storage;

  /// When provided, the screen skips camera/gallery buttons and auto-analyzes.
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
      _image = widget.initialImage;
      // Auto-analyze when image comes from scanner/gallery.
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
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
      setState(() {
        _error = 'Add your $providerLabel API key in Settings first.';
      });
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
        // Cross-check: AI meal type overrides time-based default when confident.
        if (result.mealType != null) {
          _mealType = result.mealType!;
        }
        if (result.items.isEmpty) {
          _error = 'No food detected in this image. Try another photo.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = _friendlyError(e.toString());
      setState(() {
        _analyzing = false;
        _error = msg;
      });
    }
  }

  static String _friendlyError(String raw) {
    var s = raw.replaceAll(RegExp(r'key=[^&\s]+'), 'key=***');
    if (s.contains('SocketException') ||
        s.contains('Connection abort') ||
        s.contains('Connection reset') ||
        s.contains('Network is unreachable') ||
        s.contains('Connection refused')) {
      return 'Network error. Check your connection and try again.';
    }
    if (s.contains('429') || s.contains('quota') || s.contains('Too Many Requests')) {
      return 'Too many requests. Wait a moment and try again.';
    }
    if (s.contains('403') || s.contains('permission') || s.contains('API key')) {
      return 'API key error. Check your key in Settings.';
    }
    if (s.contains('500') || s.contains('502') || s.contains('503')) {
      return 'Server error. Try again in a moment.';
    }
    return 'Analysis failed. Please try again.';
  }

  Future<void> _log() async {
    final items = _items;
    if (items == null || items.isEmpty) return;

    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: items,
      imagePath: _image!.path,
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
            // Top bar
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
                      'Log a meal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance
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
                        child: Image.file(_image!, height: 280, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Text('Take or pick a photo of your food',
                              style: TextStyle(color: _muted, fontSize: 15)),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Camera / Gallery buttons (only when no initial image)
                    if (widget.initialImage == null)
                      Row(
                        children: [
                          Expanded(
                            child: _outlineBtn(
                              icon: Icons.photo_camera,
                              label: 'Camera',
                              onTap: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _outlineBtn(
                              icon: Icons.photo_library,
                              label: 'Gallery',
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
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
                                style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 14)),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _analyze,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Retry'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Analyzing spinner
                    if (_image != null && _analyzing) ...[
                      const SizedBox(height: 32),
                      const Center(child: CircularProgressIndicator(color: _ink)),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text('Analyzing your food...',
                            style: TextStyle(color: _muted, fontSize: 14)),
                      ),
                    ],

                    // Results
                    if (_items != null && !_analyzing) ...[
                      const SizedBox(height: 20),

                      // Meal type selector
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
                              fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
                          items: const [
                            DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                            DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                            DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                            DropdownMenuItem(value: 'snack', child: Text('Snack')),
                          ],
                          onChanged: (v) => setState(() => _mealType = v!),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Detected foods card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Detected foods',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
                            const SizedBox(height: 12),
                            ..._items!.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name,
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: _ink)),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                _macroDot(_proteinColor, '${item.protein.toStringAsFixed(0)}g P'),
                                                const SizedBox(width: 8),
                                                _macroDot(_carbsColor, '${item.carbs.toStringAsFixed(0)}g C'),
                                                const SizedBox(width: 8),
                                                _macroDot(_fatColor, '${item.fat.toStringAsFixed(0)}g F'),
                                              ],
                                            ),
                                            if (item.fiber > 0 || item.sugar > 0 || item.sodium > 0) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  if (item.fiber > 0) ...[
                                                    _macroDot(const Color(0xFF8D6E63), '${item.fiber.toStringAsFixed(0)}g fiber'),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  if (item.sugar > 0) ...[
                                                    _macroDot(const Color(0xFFE91E63), '${item.sugar.toStringAsFixed(0)}g sugar'),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  if (item.sodium > 0)
                                                    _macroDot(const Color(0xFF78909C), '${item.sodium.toStringAsFixed(0)}mg sodium'),
                                                 ],
                                               ),
                                             ],
                                           ],
                                         ),
                                       ),
                                       Text('${item.calories} kcal',
                                           style: const TextStyle(
                                               fontSize: 15,
                                               fontWeight: FontWeight.w700,
                                               color: _ink)),
                                     ],
                                   ),
                                 )),
                            // Total
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0xFFECECE7))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: _ink)),
                                  Text(
                                    '${_items!.fold(0, (s, i) => s + i.calories)} kcal',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: _ink),
                                  ),
                                ],
                              ),
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
                          child: const Text('Log this meal',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _macroDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _muted)),
      ],
    );
  }
}
