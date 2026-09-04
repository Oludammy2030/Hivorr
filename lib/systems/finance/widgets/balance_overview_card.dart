import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/balance.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/widgets/balance_chip.dart';

/// Per-currency balance card displaying available/held/pending chips (EP-02-13 §5.6).
///
/// Uses only [AppTheme] tokens (AGENT.md Rule 5) — no hardcoded colors or fonts.
class BalanceOverviewCard extends StatelessWidget {
  const BalanceOverviewCard({
    super.key,
    required this.balances,
    this.defaultCurrencyCode,
  });

  /// The per-currency balances to display.
  final Map<String, Balance> balances;

  /// The default currency code (highlighted first).
  final String? defaultCurrencyCode;

  @override
  Widget build(BuildContext context) {
    if (balances.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort: default currency first, then alphabetical.
    final entries = balances.entries.toList()
      ..sort((a, b) {
        if (a.key == defaultCurrencyCode) return -1;
        if (b.key == defaultCurrencyCode) return 1;
        return a.key.compareTo(b.key);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Balances',
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: HivorrSpacing.sm),
        ...entries.map((entry) {
          final currency = SupportedCurrency.fromCode(entry.key);
          final label = currency != null
              ? '${currency.symbol} ${currency.name} (${currency.code})'
              : entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Wrap(
                  spacing: HivorrSpacing.sm,
                  runSpacing: HivorrSpacing.xs,
                  children: <Widget>[
                    BalanceChip(
                      currencyCode: entry.key,
                      amount: entry.value.availableBalance,
                      kind: BalanceChipKind.available,
                    ),
                    BalanceChip(
                      currencyCode: entry.key,
                      amount: entry.value.heldBalance,
                      kind: BalanceChipKind.held,
                    ),
                    BalanceChip(
                      currencyCode: entry.key,
                      amount: entry.value.pendingBalance,
                      kind: BalanceChipKind.pending,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
