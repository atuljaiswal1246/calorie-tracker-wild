import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/food_entry.dart';

class GeminiService {
  final String apiKey;

  GeminiService({required this.apiKey});

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/';

  Future<({List<FoodItem> items, String? mealType})> analyzeImage(
    String imagePath, {
    String model = 'gemini-3.6-flash',
  }) async {
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
{"mealType":"lunch","items":[{"name":"item name","calories":250,"protein":10.5,"carbs":30.0,"fat":8.0,"fiber":3.5,"sugar":5.0,"sodium":450.0}]}

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

    final uri = Uri.parse('$_endpoint$model:generateContent')
        .replace(queryParameters: {'key': apiKey});

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mime,
                'data': base64,
              }
            },
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 2000,
      },
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini request failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List? ?? [];
    if (candidates.isEmpty) {
      throw const FormatException('No analysis returned from Gemini.');
    }
    final parts = (candidates.first['content']['parts'] as List? ?? []);
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();

    return _parseResponse(text);
  }

  ({List<FoodItem> items, String? mealType}) _parseResponse(String content) {
    var trimmed = content.trim();

    // Try to extract JSON from markdown fences
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
    if (fenced != null) {
      trimmed = fenced.group(1)!.trim();
    }

    // Find the outermost { ... }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      trimmed = trimmed.substring(start, end + 1);
    }

    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      String? mealType = json['mealType'] as String?;
      if (mealType != null) {
        mealType = mealType.toLowerCase();
        if (!['breakfast', 'lunch', 'dinner', 'snack'].contains(mealType)) {
          mealType = null;
        }
      }

      if (json['items'] is List) {
        final items = json['items'] as List;
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
    } catch (_) {
      // JSON parse failed — try to find an array of objects as fallback
      final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(content);
      if (arrayMatch != null) {
        try {
          final list = jsonDecode(arrayMatch.group(0)!) as List;
          if (list.isNotEmpty && list.first is Map) {
            return (
              items: list
                  .whereType<Map<String, dynamic>>()
                  .map((e) => FoodItem.fromJson(e))
                  .toList(),
              mealType: null,
            );
          }
        } catch (_) {}
      }
    }

    // No food detected or unparseable response
    return (items: [], mealType: null);
  }
}
