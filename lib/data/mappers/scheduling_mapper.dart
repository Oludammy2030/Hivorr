import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';

/// Transformations between the scheduling transport DTOs and the pure-Dart
/// domain entities (EP-03-14).
///
/// The single transformation boundary between the RPC/RLS layer and the
/// domain — no I/O and no business logic, only null-safe field copying
/// (EP-01-08 §5.3, mirrors `ContractMapper`).
abstract final class SchedulingMapper {
  /// Maps an `availability_slots` DTO into a domain [AvailabilitySlot].
  static AvailabilitySlot slotToEntity(AvailabilitySlotDto dto) =>
      AvailabilitySlot(
        id: dto.id,
        entityId: dto.entityId,
        professionId: dto.professionId,
        weekday: dto.weekday,
        startTime: dto.startTime,
        endTime: dto.endTime,
        slotDurationMin: dto.slotDurationMin,
        timezone: dto.timezone,
        isActive: dto.isActive,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
      );

  /// Maps an `appointments` DTO into a domain [Appointment].
  ///
  /// Rows without concrete `starts_at`/`ends_at` fall back to `now()` so the
  /// entity invariant (non-nullable window) holds even for malformed payloads
  /// in tests; production rows always carry both timestamps.
  static Appointment appointmentToEntity(AppointmentDto dto) {
    final DateTime fallback = DateTime.now().toUtc();
    return Appointment(
      id: dto.id,
      contractId: dto.contractId,
      slotId: dto.slotId,
      professionalEntityId: dto.professionalEntityId,
      clientEntityId: dto.clientEntityId,
      startsAt: (dto.startsAt ?? fallback).toUtc(),
      endsAt: (dto.endsAt ?? fallback).toUtc(),
      status: dto.status,
      rescheduleOf: dto.rescheduleOf,
      idempotencyKey: dto.idempotencyKey,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
    );
  }

  /// Maps an `appointment_events` DTO into a domain [AppointmentEvent].
  static AppointmentEvent eventToEntity(AppointmentEventDto dto) =>
      AppointmentEvent(
        id: dto.id,
        appointmentId: dto.appointmentId,
        contractId: dto.contractId,
        eventType: dto.eventType,
        fromStatus: dto.fromStatus,
        toStatus: dto.toStatus,
        actorId: dto.actorId,
        details: dto.details,
        createdAt: dto.createdAt,
      );

  /// Maps an `availability_list` envelope into domain slots in server order
  /// (verbatim — the client never re-sorts).
  static List<AvailabilitySlot> listEnvelopeToSlots(
    AvailabilityListEnvelopeDto dto,
  ) => dto.slots.map(slotToEntity).toList(growable: false);

  /// Maps an `appointment_reschedule` envelope into the replacement
  /// domain [Appointment] (the row the UI advances to).
  static Appointment rescheduleEnvelopeToEntity(
    AppointmentRescheduleEnvelopeDto dto,
  ) => appointmentToEntity(dto.newAppointment);
}

/// A keyset page of appointments.
class AppointmentPage {
  const AppointmentPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  /// The page items in server order (verbatim).
  final List<Appointment> items;

  /// Whether further pages exist.
  final bool hasMore;

  /// Cursor for the next page, when [hasMore].
  final String? nextCursor;
}
