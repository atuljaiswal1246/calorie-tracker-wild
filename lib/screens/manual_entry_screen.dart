import 'package:flutter/material.dart';

import '../models/food_entry.dart';
import '../services/food_search_service.dart';
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
  final _focusNode = FocusNode();
  List<FoodDBItem> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;

  bool _analyzing = false;
  String? _error;
  List<FoodItem>? _aiItems;
  String _mealType = _autoMealType();

  static String _autoMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'breakfast';
    if (hour < 16) return 'lunch';
    if (hour < 21) return 'dinner';
    return 'snack';
  }

  List<Map<String, dynamic>> get _recentFoods => widget.storage.recentFoods;
  List<Map<String, dynamic>> get _favoriteFoods => widget.storage.favoriteFoods;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _controller.text.trim();
    if (q.length >= 2) {
      _search(q);
    } else {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
    }
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final results = await FoodSearchService.search(query, limit: 15);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
      _showResults = true;
    });
  }

  void _selectFood(FoodDBItem food) {
    _controller.text = food.name;
    setState(() {
      _showResults = false;
      _searchResults = [];
    });
    _showFoodConfirmation(food);
  }

  void _showFoodConfirmation(FoodDBItem food) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FoodConfirmSheet(
        food: food,
        mealType: _mealType,
        onMealTypeChanged: (v) => setState(() => _mealType = v),
        onLog: () => _logLocalFood(food),
      ),
    );
  }

  Future<void> _logLocalFood(FoodDBItem food) async {
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: [
        FoodItem(
          name: food.name,
          calories: food.calories,
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
          fiber: food.fiber,
          sugar: food.sugar,
          sodium: food.sodium,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged! Added to your day.')),
    );
    Navigator.of(context).pop(true);
  }

  Future<void> _analyzeWithAI() async {
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
      _aiItems = null;
      _showResults = false;
    });

    try {
      ({List<FoodItem> items, String? mealType}) result;
      if (provider == 'gemini') {
        result = await GeminiService(apiKey: apiKey).analyzeText(text);
      } else {
        result = await OpenAIService(apiKey: apiKey).analyzeText(text);
      }
      if (!mounted) return;

      // Attach database match for comparison
      final dbResults = await FoodSearchService.search(text);
      final match = dbResults.isNotEmpty ? dbResults.first : null;
      final List<FoodItem> enrichedItems = [];
      for (final item in result.items) {
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
        _aiItems = enrichedItems.isNotEmpty ? enrichedItems : null;
        _analyzing = false;
        if (result.mealType != null) {
          _mealType = result.mealType!;
        }
        if (enrichedItems.isEmpty) {
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

  Future<void> _logAIFood() async {
    final items = _aiItems;
    if (items == null || items.isEmpty) return;

    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: items,
      imagePath: '',
    );

    await widget.storage.addEntry(entry);

    for (final item in items) {
      await widget.storage.addRecentFood({
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
      });
    }

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search food...',
                  prefixIcon: const Icon(Icons.search, color: _muted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _searchResults = [];
                              _showResults = false;
                            });
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) {
                  if (_searchResults.isNotEmpty) {
                    _selectFood(_searchResults.first);
                  } else {
                    _analyzeWithAI();
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
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
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_showResults && _searchResults.isNotEmpty) {
      return _buildSearchResults();
    }
    if (_searching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(color: _ink, strokeWidth: 2),
        ),
      );
    }
    if (_aiItems != null && !_analyzing) {
      return _buildAIResults();
    }
    if (_analyzing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: CircularProgressIndicator(color: _ink, strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return _buildAIError();
    }
    return _buildDefault();
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final food = _searchResults[i];
        return _FoodResultTile(
          food: food,
          isFavorite: widget.storage.isFavorite(food.name),
          onTap: () => _selectFood(food),
          onFavorite: () async {
            await widget.storage.toggleFavorite({
              'name': food.name,
              'calories': food.calories,
              'protein': food.protein,
              'carbs': food.carbs,
              'fat': food.fat,
            });
            setState(() {});
          },
        );
      },
    );
  }

  Widget _buildDefault() {
    final recent = _recentFoods;
    final favs = _favoriteFoods;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (favs.isNotEmpty) ...[
            const Text('Favorites',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...favs.map((f) => _QuickFoodTile(
                  food: f,
                  isFavorite: true,
                  onTap: () => _logQuickFood(f),
                  onFavorite: () async {
                    await widget.storage.toggleFavorite(f);
                    setState(() {});
                  },
                )),
            const SizedBox(height: 20),
          ],
          if (recent.isNotEmpty) ...[
            const Text('Recently logged',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...recent.map((f) => _QuickFoodTile(
                  food: f,
                  isFavorite: widget.storage.isFavorite(f['name'] as String? ?? ''),
                  onTap: () => _logQuickFood(f),
                  onFavorite: () async {
                    await widget.storage.toggleFavorite(f);
                    setState(() {});
                  },
                )),
          ],
          if (recent.isEmpty && favs.isEmpty) ...[
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(Icons.search, size: 48, color: _muted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'Search for a food to get started',
                    style: TextStyle(fontSize: 15, color: _muted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Type a food name above',
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logQuickFood(Map<String, dynamic> food) async {
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: [
        FoodItem(
          name: food['name'] as String? ?? '',
          calories: (food['calories'] as num?)?.toInt() ?? 0,
          protein: (food['protein'] as num?)?.toDouble() ?? 0,
          carbs: (food['carbs'] as num?)?.toDouble() ?? 0,
          fat: (food['fat'] as num?)?.toDouble() ?? 0,
        ),
      ],
      imagePath: '',
    );

    await widget.storage.addEntry(entry);
    await widget.storage.addRecentFood(food);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged! Added to your day.')),
    );
    Navigator.of(context).pop(true);
  }

  Widget _buildAIResults() {
    final items = _aiItems!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
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
                const Text('Detected foods',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                const SizedBox(height: 12),
                ...items.map((item) => Padding(
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
                        top: BorderSide(color: Color(0xFFECECE7))),
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
                        '${items.fold<int>(0, (s, i) => s + i.calories)} kcal',
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
            width: double.infinity,
            child: FilledButton(
              onPressed: _logAIFood,
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Log this meal',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFD32F2F), fontSize: 14)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _analyzeWithAI,
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

// ---- Food result tile (search results) ----

class _FoodResultTile extends StatelessWidget {
  final FoodDBItem food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _FoodResultTile({
    required this.food,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _macroPill(const Color(0xFFE53935),
                          '${food.protein.toStringAsFixed(0)}g P'),
                      const SizedBox(width: 6),
                      _macroPill(const Color(0xFFFF9500),
                          '${food.carbs.toStringAsFixed(0)}g C'),
                      const SizedBox(width: 6),
                      _macroPill(const Color(0xFF007AFF),
                          '${food.fat.toStringAsFixed(0)}g F'),
                    ],
                  ),
                ],
              ),
            ),
            Text('${food.calories} kcal',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onFavorite,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite
                    ? const Color(0xFFE53935)
                    : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroPill(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ---- Quick food tile (recent / favorites) ----

class _QuickFoodTile extends StatelessWidget {
  final Map<String, dynamic> food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _QuickFoodTile({
    required this.food,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final name = food['name'] as String? ?? '';
    final calories = (food['calories'] as num?)?.toInt() ?? 0;
    final protein = (food['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (food['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (food['fat'] as num?)?.toDouble() ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _macroPill(const Color(0xFFE53935),
                          '${protein.toStringAsFixed(0)}g P'),
                      const SizedBox(width: 6),
                      _macroPill(const Color(0xFFFF9500),
                          '${carbs.toStringAsFixed(0)}g C'),
                      const SizedBox(width: 6),
                      _macroPill(const Color(0xFF007AFF),
                          '${fat.toStringAsFixed(0)}g F'),
                    ],
                  ),
                ],
              ),
            ),
            Text('$calories kcal',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onFavorite,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite
                    ? const Color(0xFFE53935)
                    : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroPill(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ---- Food confirmation bottom sheet ----

class _FoodConfirmSheet extends StatefulWidget {
  final FoodDBItem food;
  final String mealType;
  final ValueChanged<String> onMealTypeChanged;
  final VoidCallback onLog;

  const _FoodConfirmSheet({
    required this.food,
    required this.mealType,
    required this.onMealTypeChanged,
    required this.onLog,
  });

  @override
  State<_FoodConfirmSheet> createState() => _FoodConfirmSheetState();
}

class _FoodConfirmSheetState extends State<_FoodConfirmSheet> {
  late String _mealType;

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
          Text(food.name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E))),
          const SizedBox(height: 4),
          Text('${food.calories} kcal per 100g',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF8E8E93))),
          const SizedBox(height: 16),
          Row(
            children: [
              _macroCard(const Color(0xFFE53935), 'Protein',
                  '${food.protein.toStringAsFixed(1)}g'),
              const SizedBox(width: 8),
              _macroCard(const Color(0xFFFF9500), 'Carbs',
                  '${food.carbs.toStringAsFixed(1)}g'),
              const SizedBox(width: 8),
              _macroCard(
                  const Color(0xFF007AFF), 'Fat', '${food.fat.toStringAsFixed(1)}g'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F7),
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
                  color: Color(0xFF1C1C1E)),
              items: const [
                DropdownMenuItem(
                    value: 'breakfast', child: Text('Breakfast')),
                DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                DropdownMenuItem(value: 'snack', child: Text('Snack')),
              ],
              onChanged: (v) {
                setState(() => _mealType = v!);
                widget.onMealTypeChanged(v!);
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onLog();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Log this food',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCard(Color color, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
