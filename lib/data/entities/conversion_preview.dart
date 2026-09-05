/// A purely local conversion estimate (EP-02-15 §5.2).
///
/// Computed by the repository from the trusted [ConversionRateSource] seam —
/// it performs **zero RPCs** and is display-only. The authoritative `toAmount`
/// after execution comes from `financial_convert_currency`'s response
/// (`1558-1561`), never this client-computed estimate (DoD SV-07).
///
/// Invariant: `toAmount == grossAmount - fee` — matching the server formula
/// `to_amount := p_amount * p_rate - v_fee` (`financial_convert_currency`
/// `1515`, `v_fee := 0` `1479`).
class ConversionPreview {
  const ConversionPreview({
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.grossAmount,
    required this.fee,
    required this.toAmount,
    required this.exchangeRate,
  });

  /// Source currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String fromCurrency;

  /// Destination currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String toCurrency;

  /// The amount the user intends to convert (must be `> 0`).
  final double fromAmount;

  /// `fromAmount * exchangeRate` — the destination-currency gross.
  final double grossAmount;

  /// Estimated fee (`0` while the server applies `v_fee := 0`).
  final double fee;

  /// `grossAmount - fee` — the estimated net the entity receives.
  final double toAmount;

  /// The trusted rate from [ConversionRateSource] (`toAmount = fromAmount * rate`).
  final double exchangeRate;

  /// Whether the estimate is financially meaningful (`fromAmount > 0` and
  /// `toAmount > 0`).
  bool get isActionable => fromAmount > 0 && toAmount > 0;
}