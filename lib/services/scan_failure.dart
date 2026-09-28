/// What a user is told when a scan cannot complete — and what is retried.
///
/// Extracted from `capture_screen.dart` on 2026-09-28 so it can be TESTED. It was
/// a private static method taking a raw exception string, which is why two of
/// its worst properties were invisible: nobody could enumerate the status codes
/// it handled, and nobody could notice the messages it produced.
///
/// TWO REAL DEFECTS, both live, both found while the tiers were MONEY BLOCKED —
/// which is exactly the condition a user hits the day we have no provider budget.
///
/// 1. IT SENT USERS TO A SETTINGS FIELD THAT DOES NOT EXIST.
///    On a 403 the app said: "Invalid API key. Go to Settings and check your key."
///    There is no key in Settings. There is no key anywhere in the app — §0 rule
///    2 removed it deliberately, and `test/no_provider_keys_test.dart` fails if
///    one ever comes back. So the one message that tells a user to fix something
///    was pointing at nothing. A user who saw it would hunt through Settings,
///    find nothing, and conclude the app is broken. It blamed the user for a
///    fault that is ours.
///
/// 2. A 402 — "we have no money for this provider" — FELL THROUGH TO
///    "Something went wrong. Please try again." That is our own billing state
///    being reported to the user as their mistake, with no information and no
///    way to act. A 402 is not the user's problem, and the app must never imply
///    that it is.
///
/// AND THE RETRY WAS TOLD TO RETRY IT. `analyzeImage` made three attempts two
/// seconds apart for ANY exception, so a guaranteed-to-fail payment error cost
/// the user four seconds of staring at a spinner and hit the Worker three times.
/// Retrying is for things that might succeed on the second try. A 402 is a
/// decision, not a hiccup.
///
/// The rules that come out of this:
///   - never name a cause the user cannot act on, and never send them somewhere
///     that does not exist;
///   - never tell a user about our money, our quota or our providers;
///   - retry only what can plausibly succeed on a second attempt.
library;

/// Why a scan did not complete. Named, because "the network was sad" and "we
/// cannot pay for this right now" need different words and the same silence.
enum ScanFailure {
  /// No route to the network at all.
  offline,

  /// The provider is rate-limiting. Worth waiting out.
  busy,

  /// WE have no budget / the upstream refused for money reasons. Never the
  /// user's fault and never something they can fix.
  noBudget,

  /// The upstream is broken on our side.
  upstreamDown,

  /// The image itself could not be read or was unusable.
  badImage,

  /// The request took too long.
  timedOut,

  /// Anything we have not classified. Never a raw upstream string.
  unknown,
}

/// Classify a failure. Pure, so every branch is reachable from a test.
///
/// The order matters: the money branch is checked BEFORE the generic HTTP-code
/// branches, because "402" and "quota" both appear in upstream error bodies and
/// a quota message is about our account, not the user's rate limit.
ScanFailure classifyScanFailure(String raw) {
  final s = raw.toLowerCase();

  // MONEY FIRST. A 402 is our billing state. It must never be reported as the
  // user's quota, their rate limit, or a transient blip.
  if (s.contains('402') ||
      s.contains('payment required') ||
      s.contains('insufficient_quota') ||
      s.contains('insufficient balance') ||
      s.contains('no funds') ||
      s.contains('exceeded your current quota')) {
    return ScanFailure.noBudget;
  }

  if (s.contains('sockethostlookup') ||
      s.contains('sockexception') ||
      s.contains('connection reset') ||
      s.contains('connection refused') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable')) {
    return ScanFailure.offline;
  }

  if (s.contains('429') ||
      s.contains('rate limit') ||
      s.contains('too many requests')) {
    return ScanFailure.busy;
  }

  if (s.contains('500') ||
      s.contains('502') ||
      s.contains('503') ||
      s.contains('504') ||
      s.contains('bad gateway') ||
      s.contains('service unavailable')) {
    return ScanFailure.upstreamDown;
  }

  if (s.contains('timeout') || s.contains('timed out')) {
    return ScanFailure.timedOut;
  }

  if (s.contains('could not find') ||
      s.contains('unable to decode') ||
      s.contains('invalid image') ||
      s.contains('unsupported image')) {
    return ScanFailure.badImage;
  }

  return ScanFailure.unknown;
}

/// Should this failure be retried automatically?
///
/// Only what can plausibly succeed unchanged on a second attempt. A 402 cannot:
/// we are out of money and a second identical request spends nothing and
/// succeeds never. Retrying it made a user stare at a spinner for four seconds
/// to be told, eventually, the same thing.
bool shouldRetryScan(ScanFailure failure) {
  switch (failure) {
    case ScanFailure.offline:
    case ScanFailure.busy:
    case ScanFailure.upstreamDown:
    case ScanFailure.timedOut:
      return true;
    case ScanFailure.noBudget:
    case ScanFailure.badImage:
    case ScanFailure.unknown:
      return false;
  }
}

/// The one line the user reads.
///
/// Constraints this function exists to hold, each of them a past defect:
///   - no mention of an API key (the app has none, and never will);
///   - no instruction to go to a screen that does not have the thing;
///   - no mention of quota, billing, providers or money — that is ours;
///   - no blame, and no shame. The house rule: the user did nothing wrong.
String scanFailureMessage(ScanFailure failure) {
  switch (failure) {
    case ScanFailure.offline:
      return 'No internet connection. Check your WiFi or mobile data.';
    case ScanFailure.busy:
      return 'Scanning is busy right now. Wait a minute and try again.';
    case ScanFailure.noBudget:
      // Ours, plainly, without the finances. "Try again later" is true and is
      // the only action they can take; the absence of a number is deliberate.
      return 'Scanning is unavailable for a moment. Your logged meals are safe '
          '— try again later.';
    case ScanFailure.upstreamDown:
      return 'Scanning is temporarily down. Please try again in a moment.';
    case ScanFailure.timedOut:
      return 'That took too long. Try again, or check your connection.';
    case ScanFailure.badImage:
      return 'Could not read that photo. Try a clearer one.';
    case ScanFailure.unknown:
      return 'Something went wrong. Please try again.';
  }
}
