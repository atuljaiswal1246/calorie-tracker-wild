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
{"mealType":"lunch","items":[{"name":"item","calories":250,"protein":10.5,"carbs":30.0,"fat":8.0,"fiber":3.5,"sugar":5.0,"sodium":450.0}]}

If no food visible: {"mealType":"snack","items":[]}

Rules: mealType = breakfast/lunch/dinner/snack. Calories = integer kcal. protein/carbs/fat/fiber/sugar = grams. sodium = mg. Indian household serving sizes. Only include visible foods.
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
      'max_tokens': 1200,
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
{"mealType":"lunch","items":[{"name":"item","calories":250,"protein":10.5,"carbs":30.0,"fat":8.0,"fiber":3.5,"sugar":5.0,"sodium":450.0}]}

Rules: mealType = breakfast/lunch/dinner/snack. Calories = integer kcal. protein/carbs/fat/fiber/sugar = grams. sodium = mg. Indian household serving sizes. Use quantity if specified, otherwise typical single serving.
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
      'max_tokens': 1200,
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
