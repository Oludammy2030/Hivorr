import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/payout_account.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/models/payout_account_status.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Card for a single bound payout account (EP-02-16).
///
/// Shows currency, bank, masked account number, and the ownership-verification
/// state (the server's `is_verified` + lifecycle `status`). Uses only
/// [AppTheme] tokens (AGENT.md Rule 5).
class PayoutAccountCard extends StatelessWidget {
  const PayoutAccountCard({super.key, required this.account});

  final PayoutAccount account;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final SupportedCurrency? currency = SupportedCurrency.fromCode(
      account.currencyCode,
    );
    final String currencyDisplay = currency != null
        ? '${currency.code} \u2014 ${currency.symbol} ${currency.name}'
        : account.currencyCode;

    final Color verificationColor;
    final String verificationLabel;
    if (account.status == PayoutAccountStatus.deactivated) {
      verificationColor = colors.errorContainer;
      verificationLabel = 'Deactivated';
    } else if (account.isVerified) {
      verificationColor = ext.successContainer;
      verificationLabel = 'Verified';
    } else {
      verificationColor = ext.warningContainer;
      verificationLabel = 'Verification pending';
    }

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
            color: account.isUsable
                ? colors.secondary
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(currencyDisplay, style: context.textTheme.bodyLarge),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  account.bankName,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  'Account ending ${account.maskedAccountNumber}',
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
              color: verificationColor,
              borderRadius: BorderRadius.circular(ext.radiusSm),
            ),
            child: Text(
              verificationLabel,
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
