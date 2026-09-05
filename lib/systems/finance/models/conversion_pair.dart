import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// A validated, directed currency-conversion pair (EP-02-15 §5.3).
///
/// Enforces the frozen server invariants client-side before any RPC:
/// - both legs must be supported currencies (`financial_supported_currencies`)
/// - `from.code != to.code` (self-conversion is disallowed by
///   `financial_conversions` check constraint `ck_financial_conversions_from_ne_to`
///   `375`)
///
/// The pair is the accept/reject lens for the legacy wallet conversion pairs
/// shipped in the client; the `WalletConversionPairsConfig` flag decides
/// whether a named pair participates, but a pair that fails this validation is
/// **never** offered regardless of the flag.
class ConversionPair {
  const ConversionPair._(this.from, this.to);

  /// Builds a pair, throwing [ArgumentError] if either leg is unsupported or
  /// the legs are identical.
  factory ConversionPair({required SupportedCurrency from,
      required SupportedCurrency to}) {
    if (!SupportedCurrency.isSupported(from.code)) {
      throw ArgumentError.value(
        from.code,
        'from',
        'Unsupported source currency',
      );
    }
    if (!SupportedCurrency.isSupported(to.code)) {
      throw ArgumentError.value(
        to.code,
        'to',
        'Unsupported destination currency',
      );
    }
    if (from == to) {
      throw ArgumentError.value(
        from.code,
        'from',
        'Cannot convert a currency into itself',
      );
    }
    return ConversionPair._(from, to);
  }

  /// Tries to build a pair, returning `null` (instead of throwing) when the
  /// pair is invalid. Used by flag-gated pair discovery.
  static ConversionPair? tryCreate(
      {required SupportedCurrency from, required SupportedCurrency to}) {
    try {
      return ConversionPair(from: from, to: to);
    } on ArgumentError {
      return null;
    }
  }

  final SupportedCurrency from;
  final SupportedCurrency to;

  /// Whether [from] and [to] refer to the same currency.
  bool get isSelfPair => from == to;

  /// ISO code of the source leg.
  String get fromCode => from.code;

  /// ISO code of the destination leg.
  String get toCode => to.code;

  @override
  bool operator ==(Object other) =>
      other is ConversionPair && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'ConversionPair(${from.code} \u2192 ${to.code})';
}