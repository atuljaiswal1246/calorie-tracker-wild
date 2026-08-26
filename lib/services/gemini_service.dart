import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../models/food_entry.dart';

class GeminiService {
  final String? apiKey;

  GeminiService({this.apiKey});

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

  static Future<bool> testKey(String key) async {
    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-device-id': _deviceId,
        },
        body: jsonEncode({
          'model': 'gemini-3.6-flash',
          'contents': [
            {
              'parts': [
                {'text': 'Say "ok"'}
              ]
            }
          ]
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<({List<FoodItem> items, String? mealType})> analyzeImage(
    String imagePath, {
    String model = 'gemini-3.6-flash',
  }) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _callImageApi(imagePath, model);
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
    String model,
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
''';

    final uri = Uri.parse(_endpoint);

    final body = jsonEncode({
      'model': model,
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
        'maxOutputTokens': 1000,
      },
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-device-id': _deviceId,
      },
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

  Future<({List<FoodItem> items, String? mealType})> analyzeText(
    String foodName, {
    String model = 'gemini-3.6-flash',
  }) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _callTextApi(foodName, model);
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

  Future<({List<FoodItem> items, String? mealType})> _callTextApi(
    String foodName,
    String model,
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

    final uri = Uri.parse(_endpoint);

    final body = jsonEncode({
      'model': model,
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1000,
      },
    });

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-device-id': _deviceId,
      },
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
