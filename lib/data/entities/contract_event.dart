/// An append-only audit row for a service contract lifecycle (EP-03-10).
///
/// Mirrors `contract_events`
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`).
/// `eventType` spans `offered | accepted | cancelled | milestone_completed |
/// milestone_verified | revision_requested | closed | disputed`.
/// Pure Dart domain — rows are server-written and rendered verbatim in
/// `contract_timeline`.
class ContractEvent {
  const ContractEvent({
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

  /// The event row id.
  final String id;

  /// Owning contract id.
  final String contractId;

  /// Entity the event was recorded for, when present.
  final String? entityId;

  /// Event vocabulary code.
  final String eventType;

  /// Status transition source, when applicable.
  final String? fromStatus;

  /// Status transition target, when applicable.
  final String? toStatus;

  /// Acting entity, when applicable.
  final String? actorId;

  /// Server-supplied detail payload.
  final Map<String, dynamic>? details;

  /// When the event was recorded.
  final DateTime? createdAt;
}
