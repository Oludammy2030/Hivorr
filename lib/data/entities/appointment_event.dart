/// An append-only audit row for an appointment lifecycle (EP-03-14).
///
/// Mirrors `appointment_events`
/// (`supabase/migrations/20260926090001_service_scheduling_schema.sql`).
/// `eventType` spans
/// `booked | confirmed | rescheduled | cancelled | completed`.
/// Pure Dart domain — rows are server-written and rendered verbatim in
/// `appointment_timeline`.
class AppointmentEvent {
  const AppointmentEvent({
    required this.id,
    required this.appointmentId,
    required this.contractId,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.actorId,
    this.details,
    this.createdAt,
  });

  /// The event row id.
  final String id;

  /// Owning appointment id.
  final String appointmentId;

  /// Owning contract id (denormalized for participant scoping).
  final String contractId;

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
