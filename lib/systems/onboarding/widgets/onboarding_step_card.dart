import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Step summary card: icon + title + description + completion state
/// (EP-02-18 FV-36). Spacing/radius come from [AppThemeExtension]
/// (VISUAL-IDENTITY.md 8pt grid, 16dp cards).
class OnboardingStepCard extends StatelessWidget {
  const OnboardingStepCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.stepNumber,
    this.isDone = false,
    this.isActive = false,
  });

  /// Leading step icon.
  final IconData icon;

  /// Step title.
  final String title;

  /// One-line step description.
  final String description;

  /// Optional step ordinal shown as a trailing chip.
  final int? stepNumber;

  /// Whether the step is complete (trailing check affordance).
  final bool isDone;

  /// Whether this is the current step (primary container highlight).
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final Color background = isActive
        ? colors.primaryContainer
        : colors.surfaceContainerLowest;

    final Color? borderColor = isActive ? colors.primary : null;

    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 28,
            color: isActive || isDone ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.textTheme.titleMedium),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  description,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isDone) ...<Widget>[
            const SizedBox(width: HivorrSpacing.sm),
            Icon(Icons.check_circle, color: colors.primary, size: 20),
          ] else if (stepNumber != null) ...<Widget>[
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              '$stepNumber',
              style: context.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}