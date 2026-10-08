// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/scheduling_remote_data_source.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';
import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';
import 'package:hivorr/data/repositories/scheduling_repository.dart';

/// Default implementation of [SchedulingRepository].
///
/// Implements the server-authoritative scheduling flow (EP-03-14 §7): writes
/// via the client-callable scheduling RPCs with client-side fail-fast mirrors
/// of the frozen CHECK constraints (weekday `0–6`, `start < end`, duration
/// `15–480`, IANA-shaped timezone, window `starts > now` / `ends > starts` /
/// `≤ 24h`, reason `≤ 500`), then re-reads the authoritative row. The server
/// remains the single authority; the repository mirrors the codes for
/// fail-fast UX only. Never writes scheduling tables directly
/// (`AGENT.md` Rule 4).
class SchedulingRepositoryImpl implements SchedulingRepository {
  SchedulingRepositoryImpl({required SchedulingRemoteDataSource remote})
    : _remote = remote;

  final SchedulingRemoteDataSource _remote;

  /// Appointment list status filter vocabulary (client may only filter).
  static const Set<String> statuses = <String>{
    'pending',
    'confirmed',
    'completed',
    'cancelled',
    'rescheduled',
  };

  /// Weekday vocabulary (`0 = Sunday … 6 = Saturday`).
  static const Set<int> weekdays = <int>{0, 1, 2, 3, 4, 5, 6};

  @override
  Future<List<AvailabilitySlot>> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = 'Africa/Lagos',
    bool isActive = true,
  }) async {
    _requireNonEmpty(professionId, 'professionId');
    _requireWeekday(weekday);
    _requireTimeRange(startTime, endTime);
    _requireDuration(slotDurationMin);
    _requireTimezone(timezone);
    await _remote.upsertSlot(
      professionId: professionId,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      slotDurationMin: slotDurationMin,
      timezone: timezone,
      isActive: isActive,
    );
    // Re-read the authoritative template (server holds the merged row).
    return listSlots();
  }

  @override
  Future<List<AvailabilitySlot>> listSlots({
    String? entityId,
    String? professionId,
  }) async {
    final AvailabilityListEnvelopeDto dto = await _remote.listSlots(
      entityId: entityId,
      professionId: professionId,
    );
    return SchedulingMapper.listEnvelopeToSlots(dto);
  }

  @override
  Future<Appointment> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String idempotencyKey,
  }) async {
    _requireNonEmpty(contractId, 'contractId');
    _requireNonEmpty(idempotencyKey, 'idempotencyKey');
    _requireWindow(startsAt, endsAt);
    final AppointmentDto dto = await _remote.bookAppointment(
      contractId: contractId,
      slotId: slotId,
      startsAt: startsAt,
      endsAt: endsAt,
      idempotencyKey: idempotencyKey,
    );
    // Re-read the authoritative row (server holds status + audit event).
    return getAppointment(dto.id);
  }

  @override
  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    required String idempotencyKey,
  }) async {
    _requireNonEmpty(appointmentId, 'appointmentId');
    _requireNonEmpty(idempotencyKey, 'idempotencyKey');
    _requireWindow(newStartsAt, newEndsAt);
    final AppointmentRescheduleEnvelopeDto dto = await _remote
        .rescheduleAppointment(
          appointmentId: appointmentId,
          newStartsAt: newStartsAt,
          newEndsAt: newEndsAt,
          idempotencyKey: idempotencyKey,
        );
    return getAppointment(dto.newAppointment.id);
  }

  @override
  Future<Appointment> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    _requireNonEmpty(appointmentId, 'appointmentId');
    if (reason != null && reason.trim().length > 500) {
      _fail('Cancel reason must be at most 500 characters.');
    }
    await _remote.cancelAppointment(appointmentId, reason: reason);
    return getAppointment(appointmentId);
  }

  @override
  Future<Appointment> getAppointment(String appointmentId) async {
    _requireNonEmpty(appointmentId, 'appointmentId');
    final AppointmentDto dto = await _remote.getAppointment(appointmentId);
    return SchedulingMapper.appointmentToEntity(dto);
  }

  @override
  Future<List<AppointmentEvent>> listAppointmentEvents(
    String appointmentId,
  ) async {
    _requireNonEmpty(appointmentId, 'appointmentId');
    final List<AppointmentEventDto> dtos = await _remote
        .listAppointmentEvents(appointmentId);
    return dtos.map(SchedulingMapper.eventToEntity).toList(growable: false);
  }

  @override
  Future<AppointmentPage> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    _requireNonEmpty(contractId, 'contractId');
    if (status != null) _requireInVocabulary(status, statuses, 'status');
    _requireLimit(limit);
    final AppointmentPageDto dto = await _remote.listAppointments(
      contractId: contractId,
      status: status,
      limit: limit,
      cursor: cursor,
    );
    return AppointmentPage(
      items: dto.items.map(SchedulingMapper.appointmentToEntity).toList(),
      hasMore: dto.hasMore,
      nextCursor: dto.nextCursor,
    );
  }

  void _requireWeekday(int weekday) {
    if (!weekdays.contains(weekday)) {
      _fail('Weekday must be between 0 and 6.');
    }
  }

  void _requireTimeRange(String start, String end) {
    if (start.trim().isEmpty || end.trim().isEmpty) {
      _fail('Start and end time are required.');
    }
    if (start.trim().compareTo(end.trim()) >= 0) {
      _fail('Start time must be before end time.');
    }
  }

  void _requireDuration(int minutes) {
    if (minutes < 15 || minutes > 480) {
      _fail('Slot duration must be between 15 and 480 minutes.');
    }
  }

  void _requireTimezone(String timezone) {
    final String value = timezone.trim();
    if (value.isEmpty) _fail('Timezone is required.');
    if (!RegExp(r'^[A-Za-z/_]+$').hasMatch(value)) {
      _fail('Invalid timezone.');
    }
  }

  void _requireWindow(DateTime startsAt, DateTime endsAt) {
    if (!endsAt.isAfter(startsAt)) {
      _fail('Start time must be before end time.');
    }
    if (!startsAt.isAfter(DateTime.now())) {
      _fail('Start time must be in the future.');
    }
    if (endsAt.difference(startsAt) > const Duration(hours: 24)) {
      _fail('Appointment duration must not exceed 24 hours.');
    }
  }

  void _requireLimit(int limit) {
    if (limit < 1 || limit > 100) {
      _fail('Limit must be between 1 and 100.');
    }
  }

  static void _fail(String message) {
    throw ApiException(
      kind: ApiExceptionKind.validation,
      message: message,
      code: 'PLT003',
    );
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      _fail('$field is required.');
    }
  }

  static void _requireInVocabulary(
    String value,
    Set<String> vocabulary,
    String field,
  ) {
    if (!vocabulary.contains(value)) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid $field value: $value.',
        code: 'PLT003',
      );
    }
  }
}
