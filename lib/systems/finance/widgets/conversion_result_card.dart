import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/currency_conversion.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Post-execution success confirmation (EP-02-15 §5.7, FV-43).
///
/// Renders only for the most recent completed conversion: the authoritative
/// `toAmount` (server-computed, never the local estimate), the reference
/// (`conversionId`), and a jump-to-history affordance. Uses `successContainer`
/// tokens — no raw color tokens or hex values (AGENT.md Rule 5).
class ConversionResultCard extends StatelessWidget {
  const ConversionResultCard({
    super.key,
    required this.conversion,
    this.onViewHistory,
  });

  /// The most recent executed conversion.
  final CurrencyConversion conversion;

  /// Scrolls to the history section when provided.
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final String from = BalanceFormatter.formatBalance(
      conversion.fromAmount,
      conversion.fromCurrency,
    );
    final String to = BalanceFormatter.formatBalance(
      conversion.toAmount,
      conversion.toCurrency,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ext.successContainer,
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.check_circle_outline, color: ext.onSuccessContainer),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Conversion complete',
                      style: context.textTheme.titleSmall?.copyWith(
                        color: ext.onSuccessContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$from \u2192 $to',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: ext.onSuccessContainer,
                      ),
                    ),
                    Text(
                      'Reference: ${conversion.id}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: ext.onSuccessContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onViewHistory != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: ext.onSuccessContainer,
                ),
                onPressed: onViewHistory,
                child: const Text('View history'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}