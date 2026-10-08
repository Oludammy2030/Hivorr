import 'package:hivorr/data/models/scheduling_dto.dart';

/// Envelope for `availability_list` (EP-03-14).
///
/// `data` shape: `{slots[]}` ordered `(weekday, start_time)` server-side.
/// Unknown/foreign entity yields `PLT004` (no oracle), never an empty leak.
class AvailabilityListEnvelopeDto {
  const AvailabilityListEnvelopeDto({required this.slots});

  factory AvailabilityListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['slots'];
    return AvailabilityListEnvelopeDto(
      slots: raw is List
          ? raw
                .whereType<Map<String, dynamic>>()
                .map(AvailabilitySlotDto.fromJson)
                .toList(growable: false)
          : const <AvailabilitySlotDto>[],
    );
  }

  final List<AvailabilitySlotDto> slots;
}

/// Envelope for `appointment_reschedule` (EP-03-14).
///
/// `data` shape: `{old_appointment?, new_appointment}`. The idempotent
/// early-return path carries only `{new_appointment}`.
class AppointmentRescheduleEnvelopeDto {
  const AppointmentRescheduleEnvelopeDto({
    this.oldAppointment,
    required this.newAppointment,
  });

  factory AppointmentRescheduleEnvelopeDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final Object? oldRaw = json['old_appointment'];
    final Object? newRaw = json['new_appointment'];
    return AppointmentRescheduleEnvelopeDto(
      oldAppointment: oldRaw is Map<String, dynamic>
          ? AppointmentDto.fromJson(oldRaw)
          : null,
      newAppointment: AppointmentDto.fromJson(
        newRaw is Map<String, dynamic>
            ? newRaw
            : const <String, dynamic>{},
      ),
    );
  }

  final AppointmentDto? oldAppointment;
  final AppointmentDto newAppointment;
}

/// A keyset page of appointments (client-assembled under §7.1 Option B).
class AppointmentPageDto {
  const AppointmentPageDto({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<AppointmentDto> items;
  final bool hasMore;
  final String? nextCursor;
}
