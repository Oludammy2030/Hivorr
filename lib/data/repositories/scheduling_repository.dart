import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';

/// Abstract contract for scheduling data operations (EP-03-14 §8 D4).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface rather than a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
///
/// All scheduling writes flow through the client-callable RPCs
/// (`availability_upsert`, `appointment_book/reschedule/cancel`); this
/// repository **never** writes `availability_slots`, `appointments`, or
/// `appointment_events` tables directly. Reads follow plan §7.1 Option B
/// (participant RLS-`SELECT` behind the remote seam).
abstract class SchedulingRepository {
  /// Upserts a weekly template row for the caller, then re-reads the
  /// authoritative slot list.
  ///
  /// Pre-validates weekday (`0–6`), time range (`start < end`), duration
  /// (`15–480`), and timezone shape before the RPC (fail-fast `PLT003`).
  Future<List<AvailabilitySlot>> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = 'Africa/Lagos',
    bool isActive = true,
  });

  /// Lists template rows for [entityId] (self when `null`), optionally scoped
  /// to [professionId], in server order (verbatim).
  Future<List<AvailabilitySlot>> listSlots({
    String? entityId,
    String? professionId,
  });

  /// Books a concrete window under [contractId] with a caller-supplied
  /// [idempotencyKey] (`uuid v4` per attempt), then re-reads the authoritative
  /// appointment. Pre-validates the window (`starts > now`, `ends > starts`,
  /// `≤ 24h`) before the RPC (fail-fast `PLT003`).
  Future<Appointment> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String idempotencyKey,
  });

  /// Reschedules [appointmentId] to a new window with [idempotencyKey], then
  /// re-reads the replacement appointment.
  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    required String idempotencyKey,
  });

  /// Cancels [appointmentId] (optional [reason] `≤ 500`), then re-reads the
  /// authoritative appointment.
  Future<Appointment> cancelAppointment(
    String appointmentId, {
    String? reason,
  });

  /// Fetches a single appointment (no oracle: foreign/unknown → `PLT004`).
  Future<Appointment> getAppointment(String appointmentId);

  /// Lists events for [appointmentId] in `created_at` order (verbatim).
  Future<List<AppointmentEvent>> listAppointmentEvents(String appointmentId);

  /// Lists appointments for [contractId] with keyset pagination
  /// (`(starts_at DESC, id DESC)`), optionally filtered by [status].
  Future<AppointmentPage> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  });
}
