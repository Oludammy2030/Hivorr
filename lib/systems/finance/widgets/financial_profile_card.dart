import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/financial_profile.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Profile header card showing default currency and status (EP-02-13 §5.6).
///
/// Uses only [AppTheme] tokens (AGENT.md Rule 5) — no hardcoded colors or fonts.
class FinancialProfileCard extends StatelessWidget {
  const FinancialProfileCard({
    super.key,
    required this.profile,
  });

  final FinancialProfile profile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final Color statusColor;
    final String statusLabel;
    switch (profile.status) {
      case 'active':
        statusColor = ext.successContainer;
        statusLabel = 'Active';
      case 'suspended':
        statusColor = ext.warningContainer;
        statusLabel = 'Suspended';
      default:
        statusColor = colors.surfaceContainerHighest;
        statusLabel = 'Closed';
    }

    final SupportedCurrency? currency =
        SupportedCurrency.fromCode(profile.defaultCurrency);
    final String currencyDisplay = currency != null
        ? '${currency.symbol} ${currency.name}'
        : profile.defaultCurrency;

    return Container(
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 32,
            color: colors.primary,
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Financial Profile',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'Default: $currencyDisplay',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.sm,
              vertical: HivorrSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ext.radiusSm),
            ),
            child: Text(
              statusLabel,
              style: context.textTheme.labelSmall?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
