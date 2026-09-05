import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// Write-action surface for an escrow detail (EP-02-14 §5.6 / FV-40).
///
/// When [writeAvailable] is `false` (production default), it renders a support
/// guidance card instead of buttons — reads stay fully functional and the user
/// is never surprised by a dead-end control (FV-48). When `true` (future edge
/// proxy on), it renders the provider-visible actions as [HivorrButton]s.
/// On a [isDisputed] escrow every action is disabled regardless (FV-47).
class EscrowWriteCtaPanel extends StatelessWidget {
  const EscrowWriteCtaPanel({
    super.key,
    required this.writeAvailable,
    this.isDisputed = false,
    this.onCompleteMilestone,
    this.onReleaseMilestone,
    this.onReleaseFinal,
    this.onRefund,
    this.onContactSupport,
    this.isBusy = false,
  });

  /// Whether the write proxy seam is on (`AppConfig.escrowWriteViaProxyEnabled`).
  final bool writeAvailable;

  /// Whether the escrow is under dispute — disables every action.
  final bool isDisputed;

  /// Marks the currently in-flight action as loading.
  final bool isBusy;

  final VoidCallback? onCompleteMilestone;
  final VoidCallback? onReleaseMilestone;
  final VoidCallback? onReleaseFinal;
  final VoidCallback? onRefund;
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    if (!writeAvailable) {
      return _SupportGuidanceCard(onContactSupport: onContactSupport);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrButton(
          label: 'Complete milestone',
          onPressed: isDisputed ? null : onCompleteMilestone,
          variant: HivorrButtonVariant.primary,
          isExpanded: true,
          isLoading: isBusy,
        ),
        const SizedBox(height: 8),
        HivorrButton(
          label: 'Release milestone',
          onPressed: isDisputed ? null : onReleaseMilestone,
          variant: HivorrButtonVariant.outline,
          isExpanded: true,
        ),
        const SizedBox(height: 8),
        HivorrButton(
          label: 'Release final payment',
          onPressed: isDisputed ? null : onReleaseFinal,
          variant: HivorrButtonVariant.secondary,
          isExpanded: true,
        ),
        const SizedBox(height: 8),
        HivorrButton(
          label: 'Refund escrow',
          onPressed: isDisputed ? null : onRefund,
          variant: HivorrButtonVariant.text,
          isExpanded: true,
        ),
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
          Icon(
            Icons.help_outline,
            color: colors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Escrow actions are handled by our support team',
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Release, refund and dispute actions are processed '
                  'securely by support while self-serve escrow actions are '
                  'being rolled out.',
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