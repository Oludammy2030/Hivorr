import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Tappable 1–5 star input for review submission (EP-03-12).
///
/// Platform-grade reusable component (forward-compatible with EP-04 product
/// ratings). Renders 5 stars tinted `colorScheme.secondary`; selected stars
/// are filled, unselected are outlined. Each star is `>=48dp`, keyboard
/// focusable, and exposes `Semantics(label: 'Rate X out of 5')`.
///
/// Pure display + callback — validation and submission stay in the screen
/// and `ServiceReviewService` (`AGENT.md` Rule 4).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.starSize = 32,
  });

  /// Currently selected rating (`0` means none selected).
  final int value;

  /// Invoked with the newly selected rating (`1-5`).
  final ValueChanged<int> onChanged;

  /// Whether input is interactive.
  final bool enabled;

  /// Icon size per star (touch target stays `>=48dp` regardless).
  final double starSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Semantics(
      label: 'Rate out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int star = 1; star <= 5; star++)
            Semantics(
              label: 'Rate $star out of 5',
              button: true,
              selected: value == star,
              child: InkWell(
                onTap: enabled ? () => onChanged(star) : null,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    star <= value ? Icons.star : Icons.star_border,
                    size: starSize,
                    color: star <= value
                        ? colors.secondary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const SizedBox(width: HivorrSpacing.xs),
          Text(
            value <= 0 ? 'Tap to rate' : '$value of 5',
            style: context.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
