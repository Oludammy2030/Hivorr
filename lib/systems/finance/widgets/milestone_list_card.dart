import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';
import 'package:hivorr/systems/finance/widgets/escrow_status_badge.dart';

/// Milestone progress card for a single escrow (EP-02-14 §5.6).
///
/// Pure widget: renders one row per milestone (title + amount + status chip),
/// plus a [LinearProgressIndicator] reflecting `releasedTotal / totalAmount`
/// clamped to `0..1` (`0` when nothing is released). Every color/token is
/// resolved from `colorScheme` / [AppThemeExtension] — no hardcoded hex.
class MilestoneListCard extends StatelessWidget {
  const MilestoneListCard({
    super.key,
    required this.milestones,
    required this.totalAmount,
    required this.currencyCode,
  });

  /// The milestones belonging to the escrow, in display order.
  final List<EscrowMilestone> milestones;

  /// The escrow's total funded amount (sum of all milestone amounts).
  final double totalAmount;

  /// Currency code (`NGN`, `GHS`, `USD`, `GBP`) used by the escrow.
  final String currencyCode;

  /// Sum of amounts on milestones with status `released`.
  double get releasedTotal => milestones.fold(
        0.0,
        (double acc, EscrowMilestone m) =>
            acc + (m.isReleased ? m.amount : 0.0),
      );

  /// Progress fraction clamped to `0..1`; `0` when nothing released.
  double get progressValue {
    if (totalAmount <= 0) return 0.0;
    final double ratio = releasedTotal / totalAmount;
    return ratio.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final List<EscrowMilestone> sorted = <EscrowMilestone>[...milestones]
      ..sort((EscrowMilestone a, EscrowMilestone b) =>
          a.sortOrder.compareTo(b.sortOrder));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Milestones', style: context.textTheme.titleSmall),
              Text(
                BalanceFormatter.formatBalance(releasedTotal, currencyCode),
                style: context.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressValue,
            color: colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
            minHeight: 6,
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
          const SizedBox(height: 16),
          for (final EscrowMilestone milestone in sorted)
            _MilestoneRow(
              milestone: milestone,
              currencyCode: currencyCode,
            ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.currencyCode,
  });

  final EscrowMilestone milestone;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final MilestoneStatus? status = MilestoneStatus.forCode(milestone.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${milestone.milestoneNumber}. ${milestone.title}',
                  style: context.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  BalanceFormatter.formatBalance(
                    milestone.amount,
                    currencyCode,
                  ),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (status != null) MilestoneStatusBadge(status: status),
        ],
      ),
    );
  }
}