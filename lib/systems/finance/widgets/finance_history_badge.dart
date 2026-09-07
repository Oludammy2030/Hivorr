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
/// mirror + the `financial_deposits` select grant). Uses only [AppTheme]
/// tokens (AGENT.md Rule 5).
class FinanceHistoryBadge extends StatelessWidget {
  const FinanceHistoryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    final int payoutCount =
        context.watch<FinancialPayoutProvider>().accounts.length;
    final int depositCount =
        context.watch<FinancialDepositProvider>().deposits.length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: HivorrSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.history, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: HivorrSpacing.sm),
          Text('Activity', style: context.textTheme.labelMedium),
          const Spacer(),
          _CountChip(label: 'payout accounts', count: payoutCount),
          const SizedBox(width: HivorrSpacing.sm),
          _CountChip(label: 'deposits', count: depositCount),
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