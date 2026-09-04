import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/currency_account.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Per-currency account card showing activation status and bank details (EP-02-13 §5.6).
///
/// Uses only [AppTheme] tokens (AGENT.md Rule 5) — no hardcoded colors or fonts.
class CurrencyAccountCard extends StatelessWidget {
  const CurrencyAccountCard({
    super.key,
    required this.account,
    this.guidanceMessage,
  });

  final CurrencyAccount account;

  /// Activation guidance for a pending account (e.g. "Connect NGN via
  /// Paystack"), resolved by `FinancialRepository.requestAccountActivation`.
  /// Falls back to a generic per-currency message when `null`.
  final String? guidanceMessage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final Color statusColor;
    final String statusLabel;
    switch (account.accountStatus) {
      case 'active':
        statusColor = ext.successContainer;
        statusLabel = 'Active';
      case 'pending':
        statusColor = ext.warningContainer;
        statusLabel = 'Pending';
      case 'suspended':
        statusColor = ext.warningContainer;
        statusLabel = 'Suspended';
      default:
        statusColor = colors.surfaceContainerHighest;
        statusLabel = 'Closed';
    }

    final SupportedCurrency? currency =
        SupportedCurrency.fromCode(account.currencyCode);
    final String currencyDisplay = currency != null
        ? '${currency.code} \u2014 ${currency.symbol} ${currency.name}'
        : account.currencyCode;

    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_balance,
            size: 24,
            color: account.isActive ? colors.secondary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(currencyDisplay, style: context.textTheme.bodyLarge),
                if (account.receivingBankName != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.xs),
                  Text(
                    account.receivingBankName!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (account.isActive && account.receivingAccountNumber != null)
                  Text(
                    'Account ending ${account.receivingAccountNumber}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if (account.isPending)
                  Text(
                    guidanceMessage ??
                        'Connect your ${account.currencyCode} bank account to start receiving',
                    style: context.textTheme.bodySmall?.copyWith(
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
              color: statusColor,
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
