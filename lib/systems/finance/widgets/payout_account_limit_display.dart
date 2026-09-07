import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Cashout-limit summary surfaced inside the Withdraw tab (EP-02-16).
///
/// Reads the KYC-derived limit from the financial status and renders it with
/// [BalanceFormatter]. Uses only [AppTheme] tokens (AGENT.md Rule 5).
class PayoutAccountLimitDisplay extends StatelessWidget {
  const PayoutAccountLimitDisplay({
    super.key,
    required this.limit,
    required this.currencyCode,
  });

  final double limit;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(
          context.appExtension.radiusSm,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.speed, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Text(
              'Cashout limit',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            BalanceFormatter.formatBalance(limit, currencyCode),
            style: context.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}