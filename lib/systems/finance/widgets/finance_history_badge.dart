import 'package:flutter/material.dart';

import 'package:hivorr/data/providers/financial_deposit_provider.dart';
import 'package:hivorr/data/providers/financial_payout_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:provider/provider.dart';

/// Compact account-activity summary showing the count of bound payout accounts
/// and recorded deposits (EP-02-16 §5.6 — the "history badge").
///
/// Derived entirely from RLS-readable, self-scoped data (the local payout
/// mirror + the `financial_deposits` select grant). When [ledgerCount] is
/// provided (EP-03-16), a third chip surfaces the loaded server-ledger row
/// count alongside — display-only, never a settlement figure. Uses only
/// [AppTheme] tokens (AGENT.md Rule 5).
class FinanceHistoryBadge extends StatelessWidget {
  const FinanceHistoryBadge({super.key, this.ledgerCount, this.ledgerLabel});

  /// Loaded server-ledger rows to surface (`null` hides the ledger chip,
  /// preserving the EP-02-16 two-chip layout at existing call sites).
  final int? ledgerCount;

  /// Ledger chip label override (defaults to `ledger entries`).
  final String? ledgerLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    final int payoutCount = context
        .watch<FinancialPayoutProvider>()
        .accounts
        .length;
    final int depositCount = context
        .watch<FinancialDepositProvider>()
        .deposits
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: HivorrSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.history, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: HivorrSpacing.sm),
              Text('Activity', style: context.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          // Wrap (not Row): the EP-03-16 ledger chip joins the payout and
          // deposit chips, and narrow phones must flow instead of overflow.
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              _CountChip(label: 'payout accounts', count: payoutCount),
              _CountChip(label: 'deposits', count: depositCount),
              if (ledgerCount != null)
                _CountChip(
                  label: ledgerLabel ?? 'ledger entries',
                  count: ledgerCount!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: HivorrSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.appExtension.radiusSm),
      ),
      child: Text(
        '$count $label',
        style: context.textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
