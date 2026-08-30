import 'dart:convert';

import 'package:http/http.dart' as http;

class BarcodeResult {
  final String barcode;
  final String name;
  final String brand;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final String servingSize;
  final String imageUrl;

  const BarcodeResult({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.servingSize = '',
    this.imageUrl = '',
  });

  bool get isValid => name.isNotEmpty && calories > 0;
}

enum BarcodeError { network, notFound, unknown }

class BarcodeService {
  static Future<({BarcodeResult? result, BarcodeError? error})> lookup(String barcode) async {
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return (result: null, error: BarcodeError.network);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return (result: null, error: BarcodeError.notFound);

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return (result: null, error: BarcodeError.notFound);

      final name = product['product_name'] as String? ?? '';
      if (name.isEmpty) return (result: null, error: BarcodeError.notFound);

      final brand = product['brands'] as String? ?? '';
      final servingSize = product['serving_size'] as String? ?? '';

      final nutriments =
          product['nutriments'] as Map<String, dynamic>? ?? {};

      return (
        result: BarcodeResult(
          barcode: barcode,
          name: name,
          brand: brand,
          calories: _toInt(nutriments['energy-kcal_100g']),
          protein: _toDouble(nutriments['proteins_100g']),
          carbs: _toDouble(nutriments['carbohydrates_100g']),
          fat: _toDouble(nutriments['fat_100g']),
          fiber: _toDouble(nutriments['fiber_100g']),
          sugar: _toDouble(nutriments['sugars_100g']),
          sodium: _toDouble(nutriments['sodium_100g']) * 1000,
          servingSize: servingSize,
          imageUrl: product['image_url'] as String? ?? '',
        ),
        error: null,
      );
    } catch (_) {
      return (result: null, error: BarcodeError.network);
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return 0;
  }
}
