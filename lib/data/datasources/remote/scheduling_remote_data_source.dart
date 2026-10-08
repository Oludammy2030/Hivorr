import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';

/// Contract for scheduling transport (EP-03-14 §11).
///
/// Wraps exactly the five client-callable scheduling RPCs granted to
/// `authenticated`
/// (`supabase/migrations/20260926090001_service_scheduling_schema.sql`):
/// `availability_upsert`, `availability_list`, `appointment_book`,
/// `appointment_reschedule`, `appointment_cancel`.
///
/// Scheduling tables (`availability_slots` / `appointments` /
/// `appointment_events`) are **never** written directly — all state changes
/// flow through these RPCs per `AGENT.md` Rule 4. Reads follow plan §7.1
/// Option B (participant RLS-`SELECT` on `appointments` /
/// `appointment_events`, zero new SQL); the seam is interface-shaped so a
/// future `appointment_get/list_mine` RPC pair can replace the read path
/// without touching callers.
abstract class SchedulingRemoteDataSource {
  /// Upserts a weekly template row for the caller (`availability_upsert`,
  /// VOLATILE; idempotent per `(entity, profession, weekday, start)`).
  Future<AvailabilitySlotDto> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = 'Africa/Lagos',
    bool isActive = true,
  });

  /// Lists template rows for [entityId] (self when `null`), optionally scoped
  /// to [professionId] (`availability_list`, STABLE; `PLT004` oracle for
  /// foreign/unpublished targets).
  Future<AvailabilityListEnvelopeDto> listSlots({
    String? entityId,
    String? professionId,
  });

  /// Books a concrete `timestamptz` window under an `active` contract
  /// (`appointment_book`, VOLATILE; `PLT005` on `EXCLUDE` overlap, same-id
  /// replay on `p_idempotency_key` reuse).
  Future<AppointmentDto> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String idempotencyKey,
  });

  /// Reschedules a `pending`/`confirmed` appointment
  /// (`appointment_reschedule`, VOLATILE; old row → `rescheduled`, new row
  /// `pending reschedule_of=old`).
  Future<AppointmentRescheduleEnvelopeDto> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    required String idempotencyKey,
  });

  /// Cancels a `pending`/`confirmed` appointment (`appointment_cancel`,
  /// VOLATILE; frees the `EXCLUDE WHERE` window).
  Future<AppointmentDto> cancelAppointment(
    String appointmentId, {
    String? reason,
  });

  /// Fetches a single appointment with its `events[]` (RLS-`SELECT`,
  /// participant-scoped; foreign/unknown → `PLT004` not-found, no oracle).
  Future<AppointmentDto> getAppointment(String appointmentId);

  /// Lists the events for [appointmentId] in `created_at` order (RLS-`SELECT`,
  /// participant-scoped).
  Future<List<AppointmentEventDto>> listAppointmentEvents(
    String appointmentId,
  );

  /// Lists appointments for [contractId] with keyset pagination
  /// (`(starts_at DESC, id DESC)`; unknown cursor → empty page, no oracle).
  Future<AppointmentPageDto> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  });
}
