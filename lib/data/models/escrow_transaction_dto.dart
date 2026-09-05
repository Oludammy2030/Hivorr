/// Data Transfer Object for an escrow-scoped ledger summary entry (EP-02-14).
///
/// Reserved for the `financial_escrow_get` transactions envelope. The frozen
/// EP-02-04 read model does not currently return a transactions array, so the
/// parse helper exposes an empty list; this DTO is retained so the seam is
/// ready for the envelope when it ships.
class EscrowTransactionDto {
  const EscrowTransactionDto({
    required this.id,
    required this.escrowId,
    required this.type,
    required this.amount,
    required this.direction,
    required this.entityId,
    required this.reference,
    required this.createdAt,
  });

  factory EscrowTransactionDto.fromJson(Map<String, dynamic> json) =>
      EscrowTransactionDto(
        id: (json['id'] as String?) ?? '',
        escrowId: (json['escrow_id'] as String?) ?? '',
        type: (json['type'] as String?) ?? '',
        amount: _toDouble(json['amount']),
        direction: (json['direction'] as String?) ?? 'out',
        entityId: (json['entity_id'] as String?) ?? '',
        reference: (json['reference'] as String?) ?? '',
        createdAt: _parseDateTime(json['created_at']),
      );

  final String id;
  final String escrowId;
  final String type;
  final double amount;
  final String direction;
  final String entityId;
  final String reference;
  final DateTime createdAt;

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}