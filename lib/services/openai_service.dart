import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../models/food_entry.dart';

/// Calls OpenCode Go (OpenAI-compatible) through the Cloudflare worker proxy.
/// No API key is needed or stored in the app — the worker owns the key.
class OpenAIService {
  final String model;

  OpenAIService({this.model = 'deepseek-v4-flash-vision-exp'});

  /// Cloudflare proxy — key never ships to the client.
  static const _endpoint =
      'https://cal-matters-gemini-proxy.atuljaiswal1246.workers.dev';
  static const _maxRetries = 3;

  /// Stable per-install anonymous device id for proxy quota tracking.
  static String get _deviceId {
    final dir = Directory.systemTemp;
    final f = File('${dir.path}/cal_matters_device_id');
    try {
      if (f.existsSync()) {
        final id = f.readAsStringSync().trim();
        if (id.isNotEmpty) return id;
      }
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      f.writeAsStringSync(id);
      return id;
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<bool> testKey() async {
    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-device-id': _deviceId,
        },
        body: jsonEncode({
          'model': 'deepseek-v4-flash-vision-exp',
          'messages': [
            {'role': 'user', 'content': 'Say "ok"'}
          ],
          'max_tokens': 5,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST a body to the proxy; throws if the proxy is unreachable/errors.
  Future<Map<String, dynamic>> _postToProxy(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-device-id': _deviceId,
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'AI request failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<({List<FoodItem> items, String? mealType})> analyzeImage(String imagePath) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _callImageApi(imagePath);
        if (result.items.isNotEmpty) return result;
        if (attempt < _maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return result;
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
    return (items: <FoodItem>[], mealType: null);
  }

  Future<({List<FoodItem> items, String? mealType})> _callImageApi(
    String imagePath,
  ) async {
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
{"mealType":"lunch","items":[{"name":"Dal Makhani","servingSizeGrams":200,"calories":250,"protein":12.0,"carbs":30.0,"fat":8.0,"fiber":5.0,"sugar":3.0,"sodium":450.0}]}

If no food visible: {"mealType":"snack","items":[]}

Rules:
- mealType = breakfast/lunch/dinner/snack
- servingSizeGrams = estimated total weight of that item in the photo (in grams)
- calories = integer kcal for the full serving
- protein/carbs/fat/fiber/sugar = grams for the full serving
- sodium = mg for the full serving
- Indian household serving sizes. Only include visible foods.
- If the photo shows ONE food (a single bowl of sabzi, one roti, etc.), return it as the ONLY item — do not add guesses about side dishes that are not clearly visible.
- NAMES MUST BE SPECIFIC: identify the exact dish by its traditional name (e.g. "Aloo Gobi", "Bhindi Fry", "Mixed Vegetable Curry", "Chana Masala", "Baingan Bharta", "Palak Paneer"). NEVER return generic labels like "Vegetable Curry", "Veg Sabzi", "Curry", "Side Dish" or "Vegetables" unless the photo truly shows an unidentifiable mixed dish; prefer the most specific name you can.
- If the food is a mixed dish of many items (a thali), still return each visible item separately, but each with a specific name.
''';

    final body = {
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
      'max_tokens': 1000,
    };

    final decoded = await _postToProxy(body);
    final content = (decoded['choices'] as List).first['message']['content']
        as String;

    return _parseResponse(content);
  }

  Future<({List<FoodItem> items, String? mealType})> analyzeText(String foodName) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _callTextApi(foodName);
        if (result.items.isNotEmpty) return result;
        if (attempt < _maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        return result;
      } catch (e) {
        if (attempt < _maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
    return (items: <FoodItem>[], mealType: null);
  }

  /// Plain-text chat with the same proxy — used by Asha (AI nutrition
  /// assistant). Returns the assistant message text or throws on failure.
  Future<String> chat(String systemPrompt, List<Map<String, String>> messages,
      {int? maxTokens}) async {
    final body = {
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...messages.map((m) => {
              'role': m['role'],
              'content': m['content'],
            }),
      ],
      'temperature': 0.6,
      if (maxTokens != null) 'max_tokens': maxTokens,
    };

    final decoded = await _postToProxy(body);
    final content = (decoded['choices'] as List).first['message']['content']
        as String;
    return content.trim();
  }

  Future<({List<FoodItem> items, String? mealType})> _callTextApi(
    String foodName,
  ) async {
    final prompt = '''
Estimate nutrition for this food: $foodName

Return ONLY valid JSON:
{"mealType":"lunch","items":[{"name":"Dal Makhani","servingSizeGrams":200,"calories":250,"protein":12.0,"carbs":30.0,"fat":8.0,"fiber":5.0,"sugar":3.0,"sodium":450.0}]}

Rules:
- mealType = breakfast/lunch/dinner/snack
- servingSizeGrams = estimated total weight of that item (in grams)
- calories = integer kcal for the full serving
- protein/carbs/fat/fiber/sugar = grams for the full serving
- sodium = mg for the full serving
- Indian household serving sizes. Use quantity if specified, otherwise typical single serving.
''';

    final body = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'temperature': 0.2,
      'max_tokens': 1000,
    };

    final decoded = await _postToProxy(body);
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
