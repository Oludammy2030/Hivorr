import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';

/// Escrow lifecycle chip backed by [escrowStatuses] vocabulary (7 states).
class EscrowStatusBadge extends StatelessWidget {
  const EscrowStatusBadge({super.key, required this.status});

  /// The 7-state escrow status vocabulary entry to render.
  final EscrowStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(tone: status.tone, label: status.label);
  }
}

/// Small lifecycle chip for a milestone [status] (3 states).
class MilestoneStatusBadge extends StatelessWidget {
  const MilestoneStatusBadge({super.key, required this.status});

  /// The 3-state milestone status vocabulary entry to render.
  final MilestoneStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(tone: status.tone, label: status.label);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.tone, required this.label});

  final EscrowStatusTone tone;
  final String label;

  (Color, Color) _resolve(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    switch (tone) {
      case EscrowStatusTone.warning:
        return (ext.warningContainer, ext.onWarningContainer);
      case EscrowStatusTone.info:
        return (ext.infoContainer, ext.onInfoContainer);
      case EscrowStatusTone.success:
        return (ext.successContainer, ext.onSuccessContainer);
      case EscrowStatusTone.primary:
        return (colors.primaryContainer, colors.onPrimaryContainer);
      case EscrowStatusTone.neutral:
        // `surfaceContainerHighest` carries the legacy `surfaceVariant`
        // value in this theme (app_colors.dart:87-88), satisfying the DoD's
        // `surfaceVariant` neutral for escrow badges and the milestone
        // `surfaceContainerHighest` spec without a deprecated API call.
        return (colors.surfaceContainerHighest, colors.onSurfaceVariant);
      case EscrowStatusTone.danger:
        return (colors.errorContainer, colors.onErrorContainer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = _resolve(context);
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
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