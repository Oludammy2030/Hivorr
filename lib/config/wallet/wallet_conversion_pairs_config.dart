import 'package:hivorr/systems/finance/models/conversion_pair.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';

/// Data-driven wallet currency-conversion configuration (EP-02-15 §5.9).
///
/// This is the **single guarded client rate authority**: base cross-rates
/// keyed by the alphabetically-sorted pair (`'GHS|NGN'`), seeded from the same
/// values the server would use. Rates are **never derived from user input**
/// (EP-02:174 — conversion rules are server-side config-driven, never
/// hardcoded or user-entered; the `financial_convert_currency` RPC accepts
/// `p_rate` as a caller-supplied input `1459-1500`).
///
/// Direction is `toAmount = fromAmount * rate` matching
/// `financial_convert_currency:1515`. Inverse pairs are derived only via the
/// guarded reciprocal (`1 / base` where `base > 0`); there is no rate table on
/// the server, so the rate lives here behind the `ConversionRateSource` seam
/// with a documented swap point for a future `ServerConversionRateSource` /
/// `ProviderConversionRateSource` (EP-02-16+).
class WalletConversionPairsConfig {
  const WalletConversionPairsConfig({
    this.enabled = false,
    this.baseCrossRates = const <String, double>{},
  });

  /// Whether wallet conversion is available at all. While false the rate
  /// source fails closed with `ConversionRateUnavailableException`.
  final bool enabled;

  /// Base cross-rates keyed by `'FROM|TO'` where `FROM.code < TO.code`
  /// lexicographically. The value converts one unit of `FROM` into `TO`
  /// (`rate = toAmount / fromAmount`, e.g. `'NGN|USD': 0.0007`).
  final Map<String, double> baseCrossRates;

  /// Resolves the directed rate for `from`→`to`, deriving the inverse via the
  /// guarded reciprocal when the base pair is stored in the opposite
  /// direction. Returns `null` for self-pairs, unsupported pairs, non-positive
  /// base rates, and missing pairs — callers must not invent a fallback rate.
  double? directedRate(String from, String to) {
    if (from.isEmpty || to.isEmpty || from == to) return null;
    if (!SupportedCurrency.isSupported(from) || !SupportedCurrency.isSupported(to)) {
      return null;
    }
    final bool fromIsLower = from.compareTo(to) < 0;
    final String lower = fromIsLower ? from : to;
    final String upper = fromIsLower ? to : from;
    final double? base = baseCrossRates['$lower|$upper'];
    if (base == null || base <= 0) return null;
    return fromIsLower ? base : 1 / base;
  }

  /// The ordered, directed [ConversionPair]s discoverable from
  /// [baseCrossRates]. Each base pair yields both directions (e.g.
  /// `NGN↔GHS` → `NGN→GHS` + `GHS→NGN`), producing 12 pairs for the 6 seeded
  /// pairs. Empty when conversion is disabled or no valid base rate exists.
  List<ConversionPair> availablePairs() {
    if (!enabled) return const <ConversionPair>[];
    final List<ConversionPair> result = <ConversionPair>[];
    for (final MapEntry<String, double> entry in baseCrossRates.entries) {
      if (entry.value <= 0) continue;
      final List<String> legs = entry.key.split('|');
      if (legs.length != 2) continue;
      final SupportedCurrency? lower = SupportedCurrency.fromCode(legs[0]);
      final SupportedCurrency? upper = SupportedCurrency.fromCode(legs[1]);
      if (lower == null || upper == null) continue;
      final ConversionPair? forward = ConversionPair.tryCreate(from: lower, to: upper);
      final ConversionPair? reverse =
          forward == null ? null : ConversionPair.tryCreate(from: forward.to, to: forward.from);
      if (forward != null) result.add(forward);
      if (reverse != null) result.add(reverse);
    }
    return List<ConversionPair>.unmodifiable(result);
  }
}