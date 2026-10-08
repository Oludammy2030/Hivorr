/// A concrete appointment booking under a service contract (EP-03-14).
///
/// Mirrors `appointments`
/// (`supabase/migrations/20260926090001_service_scheduling_schema.sql`).
/// `status` spans
/// `pending | confirmed | completed | cancelled | rescheduled`.
/// `startsAt`/`endsAt` are concrete `timestamptz` instants (UTC on the wire);
/// `timezone` lives on the template slot and is a display hint only.
/// `rescheduleOf` chains a replacement row to the superseded one;
/// `idempotencyKey` (`uuid v4` per booking attempt) dedups double-tap and
/// offline replay server-side (`ON CONFLICT DO NOTHING`).
///
/// Pure Dart domain — no DTO leakage, no Flutter/Supabase imports. State is
/// server-authoritative; the `can*` helpers below are view-intent hints for
/// CTA visibility only and never enforcement (`AGENT.md` Rule 4).
class Appointment {
  const Appointment({
    required this.id,
    required this.contractId,
    this.slotId,
    required this.professionalEntityId,
    required this.clientEntityId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.rescheduleOf,
    this.idempotencyKey,
    this.createdAt,
    this.updatedAt,
  });

  /// The appointment row id.
  final String id;

  /// Owning `service_contracts.id`.
  final String contractId;

  /// Source `availability_slots.id`, `null` for ad-hoc bookings.
  final String? slotId;

  /// Hired professional (derived from the contract, never client-supplied).
  final String professionalEntityId;

  /// Consuming client (derived from the contract, never client-supplied).
  final String clientEntityId;

  /// Concrete window start (`timestamptz`, UTC on the wire).
  final DateTime startsAt;

  /// Concrete window end (`timestamptz`, UTC on the wire).
  final DateTime endsAt;

  /// Lifecycle state.
  final String status;

  /// Superseded appointment id for replacement rows, when present.
  final String? rescheduleOf;

  /// Dedup key for the booking attempt (`uuid v4`).
  final String? idempotencyKey;

  /// Row timestamps (RPC-managed).
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Whether the window is still actionable (`EXCLUDE` active set).
  bool get isActiveWindow => status == 'pending' || status == 'confirmed';

  /// Whether the appointment reached a terminal state.
  bool get isTerminal =>
      status == 'cancelled' ||
      status == 'rescheduled' ||
      status == 'completed';

  /// Whether the window already passed (display hint; server decides).
  bool get isPast => DateTime.now().isAfter(endsAt);

  /// View-intent hint: reschedule affordance (either participant, active
  /// window, future end).
  bool canReschedule(String viewerEntityId) =>
      isActiveWindow &&
      !isPast &&
      (viewerEntityId == clientEntityId ||
          viewerEntityId == professionalEntityId);

  /// View-intent hint: cancel affordance (either participant, active window).
  bool canCancel(String viewerEntityId) =>
      isActiveWindow &&
      (viewerEntityId == clientEntityId ||
          viewerEntityId == professionalEntityId);
}
