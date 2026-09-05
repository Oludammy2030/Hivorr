import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// Frozen-state banner shown on a disputed escrow (EP-02-14 §5.6 / FV-41).
///
/// Rendered **only** when `escrow.status == 'disputed'` (the caller decides).
/// Uses `colorScheme.errorContainer`; every action underneath must be disabled
/// (`onPressed: null`) — the client reflects the server hold and never claims
/// to be the enforcement (DV-06).
class EscrowDisputeBanner extends StatelessWidget {
  const EscrowDisputeBanner({
    super.key,
    this.onViewDispute,
  });

  /// Routes to the EP-02-05 dispute screen. May be `null` to hide the action.
  final VoidCallback? onViewDispute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.gavel, color: colors.onErrorContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'In dispute — all actions frozen until resolved',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
                if (onViewDispute != null) ...[
                  const SizedBox(height: 4),
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