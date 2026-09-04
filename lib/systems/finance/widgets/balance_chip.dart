import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Per-currency balance chip variant used in the balance overview (EP-02-13 §5.6).
enum BalanceChipKind {
  available,
  held,
  pending,
}

/// A single balance chip displaying an amount with its semantic color (EP-02-13).
///
/// Available → `successContainer`, Held → `primaryContainer`,
/// Pending → `warningContainer`. Uses only [AppTheme] tokens (AGENT.md Rule 5).
class BalanceChip extends StatelessWidget {
  const BalanceChip({
    super.key,
    required this.currencyCode,
    required this.amount,
    required this.kind,
  });

  final String currencyCode;
  final double amount;
  final BalanceChipKind kind;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final Color backgroundColor;
    final Color labelColor;
    final String label;
    switch (kind) {
      case BalanceChipKind.available:
        backgroundColor = ext.successContainer;
        labelColor = ext.onSuccessContainer;
        label = 'Available';
      case BalanceChipKind.held:
        backgroundColor = colors.primaryContainer;
        labelColor = colors.onPrimaryContainer;
        label = 'Held';
      case BalanceChipKind.pending:
        backgroundColor = ext.warningContainer;
        labelColor = ext.onWarningContainer;
        label = 'Pending';
    }

    final String formatted = BalanceFormatter.formatBalance(amount, currencyCode);

    return Semantics(
      label: '$label balance $formatted',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.sm,
          vertical: HivorrSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(ext.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(color: labelColor),
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              formatted,
              style: context.textTheme.titleSmall?.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}
