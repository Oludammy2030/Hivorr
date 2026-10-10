import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/shared/components/hivorr_list_tile.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';

/// Human-readable labels for ledger event types (EP-03-16, display-only).
String earningsTransactionTitle(String type) => switch (type) {
  'escrow_fund' => 'Locked in escrow',
  'escrow_release' => 'Milestone payment',
  'escrow_refund' => 'Escrow refund',
  'deposit' => 'Deposit',
  'withdrawal' => 'Withdrawal',
  'conversion_debit' => 'Conversion sent',
  'conversion_credit' => 'Conversion received',
  'fee' => 'Fee',
  'adjustment' => 'Adjustment',
  _ => 'Activity',
};

/// Single server-projected ledger row for the earnings history (EP-03-16).
///
/// Renders [transaction] verbatim in server order: direction icon, type
/// title, relative timestamp with contract reference, formatted amount, and
/// a frozen badge when the backing escrow is disputed. Taps drill into the
/// attributed contract via [onTap]. Uses only [AppTheme] tokens
/// (AGENT.md Rule 5).
class EarningsTransactionTile extends StatelessWidget {
  const EarningsTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  /// The server-projected row to render.
  final EarningsTransaction transaction;

  /// Drill-down handler (contract detail when attribution exists).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool inbound = transaction.isInbound;
    final IconData icon = transaction.isDisputed
        ? Icons.lock_outline
        : inbound
        ? Icons.arrow_downward_outlined
        : Icons.arrow_upward_outlined;
    final Color iconBackground = transaction.isDisputed
        ? ext.warningContainer
        : inbound
        ? ext.successContainer
        : colors.surfaceContainerHighest;
    final Color iconForeground = transaction.isDisputed
        ? ext.onWarningContainer
        : inbound
        ? ext.onSuccessContainer
        : colors.onSurfaceVariant;
    final String signedValue =
        '${inbound ? '+' : transaction.isOutbound ? '-' : ''}'
        '${BalanceFormatter.formatBalance(transaction.amount, transaction.currencyCode)}';
    // Contract reference via the shared `***last4` helper plus the
    // server-attributed contract status when present (EP-03-16).
    final String? contractRef = transaction.contractId == null
        ? null
        : idRefSuffix(transaction.contractId!);
    final String meta = <String>[
      HivorrFormatters.relative(transaction.createdAt),
      if (contractRef != null) 'Contract $contractRef',
      if (transaction.contractStatus != null &&
          transaction.contractStatus!.isNotEmpty)
        transaction.contractStatus!,
    ].join(' · ');
    return Semantics(
      label:
          '${earningsTransactionTitle(transaction.type)} $signedValue, $meta',
      child: HivorrListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
          child: Icon(icon, size: 20, color: iconForeground),
        ),
        title: earningsTransactionTitle(transaction.type),
        subtitle: meta,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(signedValue, style: context.textTheme.titleSmall),
            if (transaction.isDisputed)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: HivorrBadge(
                  label: 'Frozen',
                  variant: HivorrBadgeVariant.warning,
                ),
              ),
          ],
        ),
        onTap: transaction.contractId == null ? null : onTap,
      ),
    );
  }
}
