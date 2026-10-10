/// Data Transfer Objects for the transaction history read model (EP-03-16).
///
/// Mirrors the `service_transaction_history` RPC envelope `data` object
/// (`supabase/migrations/20261008090001_service_earnings_visibility.sql`):
/// `items[]` rows in server order plus the `has_more` / `next_cursor`
/// keyset page contract.
class EarningsTransactionDto {
  const EarningsTransactionDto({
    required this.id,
    required this.type,
    required this.currencyCode,
    required this.amount,
    required this.direction,
    this.sourceEntityId,
    this.destinationEntityId,
    this.referenceType,
    this.referenceId,
    this.description,
    required this.createdAt,
    this.contractId,
    this.contractStatus,
    this.escrowStatus,
  });

  factory EarningsTransactionDto.fromJson(Map<String, dynamic> json) =>
      EarningsTransactionDto(
        id: (json['id'] as String?) ?? '',
        type: (json['transaction_type'] as String?) ?? '',
        currencyCode: (json['currency_code'] as String?) ?? '',
        amount: _toDouble(json['amount']),
        direction: (json['direction'] as String?) ?? 'self',
        sourceEntityId: json['source_entity_id'] as String?,
        destinationEntityId: json['destination_entity_id'] as String?,
        referenceType: json['reference_type'] as String?,
        referenceId: json['reference_id'] as String?,
        description: json['description'] as String?,
        createdAt: _parseDateTime(json['created_at']),
        contractId: json['contract_id'] as String?,
        contractStatus: json['contract_status'] as String?,
        escrowStatus: json['escrow_status'] as String?,
      );

  final String id;
  final String type;
  final String currencyCode;
  final double amount;
  final String direction;
  final String? sourceEntityId;
  final String? destinationEntityId;
  final String? referenceType;
  final String? referenceId;
  final String? description;
  final DateTime createdAt;
  final String? contractId;
  final String? contractStatus;
  final String? escrowStatus;

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

/// DTO for one keyset-paginated history page (EP-03-16).
class EarningsTransactionPageDto {
  const EarningsTransactionPageDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  factory EarningsTransactionPageDto.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems =
        (json['items'] as List<dynamic>?) ?? <dynamic>[];
    final Object? rawCursor = json['next_cursor'];
    return EarningsTransactionPageDto(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(EarningsTransactionDto.fromJson)
          .toList(growable: false),
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: rawCursor is Map
          ? Map<String, dynamic>.from(rawCursor)
          : null,
    );
  }

  final List<EarningsTransactionDto> items;
  final bool hasMore;
  final Map<String, dynamic>? nextCursor;
}
