import 'dart:math';

import 'package:flutter/material.dart';
import '../data/prebuilt_plans.dart';
import '../models/food_entry.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class MealPlanScreen extends StatefulWidget {
  final StorageService storage;
  MealPlanScreen({super.key, required this.storage});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  List<MealPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _plans = widget.storage.mealPlans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _ink,
        title: Text(
          'Meal Plans',
          style: TextStyle(
            fontSize: AppType.headline,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showSaveFromTodaySheet(context),
            icon: Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Save today',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _ink,
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: Color(0xFFFF9500)),
              SizedBox(width: 8),
              Text(
                'Expert-made plans',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '7-day Indian menus for your goal',
            style: TextStyle(fontSize: AppType.body, color: _muted),
          ),
          SizedBox(height: 14),
          ...prebuiltPlans.map((p) => _prebuiltCard(p)),
          SizedBox(height: 22),
          Row(
            children: [
              Icon(Icons.bookmark, size: 20, color: Color(0xFF1C1C1E)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'My templates',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showSaveFromTodaySheet(context),
                child: Text(
                  'Save today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (_plans.isEmpty)
            _buildEmpty()
          else
            ..._plans.map((p) => _planCard(p)),
        ],
      ),
    );
  }

  Widget _prebuiltCard(PrebuiltPlan plan) {
    final color = Color(int.parse(plan.accentHex.replaceFirst('#', 'FF'), radix: 16));
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrebuiltPlanDetailScreen(plan: plan, storage: widget.storage),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(plan.emoji, style: TextStyle(fontSize: 26)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: AppType.title,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    plan.tagline,
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          plan.focus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '7 days · 4 meals',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 56, color: _muted.withOpacity(0.4)),
          SizedBox(height: 14),
          Text(
            'No meal plans yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Save a day\'s meals as a plan to quickly\nlog the same meals again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(MealPlan plan) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: AppType.title,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteSheet(context, plan),
                child: Icon(Icons.more_horiz, size: 20, color: _muted),
              ),            ],
          ),
          SizedBox(height: 8),
          // Items list
          ...plan.items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${item.quantity.toInt()}x',
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: _ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${item.calories} kcal',
                      style: TextStyle(
                        fontSize: AppType.body,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              )),
          SizedBox(height: 10),
          // Totals + log button
          Row(
            children: [
              _macroPill('${plan.totalCalories} kcal', _ink),
              SizedBox(width: 6),
              _macroPill('${plan.totalProtein.round()}g P', Color(0xFFE53935)),
              SizedBox(width: 6),
              _macroPill('${plan.totalCarbs.round()}g C', Color(0xFFFF9500)),
              SizedBox(width: 6),
              _macroPill('${plan.totalFat.round()}g F', Color(0xFF007AFF)),
              Spacer(),
              GestureDetector(
                onTap: () => _logPlan(context, plan),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Log',
                    style: TextStyle(
                      fontSize: AppType.body,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _logPlan(BuildContext context, MealPlan plan) async {
    await widget.storage.logMealPlan(plan);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${plan.name} logged!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _showDeleteSheet(BuildContext context, MealPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              plan.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '${plan.items.length} items',
              style: TextStyle(fontSize: AppType.body, color: _muted),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () => _showRenameSheet(context, plan),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: BorderSide(color: Color(0xFFE5E5EA), width: 1.5),
                  shape: StadiumBorder(),
                ),
                child: Text(
                  'Rename plan',
                  style: TextStyle(
                      fontSize: AppType.title,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5),
                ),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: () async {
                  await widget.storage.deleteMealPlan(plan.id);
                  _load();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFFFF3B30),
                  side: BorderSide(color: Color(0xFFFF3B30), width: 1.5),
                  shape: StadiumBorder(),
                ),
                child: Text(
                  'Delete plan',
                  style: TextStyle(
                      fontSize: AppType.title,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSheet(BuildContext context, MealPlan plan) {
    final nameController = TextEditingController(text: plan.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rename plan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontSize: AppType.title,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _ink, width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final updated = MealPlan(
                    id: plan.id,
                    name: name,
                    items: plan.items,
                    createdAt: plan.createdAt,
                  );
                  await widget.storage.updateMealPlan(updated);
                  _load();
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  shape: StadiumBorder(),
                ),
                child: Text(
                  'Save',
                  style: TextStyle(
                      fontSize: AppType.title,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveFromTodaySheet(BuildContext context) {
    final todayEntries = widget.storage.entries.where((e) => e.isOn(DateTime.now())).toList();
    if (todayEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No meals logged today to save.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final selected = List<bool>.filled(todayEntries.length, true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save today\'s meals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Choose which meals to include',
                style: TextStyle(fontSize: AppType.body, color: _muted),
              ),
              SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.3,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: todayEntries.asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return GestureDetector(
                      onTap: () =>
                          setSheet(() => selected[i] = !selected[i]),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              selected[i]
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: selected[i] ? _ink : _muted,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${e.items.isEmpty ? 'Meal' : e.items.first.name}'
                                    '${e.items.length > 1 ? ' +${e.items.length - 1}' : ''}'
                                    ' · ${e.totalCalories} kcal',
                                style: TextStyle(
                                  fontSize: AppType.body,
                                  fontWeight: FontWeight.w500,
                                  color: _ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  fontSize: AppType.title,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  hintText: 'Plan name (e.g. "My usual lunch")',
                  hintStyle: TextStyle(color: _muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _ink, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final items = <FoodItem>[];
                    for (var i = 0; i < todayEntries.length; i++) {
                      if (selected[i]) items.addAll(todayEntries[i].items);
                    }
                    if (items.isEmpty) return;
                    final plan = MealPlan(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      items: items,
                    );
                    await widget.storage.saveMealPlan(plan);
                    _load();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    'Save plan',
                    style: TextStyle(
                        fontSize: AppType.title,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrebuiltPlanDetailScreen extends StatefulWidget {
  final PrebuiltPlan plan;
  final StorageService storage;

  PrebuiltPlanDetailScreen({
    super.key,
    required this.plan,
    required this.storage,
  });

  @override
  State<PrebuiltPlanDetailScreen> createState() =>
      _PrebuiltPlanDetailScreenState();
}

class _PrebuiltPlanDetailScreenState extends State<PrebuiltPlanDetailScreen> {
  static const _bg = Color(0xFFFAF9F7);
  static const _ink = Color(0xFF1C1C1E);
  static const _muted = Color(0xFF8E8E93);
  static const _cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  int _selectedDay = 1;
  final _rand = Random();

  Color get _accent =>
      Color(int.parse(widget.plan.accentHex.replaceFirst('#', 'FF'), radix: 16));

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final day =
        plan.days.firstWhere((d) => d.day == _selectedDay, orElse: () => plan.days.first);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _accent,
        title: Text(
          plan.title,
          style: TextStyle(
            fontSize: AppType.headline,
            fontWeight: FontWeight.w800,
            color: _ink,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: [
          // Plan summary
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text(plan.emoji, style: TextStyle(fontSize: 30)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plan.approxKcal} kcal/day · 7 days',
                        style: TextStyle(
                          fontSize: AppType.bodyStrong,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Log any meal or the full day',
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          // Day selector
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: plan.days.map((d) {
                final selected = d.day == _selectedDay;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = d.day),
                    child: Container(
                      width: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? _accent : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: selected ? null : _cardShadow,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Day ${d.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : _ink,
                            ),
                          ),
                          Text(
                            '${d.totalCalories}',
                            style: TextStyle(
                              fontSize: 9,
                              color: selected ? Colors.white70 : _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16),
          // Meals for selected day
          ...day.meals.map((meal) => _mealBlock(meal, day)),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () async {
                await _logDay(day);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Day $_selectedDay logged!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                shape: StadiumBorder(),
              ),
              child: Text(
                'Log full day',
                style: TextStyle(
                    fontSize: AppType.title,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealBlock(PlanMeal meal, PlanDay day) {
    final title = switch (meal.title) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      _ => 'Snack',
    };
    final icon = switch (meal.title) {
      'breakfast' => Icons.wb_twilight,
      'lunch' => Icons.light_mode,
      'dinner' => Icons.nights_stay,
      _ => Icons.cookie,
    };

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _accent),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppType.bodyStrong,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '${meal.totalCalories} kcal',
                style: TextStyle(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ...meal.items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          Text(
                            item.serving,
                            style: TextStyle(
                              fontSize: 11,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.calories} kcal · ${item.protein.toStringAsFixed(0)}P',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              )),
          SizedBox(height: 4),
          Row(
            children: [
              _miniPill('P ${meal.totalProtein.toStringAsFixed(0)}g', Color(0xFFE53935)),
              SizedBox(width: 6),
              _miniPill('C ${meal.totalCarbs.toStringAsFixed(0)}g', Color(0xFFFF9500)),
              SizedBox(width: 6),
              _miniPill('F ${meal.totalFat.toStringAsFixed(0)}g', Color(0xFF007AFF)),
              Spacer(),
              GestureDetector(
                onTap: () => _logMeal(meal),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Log',
                    style: TextStyle(
                      fontSize: AppType.body,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniPill(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _logMeal(PlanMeal meal) async {
    await widget.storage.addEntry(FoodEntry(
      id: (DateTime.now().microsecondsSinceEpoch + _rand.nextInt(9999))
          .toString(),
      dateTime: DateTime.now(),
      mealType: meal.title,
      imagePath: '',
      items: meal.items
          .map((i) => FoodItem(
                name: i.name,
                calories: i.calories,
                protein: i.protein,
                carbs: i.carbs,
                fat: i.fat,
              ))
          .toList(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged!'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _logDay(PlanDay day) async {
    for (final meal in day.meals) {
      await widget.storage.addEntry(FoodEntry(
        id: (DateTime.now().microsecondsSinceEpoch + _rand.nextInt(99999))
            .toString(),
        dateTime: DateTime.now(),
        mealType: meal.title,
        imagePath: '',
        items: meal.items
            .map((i) => FoodItem(
                  name: i.name,
                  calories: i.calories,
                  protein: i.protein,
                  carbs: i.carbs,
                  fat: i.fat,
                ))
            .toList(),
      ));
    }
    if (mounted) Navigator.pop(context, true);
  }
}
