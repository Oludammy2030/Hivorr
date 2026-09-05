/// Data Transfer Object for a currency-conversion record (EP-02-15 §5.2).
///
/// Two transport shapes map into this DTO:
/// - `financial_convert_currency` success payload
///   (`data: {conversion_id, from_amount, to_amount, rate}`, `1558-1561`) via
///   [CurrencyConversionDto.fromRpc] — the RPC does not echo
///   `from_currency`/`to_currency`/`fee`/`status`/`entity_id`, so those are
///   supplied by the datasource (`status: 'completed'`, `fee: 0` matching
///   `v_fee := 0` `1479`).
/// - A `financial_conversions` REST history row (snake_case columns) via
///   [CurrencyConversionDto.fromJson].
class CurrencyConversionDto {
  const CurrencyConversionDto({
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

  /// Maps a `financial_conversions` history row (or a generic DB row) into
  /// this DTO. Accepts both `id` and `conversion_id` keys. Missing `fee`
  /// defaults to `0`; missing `status` defaults to `pending`; null
  /// `completed_at` stays null; missing `created_at` falls back to the epoch
  /// (never throws).
  factory CurrencyConversionDto.fromJson(Map<String, dynamic> json) =>
      CurrencyConversionDto(
        id: (json['conversion_id'] as String? ?? json['id'] as String?) ?? '',
        entityId: (json['entity_id'] as String?) ?? '',
        fromCurrency: (json['from_currency'] as String?) ?? '',
        toCurrency: (json['to_currency'] as String?) ?? '',
        fromAmount: _toDouble(json['from_amount']),
        toAmount: _toDouble(json['to_amount']),
        exchangeRate: _toDouble(json['exchange_rate']),
        fee: _toDouble(json['fee']),
        status: (json['status'] as String?) ?? 'pending',
        completedAt: json['completed_at'] != null
            ? _parseDateTime(json['completed_at'])
            : null,
        createdAt: json['created_at'] != null
            ? _parseDateTime(json['created_at'])
            : DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Maps the `financial_convert_currency` success payload into this DTO.
  ///
  /// The server inserts the conversion with `status = 'completed'` (`1550-1552`)
  /// and applies `v_fee := 0` (`1479`), so those defaults are fixed here; the
  /// authoritative row (server timestamps, ledger, audit) is re-read through
  /// the history seam.
  factory CurrencyConversionDto.fromRpc({
    required String conversionId,
    required String fromCurrency,
    required String toCurrency,
    required double fromAmount,
    required double toAmount,
    required double rate,
    String entityId = '',
    DateTime? timestamp,
  }) =>
      CurrencyConversionDto(
        id: conversionId,
        entityId: entityId,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        fromAmount: fromAmount,
        toAmount: toAmount,
        exchangeRate: rate,
        fee: 0,
        status: 'completed',
        completedAt: timestamp,
        createdAt: timestamp ?? DateTime.now(),
      );

  final String id;
  final String entityId;
  final String fromCurrency;
  final String toCurrency;
  final double fromAmount;
  final double toAmount;
  final double exchangeRate;
  final double fee;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}