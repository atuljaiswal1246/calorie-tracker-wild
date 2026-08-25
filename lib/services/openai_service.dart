import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../models/food_entry.dart';

class OpenAIService {
  final String apiKey;
  final String model;

  OpenAIService({required this.apiKey, this.model = 'gpt-4o-mini'});

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  Future<({List<FoodItem> items, String? mealType})> analyzeImage(String imagePath) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      imagePath,
      minWidth: 800,
      quality: 70,
    );
    final base64 = base64Encode(compressed ?? await File(imagePath).readAsBytes());
    final ext = imagePath.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    final prompt = '''
Analyze this food photo. Return ONLY valid JSON:
{"mealType":"lunch","items":[{"name":"Dal Makhani","servingSizeGrams":200,"calories":250,"protein":12.0,"carbs":30.0,"fat":8.0,"fiber":5.0,"sugar":3.0,"sodium":450.0,"ingredients":[{"name":"Black lentils","servingSizeGrams":120,"calories":140,"protein":9.0,"carbs":20.0,"fat":0.5},{"name":"Butter","servingSizeGrams":15,"calories":110,"protein":0.1,"carbs":0,"fat":12.0},{"name":"Cream","servingSizeGrams":30,"calories":60,"protein":0.5,"carbs":1.0,"fat":6.0}]}]}

If no food visible: {"mealType":"snack","items":[]}

Rules:
- mealType = breakfast/lunch/dinner/snack
- servingSizeGrams = estimated total weight of that item in the photo (in grams)
- calories = integer kcal for the full serving
- protein/carbs/fat/fiber/sugar = grams for the full serving
- sodium = mg for the full serving
- ingredients = breakdown of what makes up this dish, each with its own servingSizeGrams and nutrition values
- Indian household serving sizes. Only include visible foods.
''';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,$base64'},
            },
          ],
        }
      ],
      'temperature': 0.2,
      'max_tokens': 3000,
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (decoded['choices'] as List).first['message']['content']
        as String;

    return _parseResponse(content);
  }

  Future<({List<FoodItem> items, String? mealType})> analyzeText(String foodName) async {
    final prompt = '''
Estimate nutrition for this food: $foodName

Return ONLY valid JSON:
{"mealType":"lunch","items":[{"name":"Dal Makhani","servingSizeGrams":200,"calories":250,"protein":12.0,"carbs":30.0,"fat":8.0,"fiber":5.0,"sugar":3.0,"sodium":450.0,"ingredients":[{"name":"Black lentils","servingSizeGrams":120,"calories":140,"protein":9.0,"carbs":20.0,"fat":0.5},{"name":"Butter","servingSizeGrams":15,"calories":110,"protein":0.1,"carbs":0,"fat":12.0}]}]}

Rules:
- mealType = breakfast/lunch/dinner/snack
- servingSizeGrams = estimated total weight of that item (in grams)
- calories = integer kcal for the full serving
- protein/carbs/fat/fiber/sugar = grams for the full serving
- sodium = mg for the full serving
- ingredients = breakdown of what makes up this dish
- Indian household serving sizes. Use quantity if specified, otherwise typical single serving.
''';

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'temperature': 0.2,
      'max_tokens': 3000,
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = (decoded['choices'] as List).first['message']['content']
        as String;

    return _parseResponse(content);
  }

  ({List<FoodItem> items, String? mealType}) _parseResponse(String content) {
    var json = _extractJson(content);

    if (json is Map && json['items'] is List) {
      final items = json['items'] as List;
      String? mealType = json['mealType'] as String?;
      if (mealType != null) {
        mealType = mealType.toLowerCase();
        if (!['breakfast', 'lunch', 'dinner', 'snack'].contains(mealType)) {
          mealType = null;
        }
      }
      if (items.isNotEmpty) {
        return (
          items: items
              .whereType<Map<String, dynamic>>()
              .map((e) => FoodItem.fromJson(e))
              .toList(),
          mealType: mealType,
        );
      }
    }

    // No food detected or unparseable response
    return (items: [], mealType: null);
  }

  dynamic _extractJson(String content) {
    var trimmed = content.trim();

    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
    if (fenced != null) {
      trimmed = fenced.group(1)!.trim();
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      trimmed = trimmed.substring(start, end + 1);
    }

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }
}
