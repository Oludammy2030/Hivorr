import 'package:hivorr/data/entities/conversion_preview.dart';
import 'package:hivorr/data/entities/currency_conversion.dart';

/// Abstract contract for currency-conversion data operations (EP-02-15 §5.4).
///
/// **Rate integrity is THE enforced boundary:** `financial_convert_currency`
/// accepts `p_rate` as a caller-supplied input
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1459-1500`),
/// so every rate this repository hands to the RPC originates **exclusively**
/// from the injected `ConversionRateSource` seam — never from a user-arbitrary
/// value, an inline literal, or a client guess (DoD SV-01, TT-09).
///
/// Additional invariants:
/// - `previewConversion` performs **zero RPCs** — pure local math
///   (gross/fee/net) against the trusted rate seam (DoD FV-19).
/// - The client **never** writes `financial_conversions`/`financial_balances`
///   directly; all balance mutation is server-authoritative inside
///   `financial_convert_currency` under `FOR UPDATE` locks (AGENT.md Rule 4).
/// - Pair/amount/rate are validated against `SupportedCurrency` and the frozen
///   check constraints **before** any RPC is attempted.
abstract class ConversionRepository {
  /// Returns the current trusted rate for `fromCurrency`→`toCurrency`
  /// (units of `to` per unit of `from`), delegating to `ConversionRateSource`.
  ///
  /// Validates the pair (`SupportedCurrency`, `from != to`) before delegation;
  /// performs **no RPC**. Throws `PLT003` validation on an invalid pair and
  /// [ConversionRateUnavailableException] when no configured rate exists.
  Future<double> getRate({
    required String fromCurrency,
    required String toCurrency,
  });

  /// Computes a local conversion estimate.
  ///
  /// Validates pair/amount, fetches the trusted rate, and returns
  /// `ConversionPreview` with `gross = amount * rate`, `fee` (default `0`
  /// matching `v_fee := 0`), `net = gross - fee` — matching the server formula
  /// `to_amount := p_amount * p_rate - v_fee` (`1515`). **Zero RPCs.**
  Future<ConversionPreview> previewConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  });

  /// Executes a conversion via `financial_convert_currency`.
  ///
  /// Validates pair/amount/rate-positive, fetches the rate from the single
  /// trusted source, calls `remote.convertCurrency(from, to, amount, rate)`,
  /// then best-effort re-reads `financial_status_get` (via the injected
  /// `FinancialRepository`) to refresh balances. **Prevents user-arbitrary
  /// rates**; surfaces `PLT006` insufficient balance (`1511-1513`) as a
  /// [ApiException] with kind `conflict`.
  Future<CurrencyConversion> executeConversion({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
  });

  /// Fetches the caller's conversion history through the remote history seam.
  ///
  /// Returns an empty list when no records exist. Never writes.
  Future<List<CurrencyConversion>> getHistory();
}