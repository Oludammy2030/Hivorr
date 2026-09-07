import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Client-side formatting validation for bank account numbers (EP-02-16).
///
/// The server (`financial_payout_account_bind`) enforces only that the number
/// is non-blank (`PLT003`) and `char_length <= 50` (table check). The client
/// adds a stricter format gate so users catch typo'd numbers before the RPC:
/// a fully numeric value; exactly 10 digits (NUBAN standard) for NGN, and
/// 8-15 digits for other currencies (GHS/USD/GBP variants).
abstract final class BankAccountNumberValidator {
  /// Returns `null` when [value] is acceptable for [currencyCode], or a
  /// user-facing error message otherwise.
  static String? validate({
    required String? value,
    required String currencyCode,
  }) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter the account number';
    }
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'Account number must contain digits only';
    }
    final bool isNgn = SupportedCurrency.isSupported(currencyCode) &&
        currencyCode == 'NGN';
    if (isNgn) {
      if (trimmed.length != 10) {
        return 'NGN account numbers are 10 digits (NUBAN)';
      }
    } else if (trimmed.length < 8 || trimmed.length > 15) {
      return 'Account number must be between 8 and 15 digits';
    }
    return null;
  }

  /// Whether [value] passes the format gate for [currencyCode].
  static bool isValid({required String value, required String currencyCode}) =>
      validate(value: value, currencyCode: currencyCode) == null;
}