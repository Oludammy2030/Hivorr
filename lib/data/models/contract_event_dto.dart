/// Data Transfer Object for a `contract_events` row (EP-03-10).
///
/// Append-only audit rows
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`
/// `contract_events` section). `event_type` spans
/// `offered | accepted | cancelled | milestone_completed | milestone_verified |
/// revision_requested | closed | disputed`.
class ContractEventDto {
  const ContractEventDto({
    required this.id,
    required this.contractId,
    this.entityId,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.actorId,
    this.details,
    this.createdAt,
  });

  factory ContractEventDto.fromJson(Map<String, dynamic> json) =>
      ContractEventDto(
        id: (json['id'] as String?) ?? '',
        contractId: (json['contract_id'] as String?) ?? '',
        entityId: json['entity_id'] as String?,
        eventType: (json['event_type'] as String?) ?? '',
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        actorId: json['actor_id'] as String?,
        details: json['details'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['details'] as Map)
            : null,
        createdAt: json['created_at'] is String
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final String contractId;
  final String? entityId;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? actorId;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;
}
