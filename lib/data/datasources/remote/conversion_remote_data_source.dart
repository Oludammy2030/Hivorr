import 'package:hivorr/data/models/currency_conversion_dto.dart';

/// Abstract contract for the remote (Supabase) side of currency conversion
/// (EP-02-15 §5.2).
///
/// Supports the single authorized conversion write path: the authenticated
/// `financial_convert_currency` RPC, whose grant covers the authenticated role
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1686`)
/// — unlike escrow, the RLS-backed client may invoke conversion directly. The
/// client **never** writes `financial_conversions` / `financial_balances`
/// directly; `financial_convert_currency` inserts the conversion row and
/// mutates balances atomically under `FOR UPDATE` (AGENT.md Rule 4).
///
/// The rate passed to [convertCurrency] originates exclusively from the
/// `ConversionRateSource` seam (rate-integrity, DoD SV-01) — never from user
/// input.
abstract class ConversionRemoteDataSource {
  /// Executes `financial_convert_currency(p_from_currency, p_to_currency,
  /// p_amount, p_rate)` and maps the success envelope
  /// `{conversion_id, from_amount, to_amount, rate}` (`1558-1561`) to a
  /// `CurrencyConversionDto` (`status: 'completed'`, `fee: 0`).
  Future<CurrencyConversionDto> convertCurrency({
    required String fromCurrency,
    required String toCurrency,
    required double amount,
    required double rate,
  });

  /// Fetches the caller's conversion history.
  ///
  /// Transported through a seam (build-time decision gate §5.2): either the
  /// `financial_conversions` REST read (identity-scoped via the
  /// `financial_conversions_select` RLS policy `620-621`) or an empty list
  /// when the REST read is not permitted under the authenticated scope. The
  /// future `financial_conversions_list` RPC is the documented swap point;
  /// the marshalling and UI remain stable regardless of transport. Never
  /// writes.
  Future<List<CurrencyConversionDto>> getHistory();
}