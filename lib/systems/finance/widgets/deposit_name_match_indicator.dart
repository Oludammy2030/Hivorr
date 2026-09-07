import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';

/// Compact chip surfacing a deposit's server-computed name-match status
/// (EP-02-16).
///
/// Labels map to [DepositNameMatchStatus.displayLabel]: Unverified / Pending /
/// Verified / Failed. Uses only [AppTheme] tokens (AGENT.md Rule 5).
class DepositNameMatchIndicator extends StatelessWidget {
  const DepositNameMatchIndicator({super.key, required this.status});

  final DepositNameMatchStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final Color background;
    final Color foreground;
    final IconData icon;
    switch (status) {
      case DepositNameMatchStatus.matched:
        background = ext.successContainer;
        foreground = ext.onSuccessContainer;
        icon = Icons.verified_outlined;
      case DepositNameMatchStatus.mismatched:
        background = colors.errorContainer;
        foreground = colors.onErrorContainer;
        icon = Icons.gpp_bad_outlined;
      case DepositNameMatchStatus.pending:
        background = ext.warningContainer;
        foreground = ext.onWarningContainer;
        icon = Icons.hourglass_top;
      case DepositNameMatchStatus.unverified:
        background = colors.surfaceContainerHighest;
        foreground = colors.onSurfaceVariant;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: HivorrSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: HivorrSpacing.xs),
          Text(
            'Match: ${status.displayLabel}',
            style: context.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
