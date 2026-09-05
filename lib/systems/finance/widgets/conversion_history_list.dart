import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/helpers/conversion_formatter.dart';

/// Reverse-chronological conversion history (EP-02-15 §5.4).
///
/// Renders each executed conversion with give→receive amounts, the applied
/// rate, a timestamp, and a lifecycle status chip. Uses only [AppTheme] tokens
/// (AGENT.md Rule 5). Shows a branded empty state while there is no history.
class ConversionHistoryList extends StatelessWidget {
  const ConversionHistoryList({super.key, required this.history});

  /// Ordered (newest-first) conversion history from the provider.
  final List<CurrencyConversion> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const HivorrEmptyState(
        icon: Icon(Icons.swap_horiz),
        title: 'No conversions yet',
        subtitle:
            'Convert between your supported balances and the history will appear here.',
      );
    }
    return Column(
      children: <Widget>[
        for (final CurrencyConversion conversion in history)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: _ConversionHistoryTile(conversion: conversion),
          ),
      ],
    );
  }
}

class _ConversionHistoryTile extends StatelessWidget {
  const _ConversionHistoryTile({required this.conversion});

  final CurrencyConversion conversion;

  @override
  Widget build(BuildContext context) {
    final String from = BalanceFormatter.formatBalance(
      conversion.fromAmount,
      conversion.fromCurrency,
    );
    final String to = BalanceFormatter.formatBalance(
      conversion.toAmount,
      conversion.toCurrency,
    );
    final String rate = ConversionFormatter.rate(
      conversion.exchangeRate,
      fromCurrency: conversion.fromCurrency,
      toCurrency: conversion.toCurrency,
    );
    return HivorrCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.swap_horiz, color: context.colorScheme.primary),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$from \u2192 $to', style: context.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '$rate \u00B7 ${HivorrFormatters.dateTime(conversion.createdAt)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          _ConversionStatusChip(status: conversion.status),
        ],
      ),
    );
  }
}

class _ConversionStatusChip extends StatelessWidget {
  const _ConversionStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final Color background;
    final Color foreground;
    final String label;
    switch (status) {
      case 'completed':
        background = ext.successContainer;
        foreground = ext.onSuccessContainer;
        label = 'Completed';
      case 'failed':
        background = colors.errorContainer;
        foreground = colors.onErrorContainer;
        label = 'Failed';
      default:
        background = ext.infoContainer;
        foreground = ext.onInfoContainer;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}