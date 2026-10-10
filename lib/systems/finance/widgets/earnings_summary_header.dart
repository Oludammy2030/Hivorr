import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Server-verified earnings summary header (EP-03-16).
///
/// Renders Available / In escrow (held) / Lifetime earned as [HivorrStatCard]
/// metrics plus a `Server-verified` caption. Every figure is server-aggregated
/// (see [EarningsSummary]); this widget formats display only and never
/// recomputes settlement. Uses only [AppTheme] tokens (AGENT.md Rule 5).
class EarningsSummaryHeader extends StatelessWidget {
  const EarningsSummaryHeader({super.key, required this.summary});

  /// The server-aggregated summary to render verbatim.
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 600 ? 3 : 2;
            return HivorrStatGrid(
              columns: columns,
              maxWidth: constraints.maxWidth,
              children: <Widget>[
                HivorrStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconBackground: ext.successContainer,
                  iconForeground: ext.onSuccessContainer,
                  label: 'Available',
                  value: BalanceFormatter.formatBalance(
                    summary.availableBalance,
                    summary.currencyCode,
                  ),
                  sub: 'Withdrawable',
                ),
                HivorrStatCard(
                  icon: Icons.lock_outline,
                  iconBackground: colors.primaryContainer,
                  iconForeground: colors.onPrimaryContainer,
                  label: 'In escrow',
                  value: BalanceFormatter.formatBalance(
                    summary.heldBalance,
                    summary.currencyCode,
                  ),
                  sub: 'Held for active work',
                ),
                HivorrStatCard(
                  icon: Icons.trending_up_outlined,
                  iconBackground: colors.secondaryContainer,
                  iconForeground: colors.onSecondaryContainer,
                  label: 'Lifetime earned',
                  value: BalanceFormatter.formatBalance(
                    summary.lifetimeEarned,
                    summary.currencyCode,
                  ),
                  sub: summary.completedContracts == 1
                      ? 'Across 1 contract'
                      : 'Across ${summary.completedContracts} contracts',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Row(
          children: <Widget>[
            Icon(
              Icons.verified_outlined,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: HivorrSpacing.xs),
            Text(
              'Server-verified figures',
              style: context.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
