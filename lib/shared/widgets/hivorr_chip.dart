import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Semantic color variants for [HivorrChip].
enum HivorrChipVariant {
  primary,
  secondary,
  surface,
}

/// Selectable / dismissible chip built from [AppTheme] tokens (AGENT.md Rule 5).
///
/// Selected chips are filled with the variant color; unselected chips show an
/// [ColorScheme.outline] outline. A trailing dismiss affordance is shown when
/// [onDismissed] is provided. Minimum touch target height is 48dp.
class HivorrChip extends StatelessWidget {
  const HivorrChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onSelected,
    this.onDismissed,
    this.variant = HivorrChipVariant.primary,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDismissed;
  final HivorrChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final Color fill;
    final Color border;
    final Color foreground;
    switch (variant) {
      case HivorrChipVariant.primary:
        fill = colors.primary;
        border = colors.primary;
        foreground = colors.onPrimary;
      case HivorrChipVariant.secondary:
        fill = colors.secondary;
        border = colors.secondary;
        foreground = colors.onSecondary;
      case HivorrChipVariant.surface:
        fill = colors.surfaceContainerHighest;
        border = colors.outline;
        foreground = colors.onSurfaceVariant;
    }

    final Color textColor = isSelected ? foreground : colors.onSurfaceVariant;
    final bool tapEnabled = onSelected != null;

    final Widget inner = Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: isSelected ? fill : null,
        border: Border.all(
          color: isSelected ? border : colors.outline,
        ),
        borderRadius: BorderRadius.circular(ext.radiusLg),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: HivorrSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(color: textColor),
          ),
          if (onDismissed != null) ...<Widget>[
            const SizedBox(width: HivorrSpacing.xs),
            InkWell(
              onTap: onDismissed,
              borderRadius: BorderRadius.circular(ext.radiusSm),
              child: Icon(
                Icons.cancel,
                size: 16,
                color: textColor,
              ),
            ),
          ],
        ],
      ),
    );

    final Widget chip = tapEnabled
        ? InkWell(
            onTap: () => onSelected!(!isSelected),
            borderRadius: BorderRadius.circular(ext.radiusLg),
            splashColor: colors.primary.withValues(alpha: 0.12),
            child: inner,
          )
        : inner;

    return Semantics(
      label: label,
      selected: isSelected,
      toggled: tapEnabled,
      child: chip,
    );
  }
}
