import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/service_dispute_contract_summary.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';

/// Service-engagement context card for dispute detail surfaces (EP-03-17).
///
/// Read-only summary of the disputed engagement (listing title, total,
/// status, escrow linkage) shared by the participant
/// `DisputeDetailScreen` and the Admin-shell dispute detail. Navigation is
/// injected via [onViewContract]/[onViewEscrow] so each host owns its route
/// table; `onViewEscrow` is hidden when `null` (unfunded engagements).
/// Tokens only — no hardcoded colors, no per-widget fonts.
class DisputeContractCard extends StatelessWidget {
  const DisputeContractCard({
    super.key,
    required this.summary,
    this.onViewContract,
    this.onViewEscrow,
  });

  final ServiceDisputeContractSummary summary;

  /// Routes to the disputed engagement. `null` hides the action.
  final VoidCallback? onViewContract;

  /// Routes to the frozen escrow. `null` hides the action.
  final VoidCallback? onViewEscrow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  summary.listingTitle ?? 'Service contract',
                  style: context.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              ContractStatusBadge(status: summary.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            BalanceFormatter.formatBalance(
              summary.totalAmount,
              summary.currencyCode,
            ),
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            summary.isFunded
                ? 'Escrow ${idRefSuffix(summary.escrowId!)}'
                : 'Funding pending — contract frozen without an escrow hold.',
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (onViewContract != null || onViewEscrow != null) ...[
            const SizedBox(height: HivorrSpacing.sm),
            Wrap(
              spacing: HivorrSpacing.sm,
              children: <Widget>[
                if (onViewContract != null)
                  TextButton(
                    onPressed: onViewContract,
                    child: const Text('View contract'),
                  ),
                if (onViewEscrow != null)
                  TextButton(
                    onPressed: onViewEscrow,
                    child: const Text('View escrow'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
