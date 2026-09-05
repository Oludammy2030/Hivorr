import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Pure, locale-aware display helpers for currency conversion (EP-02-15 §5.3).
///
/// Reuses `BalanceFormatter` (EP-02-13) so money never falls back to raw
/// `double.toString()` — gross/fee/net always render with the destination
/// currency symbol and thousands separators (DoD FV-25).
class ConversionFormatter {
  const ConversionFormatter._();

  /// Formats a preview as `'₦50,000.00 → $35.00'`.
  ///
  /// `fromAmount` uses its own currency symbol; `toAmount` (the net) uses the
  /// destination currency symbol.
  static String preview(ConversionPreview preview) =>
      '${BalanceFormatter.formatBalance(preview.fromAmount, preview.fromCurrency)}'
      ' \u2192 '
      '${BalanceFormatter.formatBalance(preview.toAmount, preview.toCurrency)}';

  /// Formats a rate as `'1 NGN = 0.0007 USD'`.
  ///
  /// Sub-unit rates keep significant decimals (`0.0007`); whole rates use two
  /// decimals (`1500.00`). Never rounds sub-unit rates to zero.
  static String rate(
    double rate, {
    required String fromCurrency,
    required String toCurrency,
  }) {
    final String value = rate >= 1
        ? rate.toStringAsFixed(2)
        : rate
            .toStringAsFixed(6)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
    return '1 $fromCurrency = $value $toCurrency';
  }
}