import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/helpers/conversion_formatter.dart';

/// Displays the trusted rate for the active pair (EP-02-15 §5.4, FV-34).
///
/// The rate is sourced exclusively from the [ConversionRateSource] seam via
/// the [ConversionProvider] — the UI cannot enter or invent a rate. Shows the
/// directed rate (`1 NGN = 0.0007 USD`) plus its guarded inverse, a
/// "platform rate" source label, a loading state while a fetch is in flight,
/// and a "rate unavailable for this pair" error state when the seam has no
/// configured rate for the pair.
class ConversionRateCard extends StatelessWidget {
  const ConversionRateCard({
    super.key,
    required this.rate,
    required this.fromCurrency,
    required this.toCurrency,
    required this.isLoading,
    required this.isUnavailable,
    this.onRetry,
  });

  /// The trusted rate from the seam, or `null` when none is loaded.
  final double? rate;

  /// Source currency code.
  final String? fromCurrency;

  /// Destination currency code.
  final String? toCurrency;

  /// Whether a rate fetch is in flight.
  final bool isLoading;

  /// Whether the pair has no configured rate (fail closed).
  final bool isUnavailable;

  /// Retry callback for the unavailable state.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const HivorrLoadingState(message: 'Fetching rate...');
    }
    if (isUnavailable) {
      return HivorrErrorState(
        message: 'Rate unavailable for this pair',
        detail:
            'No conversion rate is currently available for this currency pair.',
        onRetry: onRetry,
      );
    }

    final bool hasRate =
        rate != null && rate! > 0 && fromCurrency != null && toCurrency != null;
    if (!hasRate) {
      return HivorrCard(
        child: Row(
          children: <Widget>[
            Text('Rate', style: context.textTheme.titleSmall),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Text(
                'Select a pair and an amount to see today\u2019s rate.',
                textAlign: TextAlign.end,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String directed = ConversionFormatter.rate(
      rate!,
      fromCurrency: fromCurrency!,
      toCurrency: toCurrency!,
    );
    final String inverse = ConversionFormatter.rate(
      1 / rate!,
      fromCurrency: toCurrency!,
      toCurrency: fromCurrency!,
    );
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Rate', style: context.textTheme.titleSmall),
              Text(
                directed,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Platform rate',
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                inverse,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}