/// NutriCoins shop models (plan §4.4).
library;

enum ShopItemType { consumable, cosmetic, feature, personality }

/// A purchasable shop item. Non-consumables are owned once; consumables can be
/// bought repeatedly while they make sense (e.g. freezes, up to the bank cap).
class ShopItem {
  final String id;
  final String name;
  final String description;
  final int cost;
  final ShopItemType type;
  final String emoji;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    required this.emoji,
  });

  bool get repeatable => type == ShopItemType.consumable;
}

/// What the user owns / has equipped. Persisted as `shop_inventory`.
class ShopInventory {
  /// Owned non-consumable item ids.
  final List<String> owned;

  /// Currently equipped cosmetics.
  String? profileFrame;
  String? theme;
  String? ashaPersonality;

  /// ISO time until the Double Points boost is active (null = none).
  String? doublePointsUntil;

  ShopInventory({
    List<String>? owned,
    this.profileFrame,
    this.theme,
    this.ashaPersonality,
    this.doublePointsUntil,
  }) : owned = owned ?? <String>[];

  bool owns(String id) => owned.contains(id);

  bool get doublePointsActive {
    final until = doublePointsUntil;
    if (until == null) return false;
    final t = DateTime.tryParse(until);
    return t != null && t.isAfter(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'owned': owned,
        'profileFrame': profileFrame,
        'theme': theme,
        'ashaPersonality': ashaPersonality,
        'doublePointsUntil': doublePointsUntil,
      };

  factory ShopInventory.fromJson(Map<String, dynamic> json) => ShopInventory(
        owned: (json['owned'] as List?)?.map((e) => e as String).toList(),
        profileFrame: json['profileFrame'] as String?,
        theme: json['theme'] as String?,
        ashaPersonality: json['ashaPersonality'] as String?,
        doublePointsUntil: json['doublePointsUntil'] as String?,
      );
}
