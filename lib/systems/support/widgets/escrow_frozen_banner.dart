import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Frozen-state banner for a disputed escrow (EP-02-17 §5.7).
///
/// Rendered when the linked escrow is `disputed`. Uses
/// `colorScheme.errorContainer` with `Icons.gavel` and the explicit freeze copy;
/// [onViewDispute] routes to `/support/disputes/:id`. Every action underneath
/// the frozen escrow is hidden — the client reflects the server hold and never
/// presents an actionable control on a disputed escrow (EP-02-17 §11).
class EscrowFrozenBanner extends StatelessWidget {
  const EscrowFrozenBanner({
    super.key,
    this.onViewDispute,
  });

  /// Routes to the dispute detail screen. May be `null` to hide the action.
  final VoidCallback? onViewDispute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.gavel, color: colors.onErrorContainer, size: 20),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This escrow is in dispute — all actions are frozen '
                  'until resolved',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
                if (onViewDispute != null) ...[
                  const SizedBox(height: HivorrSpacing.xs),
                  InkWell(
                    onTap: onViewDispute,
                    borderRadius: BorderRadius.circular(ext.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        'View dispute',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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