import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../services/gamification_controller.dart';
import '../services/shop_service.dart';
import '../theme/app_colors.dart';

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
          Text('🪙', style: TextStyle(fontSize: 26)),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${gami.nutriCoins} NutriCoins',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              Text(
                'Earned from quests, streaks and leagues',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          Spacer(),
          Text('❄️ ${gami.freezes}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
        ],
      ),
    );
  }

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
            fontSize: 15,
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: TextStyle(fontSize: 24)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          if (owned && !item.repeatable)
            (_shop?.isEquipped(item) ?? false)
                ? Text('Equipped',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green))
                : TextButton(
                    onPressed: () => _equip(item),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Use',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  )
          else
            TextButton(
              onPressed: affordable ? () => _buy(item) : null,
              style: TextButton.styleFrom(
                backgroundColor:
                    affordable ? AppColors.inkButton : AppColors.cardAlt,
                foregroundColor: affordable ? Colors.white : AppColors.muted,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('🪙 ${item.cost}',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
