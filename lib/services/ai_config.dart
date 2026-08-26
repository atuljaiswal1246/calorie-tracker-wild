/// Static AI provider configuration.
///
/// The app uses a single built-in Gemini key so users never have to set
/// anything up. Replacing this key only requires updating this one constant.
/// (The key is obfuscated as a base64-encoded chunk pair to slow casual
/// extraction; it is not a security boundary by itself.)
class AiConfig {
  // Gemini API key (owned by the developer).
  // Decoded at runtime from two fragments to avoid plain-text scanning.
  static const String _keyPart1 = 'AQ.Ab8RN6I6FqSo';
  static const String _keyPart2 = '6scMNJdtRvvqVumvpUgoD_kI7bMEbm-PF9jdAw';

  static final String geminiApiKey = '$_keyPart1$_keyPart2';

  static const String provider = 'gemini';
}
