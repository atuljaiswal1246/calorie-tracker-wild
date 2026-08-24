import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/food_entry.dart';

class OpenAIService {
  final String apiKey;
  final String model;

  OpenAIService({required this.apiKey, this.model = 'gpt-4o-mini'});

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  Future<({List<FoodItem> items, String? mealType})> analyzeImage(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final base64 = base64Encode(bytes);
    final ext = imagePath.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    final prompt = '''
You are a nutrition expert for Indian food. Analyze the food in this photo and return ONLY valid JSON, no markdown, no extra text.

Estimate portion sizes as typical Indian household servings. Use realistic calorie and macro estimates for Indian dishes (e.g. dal, roti, rice, biryani, samosa, dosa, paneer, curry, etc.). Include every visible food item as a separate object.

Respond with this exact JSON structure:
{
  "mealType": "lunch",
  "items": [
    {
      "name": "item name",
      "calories": 250,
      "protein": 10.5,
      "carbs": 30.0,
      "fat": 8.0,
      "fiber": 3.5,
      "sugar": 5.0,
      "sodium": 450.0
    }
  ]
}

If there is no food visible, or the cup/plate is nearly empty with only residue or a few drops left, return {"mealType":"snack","items":[]}.

Rules:
- "mealType" must be one of: "breakfast", "lunch", "dinner", "snack". Infer from the food type and likely time of day (Indian meal patterns: paratha/poha/upma/dosa = breakfast, dal-roti/rice-curry = lunch, roti-curry/rice = dinner, chai-samosa/pakora = snack).
- "calories" is an integer in kcal.
- protein, carbs, fat, fiber, sugar are in grams (numbers).
- sodium is in milligrams (number).
- For fiber: estimate based on food type (whole grains, lentils, vegetables are high; refined flour, rice are low).
- For sugar: include both natural sugars (lactose in milk, fructose in fruit) and estimate added sugar based on typical preparation.
- For sodium: estimate based on typical salt usage in Indian cooking (curries moderate, pickles/chaat high, plain rice/roti low).
- If unsure, give a reasonable estimate.
- Only include foods actually visible.
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
