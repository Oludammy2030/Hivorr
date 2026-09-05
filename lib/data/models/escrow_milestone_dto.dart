/// Data Transfer Object for an escrow milestone read model (EP-02-14).
///
/// Mirrors a `financial_escrow_milestones` row returned within the
/// `financial_escrow_get` envelope
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:232-257`).
class EscrowMilestoneDto {
  const EscrowMilestoneDto({
    required this.id,
    required this.escrowId,
    required this.milestoneNumber,
    required this.title,
    required this.amount,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    this.description,
    this.completedAt,
    this.releasedAt,
  });

  factory EscrowMilestoneDto.fromJson(Map<String, dynamic> json) =>
      EscrowMilestoneDto(
        id: (json['id'] as String?) ?? '',
        escrowId: (json['escrow_id'] as String?) ?? '',
        milestoneNumber: _toInt(json['milestone_number']),
        title: (json['title'] as String?) ?? '',
        description: json['description'] as String?,
        amount: _toDouble(json['amount']),
        status: (json['status'] as String?) ?? 'pending',
        sortOrder: _toInt(json['sort_order']),
        createdAt: _parseDateTime(json['created_at']),
        completedAt: _parseNullableDateTime(json['completed_at']),
        releasedAt: _parseNullableDateTime(json['released_at']),
      );

  final String id;
  final String escrowId;
  final int milestoneNumber;
  final String title;
  final String? description;
  final double amount;
  final String status;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? releasedAt;

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

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

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}