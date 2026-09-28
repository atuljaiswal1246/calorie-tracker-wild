import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'scan_failure.dart';

import '../models/food_entry.dart';

/// Calls OpenCode Go (OpenAI-compatible) through the Cloudflare worker proxy.
/// No API key is needed or stored in the app — the worker owns the key.
class OpenAIService {
  final String model;

  OpenAIService({this.model = 'mimo-v2.5'});

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
          'model': 'mimo-v2.5',
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

  Future<({List<FoodItem> items, String? mealType, bool unrecognised})>
      analyzeImage(String imagePath) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _callImageApi(imagePath);
        if (result.items.isNotEmpty) return result;
        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
        return result;
      } catch (e) {
        // Retry only what a second attempt can plausibly fix. A 402 is our own
        // billing state: an identical retry spends nothing, succeeds never, and
        // costs the user four seconds of spinner. Before this every exception was
        // retried, so a guaranteed failure was made guaranteed three times over
        // and the Worker was hit three times for nothing.
        if (!shouldRetryScan(classifyScanFailure(e.toString()))) rethrow;
        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
    return (items: <FoodItem>[], mealType: null, unrecognised: true);
  }

  Future<({List<FoodItem> items, String? mealType, bool unrecognised})>
      _callImageApi(
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

    // The shape below is a SCHEMA, not an answer. It deliberately contains NO
    // realistic-looking numbers. A concrete example (e.g. a "Dal Makhani 250
    // kcal / 12 / 30 / 8" sample) is a copy magnet: measured on a real
    // palak-paneer photo, the model returned that example's exact numbers and
    // invented a Naan that was not in the picture. Schema-only + an explicit
    // "estimate from THIS photo" instruction gave photo-derived numbers
    // (300g, 450 kcal, P20/C30/F30) and no hallucinated side dish.
    final prompt = '''
Analyze this food photo and return ONLY valid JSON with this exact shape:

{"mealType": "<breakfast|lunch|dinner|snack>",
 "items": [
   {"name": "<specific Indian dish name>",
    "servingSizeGrams": <integer>,
    "calories": <integer kcal for the whole serving>,
    "protein": <grams>, "carbs": <grams>, "fat": <grams>,
    "fiber": <grams>, "sugar": <grams>, "sodium": <mg>,
    "calcium": <mg>, "iron": <mg>, "vitaminC": <mg>,
    "confidence": <0.0-1.0, how sure you are of this dish name>}
 ],
 "unrecognised": <true ONLY if you cannot identify the dish with confidence>
}

The shape above is a SCHEMA, not an answer. Every value MUST be estimated from
THIS photo. Never reuse any number or dish name from this instruction.

**IF YOU ARE NOT SURE WHAT THE DISH IS, SAY SO INSTEAD OF GUESSING.**
Set "unrecognised": true and return "items": []. A dish you invent is worse than
no answer at all: the user cannot tell a made-up dish from a real one, and a
wrong number goes straight into their diet. The app will offer to let them type
the name instead. Not recognising something is a normal answer, not a failure.

If no food visible: {"mealType":"snack","items":[],"unrecognised":true}

Rules:
- Set "confidence" honestly per dish. Below about 0.6 means you are guessing.
- mealType = breakfast/lunch/dinner/snack
- servingSizeGrams = estimated total weight of that item in the photo (in grams)
- calories = integer kcal for the full serving
- protein/carbs/fat/fiber/sugar = grams for the full serving
- sodium = mg for the full serving
- calcium/iron/vitaminC = mg for the full serving — estimate from the typical nutrient content of the dish (e.g. dal and paneer are calcium-rich, leafy greens are iron-rich). If you cannot estimate a value, output 0.
- Indian household serving sizes. Only include visible foods.
- List ONLY food actually visible in the photo. Do not add sides, breads or drinks that are not clearly visible — a missing side is better than an invented one.
- If the photo shows ONE food (a single bowl of sabzi, one roti, etc.), return it as the ONLY item — do not add guesses about side dishes that are not clearly visible.
- NAMES MUST BE SPECIFIC: identify the exact dish by its traditional name (e.g. "Aloo Gobi", "Bhindi Fry", "Mixed Vegetable Curry", "Chana Masala", "Baingan Bharta", "Palak Paneer"). NEVER return generic labels like "Vegetable Curry", "Veg Sabzi", "Curry", "Side Dish" or "Vegetables" unless the photo truly shows an unidentifiable mixed dish; prefer the most specific name you can.
- If the food is a mixed dish of many items (a thali), still return each visible item separately, but each with a specific name.
- IMPORTANT: For a thali or multi-item meal, list EVERY visible item — do not merge two dishes into one, and do NOT omit small items (sambar, chutney, papad, curd, pickle, salad, dal, sabzi are all separate items). Count every distinct dish you can see, then return exactly that many items.
- IMPORTANT: Use realistic home-cooked Indian portion sizes, not restaurant mega-serves. A single katori of dal is ~150-200g, one roti is ~40g, one bowl of rice is ~200g cooked. Prefer reasonable home portions and keep total meal calories plausible (a standard home thali is usually 500-900 kcal, not 1500+).
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

  Future<({List<FoodItem> items, String? mealType, bool unrecognised})>
      analyzeText(String foodName) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final result = await _callTextApi(foodName);
        if (result.items.isNotEmpty) return result;
        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
        return result;
      } catch (e) {
        // Retry only what a second attempt can plausibly fix. A 402 is our own
        // billing state: an identical retry spends nothing, succeeds never, and
        // costs the user four seconds of spinner. Before this every exception was
        // retried, so a guaranteed failure was made guaranteed three times over
        // and the Worker was hit three times for nothing.
        if (!shouldRetryScan(classifyScanFailure(e.toString()))) rethrow;
        if (attempt < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
    }
    return (items: <FoodItem>[], mealType: null, unrecognised: true);
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

  Future<({List<FoodItem> items, String? mealType, bool unrecognised})>
      _callTextApi(
    String foodName,
  ) async {
    // Schema-only, for the same reason as the image prompt: a concrete sample
    // ("Dal Makhani 250 kcal / 12 / 30 / 8") gets echoed back as the answer
    // for whatever food was asked for.
    final prompt = '''
Estimate nutrition for this food: $foodName

Return ONLY valid JSON with this exact shape:

{"mealType": "<breakfast|lunch|dinner|snack>",
 "items": [
   {"name": "$foodName",
    "servingSizeGrams": <integer>,
    "calories": <integer kcal for the whole serving>,
    "protein": <grams>, "carbs": <grams>, "fat": <grams>,
    "fiber": <grams>, "sugar": <grams>, "sodium": <mg>,
    "calcium": <mg>, "iron": <mg>, "vitaminC": <mg>}
 ]}

The shape above is a SCHEMA, not an answer. Every value MUST be estimated for
"$foodName" itself. Never reuse any number from this instruction.

Rules:
- mealType = breakfast/lunch/dinner/snack
- servingSizeGrams = estimated total weight of that item (in grams)
- calories = integer kcal for the full serving
- protein/carbs/fat/fiber/sugar = grams for the full serving
- sodium = mg for the full serving
- calcium/iron/vitaminC = mg for the full serving — estimate from the typical nutrient content of the dish. If you cannot estimate a value, output 0.
- Indian household serving sizes. Use quantity if specified, otherwise typical single serving.
- IMPORTANT: Use realistic home-cooked Indian portion sizes, not restaurant mega-serves (a katori of dal ~150-200g cooked, one roti ~40g, one bowl of rice ~200g cooked). Keep total meal calories plausible.
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

  /// Test seam for the abstain path. The parser is private on purpose — it is
  /// an implementation detail of the request — but the ABSTAIN decision is a
  /// product guarantee, so it needs to be directly testable without a network
  /// call. See test/abstain_path_test.dart.
  @visibleForTesting
  ({List<FoodItem> items, String? mealType, bool unrecognised}) parseForTest(
    String content,
  ) =>
      _parseResponse(content);

  /// Parses the model's answer.
  ///
  /// [unrecognised] is the ABSTAIN signal, and it is the whole point of this
  /// method. Measured on 2026-09-28: when the model is shown a dish it does not
  /// know, it does not say so — it invents a plausible one (uthappam came back
  /// as a different dish, with a confident-looking calorie number). An invented
  /// dish is the one failure a user cannot catch, and a wrong number goes
  /// straight into their diet. Saying "I don't know" is strictly better than a
  /// confident guess, so the model is asked for a confidence and the app is
  /// given a way to abstain.
  ({List<FoodItem> items, String? mealType, bool unrecognised}) _parseResponse(
    String content,
  ) {
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
      // The model may abstain explicitly, or simply return nothing it is sure
      // about. Both mean the same thing to the user: we do not know this dish.
      final abstained = json['unrecognised'] == true;
      if (items.isNotEmpty && !abstained) {
        return (
          items: items
              .whereType<Map<String, dynamic>>()
              .map((e) => FoodItem.fromJson(e))
              .toList(),
          mealType: mealType,
          unrecognised: false,
        );
      }
      return (items: [], mealType: mealType, unrecognised: true);
    }

    return (items: [], mealType: null, unrecognised: true);
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
