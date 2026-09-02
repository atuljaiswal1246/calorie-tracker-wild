import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/food_entry.dart';
import '../services/food_search_service.dart';
import '../services/notification_service.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import 'manual_entry_screen.dart';

class CaptureScreen extends StatefulWidget {
  final StorageService storage;
  final File? initialImage;
  final List<File>? initialImages;

  CaptureScreen({
    super.key,
    required this.storage,
    this.initialImage,
    this.initialImages,
  });

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

  // ---- Batch (gallery auto-log) mode ----
  bool _batchMode = false;
  late List<File> _batchFiles;
  final Map<String, List<FoodItem>> _batchResults = {};
  final Set<String> _batchFailed = {};
  String _batchMealType = _autoMealType();
  bool _batchAnalyzing = false;
  int _batchIndex = 0;

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
    final images = widget.initialImages;
    if (images != null && images.length > 1) {
      _enterBatchMode(images);
      return;
    }
    final fallback = widget.initialImage ?? (images != null && images.isNotEmpty ? images.first : null);
    if (fallback != null) {
      _copyToPermanent(fallback);
    }
  }

  // ---- Batch helpers ----

  void _enterBatchMode(List<File> images) {
    _batchMode = true;
    _batchFiles = [];
    // Copy each picked photo to a permanent location, then analyze.
    var remaining = images.length;
    for (final img in images) {
      _toPermanent(img).then((path) {
        if (!mounted) return;
        _batchFiles.add(File(path));
        remaining--;
        if (remaining == 0) _analyzeBatch();
      }).catchError((_) {
        if (!mounted) return;
        _batchFiles.add(img);
        remaining--;
        if (remaining == 0) _analyzeBatch();
      });
    }
  }

  Future<void> _analyzeBatch() async {
    setState(() {
      _batchAnalyzing = true;
      _batchIndex = 0;
    });
    for (final file in _batchFiles) {
      setState(() => _batchIndex = _batchFiles.indexOf(file) + 1);
      try {
        final result = await OpenAIService().analyzeImage(file.path);
        if (!mounted) return;
        setState(() {
          if (result.items.isEmpty) {
            _batchFailed.add(file.path);
          } else {
            _batchResults[file.path] = result.items;
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _batchFailed.add(file.path));
      }
    }
    if (!mounted) return;
    setState(() => _batchAnalyzing = false);
  }

  Future<void> _logBatch() async {
    final successes = _batchResults.entries.toList();
    if (successes.isEmpty) return;

    for (final e in successes) {
      final savedPath = await _toPermanent(File(e.key));
      final entry = FoodEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime: DateTime.now(),
        mealType: _batchMealType,
        items: e.value,
        imagePath: savedPath,
      );
      await widget.storage.addEntry(entry);
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    await _showLoggedDialog();
  }

  Future<void> _askMealRemindersOnce() async {
    if (widget.storage.shouldRePromptMealPromptsNow()) {
      await _askMealReminders();
    }
  }

  /// Success dialog for batch: "Scan another" resets, "Done" exits to Home.
  Future<void> _showLoggedDialog() async {
    if (mounted) {
      _askMealRemindersOnce();
    }
    final scanAnother = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✅', style: TextStyle(fontSize: 32)),
              SizedBox(height: 10),
              Text(
                'Logged!',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Added to your day.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Scan another',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child:
                      Text('Done', style: TextStyle(color: AppColors.muted)),
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
        _batchMode = false;
        _batchFiles = [];
        _batchResults.clear();
        _batchFailed.clear();
        _batchIndex = 0;
        _image = null;
        _items = null;
        _error = null;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  /// Copy a picked image into app docs (permanent storage).
  Future<String> _toPermanent(File source) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final ext = source.path.split('.').last;
      final fileName = 'meal_${DateTime.now().microsecondsSinceEpoch}_${source.path.hashCode.abs()}.$ext';
      final dest = '${appDir.path}/$fileName';
      final permanentFile = await source.copy(dest);
      if (await permanentFile.exists()) return permanentFile.path;
    } catch (e) {
      debugPrint('Image copy failed: $e');
    }
    return source.path;
  }

  Future<void> _copyToPermanent(File source) async {
    final path = await _toPermanent(source);
    if (!mounted) return;
    setState(() {
      _image = File(path);
    });
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

    // First meal ever logged (or the one re-prompt ~4 meals later):
    // ask to enable meal reminders. Max twice ever.
    if (widget.storage.shouldRePromptMealPromptsNow()) {
      await _askMealReminders();
      if (!mounted) return;
    }

    final scanAnother = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✅', style: TextStyle(fontSize: 32)),
              SizedBox(height: 10),
              Text(
                'Logged!',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Added to your day.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  /// First-log moment: ask if the user wants meal-time prompts.
  Future<void> _askMealReminders() async {
    // Count THIS prompt as shown, whether they accept or decline.
    await widget.storage.recordMealPrompt();
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Turn on meal reminders?'),
        content: Text(
          'Get a gentle nudge at lunch, dinner and night to log your meals. '
          'You can turn this off anytime in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Turn on'),
          ),
        ],
      ),
    );
    if (enable == true) {
      await NotificationService.requestPermissions();
      await widget.storage.saveMealRemindersEnabled(true);
      if (widget.storage.remindersEnabled) {
        await NotificationService.scheduleAll(
          water: true,
          meal: true,
        );
      }
    }
  }

  /// OpenAI often collapses any vegetable curry into a generic
  /// "Vegetable Curry" / "Veg Sabzi" — same nutrition for bhindi, aloo
  /// gobi and mixed veg equals wrong estimates. Flag those so the user
  /// can switch to manual entry (typed name -> accurate macros).
  static bool _isGenericVegCurry(String name) {
    final n = name.toLowerCase();
    if (!n.contains('veg') && !n.contains('sabzi') && !n.contains('curry')) {
      return false;
    }
    return n.contains('vegetable') ||
        n.startsWith('veg ') ||
        n.startsWith('mixed veg') ||
        n == 'sabzi' ||
        n.contains('subzi') ||
        n.startsWith('vegetable') ||
        (n.contains('curry') && !RegExp(r'\b(chana|paneer|dal|chicken|egg|fish|tikka)\b').hasMatch(n));
  }

  bool get _hasGenericVegCurry =>
      (_items ?? []).any((i) => _isGenericVegCurry(i.name));

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
        insetPadding: EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🗑️', style: TextStyle(fontSize: 32)),
              SizedBox(height: 10),
              Text(
                'Discard this meal?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              SizedBox(height: 8),
              Text(
                'Your analysis will be lost.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.missedRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Discard', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Keep editing', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  /// Pre-log edit: correct an item's calories/macros/servings.
  Future<void> _editItem(FoodItem item) async {
    final ctrlCal = TextEditingController(text: item.calories.toString());
    final ctrlPro = TextEditingController(text: item.protein.toStringAsFixed(1));
    final ctrlCarbs =
        TextEditingController(text: item.carbs.toStringAsFixed(1));
    final ctrlFat = TextEditingController(text: item.fat.toStringAsFixed(1));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.name,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              SizedBox(height: 4),
              Text('Adjust and save. Quantity edits apply per serving.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              SizedBox(height: 20),
              _editField('Calories (kcal)', ctrlCal, isNumber: true),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _editField('Protein (g)', ctrlPro,
                          isNumber: true)),
                  SizedBox(width: 12),
                  Expanded(
                      child: _editField('Carbs (g)', ctrlCarbs,
                          isNumber: true)),
                  SizedBox(width: 12),
                  Expanded(
                      child: _editField('Fat (g)', ctrlFat,
                          isNumber: true)),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Save',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      // Rebuild the item with corrected base values (per 1 serving).
      final q = item.quantity == 0 ? 1.0 : item.quantity;
      setState(() {
        item.quantity = 1;
        final calories = int.tryParse(ctrlCal.text.trim()) ?? item.calories;
        final protein = double.tryParse(ctrlPro.text.trim()) ?? item.protein;
        final carbs = double.tryParse(ctrlCarbs.text.trim()) ?? item.carbs;
        final fat = double.tryParse(ctrlFat.text.trim()) ?? item.fat;
        // Can't modify final fields in place — replace item with a new one.
        final i = _items!.indexOf(item);
        if (i >= 0) {
          _items![i] = FoodItem(
            name: item.name,
            servingSizeGrams: item.servingSizeGrams,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: item.fiber,
            sugar: item.sugar,
            sodium: item.sodium,
            quantity: q,
          );
        }
      });
    }
    ctrlCal.dispose();
    ctrlPro.dispose();
    ctrlCarbs.dispose();
    ctrlFat.dispose();
  }

  Widget _editField(String label, TextEditingController ctrl,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted)),
        SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber
              ? TextInputType.numberWithOptions(decimal: true)
              : null,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: AppColors.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.ink, width: 1.5),
            ),
          ),
        ),
      ],
    );
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
              padding: EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: _confirmDiscard,
                  ),
                  Expanded(
                    child: Text(
                      'Nutrition',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink),
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _batchMode
                  ? _batchBody()
                  : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),

                    // Quality warning
                    if (_qualityWarning != null && !_analyzing) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warningOrange),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _qualityWarning!,
                                style: TextStyle(fontSize: 12, color: AppColors.warningOrange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 16),

                    // Camera / Gallery. Show whenever we have no photo in
                    // hand (fresh open OR after "Scan another"), regardless
                    // of how we entered the screen.
                    if (_image == null && _items == null)
                      Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 16, color: AppColors.muted),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Scan ONE food at a time for the best result. '
                                    'A thali? Scan roti, then sabzi, then the next '
                                    'item. Vegetable curries are most accurate '
                                    'when typed instead (see below).',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                        height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _outlineBtn(
                                    icon: Icons.photo_camera,
                                    label: 'Camera',
                                    onTap: () => _pickImage(ImageSource.camera)),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _outlineBtn(
                                    icon: Icons.photo_library,
                                    label: 'Gallery',
                                    onTap: () => _pickImage(ImageSource.gallery)),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManualEntryScreen(
                                      storage: widget.storage),
                                ),
                              ).then((v) {
                                if (v == true) Navigator.pop(context, true);
                              });
                            },
                            child: Text(
                              'Type it manually (best for vegetable curries)',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),

                    // Error
                    if (_error != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(_error!,
                                style: TextStyle(
                                    color: AppColors.missedRed, fontSize: 14)),
                            SizedBox(height: 10),
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
                                      side: BorderSide(color: AppColors.missedRed),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text('Enter manually'),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _analyze,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.missedRed,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: Text('Retry'),
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
                      SizedBox(height: 32),
                      Center(
                          child:
                              CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2)),
                      SizedBox(height: 12),
                      Center(
                        child: Text('Analyzing your food...',
                            style: TextStyle(color: AppColors.muted, fontSize: 14)),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _analyzing = false;
                              _error = null;
                            });
                          },
                          child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
                        ),
                      ),
                    ],

                    // Results
                    if (_items != null && !_analyzing) ...[
                      SizedBox(height: 16),

                      // Generic-veg-curry suggestion: the model can't tell
                      // bhindi from aloo gobi, so typing the exact name
                      // gets far better macros.
                      if (_hasGenericVegCurry) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF7E6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Color(0xFFE6C567)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16,
                                      color: Color(0xFF8A6D1F)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This looks like a generic vegetable curry. '
                                      'Typing the exact name (e.g. "Aloo Gobi", '
                                      '"Bhindi Fry") gives much closer calories '
                                      'and macros. Tap to type it:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B5414),
                                          height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ManualEntryScreen(
                                            storage: widget.storage),
                                      ),
                                    ).then((v) {
                                      if (v == true &&
                                          mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Color(0xFF8A6D1F),
                                    side: BorderSide(
                                        color: Color(0xFFE6C567)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'Type it manually',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Meal type pills
                      Row(
                        children: [
                          _mealPill('Breakfast', 'breakfast'),
                          SizedBox(width: 8),
                          _mealPill('Lunch', 'lunch'),
                          SizedBox(width: 8),
                          _mealPill('Dinner', 'dinner'),
                          SizedBox(width: 8),
                          _mealPill('Snack', 'snack'),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Food items
                      ..._items!.map((item) {
                        return _FoodItemCard(
                          item: item,
                          onChanged: () => setState(() {}),
                          onEdit: () => _editItem(item),
                          onDelete: () {
                            setState(() => _items!.remove(item));
                            if (_items!.isEmpty) {
                              setState(() => _items = null);
                            }
                          },
                        );
                      }),

                      SizedBox(height: 12),

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
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                            child: Text('Log this meal',
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
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.ink),
            SizedBox(width: 8),
            Text(label,
                style: TextStyle(
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
          padding: EdgeInsets.symmetric(vertical: 10),
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

  // ---- Batch (gallery auto-log) UI ----

  Widget _batchBody() {
    final total = _batchFiles.length;
    final done = _batchResults.length + _batchFailed.length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('📸', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Batch review — $total photo${total == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (_batchAnalyzing)
                Text(
                  '$_batchIndex / $total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          if (_batchAnalyzing) ...[
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.ink),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Analyzing photo $_batchIndex of $total…',
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          if (_batchFailed.isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: AppColors.warningOrange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_batchFailed.length} photo(s) had no food '
                      'detected — skipped.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.warningOrange),
                    ),
                  ),
                ],
              ),
            ),
          ..._batchFiles.map((file) {
            final items = _batchResults[file.path];
            final failed = _batchFailed.contains(file.path);
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        file,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: items != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...items.take(3).map((i) => Text(
                                      '• ${i.name} — ${i.calories} kcal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                        height: 1.4,
                                      ),
                                    )),
                                if (items.length > 3)
                                  Text(
                                    '+${items.length - 3} more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                              ],
                            )
                          : failed
                              ? Text(
                                  'No food detected',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.muted),
                                )
                              : Row(
                                  children: [
                                    SizedBox(
                                      width: 13,
                                      height: 13,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 1.8,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Waiting…',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.muted),
                                    ),
                                  ],
                                ),
                    ),
                    if (items != null)
                      Text(
                        '${items.fold(0, (s, i) => s + i.calories)} kcal',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (!_batchAnalyzing && _batchResults.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Meal type (applies to all):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _mealPill('Breakfast', 'breakfast'),
                SizedBox(width: 6),
                _mealPill('Lunch', 'lunch'),
                SizedBox(width: 6),
                _mealPill('Dinner', 'dinner'),
                SizedBox(width: 6),
                _mealPill('Snack', 'snack'),
              ],
            ),
            SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _logBatch,
                child: Text(
                  'Log ${_batchResults.length} photo'
                  '${_batchResults.length == 1 ? '' : 's'}'
                  ' (${_batchResults.values.fold(0, (s, list) => s + list.fold(0, (a, i) => a + i.calories))} kcal)',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else if (!_batchAnalyzing && _batchResults.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No food was detected in any photo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Food Item Card ----

class _FoodItemCard extends StatefulWidget {
  final FoodItem item;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  _FoodItemCard({
    required this.item,
    required this.onChanged,
    this.onDelete,
    this.onEdit,
  });

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
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
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
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ),
              if (widget.onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.muted),
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              if (widget.onDelete != null)
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: AppColors.muted),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              SizedBox(width: 8),
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
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity.round()}',
                          style: TextStyle(
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
          SizedBox(height: 12),

          // Serving size + Calories
          Row(
            children: [
              if (item.servingSizeGrams > 0)
                Text(
                  '${_intuitiveServing(item.servingSizeGrams)} · ${item.servingSizeGrams.round()}g',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted),
                ),
              Spacer(),
              Text('${item.calories} kcal',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
          SizedBox(height: 12),

          // Macro pills row 1
          Row(
            children: [
              _macroPill('Protein ${item.protein.toStringAsFixed(1)}g', AppColors.protein),
              SizedBox(width: 8),
              _macroPill('Carbs ${item.carbs.toStringAsFixed(1)}g', AppColors.carbs),
              SizedBox(width: 8),
              _macroPill('Fat ${item.fat.toStringAsFixed(1)}g', AppColors.fat),
            ],
          ),

          // Macro pills row 2
          if (hasSecondary) ...[
            SizedBox(height: 8),
            Row(
              children: [
                if (item.fiber > 0)
                  _macroPill('Fiber ${item.fiber.toStringAsFixed(1)}g', AppColors.fiber),
                if (item.fiber > 0 && item.sugar > 0) SizedBox(width: 8),
                if (item.sugar > 0)
                  _macroPill('Sugar ${item.sugar.toStringAsFixed(1)}g', AppColors.sugar),
                if ((item.fiber > 0 || item.sugar > 0) && item.sodium > 0)
                  SizedBox(width: 8),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  _TotalCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final totalCal = items.fold(0, (s, i) => s + i.calories);
    final totalP = items.fold(0.0, (s, i) => s + i.protein);
    final totalC = items.fold(0.0, (s, i) => s + i.carbs);
    final totalF = items.fold(0.0, (s, i) => s + i.fat);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          SizedBox(height: 16),
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
        Text(emoji, style: TextStyle(fontSize: 20)),
        SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }
}
