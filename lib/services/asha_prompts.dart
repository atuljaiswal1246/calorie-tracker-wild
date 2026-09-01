import 'dart:math';

/// Asha's personality: a pool of wild, curious, social-media-grade questions
/// that rotate on the Home card. Every entry is designed for a "wait, what?"
/// screenshot/reel moment.
class AshaPrompts {
  static const _pool = [
    'Do you know Tony Stark ate 5 samosas before the first Iron Man suit test?',
    'In 1969 humanity reached the Moon. You know what else happened? Someone ate a 6th dosa. Wild.',
    'Wait, you haven\'t heard this — chocolate samosa is a real thing. Should I describe the chaos?',
    'My nani says pressure-cooker pani-puri is a war crime. Do you agree?',
    'Einstein loved dal-chawal. Coincidence? Don\'t answer, eat it.',
    'Do you know what 1,000 samosas look like? A problem. Let me tell you about it.',
    'Somewhere in Mumbai someone just put paneer in their maggi and it changed the multiverse.',
    'You can skip breakfast but you can NEVER skip Asha. That\'s science.',
    'Fun fact: every kilo of weight has a khaana plan. Mine is just better.',
    'My uncle ate 3 plates of chole bhature at a wedding. 3. In a row. Respect.',
    'If you log your chai today, I\'ll tell you why Lord Krishna loved makhan (it slipped).',
    'I knew a guy who ate biryani on 137 consecutive days. He\'s the guy right now in the mirror, wait no.',
    'Do you know there\'s a villain who eats salad? Actually no, that\'s too dark.',
    '*screams in diet* — 4 rotis is not a crime if you walk after, okay?',
    'Bhai, Netflix + binge = guilt. Binge + a walk = balance. Do both. I\'ll count it.',
    'Googles "khaana facts"… I found that coconuts have more water than a monsoon. Log some.',
    'Pizza is a yaari. Biryani is a commitment. Chai is a way of life. Pick your vibe.',
    'I once saw a thali so big it had its own postcode. Logged. Logged. Logged.',
    'Do you know what happens when you skip meals? Asha starts crying. Don\'t do this to me.',
    'The protein fairy visited only 3 people today. Let\'s see if you\'re one of them.',
  ];

  /// Returns a deterministic-but-emerging rotation based on time so the
  /// card changes every few seconds without duplicate shows in a row.
  static String next({int? tick}) {
    final i = (tick ?? DateTime.now().millisecondsSinceEpoch ~/ 4000) %
        _pool.length;
    return _pool[i];
  }

  static String get random => _pool[Random().nextInt(_pool.length)];
}
