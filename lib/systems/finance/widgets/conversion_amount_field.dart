import 'package:flutter/material.dart';

import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Amount entry for the conversion form (EP-02-15 §5.4).
///
/// Decimal keyboard, prefixed with the selected source currency symbol, label
/// set to the source code once a source is chosen. The [controller] is owned
/// by the parent screen (kept alive across provider rebuilds).
class ConversionAmountField extends StatelessWidget {
  const ConversionAmountField({
    super.key,
    required this.controller,
    required this.currencyCode,
    required this.onChanged,
  });

  /// Text controller owned by the parent screen.
  final TextEditingController controller;

  /// Selected source currency code, or `null`.
  final String? currencyCode;

  /// Raw-input callback (parsing is the parent's responsibility).
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final SupportedCurrency? currency =
        currencyCode == null ? null : SupportedCurrency.fromCode(currencyCode!);
    return HivorrTextField(
      controller: controller,
      label: currency == null ? 'Amount' : 'Amount (${currency.code})',
      hint: '0.00',
      prefix: currency == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                label: currency.name,
                child: Text(
                  currency.symbol,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }
}