import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';

/// Dispute status chip backed by [disputeStatuses] vocabulary (5 states).
class DisputeStatusBadge extends StatelessWidget {
  const DisputeStatusBadge({super.key, required this.status});

  /// The 5-state dispute status vocabulary entry to render.
  final DisputeStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(tone: status.tone, label: status.label);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tone, required this.label});

  final DisputeStatusTone tone;
  final String label;

  (Color, Color) _resolve(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    switch (tone) {
      case DisputeStatusTone.warning:
        return (ext.warningContainer, ext.onWarningContainer);
      case DisputeStatusTone.info:
        return (colors.primaryContainer, colors.onPrimaryContainer);
      case DisputeStatusTone.success:
        return (ext.successContainer, ext.onSuccessContainer);
      case DisputeStatusTone.neutral:
        return (colors.surfaceContainerHighest, colors.onSurfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = _resolve(context);
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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