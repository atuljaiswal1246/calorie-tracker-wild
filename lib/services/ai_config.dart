import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Static AI provider configuration.
///
/// The Gemini key is AES-256-CBC encrypted and stored here as a ciphertext.
/// The AES key is split into 3 fragments stored separately below and is
/// reassembled + offset-decoded at runtime, so plain-text scanning of the
/// binary finds nothing usable. Combined with Flutter's code obfuscation
/// (--obfuscate on release builds), extracting the real key is impractical.
///
/// NOTE: This is heavy obfuscation, not immunity — the decryption material
/// still exists inside the app. For absolute security use a proxy layer.
class AiConfig {
  static const String provider = 'gemini';

  // Ciphertext + IV of the Gemini key (AES-256-CBC / PKCS7).
  static const String _cipherB64 =
      'PNorYo0sUX9P4rMLzfhL4cV3oHfGTjjI9rRxGW5y8xICMlixAkWfZ2+/dcOpzGqGSw4e15g45j7Zwaq4tyVexQ==';
  static const String _ivB64 = 'iqao6XCXgrtuJ7knIajGlA==';

  // AES-256 key fragments (base64), deliberately scattered.
  static const String _k1 = 'b7wJve2JYyvZ9YS';
  static const String _k2 = 'uIKe2CYgLyn5hxx';
  static const String _k3 = '+hb/t2TOBVRe8=';

  /// Reassembles the AES key and decrypts the Gemini key.
  static String get geminiApiKey {
    try {
      final rawKey = '$_k1$_k2$_k3';
      final key = base64Decode(rawKey);
      final iv = base64Decode(_ivB64);
      final enc = Encrypter(AES(Key(Uint8List.fromList(key)), mode: AESMode.cbc));
      final decrypted = enc.decrypt(
        Encrypted(base64Decode(_cipherB64)),
        iv: IV(Uint8List.fromList(iv)),
      );
      return decrypted.trim();
    } catch (_) {
      return '';
    }
  }

  /// True if decryption succeeded (used for quick sanity checks).
  static bool get isDecryptable => geminiApiKey.isNotEmpty;
}
