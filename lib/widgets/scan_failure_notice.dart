/// The line a user reads when a scan cannot finish.
///
/// Extracted from `capture_screen.dart` on 2026-09-28 for ONE reason, and the
/// reason is a gap I found in my own fix: `lib/services/scan_failure.dart` is a
/// pure library and every branch of it is unit-tested, but nothing proved the
/// SCREEN SHOWED the mapped message. The catch block assigned `_error` and a bare
/// `Text(_error!)` rendered it, so the whole chain rested on a line nobody read.
/// That is the shape this repo keeps paying for: a gate that cannot read what the
/// reader reads, tested at the layer where it is convenient rather than where it
/// is used.
///
/// A component can be pumped in a test with no plugins and no camera, so what the
/// user sees is now something a test can actually look at. The message still comes
/// from `scanFailureMessage(classifyScanFailure(raw))` — this widget does not
/// decide anything, it only makes the decision VISIBLE.
///
/// Deliberately unchanged visually: same padding, colour, radius and the same two
/// buttons, so the existing capture golden does not move for a refactor.
library;

import 'package:flutter/material.dart';

import '../services/scan_failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class ScanFailureNotice extends StatelessWidget {
  const ScanFailureNotice({
    super.key,
    required this.rawError,
    required this.onRetry,
    required this.onEnterManually,
  });

  /// The RAW error — an exception's `toString()`. Taking the raw string and
  /// classifying it here is the point: a test can then pass `Exception('AI
  /// request failed (402): ...')` and assert on what a user would read, rather
  /// than asserting that a classification function returns an enum.
  final String rawError;

  final VoidCallback onRetry;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final message = scanFailureMessage(classifyScanFailure(rawError));
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(color: AppColors.missedRed, fontSize: AppType.body),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEnterManually,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.missedRed,
                    side: BorderSide(color: AppColors.missedRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  child: const Text('Enter manually'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.missedRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  child: const Text('Try again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
