import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Semantic color variants for [HivorrBadge].
///
/// [neutral] is the non-semantic fallback for values that carry no
/// success/warning/error/info meaning (unknown statuses, raw labels).
/// [primary] covers brand-tinted states (open, shortlisted, categories)
/// that are identity-flavored rather than semantic.
enum HivorrBadgeVariant { success, error, warning, info, neutral, primary }

/// Small status / count indicator tinted with a semantic color from
/// [AppThemeExtension].
class HivorrBadge extends StatelessWidget {
  const HivorrBadge({
    super.key,
    required this.label,
    this.variant = HivorrBadgeVariant.info,
  });

  /// Text shown inside the badge.
  final String label;

  /// Semantic color variant.
  final HivorrBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final ColorScheme colors = context.colorScheme;
    final Color background;
    final Color foreground;
    switch (variant) {
      case HivorrBadgeVariant.success:
        background = ext.successContainer;
        foreground = ext.onSuccessContainer;
      case HivorrBadgeVariant.error:
        background = context.colorScheme.errorContainer;
        foreground = context.colorScheme.onErrorContainer;
      case HivorrBadgeVariant.warning:
        background = ext.warningContainer;
        foreground = ext.onWarningContainer;
      case HivorrBadgeVariant.info:
        background = ext.infoContainer;
        foreground = ext.onInfoContainer;
      case HivorrBadgeVariant.neutral:
        background = colors.surfaceContainerHighest;
        foreground = colors.onSurfaceVariant;
      case HivorrBadgeVariant.primary:
        background = colors.primaryContainer;
        foreground = colors.onPrimaryContainer;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
