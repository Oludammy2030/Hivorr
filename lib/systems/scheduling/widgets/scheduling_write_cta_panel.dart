import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Role-gated write-action surface for an appointment detail (EP-03-14 §8
/// D10).
///
/// Mirrors the `ContractWriteCtaPanel` structure (pattern copy, not a
/// generalization — contract labels stay contract-specific per EP-03-10).
/// When [writeAvailable] is `false` (non-participant, non-`active` contract,
/// or terminal appointment), it renders a support guidance card instead of
/// buttons so reads stay functional and the user is never surprised by a
/// dead-end control. When `true`, it renders exactly the caller-supplied
/// role actions as [HivorrButton]s — visibility is decided by the caller from
/// the authoritative row (`canReschedule/canCancel` view-intent hints);
/// enforcement stays server-side (`AGENT.md` Rule 4).
class SchedulingWriteCtaPanel extends StatelessWidget {
  const SchedulingWriteCtaPanel({
    super.key,
    required this.writeAvailable,
    this.onReschedule,
    this.onCancel,
    this.onBookAnother,
    this.onFileDispute,
    this.onContactSupport,
    this.guidanceMessage,
    this.isBusy = false,
  });

  /// Whether role actions apply (`false` → guidance card).
  final bool writeAvailable;

  /// Marks the currently in-flight action as loading.
  final bool isBusy;

  /// Optional guidance text for the unavailable state.
  final String? guidanceMessage;

  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onBookAnother;
  final VoidCallback? onFileDispute;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    if (!writeAvailable) {
      return _SupportGuidanceCard(
        message: guidanceMessage,
        onFileDispute: onFileDispute,
        onContactSupport: onContactSupport,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (onReschedule != null) ...[
          HivorrButton(
            label: 'Reschedule',
            onPressed: onReschedule,
            variant: HivorrButtonVariant.primary,
            isExpanded: true,
            isLoading: isBusy,
          ),
          const SizedBox(height: 8),
        ],
        if (onCancel != null) ...[
          HivorrButton(
            label: 'Cancel appointment',
            onPressed: onCancel,
            variant: HivorrButtonVariant.outline,
            isExpanded: true,
            isLoading: isBusy,
          ),
          const SizedBox(height: 8),
        ],
        if (onBookAnother != null) ...[
          HivorrButton(
            label: 'Book another time',
            onPressed: onBookAnother,
            variant: HivorrButtonVariant.secondary,
            isExpanded: true,
          ),
          const SizedBox(height: 8),
        ],
        if (onFileDispute != null) ...[
          HivorrButton(
            label: 'File dispute',
            onPressed: onFileDispute,
            variant: HivorrButtonVariant.text,
            isExpanded: true,
          ),
        ],
      ],
    );
  }
}

class _SupportGuidanceCard extends StatelessWidget {
  const _SupportGuidanceCard({
    this.message,
    this.onFileDispute,
    this.onContactSupport,
  });

  final String? message;
  final VoidCallback? onFileDispute;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message ??
                'This appointment can no longer be changed. Contact support if you need help.',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (onFileDispute != null)
            HivorrButton(
              label: 'File dispute',
              onPressed: onFileDispute,
              variant: HivorrButtonVariant.outline,
              isExpanded: true,
            ),
          if (onContactSupport != null) ...[
            const SizedBox(height: 8),
            HivorrButton(
              label: 'Contact support',
              onPressed: onContactSupport,
              variant: HivorrButtonVariant.text,
              isExpanded: true,
            ),
          ],
        ],
      ),
    );
  }
}
