import 'package:hivorr/systems/finance/models/supported_currency.dart';

import 'package:intl/intl.dart';

/// Pure formatting helper for multi-currency balance display (EP-02-13 §5.4).
///
/// Formats numeric amounts with the correct currency symbol, thousands
/// separator, and decimal places. Locale-aware via the `intl` package.
abstract final class BalanceFormatter {
  /// Formats [amount] with the correct currency symbol and decimal places
  /// for the given [currencyCode].
  ///
  /// Examples:
  /// - `formatBalance(50000, 'NGN')` → `₦50,000.00`
  /// - `formatBalance(1200, 'GHS')` → `₵1,200.00`
  /// - `formatBalance(100, 'USD')` → `$100.00`
  /// - `formatBalance(75.5, 'GBP')` → `£75.50`
  ///
  /// Throws [ArgumentError] for negative amounts.
  /// Falls back to code-only display for unsupported currencies.
  static String formatBalance(double amount, String currencyCode) {
    if (amount < 0) {
      throw ArgumentError('Balance amount must not be negative: $amount');
    }
    final SupportedCurrency? currency = SupportedCurrency.fromCode(currencyCode);
    if (currency == null) return '$amount $currencyCode';
    final NumberFormat formatter = NumberFormat.currency(
      symbol: currency.symbol,
      decimalDigits: currency.decimalPlaces,
    );
    return formatter.format(amount);
  }
}
