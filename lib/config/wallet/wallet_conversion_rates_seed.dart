/// Default seeded base cross-rates for wallet currency conversion
/// (EP-02-15 §7.4, DoD FV-14).
///
/// Six base pairs covering the four supported currencies (NGN, GHS, USD, GBP),
/// keyed by the alphabetically-sorted pair (`'FROM|TO'` where `FROM.code <
/// TO.code`). Each value converts one unit of `FROM` into `TO`
/// (`rate = toAmount / fromAmount`, e.g. `'NGN|USD': 0.0007` → 1 NGN = 0.0007
/// USD). Inverse pairs are derived only via the guarded reciprocal.
///
/// These are demo seeds mirroring the values a server/seed origin would
/// publish; the authoritative feed replaces this constant in EP-02-16 via a
/// `ServerConversionRateSource` / `ProviderConversionRateSource` at DI —
/// no repository or screen change (Open/Closed). Only `NGN|USD = 0.0007` is
/// contract-referenced by the test suites (DoD TT-14, UA-01).
abstract final class WalletConversionRatesSeed {
  const WalletConversionRatesSeed._();

  static const Map<String, double> baseCrossRates = <String, double>{
    'GHS|NGN': 1111.1111111111111,
    'NGN|USD': 0.0007,
    'NGN|GBP': 0.00085,
    'GHS|USD': 0.78,
    'GHS|GBP': 0.625,
    'USD|GBP': 0.7874,
  };
}