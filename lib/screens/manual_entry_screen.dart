import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/food_entry.dart';
import '../services/food_search_service.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class ManualEntryScreen extends StatefulWidget {
  final StorageService storage;

  const ManualEntryScreen({super.key, required this.storage});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {

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

  Future<bool> _showLogAnotherDialog() async {
    final result = await showDialog<bool>(
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
              const Text('Logged!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
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
                  child: const Text('Log another', style: TextStyle(fontWeight: FontWeight.w700)),
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
    return result ?? false;
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

  double _selectedQuantity = 100;

  void _showFoodConfirmation(FoodDBItem food) {
    _selectedQuantity = 100;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FoodConfirmSheet(
        food: food,
        mealType: _mealType,
        onMealTypeChanged: (v) => setState(() => _mealType = v),
        onQuantityChanged: (v) => _selectedQuantity = v,
        onLog: () => _logLocalFood(food),
      ),
    );
  }

  Future<void> _logLocalFood(FoodDBItem food) async {
    final qty = _selectedQuantity;
    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: [
        FoodItem(
          name: food.name,
          servingSizeGrams: qty,
          calories: (food.calories * qty / 100).round(),
          protein: food.protein * qty / 100,
          carbs: food.carbs * qty / 100,
          fat: food.fat * qty / 100,
          fiber: food.fiber * qty / 100,
          sugar: food.sugar * qty / 100,
          sodium: food.sodium * qty / 100,
          calcium: food.calcium * qty / 100,
          iron: food.iron * qty / 100,
          vitaminC: food.vitaminC * qty / 100,
          quantity: qty / 100,
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
    HapticFeedback.lightImpact();

    if (!mounted) return;
    final logAnother = await _showLogAnotherDialog();
    if (logAnother) {
      _controller.clear();
      setState(() {
        _searchResults = [];
        _showResults = false;
        _aiItems = null;
      });
      _focusNode.requestFocus();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _analyzeWithAI() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a food name first.');
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
      result = await OpenAIService().analyzeText(text);
      if (!mounted) return;

      // Attach database match for comparison
      final dbResults = await FoodSearchService.search(text);
      final match = dbResults.isNotEmpty ? dbResults.first : null;
      final List<FoodItem> enrichedItems = [];
      for (final item in result.items) {
        if (match != null) {
          final q = item.quantity > 0 ? item.quantity : 1;
          // DB per-100g values scaled up to the AI-estimated serving size.
          final scale = item.servingSizeGrams / 100;
          // Backfill ONLY values the AI couldn't estimate (0 = "unknown").
          double fill(double aiVal, double dbPer100g) =>
              aiVal > 0 ? aiVal : dbPer100g * scale;

          enrichedItems.add(FoodItem(
            name: item.name,
            servingSizeGrams: item.servingSizeGrams,
            calories: (item.calories / q).round(),
            protein: item.protein / q,
            carbs: item.carbs / q,
            fat: item.fat / q,
            fiber: item.fiber / q,
            sugar: item.sugar / q,
            sodium: item.sodium / q,
            calcium: fill(item.calcium / q, match.calcium),
            iron: fill(item.iron / q, match.iron),
            vitaminC: fill(item.vitaminC / q, match.vitaminC),
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
    return 'Something went wrong. Please try again.';
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
    final logAnother = await _showLogAnotherDialog();
    if (logAnother) {
      _controller.clear();
      setState(() {
        _searchResults = [];
        _showResults = false;
        _aiItems = null;
      });
      _focusNode.requestFocus();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Add food manually',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
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
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.card,
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
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButton<String>(
                  value: _mealType,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
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
          child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
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
          child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2),
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
                    color: AppColors.muted,
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
                    color: AppColors.muted,
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
                  Icon(Icons.search, size: 48, color: AppColors.muted.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'Search for a food to get started',
                    style: TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Type a food name above',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _showCustomFoodEntry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.ink),
                          SizedBox(width: 6),
                          Text(
                            'Enter food manually',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
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
    final name = food['name'] as String? ?? '';
    final calories = (food['calories'] as num?)?.toInt() ?? 0;
    final protein = (food['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (food['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (food['fat'] as num?)?.toDouble() ?? 0;

    double quantity = 100;
    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _QuickLogSheet(
        name: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        mealType: _mealType,
      ),
    );

    if (result == null || !mounted) return;
    quantity = result;

    final entry = FoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      mealType: _mealType,
      items: [
        FoodItem(
          name: name,
          servingSizeGrams: quantity,
          calories: (calories * quantity / 100).round(),
          protein: protein * quantity / 100,
          carbs: carbs * quantity / 100,
          fat: fat * quantity / 100,
          quantity: quantity / 100,
        ),
      ],
      imagePath: '',
    );

    await widget.storage.addEntry(entry);
    await widget.storage.addRecentFood(food);

    if (!mounted) return;
    final logAnother = await _showLogAnotherDialog();
    if (logAnother) {
      _controller.clear();
      setState(() {
        _searchResults = [];
        _showResults = false;
        _aiItems = null;
      });
      _focusNode.requestFocus();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _showCustomFoodEntry() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _CustomFoodSheet(
        mealType: _mealType,
        onMealTypeChanged: (v) => setState(() => _mealType = v),
        onLog: (name, cal, p, c, f) async {
          final entry = FoodEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            dateTime: DateTime.now(),
            mealType: _mealType,
            items: [
              FoodItem(
                name: name,
                calories: cal,
                protein: p,
                carbs: c,
                fat: f,
              ),
            ],
            imagePath: '',
          );
          await widget.storage.addEntry(entry);
          await widget.storage.addRecentFood({
            'name': name, 'calories': cal, 'protein': p, 'carbs': c, 'fat': f,
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged! Added to your day.')),
          );
          Navigator.of(context).pop(true);
        },
      ),
    );
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detected foods',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
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
                                        color: AppColors.ink)),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    _macroDot(AppColors.protein,
                                        '${item.protein.toStringAsFixed(0)}g P'),
                                    const SizedBox(width: 8),
                                    _macroDot(AppColors.carbs,
                                        '${item.carbs.toStringAsFixed(0)}g C'),
                                    const SizedBox(width: 8),
                                    _macroDot(AppColors.fat,
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
                                  color: AppColors.ink)),
                        ],
                      ),
                    )),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: AppColors.track)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ink)),
                      Text(
                        '${items.fold<int>(0, (s, i) => s + i.calories)} kcal',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink),
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
                backgroundColor: AppColors.ink,
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
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontSize: 14)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _analyzeWithAI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
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
                fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.muted)),
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
          color: AppColors.card,
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
                          color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _macroPill(AppColors.protein,
                          '${food.protein.toStringAsFixed(0)}g P'),
                      const SizedBox(width: 6),
                      _macroPill(AppColors.carbs,
                          '${food.carbs.toStringAsFixed(0)}g C'),
                      const SizedBox(width: 6),
                      _macroPill(AppColors.fat,
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
                    color: AppColors.ink)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onFavorite,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite
                    ? AppColors.protein
                    : AppColors.muted,
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
          color: AppColors.card,
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
                          color: AppColors.ink)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _macroPill(AppColors.protein,
                          '${protein.toStringAsFixed(0)}g P'),
                      const SizedBox(width: 6),
                      _macroPill(AppColors.carbs,
                          '${carbs.toStringAsFixed(0)}g C'),
                      const SizedBox(width: 6),
                      _macroPill(AppColors.fat,
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
                    color: AppColors.ink)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onFavorite,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite
                    ? AppColors.protein
                    : AppColors.muted,
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
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onLog;

  const _FoodConfirmSheet({
    required this.food,
    required this.mealType,
    required this.onMealTypeChanged,
    required this.onQuantityChanged,
    required this.onLog,
  });

  @override
  State<_FoodConfirmSheet> createState() => _FoodConfirmSheetState();
}

class _FoodConfirmSheetState extends State<_FoodConfirmSheet> {
  late String _mealType;
  double _quantity = 100;

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final cal = (food.calories * _quantity / 100).round();
    final prot = food.protein * _quantity / 100;
    final carb = food.carbs * _quantity / 100;
    final ft = food.fat * _quantity / 100;

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
                color: AppColors.track,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(food.name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 16),

          // Quantity presets
          Row(
            children: [
              const Text('Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const Spacer(),
              Text('$_quantity g',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _qtyPreset('50g', 50),
              const SizedBox(width: 8),
              _qtyPreset('100g', 100),
              const SizedBox(width: 8),
              _qtyPreset('150g', 150),
              const SizedBox(width: 8),
              _qtyPreset('200g', 200),
            ],
          ),
          const SizedBox(height: 16),

          // Calculated macros
          Row(
            children: [
              _macroCard(AppColors.protein, 'Protein', '${prot.toStringAsFixed(1)}g'),
              const SizedBox(width: 8),
              _macroCard(AppColors.carbs, 'Carbs', '${carb.toStringAsFixed(1)}g'),
              const SizedBox(width: 8),
              _macroCard(AppColors.fat, 'Fat', '${ft.toStringAsFixed(1)}g'),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('$cal kcal',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          const SizedBox(height: 16),

          // Meal type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bg,
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
                  color: AppColors.ink),
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
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
                widget.onQuantityChanged(_quantity);
                widget.onLog();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
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

  Widget _qtyPreset(String label, double grams) {
    final selected = _quantity == grams;
    return GestureDetector(
      onTap: () => setState(() => _quantity = grams),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bg,
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

// ---- Quick log confirmation sheet ----

class _QuickLogSheet extends StatefulWidget {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String mealType;

  const _QuickLogSheet({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealType,
  });

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  double _quantity = 100;

  @override
  Widget build(BuildContext context) {
    final cal = (widget.calories * _quantity / 100).round();
    final prot = widget.protein * _quantity / 100;
    final carb = widget.carbs * _quantity / 100;
    final ft = widget.fat * _quantity / 100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 5,
              decoration: BoxDecoration(
                color: AppColors.track,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 16),

          // Quantity presets
          Row(
            children: [
              const Text('Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const Spacer(),
              Text('$_quantity g',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _preset('50g', 50),
              const SizedBox(width: 8),
              _preset('100g', 100),
              const SizedBox(width: 8),
              _preset('150g', 150),
              const SizedBox(width: 8),
              _preset('200g', 200),
            ],
          ),
          const SizedBox(height: 16),

          // Macros
          Row(
            children: [
              _macro(AppColors.protein, 'Protein', '${prot.toStringAsFixed(1)}g'),
              const SizedBox(width: 8),
              _macro(AppColors.carbs, 'Carbs', '${carb.toStringAsFixed(1)}g'),
              const SizedBox(width: 8),
              _macro(AppColors.fat, 'Fat', '${ft.toStringAsFixed(1)}g'),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('$cal kcal',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _quantity),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Log this food',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preset(String label, double grams) {
    final selected = _quantity == grams;
    return GestureDetector(
      onTap: () => setState(() => _quantity = grams),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink)),
      ),
    );
  }

  Widget _macro(Color color, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ---- Custom food entry sheet ----

class _CustomFoodSheet extends StatefulWidget {
  final String mealType;
  final ValueChanged<String> onMealTypeChanged;
  final Future<void> Function(String name, int cal, double p, double c, double f) onLog;

  const _CustomFoodSheet({
    required this.mealType,
    required this.onMealTypeChanged,
    required this.onLog,
  });

  @override
  State<_CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends State<_CustomFoodSheet> {
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController(text: '0');
  final _carbCtrl = TextEditingController(text: '0');
  final _fatCtrl = TextEditingController(text: '0');
  late String _mealType;

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 5,
                decoration: BoxDecoration(
                  color: AppColors.track,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Enter food manually',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),

            _field('Food name', _nameCtrl, hint: 'e.g. Dal rice'),
            const SizedBox(height: 12),
            _field('Calories (kcal)', _calCtrl, hint: 'e.g. 250', keyboardType: TextInputType.number),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _field('Protein (g)', _protCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Carbs (g)', _carbCtrl, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Fat (g)', _fatCtrl, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButton<String>(
                value: _mealType,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
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
                  final name = _nameCtrl.text.trim();
                  final cal = int.tryParse(_calCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || cal <= 0) return;
                  widget.onLog(
                    name,
                    cal,
                    double.tryParse(_protCtrl.text.trim()) ?? 0,
                    double.tryParse(_carbCtrl.text.trim()) ?? 0,
                    double.tryParse(_fatCtrl.text.trim()) ?? 0,
                  );
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Log this food',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String hint = '', TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
