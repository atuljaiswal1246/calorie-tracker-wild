import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calorie_tracker/models/gamification_state.dart';
import 'package:calorie_tracker/models/shop.dart';
import 'package:calorie_tracker/services/gamification_controller.dart';
import 'package:calorie_tracker/services/shop_service.dart';
import 'package:calorie_tracker/services/storage_service.dart';
import 'package:calorie_tracker/theme/app_colors.dart';

void main() {
  late StorageService storage;
  late GamificationController gami;
  late ShopService shop;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    gami = GamificationController(storage);
    await gami.init();
    shop = ShopService(storage, gami);
    gami.state.nutriCoins = 1000;
  });

  ShopItem item(String id) => ShopService.byId(id)!;

  test('catalog matches the plan and ids are unique', () {
    expect(ShopService.catalog.length, 13);
    expect(
        ShopService.catalog.map((i) => i.id).toSet().length,
        ShopService.catalog.length);
  });

  test('buying a streak freeze spends coins and banks a freeze', () async {
    final before = gami.freezes;
    final r = await shop.purchase(item('streak_freeze'));
    expect(r.success, isTrue);
    expect(gami.nutriCoins, 900);
    expect(gami.freezes, before + 1);
  });

  test('cannot buy a freeze when the bank is full', () async {
    gami.state.streak.freezeCount = StreakState.maxFreezeBank;
    final r = await shop.purchase(item('streak_freeze'));
    expect(r.success, isFalse);
    expect(gami.nutriCoins, 1000);
  });

  test('insufficient coins are rejected with a helpful message', () async {
    gami.state.nutriCoins = 10;
    final r = await shop.purchase(item('frame_gold'));
    expect(r.success, isFalse);
    expect(r.message, contains('more NutriCoins'));
  });

  test('cosmetics are owned once and equipped', () async {
    final r = await shop.purchase(item('frame_bronze'));
    expect(r.success, isTrue);
    final inv = shop.inventory;
    expect(inv.owns('frame_bronze'), isTrue);
    expect(inv.profileFrame, 'frame_bronze');

    final again = await shop.purchase(item('frame_bronze'));
    expect(again.success, isFalse);
    expect(again.message, contains('already own'));
  });

  test('Asha personalities are recorded', () async {
    await shop.purchase(item('asha_coach'));
    expect(shop.inventory.ashaPersonality, 'asha_coach');
  });

  test('double points activates a 24h boost', () async {
    await shop.purchase(item('double_points'));
    expect(shop.inventory.doublePointsActive, isTrue);
  });

  test('purchases persist across reload', () async {
    await shop.purchase(item('theme_forest'));
    final reloaded = ShopService(storage, gami);
    expect(reloaded.inventory.owns('theme_forest'), isTrue);
    expect(reloaded.inventory.theme, 'theme_forest');
  });

  test('owned cosmetics can be re-equipped', () async {
    await shop.purchase(item('frame_bronze'));
    await shop.purchase(item('frame_silver'));
    // The most recent purchase is equipped by default.
    expect(shop.isEquipped(item('frame_silver')), isTrue);
    final ok = await shop.equip(item('frame_bronze'));
    expect(ok, isTrue);
    expect(shop.isEquipped(item('frame_bronze')), isTrue);
    expect(shop.isEquipped(item('frame_silver')), isFalse);
  });

  test('cannot equip something not owned', () async {
    expect(await shop.equip(item('theme_midnight')), isFalse);
  });

  test('buying a theme applies it globally', () async {
    await shop.purchase(item('theme_forest'));
    expect(AppColors.themeNotifier.value, 'theme_forest');
    expect(AppColors.accent.toARGB32(), const Color(0xFF2E7D32).toARGB32());
  });
}
