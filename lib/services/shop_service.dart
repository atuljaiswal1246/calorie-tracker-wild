/// NutriCoins shop (plan §4.4).
///
/// Spends the user's NutriCoins on streak freezes and cosmetics. Freezes are
/// applied through the gamification engine (respecting the bank cap); other
/// items are recorded in the inventory for later feature wiring.
library;

import '../models/gamification_state.dart';
import '../models/shop.dart';
import 'gamification_controller.dart';
import 'storage_service.dart';

class PurchaseResult {
  final bool success;
  final String message;

  const PurchaseResult(this.success, this.message);
}

class ShopService {
  final StorageService storage;
  final GamificationController controller;

  ShopService(this.storage, this.controller);

  /// The storefront (plan §4.4 shop table).
  static const List<ShopItem> catalog = [
    ShopItem(
      id: 'streak_freeze',
      name: 'Streak Freeze',
      description: 'Covers one missed day so a rest day never breaks you.',
      cost: 100,
      type: ShopItemType.consumable,
      emoji: '❄️',
    ),
    ShopItem(
      id: 'double_points',
      name: 'Double Points',
      description: 'Earn 2× Cal Points for 24 hours.',
      cost: 150,
      type: ShopItemType.consumable,
      emoji: '✨',
    ),
    ShopItem(
      id: 'frame_bronze',
      name: 'Bronze Frame',
      description: 'A bronze ring around your avatar.',
      cost: 200,
      type: ShopItemType.cosmetic,
      emoji: '🥉',
    ),
    ShopItem(
      id: 'frame_silver',
      name: 'Silver Frame',
      description: 'A silver ring around your avatar.',
      cost: 400,
      type: ShopItemType.cosmetic,
      emoji: '🥈',
    ),
    ShopItem(
      id: 'frame_gold',
      name: 'Gold Frame',
      description: 'A gold ring around your avatar.',
      cost: 800,
      type: ShopItemType.cosmetic,
      emoji: '🥇',
    ),
    ShopItem(
      id: 'frame_seasonal',
      name: 'Seasonal Frame',
      description: 'A limited rotating frame — this season only.',
      cost: 500,
      type: ShopItemType.cosmetic,
      emoji: '🍃',
    ),
    ShopItem(
      id: 'theme_midnight',
      name: 'Midnight Theme',
      description: 'A deeper, darker app theme.',
      cost: 300,
      type: ShopItemType.cosmetic,
      emoji: '🌙',
    ),
    ShopItem(
      id: 'theme_forest',
      name: 'Forest Theme',
      description: 'A calm green-accented theme.',
      cost: 300,
      type: ShopItemType.cosmetic,
      emoji: '🌲',
    ),
    ShopItem(
      id: 'asha_coach',
      name: 'Asha: Coach',
      description: 'A firmer, goal-focused Asha voice.',
      cost: 200,
      type: ShopItemType.personality,
      emoji: '🎯',
    ),
    ShopItem(
      id: 'asha_friend',
      name: 'Asha: Friend',
      description: 'A warmer, chattier Asha voice.',
      cost: 200,
      type: ShopItemType.personality,
      emoji: '💬',
    ),
    ShopItem(
      id: 'meal_plan_week',
      name: 'Premium Meal Plan',
      description: 'Unlock one week of curated meal plans.',
      cost: 500,
      type: ShopItemType.feature,
      emoji: '🍱',
    ),
    ShopItem(
      id: 'macro_targets',
      name: 'Custom Macro Targets',
      description: 'Set your own macro split for a month.',
      cost: 300,
      type: ShopItemType.feature,
      emoji: '🎚️',
    ),
    ShopItem(
      id: 'badge_slot',
      name: 'Extra Badge Slot',
      description: 'Showcase one more badge on your profile.',
      cost: 250,
      type: ShopItemType.cosmetic,
      emoji: '🏅',
    ),
  ];

  static ShopItem? byId(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  ShopInventory get inventory =>
      ShopInventory.fromJson(storage.shopInventoryRaw ?? const {});

  /// Buy [item]. Returns a success flag plus a message for the UI.
  Future<PurchaseResult> purchase(ShopItem item) async {
    final inv = inventory;

    if (!item.repeatable && inv.owns(item.id)) {
      return const PurchaseResult(false, 'You already own this.');
    }
    if (item.id == 'streak_freeze' &&
        controller.freezes >= StreakState.maxFreezeBank) {
      return const PurchaseResult(
          false, 'Your freeze bank is full (${StreakState.maxFreezeBank}).');
    }
    if (controller.nutriCoins < item.cost) {
      return PurchaseResult(false,
          'You need ${item.cost - controller.nutriCoins} more NutriCoins.');
    }
    if (!controller.service.spendCoins(item.cost)) {
      return const PurchaseResult(false, 'Not enough NutriCoins.');
    }

    switch (item.id) {
      case 'streak_freeze':
        controller.service.addFreezes(1);
        break;
      case 'double_points':
        inv.doublePointsUntil =
            DateTime.now().add(const Duration(days: 1)).toIso8601String();
        break;
      default:
        if (!inv.owned.contains(item.id)) inv.owned.add(item.id);
        if (item.id.startsWith('frame_')) {
          inv.profileFrame = item.id;
        } else if (item.id.startsWith('theme_')) {
          inv.theme = item.id;
        } else if (item.id.startsWith('asha_')) {
          inv.ashaPersonality = item.id;
        }
    }

    await storage.saveShopInventory(inv.toJson());
    controller.refresh();
    return PurchaseResult(true, 'Purchased ${item.name}.');
  }
}
