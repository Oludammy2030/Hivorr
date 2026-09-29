import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/jobs/models/job_status.dart';

/// Status badge for job/application/quotation/hire codes (EP-04-03).
///
/// Maps [HiringStatusTone] to theme containers: success/info/warning/critical
/// from [AppThemeExtension], neutral from the surface container. Never
/// hardcodes colors (AGENT.md Rule 5).
class HiringStatusBadge extends StatelessWidget {
  const HiringStatusBadge({super.key, required this.code});

  /// The server status code.
  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final HiringStatus? entry = HiringStatus.forCode(code);

    final Color background;
    final Color foreground;
    switch (entry?.tone) {
      case HiringStatusTone.success:
        background = ext.successContainer;
        foreground = ext.onSuccessContainer;
      case HiringStatusTone.info:
        background = ext.infoContainer;
        foreground = ext.onInfoContainer;
      case HiringStatusTone.warning:
        background = ext.warningContainer;
        foreground = ext.onWarningContainer;
      case HiringStatusTone.critical:
        background = colors.errorContainer;
        foreground = colors.onErrorContainer;
      case HiringStatusTone.neutral:
      case null:
        background = colors.surfaceContainerHighest;
        foreground = colors.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        entry?.label ?? code,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
