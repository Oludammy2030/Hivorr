import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Role-gated write-action surface for a contract detail (EP-03-10 §8 D10).
///
/// Mirrors the `EscrowWriteCtaPanel` structure (pattern copy, not a
/// generalization — escrow labels stay escrow-specific per EP-02-14
/// `FV-40/47/48`). When [writeAvailable] is `false` (disputed, expired,
/// stranger, or terminal state), it renders a support guidance card instead of
/// buttons so reads stay functional and the user is never surprised by a
/// dead-end control. When `true`, it renders exactly the caller-supplied
/// role actions as [HivorrButton]s — visibility is decided by the caller from
/// the authoritative row (`canAccept/canVerify/...` view-intent hints);
/// enforcement stays server-side (`AGENT.md` Rule 4).
class ContractWriteCtaPanel extends StatelessWidget {
  const ContractWriteCtaPanel({
    super.key,
    required this.writeAvailable,
    this.onAccept,
    this.onCancel,
    this.onCompleteMilestone,
    this.onVerifyMilestone,
    this.onVerifyAndRelease,
    this.onViewEscrow,
    this.onRequestRevision,
    this.onClose,
    this.onFileDispute,
    this.onContactSupport,
    this.isBusy = false,
  });

  /// Whether role actions apply (`false` → guidance card).
  final bool writeAvailable;

  /// Marks the currently in-flight action as loading.
  final bool isBusy;

  final VoidCallback? onAccept;
  final VoidCallback? onCancel;
  final VoidCallback? onCompleteMilestone;
  final VoidCallback? onVerifyMilestone;

  /// Combined client action wired to the EP-03-11 orchestrator
  /// (`verifyAndReleaseMilestone`): verifies a `completed` milestone then
  /// releases its funds through the proxy seam. Rendered only when the
  /// authoritative row is `verified`/`completed` and the caller supplies it;
  /// enforcement stays server-side (`AGENT.md` Rule 4).
  final VoidCallback? onVerifyAndRelease;

  /// Read-only navigation to the linked escrow detail (`/finance/escrow/:id`).
  final VoidCallback? onViewEscrow;
  final VoidCallback? onRequestRevision;
  final VoidCallback? onClose;
  final VoidCallback? onFileDispute;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    if (!writeAvailable) {
      return _SupportGuidanceCard(onContactSupport: onContactSupport);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (onAccept != null) ...[
          HivorrButton(
            label: 'Accept offer',
            onPressed: onAccept,
            variant: HivorrButtonVariant.primary,
            isExpanded: true,
            isLoading: isBusy,
          ),
          const SizedBox(height: 8),
        ],
        if (onCompleteMilestone != null) ...[
          HivorrButton(
            label: 'Mark milestone complete',
            onPressed: onCompleteMilestone,
            variant: HivorrButtonVariant.primary,
            isExpanded: true,
            isLoading: isBusy,
          ),
          const SizedBox(height: 8),
        ],
        if (onVerifyMilestone != null) ...[
          HivorrButton(
            label: 'Verify milestone',
            onPressed: onVerifyMilestone,
            variant: HivorrButtonVariant.primary,
            isExpanded: true,
            isLoading: isBusy,
          ),
          const SizedBox(height: 8),
        ],
        if (onVerifyAndRelease != null) ...[
          HivorrButton(
            label: 'Verify & release',
            onPressed: onVerifyAndRelease,
            variant: HivorrButtonVariant.primary,
            isExpanded: true,
            isLoading: isBusy,
          ),
          const SizedBox(height: 8),
        ],
        if (onViewEscrow != null) ...[
          HivorrButton(
            label: 'View escrow',
            onPressed: onViewEscrow,
            variant: HivorrButtonVariant.outline,
            isExpanded: true,
          ),
          const SizedBox(height: 8),
        ],
        if (onRequestRevision != null) ...[
          HivorrButton(
            label: 'Request revision',
            onPressed: onRequestRevision,
            variant: HivorrButtonVariant.outline,
            isExpanded: true,
          ),
          const SizedBox(height: 8),
        ],
        if (onClose != null) ...[
          HivorrButton(
            label: 'Close contract',
            onPressed: onClose,
            variant: HivorrButtonVariant.secondary,
            isExpanded: true,
          ),
          const SizedBox(height: 8),
        ],
        if (onCancel != null) ...[
          HivorrButton(
            label: 'Cancel contract',
            onPressed: onCancel,
            variant: HivorrButtonVariant.text,
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
  const _SupportGuidanceCard({this.onContactSupport});

  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.help_outline, color: colors.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Contract actions are unavailable right now',
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'This contract cannot be changed in its current state. '
                  'Accept, milestone, and close actions are processed '
                  'securely by the platform when they apply to you.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (onContactSupport != null) ...[
                  const SizedBox(height: 8),
                  HivorrButton(
                    label: 'Contact support',
                    onPressed: onContactSupport,
                    variant: HivorrButtonVariant.outline,
                    size: HivorrButtonSize.small,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
