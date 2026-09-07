/// Data Transfer Object for a `dispute_cases` row (EP-02-17).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:54-101`),
/// using the actual snake_case keys returned inside the `dispute_file` /
/// `dispute_get` / `dispute_list` envelopes.
class DisputeCaseDto {
  const DisputeCaseDto({
    required this.id,
    required this.escrowId,
    required this.filerEntityId,
    required this.counterpartyEntityId,
    required this.disputeType,
    required this.status,
    required this.reason,
    this.desiredOutcome,
    this.priority = 'medium',
    required this.filedAt,
    this.resolvedAt,
    this.closedAt,
    this.withdrawnAt,
    this.metadata = const <String, dynamic>{},
  });

  factory DisputeCaseDto.fromJson(Map<String, dynamic> json) => DisputeCaseDto(
        id: (json['id'] as String?) ?? '',
        escrowId: (json['escrow_id'] as String?) ?? '',
        filerEntityId: (json['filer_entity_id'] as String?) ?? '',
        counterpartyEntityId: (json['counterparty_entity_id'] as String?) ?? '',
        disputeType: (json['dispute_type'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'open',
        reason: (json['reason'] as String?) ?? '',
        desiredOutcome: json['desired_outcome'] as String?,
        priority: (json['priority'] as String?) ?? 'medium',
        filedAt: _parseDateTime(json['filed_at']),
        resolvedAt: _parseNullableDateTime(json['resolved_at']),
        closedAt: _parseNullableDateTime(json['closed_at']),
        withdrawnAt: _parseNullableDateTime(json['withdrawn_at']),
        metadata:
            (json['metadata'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      );

  final String id;
  final String escrowId;
  final String filerEntityId;
  final String counterpartyEntityId;
  final String disputeType;
  final String status;
  final String reason;
  final String? desiredOutcome;
  final String priority;
  final DateTime filedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime? withdrawnAt;
  final Map<String, dynamic> metadata;

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