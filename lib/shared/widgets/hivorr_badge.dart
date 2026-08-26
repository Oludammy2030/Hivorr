import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Semantic color variants for [HivorrBadge].
enum HivorrBadgeVariant {
  success,
  error,
  warning,
  info,
}

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
