// The ABSTAIN card, as a widget that can be rendered and looked at.
//
// Extracted 2026-09-28 from capture_screen.dart. Two reasons, both about being
// able to CHECK something:
//
//   1. The card was unreachable in tests. `_unrecognised` was set and then cleared
//      two lines later, so the card could never render - and once that was fixed,
//      the card still could not be rendered by a test, because reaching it meant
//      driving the whole analyse path with a fake image and a fake service. A
//      card nobody has ever seen rendered is a card nobody has ever looked at.
//   2. The quiet rule it encodes is now visible in one place: an abstention is a
//      NORMAL outcome, so it is not styled as an error. A red box would teach the
//      user that the app is broken, which is exactly the lesson to avoid when the
//      app is behaving correctly.

import 'package:calorie_tracker/theme/app_colors.dart';
import 'package:calorie_tracker/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Shown when the model declines to name the dish. Offers the keyboard instead
/// of logging a number the user cannot verify.
class AbstainCard extends StatelessWidget {
  const AbstainCard({
    super.key,
    required this.onNameDish,
    required this.onScanAgain,
  });

  /// Open the add-item flow so the user can type the dish and have it looked up.
  final VoidCallback onNameDish;

  /// Dismiss and go back to the camera, without changing anything.
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "I don't recognise this dish",
            style: TextStyle(
              fontSize: AppType.title,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Better an honest "I don\'t know" than a number that is quietly '
            'wrong. Type the name and we\'ll find the calories.',
            style: TextStyle(
              fontSize: AppType.body,
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onNameDish,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('Name the dish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onScanAgain,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text('Scan again'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
