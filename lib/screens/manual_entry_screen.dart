import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../services/gemini_service.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';

class ManualEntryScreen extends StatefulWidget {
  final StorageService storage;

  const ManualEntryScreen({super.key, required this.storage});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _proteinColor = Color(0xFFE53935);
  static const _carbsColor = Color(0xFFFF9500);
  static const _fatColor = Color(0xFF007AFF);

  final _controller = TextEditingController();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a food name first.');
      return;
    }

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

    setState(() {
      _analyzing = true;
      _error = null;
      _items = null;
    });

    try {
      ({List<FoodItem> items, String? mealType}) result;
      if (provider == 'gemini') {
        result = await GeminiService(apiKey: apiKey).analyzeText(text);
      } else {
        result = await OpenAIService(apiKey: apiKey).analyzeText(text);
      }
      if (!mounted) return;
      setState(() {
        _items = result.items.isNotEmpty ? result.items : null;
        _analyzing = false;
        if (result.mealType != null) {
          _mealType = result.mealType!;
        }
        if (result.items.isEmpty) {
          _error = 'Could not find nutrition info. Try a different name.';
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
    if (s.contains('SocketException') || s.contains('Connection reset')) {
      return 'Network error. Check your connection and try again.';
    }
    if (s.contains('429') || s.contains('quota')) {
      return 'Too many requests. Wait a moment and try again.';
    }
    if (s.contains('403') || s.contains('API key')) {
      return 'API key error. Check your key in Settings.';
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
      imagePath: '',
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
                      'Add food manually',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What did you eat?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'e.g. "2 roti with dal", "1 bowl of rice", "apple"',
                            style: TextStyle(fontSize: 13, color: _muted),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _controller,
                            onSubmitted: (_) => _analyze(),
                            decoration: InputDecoration(
                              hintText: 'Enter food name...',
                              filled: true,
                              fillColor: _bg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => _controller.clear(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _analyzing ? null : _analyze,
                              style: FilledButton.styleFrom(
                                backgroundColor: _ink,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _analyzing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Get nutrition info',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                    if (_items != null && !_analyzing) ...[
                      const SizedBox(height: 20),
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
                            DropdownMenuItem(
                                value: 'lunch', child: Text('Lunch')),
                            DropdownMenuItem(
                                value: 'dinner', child: Text('Dinner')),
                            DropdownMenuItem(
                                value: 'snack', child: Text('Snack')),
                          ],
                          onChanged: (v) => setState(() => _mealType = v!),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _ink)),
                            const SizedBox(height: 12),
                            ..._items!.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name,
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: _ink)),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                _macroDot(_proteinColor,
                                                    '${item.protein.toStringAsFixed(0)}g P'),
                                                const SizedBox(width: 8),
                                                _macroDot(_carbsColor,
                                                    '${item.carbs.toStringAsFixed(0)}g C'),
                                                const SizedBox(width: 8),
                                                _macroDot(_fatColor,
                                                    '${item.fat.toStringAsFixed(0)}g F'),
                                              ],
                                            ),
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
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                    top: BorderSide(
                                        color: Color(0xFFECECE7))),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
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
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: _muted)),
      ],
    );
  }
}
