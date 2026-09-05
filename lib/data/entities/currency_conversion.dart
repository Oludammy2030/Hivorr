/// A single executed currency conversion between two supported balances
/// (EP-02-15 §5.2).
///
/// Mirrors the server-authoritative `financial_conversions` read model
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:355-382`)
/// and the `financial_convert_currency` success payload (`1558-1561`). Pure
/// Dart domain — the conversion is executed server-side by
/// `financial_convert_currency` under `FOR UPDATE` locks; the client never
/// writes this table directly (AGENT.md Rule 4).
///
/// Invariants (mirroring the frozen check constraints):
/// - `fromAmount > 0` and `toAmount > 0` (`365-366`)
/// - `exchangeRate > 0` (`367`)
/// - `fee >= 0` (`368`)
/// - `fromCurrency != toCurrency` (`375`)
/// - `status` in `pending | completed | failed` (`369-370`)
class CurrencyConversion {
  const CurrencyConversion({
    required this.id,
    required this.entityId,
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.toAmount,
    required this.exchangeRate,
    required this.fee,
    required this.status,
    this.completedAt,
    required this.createdAt,
  });

  /// The `financial_conversions` row id (RPC `conversion_id`).
  final String id;

  /// The owning entity id (`auth.uid()`-self-scoped).
  final String entityId;

  /// Source currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String fromCurrency;

  /// Destination currency code (`NGN`, `GHS`, `USD`, `GBP`).
  final String toCurrency;

  /// Source amount debited from the available balance.
  final double fromAmount;

  /// Destination amount credited (`gross - fee`), server-computed.
  final double toAmount;

  /// The rate applied (`toAmount = fromAmount * rate - fee`).
  final double exchangeRate;

  /// Fee deducted server-side (`0` while `v_fee := 0`, EP-02-04 §1479).
  final double fee;

  /// Conversion lifecycle status: `pending | completed | failed`.
  final String status;

  /// When the conversion completed server-side, when reported.
  final DateTime? completedAt;

  /// Record creation timestamp.
  final DateTime createdAt;

  /// Whether the conversion reached the terminal `completed` state.
  bool get isCompleted => status == 'completed';

  /// Whether the conversion failed server-side.
  bool get isFailed => status == 'failed';
}