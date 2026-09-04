/// Supported currency vocabulary for the financial profile system (EP-02-13).
///
/// Data-driven from `financial_supported_currencies`
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:37-62`).
/// The four currencies (NGN, GHS, USD, GBP) are the current set; future
/// additions (KES, ZAR) require only an enum extension + server seed insert.
enum SupportedCurrency {
  ngn(code: 'NGN', name: 'Nigerian Naira', symbol: '\u20A6', decimalPlaces: 2),
  ghs(code: 'GHS', name: 'Ghanaian Cedi', symbol: '\u20B5', decimalPlaces: 2),
  usd(code: 'USD', name: 'US Dollar', symbol: '\$', decimalPlaces: 2),
  gbp(code: 'GBP', name: 'British Pound', symbol: '\u00A3', decimalPlaces: 2);

  const SupportedCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
  });

  /// ISO 4217 currency code.
  final String code;

  /// Human-readable currency name.
  final String name;

  /// Currency display symbol.
  final String symbol;

  /// Number of decimal places for display.
  final int decimalPlaces;

  /// All registered currency codes for validation.
  static final Set<String> codes = SupportedCurrency.values
      .map((SupportedCurrency c) => c.code)
      .toSet();

  /// Lookup a [SupportedCurrency] by its ISO code.
  ///
  /// Returns `null` for unknown codes.
  static SupportedCurrency? fromCode(String code) {
    for (final SupportedCurrency c in SupportedCurrency.values) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// Whether [code] is in the supported set.
  static bool isSupported(String code) => codes.contains(code);
}
