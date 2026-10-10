import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/scheduling_remote_data_source.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';
import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';
import 'package:hivorr/data/repositories/scheduling_repository.dart';

/// Builds an `availability_slots`-shaped row for fakes.
Map<String, dynamic> availabilitySlotRow({
  required String id,
  String entityId = 'pro-1',
  String professionId = 'profession-1',
  int weekday = 1,
  String startTime = '09:00:00',
  String endTime = '12:00:00',
  int duration = 60,
  String timezone = 'Africa/Lagos',
  bool isActive = true,
}) => <String, dynamic>{
  'id': id,
  'entity_id': entityId,
  'profession_id': professionId,
  'weekday': weekday,
  'start_time': startTime,
  'end_time': endTime,
  'slot_duration_min': duration,
  'timezone': timezone,
  'is_active': isActive,
};

/// Builds an `appointments`-shaped row for fakes.
Map<String, dynamic> appointmentRow({
  required String id,
  String contractId = 'contract-1',
  String? slotId,
  String professionalId = 'pro-1',
  String clientId = 'client-1',
  String startsAt = '2030-10-06T09:00:00.000Z',
  String endsAt = '2030-10-06T10:00:00.000Z',
  String status = 'pending',
  String? rescheduleOf,
  String? idempotencyKey,
}) => <String, dynamic>{
  'id': id,
  'contract_id': contractId,
  'slot_id': slotId,
  'professional_entity_id': professionalId,
  'client_entity_id': clientId,
  'starts_at': startsAt,
  'ends_at': endsAt,
  'status': status,
  'reschedule_of': rescheduleOf,
  'idempotency_key': idempotencyKey ?? 'key-$id',
};

/// Builds an `appointment_events`-shaped row for fakes.
Map<String, dynamic> appointmentEventRow({
  required String id,
  required String appointmentId,
  String contractId = 'contract-1',
  String eventType = 'booked',
  String? fromStatus,
  String? toStatus = 'pending',
}) => <String, dynamic>{
  'id': id,
  'appointment_id': appointmentId,
  'contract_id': contractId,
  'event_type': eventType,
  'from_status': fromStatus,
  'to_status': toStatus,
  'created_at': '2030-10-05T10:00:00.000Z',
};

/// In-memory fake for [SchedulingRemoteDataSource] (EP-03-14 tests).
class FakeSchedulingRemoteDataSource implements SchedulingRemoteDataSource {
  FakeSchedulingRemoteDataSource({
    List<Map<String, dynamic>>? slots,
    List<Map<String, dynamic>>? appointments,
    List<Map<String, dynamic>>? events,
  }) : _slots = <Map<String, dynamic>>[...?slots],
       _appointments = <Map<String, dynamic>>[...?appointments],
       _events = <Map<String, dynamic>>[...?events];

  final List<Map<String, dynamic>> _slots;
  final List<Map<String, dynamic>> _appointments;
  final List<Map<String, dynamic>> _events;

  int upsertCalls = 0;
  int listSlotsCalls = 0;
  int bookCalls = 0;
  int rescheduleCalls = 0;
  int cancelCalls = 0;
  int getCalls = 0;
  int listEventsCalls = 0;
  int listAppointmentsCalls = 0;
  String? lastStatus;
  String? lastCursor;

  /// Simulates the server `EXCLUDE` overlap guard when `true`.
  bool overlapNextBook = false;

  Map<String, dynamic> _findAppointment(String id) =>
      _appointments.firstWhere(
        (Map<String, dynamic> e) => e['id'] == id,
        orElse: () => throw const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Appointment not found.',
          code: 'PLT004',
        ),
      );

  @override
  Future<AvailabilitySlotDto> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = 'Africa/Lagos',
    bool isActive = true,
  }) async {
    upsertCalls++;
    final int existing = _slots.indexWhere(
      (Map<String, dynamic> e) =>
          e['profession_id'] == professionId &&
          e['weekday'] == weekday &&
          e['start_time'] == startTime,
    );
    final Map<String, dynamic> row = availabilitySlotRow(
      id: existing >= 0
          ? _slots[existing]['id'] as String
          : 'slot-${_slots.length + 1}',
      professionId: professionId,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      duration: slotDurationMin,
      timezone: timezone,
      isActive: isActive,
    );
    if (existing >= 0) {
      _slots[existing] = row;
    } else {
      _slots.add(row);
    }
    return AvailabilitySlotDto.fromJson(row);
  }

  @override
  Future<AvailabilityListEnvelopeDto> listSlots({
    String? entityId,
    String? professionId,
  }) async {
    listSlotsCalls++;
    final List<Map<String, dynamic>> filtered = _slots.where((
      Map<String, dynamic> e,
    ) {
      if (professionId != null && e['profession_id'] != professionId) {
        return false;
      }
      return e['is_active'] == true;
    }).toList();
    return AvailabilityListEnvelopeDto.fromJson(
      <String, dynamic>{'slots': filtered},
    );
  }

  @override
  Future<AppointmentDto> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String idempotencyKey,
  }) async {
    bookCalls++;
    // Idempotent replay: same key returns the existing row.
    for (final Map<String, dynamic> existing in _appointments) {
      if (existing['idempotency_key'] == idempotencyKey) {
        return AppointmentDto.fromJson(existing);
      }
    }
    if (overlapNextBook) {
      overlapNextBook = false;
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Slot taken. Pick another time.',
        code: 'PLT005',
      );
    }
    final Map<String, dynamic> row = appointmentRow(
      id: 'appt-${_appointments.length + 1}',
      contractId: contractId,
      slotId: slotId,
      startsAt: startsAt.toUtc().toIso8601String(),
      endsAt: endsAt.toUtc().toIso8601String(),
      idempotencyKey: idempotencyKey,
    );
    _appointments.insert(0, row);
    _events.add(
      appointmentEventRow(
        id: 'ev-${_events.length + 1}',
        appointmentId: row['id'] as String,
        contractId: contractId,
      ),
    );
    return AppointmentDto.fromJson(row);
  }

  @override
  Future<AppointmentRescheduleEnvelopeDto> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    required String idempotencyKey,
  }) async {
    rescheduleCalls++;
    for (final Map<String, dynamic> existing in _appointments) {
      if (existing['idempotency_key'] == idempotencyKey) {
        return AppointmentRescheduleEnvelopeDto.fromJson(
          <String, dynamic>{
            'new_appointment': existing,
          },
        );
      }
    }
    final Map<String, dynamic> old = _findAppointment(appointmentId);
    if (old['status'] != 'pending' && old['status'] != 'confirmed') {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Only pending or confirmed appointments can be rescheduled.',
        code: 'PLT005',
      );
    }
    old['status'] = 'rescheduled';
    final Map<String, dynamic> fresh = appointmentRow(
      id: 'appt-${_appointments.length + 1}',
      contractId: old['contract_id'] as String,
      slotId: old['slot_id'] as String?,
      professionalId: old['professional_entity_id'] as String,
      clientId: old['client_entity_id'] as String,
      startsAt: newStartsAt.toUtc().toIso8601String(),
      endsAt: newEndsAt.toUtc().toIso8601String(),
      rescheduleOf: appointmentId,
      idempotencyKey: idempotencyKey,
    );
    _appointments.insert(0, fresh);
    return AppointmentRescheduleEnvelopeDto.fromJson(
      <String, dynamic>{
        'old_appointment': old,
        'new_appointment': fresh,
      },
    );
  }

  @override
  Future<AppointmentDto> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    cancelCalls++;
    final Map<String, dynamic> row = _findAppointment(appointmentId);
    if (row['status'] != 'pending' && row['status'] != 'confirmed') {
      throw const ApiException(
        kind: ApiExceptionKind.conflict,
        message: 'Only pending or confirmed appointments can be cancelled.',
        code: 'PLT005',
      );
    }
    row['status'] = 'cancelled';
    return AppointmentDto.fromJson(row);
  }

  @override
  Future<AppointmentDto> getAppointment(String appointmentId) async {
    getCalls++;
    return AppointmentDto.fromJson(_findAppointment(appointmentId));
  }

  @override
  Future<List<AppointmentEventDto>> listAppointmentEvents(
    String appointmentId,
  ) async {
    listEventsCalls++;
    return _events
        .where(
          (Map<String, dynamic> e) => e['appointment_id'] == appointmentId,
        )
        .map(AppointmentEventDto.fromJson)
        .toList(growable: false);
  }

  @override
  Future<AppointmentPageDto> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    listAppointmentsCalls++;
    lastStatus = status;
    lastCursor = cursor;
    final List<Map<String, dynamic>> filtered = _appointments.where((
      Map<String, dynamic> e,
    ) {
      if (e['contract_id'] != contractId) return false;
      if (status != null && e['status'] != status) return false;
      return true;
    }).toList();
    final bool hasMore = filtered.length > limit;
    return AppointmentPageDto(
      items: (hasMore ? filtered.sublist(0, limit) : filtered)
          .map(AppointmentDto.fromJson)
          .toList(growable: false),
      hasMore: hasMore,
      nextCursor: hasMore ? 'cursor-${filtered.length}' : null,
    );
  }
}

/// In-memory fake for [SchedulingRepository] (EP-03-14 tests).
class FakeSchedulingRepository implements SchedulingRepository {
  FakeSchedulingRepository({
    List<AvailabilitySlot>? slots,
    List<Appointment>? appointments,
    this.listHasMore = false,
  }) : _slots = <AvailabilitySlot>[...?slots],
       _appointments = <Appointment>[...?appointments];

  final List<AvailabilitySlot> _slots;
  final List<Appointment> _appointments;

  /// Whether the first `listAppointments` page reports a further page.
  /// Follow-up pages (non-null `cursor`) return empty, modelling keyset
  /// exhaustion without duplicating ids.
  bool listHasMore;

  int upsertCalls = 0;
  int bookCalls = 0;
  int rescheduleCalls = 0;
  int cancelCalls = 0;
  String? lastStatus;

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
    upsertCalls++;
    _slots.add(
      AvailabilitySlot(
        id: 'slot-${_slots.length + 1}',
        entityId: 'pro-1',
        professionId: professionId,
        weekday: weekday,
        startTime: startTime,
        endTime: endTime,
        slotDurationMin: slotDurationMin,
        timezone: timezone,
        isActive: isActive,
      ),
    );
    return List<AvailabilitySlot>.unmodifiable(_slots);
  }

  @override
  Future<List<AvailabilitySlot>> listSlots({
    String? entityId,
    String? professionId,
  }) async => List<AvailabilitySlot>.unmodifiable(_slots);

  @override
  Future<Appointment> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String idempotencyKey,
  }) async {
    bookCalls++;
    final Appointment created = Appointment(
      id: 'appt-${_appointments.length + 1}',
      contractId: contractId,
      slotId: slotId,
      professionalEntityId: 'pro-1',
      clientEntityId: 'client-1',
      startsAt: startsAt,
      endsAt: endsAt,
      status: 'pending',
      idempotencyKey: idempotencyKey,
    );
    _appointments.insert(0, created);
    return created;
  }

  @override
  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    required String idempotencyKey,
  }) async {
    rescheduleCalls++;
    final Appointment fresh = Appointment(
      id: 'appt-${_appointments.length + 1}',
      contractId: 'contract-1',
      professionalEntityId: 'pro-1',
      clientEntityId: 'client-1',
      startsAt: newStartsAt,
      endsAt: newEndsAt,
      status: 'pending',
      rescheduleOf: appointmentId,
      idempotencyKey: idempotencyKey,
    );
    _appointments.insert(0, fresh);
    return fresh;
  }

  @override
  Future<Appointment> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    cancelCalls++;
    final DateTime now = DateTime.utc(2030, 10, 6, 9);
    final Appointment cancelled = Appointment(
      id: appointmentId,
      contractId: 'contract-1',
      professionalEntityId: 'pro-1',
      clientEntityId: 'client-1',
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      status: 'cancelled',
    );
    return cancelled;
  }

  @override
  Future<Appointment> getAppointment(String appointmentId) async =>
      _appointments.firstWhere(
        (Appointment a) => a.id == appointmentId,
        orElse: () => throw const ApiException(
          kind: ApiExceptionKind.notFound,
          message: 'Appointment not found.',
          code: 'PLT004',
        ),
      );

  @override
  Future<List<AppointmentEvent>> listAppointmentEvents(
    String appointmentId,
  ) async => const <AppointmentEvent>[];

  @override
  Future<AppointmentPage> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    lastStatus = status;
    if (cursor != null) {
      return const AppointmentPage(items: <Appointment>[], hasMore: false);
    }
    final List<Appointment> filtered = _appointments
        .where(
          (Appointment a) =>
              a.contractId == contractId &&
              (status == null || a.status == status),
        )
        .toList(growable: false);
    return AppointmentPage(
      items: filtered,
      hasMore: listHasMore,
      nextCursor: listHasMore ? 'cursor-1' : null,
    );
  }
}
