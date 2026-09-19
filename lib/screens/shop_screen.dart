import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../models/shop.dart';
import '../services/gamification_controller.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// NutriCoins shop (plan §4.4). Spend coins earned from quests, streaks and
/// leagues on freezes and cosmetics.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  GamificationController? get _gami => GamificationController.instance;

  ShopService? _shop;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final gami = _gami;
    if (gami != null) _shop = ShopService(gami.storage, gami);
    gami?.revision.addListener(_onChanged);
  }

  @override
  void dispose() {
    _gami?.revision.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _equip(ShopItem item) async {
    final shop = _shop;
    if (shop == null) return;
    final ok = await shop.equip(item);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(ok ? 'Equipped ${item.name}.' : 'Nothing to equip.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? AppColors.green : AppColors.ink,
    ));
  }

  Future<void> _buy(ShopItem item) async {
    final shop = _shop;
    final gami = _gami;
    if (shop == null || gami == null) return;
    final result = await shop.purchase(item);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(result.message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: result.success ? AppColors.green : AppColors.ink,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gami = _gami;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          'Shop',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
      body: gami == null
          ? Center(child: Text('Shop unavailable.', style: TextStyle(color: AppColors.muted)))
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _balance(gami),
                SizedBox(height: 20),
                ..._section('Freezes & boosts', ShopItemType.consumable, gami),
                ..._section('Cosmetics', ShopItemType.cosmetic, gami),
                ..._section('Asha voices', ShopItemType.personality, gami),
                ..._section('Features', ShopItemType.feature, gami),
              ],
            ),
    );
  }

  Widget _balance(GamificationController gami) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Symbols.monetization_on_rounded,
              size: 28, color: AppColors.gold),
          SizedBox(width: 12),
          // Expanded: the subtitle used to run under the freezes chip and
          // overflow the row on 360dp phones.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gami.nutriCoins} NutriCoins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppType.title,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Earned from quests, streaks and leagues',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Icon(Symbols.ac_unit_rounded,
              size: 15, color: AppColors.water),
          SizedBox(width: 4),
          Text('${gami.freezes}',
              style: TextStyle(
                  fontSize: AppType.body,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
        ],
      ),
    );
  }

  /// Catalogue icons are drawn as Material Symbols rather than the emoji the
  /// catalogue stores, so the shop matches the rest of the app.
  IconData _itemIcon(ShopItem item) => switch (item.id) {
        'streak_freeze' => Symbols.ac_unit_rounded,
        'double_points' => Symbols.auto_awesome_rounded,
        'frame_bronze' || 'frame_silver' || 'frame_gold' ||
        'frame_seasonal' =>
          Symbols.workspace_premium_rounded,
        'theme_midnight' => Symbols.dark_mode_rounded,
        'theme_forest' => Symbols.forest_rounded,
        'asha_coach' => Symbols.psychology_rounded,
        'asha_friend' => Symbols.chat_bubble_rounded,
        'meal_plan_week' => Symbols.restaurant_menu_rounded,
        'macro_targets' => Symbols.tune_rounded,
        'badge_slot' => Symbols.military_tech_rounded,
        _ => Symbols.redeem_rounded,
      };

  List<Widget> _section(
      String title, ShopItemType type, GamificationController gami) {
    final items = ShopService.catalog.where((i) => i.type == type).toList();
    if (items.isEmpty) return const [];
    final inv = _shop?.inventory;
    return [
      Padding(
        padding: EdgeInsets.only(bottom: 10, top: 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: AppType.bodyStrong,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
      for (final item in items) _tile(item, gami, inv?.owns(item.id) ?? false),
      SizedBox(height: 12),
    ];
  }

  Widget _tile(ShopItem item, GamificationController gami, bool owned) {
    final affordable = gami.nutriCoins >= item.cost;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Icon(_itemIcon(item),
              size: 26, color: AppColors.ink),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(fontSize: AppType.small, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          if (owned && !item.repeatable)
            (_shop?.isEquipped(item) ?? false)
                ? Text('Equipped',
                    style: TextStyle(
                        fontSize: AppType.small,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green))
                : TextButton(
                    onPressed: () => _equip(item),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      padding: EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Use',
                        style: TextStyle(
                            fontSize: AppType.small, fontWeight: FontWeight.w700)),
                  )
          else
            TextButton(
              onPressed: affordable ? () => _buy(item) : null,
              style: TextButton.styleFrom(
                backgroundColor:
                    affordable ? AppColors.inkButton : AppColors.cardAlt,
                foregroundColor: affordable ? Colors.white : AppColors.muted,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: AppSpace.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.monetization_on_rounded,
                      size: 14,
                      color: affordable ? Colors.white : AppColors.muted),
                  SizedBox(width: 4),
                  Text('${item.cost}',
                      style: TextStyle(
                          fontSize: AppType.small, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
