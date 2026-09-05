import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Currency-pair selector for the conversion form (EP-02-15 §5.4).
///
/// Renders "From" and "To" chip groups using [HivorrChip] (DoD: currency
/// picker built from chips/dropdown). Self-pairs are prevented by the parent
/// screen (swapping the other leg); the repository still rejects them with
/// `PLT003` as the enforcement backstop.
class ConversionPairSelector extends StatelessWidget {
  const ConversionPairSelector({
    super.key,
    required this.fromCurrency,
    required this.toCurrency,
    required this.onFromSelected,
    required this.onToSelected,
    this.currencies = SupportedCurrency.values,
  });

  /// Currently selected source currency code, or `null`.
  final String? fromCurrency;

  /// Currently selected destination currency code, or `null`.
  final String? toCurrency;

  /// Source-leg selection callback.
  final ValueChanged<String> onFromSelected;

  /// Destination-leg selection callback.
  final ValueChanged<String> onToSelected;

  /// Currencies offered in each lineup (defaults to all supported).
  final List<SupportedCurrency> currencies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('From', style: context.textTheme.titleSmall),
        const SizedBox(height: HivorrSpacing.xs),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            for (final SupportedCurrency currency in currencies)
              HivorrChip(
                label: currency.code,
                variant: HivorrChipVariant.surface,
                isSelected: currency.code == fromCurrency,
                onSelected: (_) => onFromSelected(currency.code),
              ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text('To', style: context.textTheme.titleSmall),
        const SizedBox(height: HivorrSpacing.xs),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            for (final SupportedCurrency currency in currencies)
              HivorrChip(
                label: currency.code,
                variant: HivorrChipVariant.surface,
                isSelected: currency.code == toCurrency,
                onSelected: (_) => onToSelected(currency.code),
              ),
          ],
        ),
      ],
    );
  }
}