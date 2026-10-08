import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/api/services/base_api_service.dart';
import 'package:hivorr/data/datasources/remote/data_exception_mapper.dart';
import 'package:hivorr/data/datasources/remote/scheduling_envelope_parser.dart';
import 'package:hivorr/data/datasources/remote/scheduling_remote_data_source.dart';
import 'package:hivorr/data/models/scheduling_dto.dart';
import 'package:hivorr/data/models/scheduling_envelopes_dto.dart';

/// Supabase-backed implementation of [SchedulingRemoteDataSource]
/// (EP-03-14 §11).
///
/// Wraps the five scheduling RPCs via `supabase.rpc(...)` and unwraps the
/// standard `{success, code, message, data}` envelope with
/// [SchedulingEnvelopeParser]. Mirrors
/// `SupabaseServiceContractRemoteDataSource` (`_guard(mapDataException)` +
/// `p_*` params). This class never writes scheduling tables directly.
///
/// Reads follow plan §7.1 Option B (zero new SQL): `getAppointment`,
/// `listAppointmentEvents`, and `listAppointments` query
/// `appointments`/`appointment_events` through the injected client under the
/// existing participant `SELECT` RLS; foreign/unknown ids map to `PLT004`
/// not-found (identical, no oracle) to preserve the server contract.
/// `limit` is clamped `1–100` before the query.
class SupabaseSchedulingRemoteDataSource extends BaseApiService
    implements SchedulingRemoteDataSource {
  SupabaseSchedulingRemoteDataSource({
    required super.dio,
    required super.supabase,
    required super.exceptionMapper,
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      throw mapDataException(e);
    }
  }

  @override
  Future<AvailabilitySlotDto> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = 'Africa/Lagos',
    bool isActive = true,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'availability_upsert',
          params: <String, dynamic>{
            'p_profession_id': professionId,
            'p_weekday': weekday,
            'p_start_time': startTime,
            'p_end_time': endTime,
            'p_slot_duration_min': slotDurationMin,
            'p_timezone': timezone,
            'p_is_active': isActive,
          },
        );
    return AvailabilitySlotDto.fromJson(
      SchedulingEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<AvailabilityListEnvelopeDto> listSlots({
    String? entityId,
    String? professionId,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'availability_list',
          params: <String, dynamic>{
            'p_entity_id': ?entityId,
            'p_profession_id': ?professionId,
          },
        );
    return AvailabilityListEnvelopeDto.fromJson(
      SchedulingEnvelopeParser.unwrapList(response),
    );
  });

  @override
  Future<AppointmentDto> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    required String idempotencyKey,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'appointment_book',
          params: <String, dynamic>{
            'p_contract_id': contractId,
            'p_slot_id': ?slotId,
            'p_starts_at': startsAt.toUtc().toIso8601String(),
            'p_ends_at': endsAt.toUtc().toIso8601String(),
            'p_idempotency_key': idempotencyKey,
          },
        );
    return AppointmentDto.fromJson(
      SchedulingEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<AppointmentRescheduleEnvelopeDto> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    required String idempotencyKey,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'appointment_reschedule',
          params: <String, dynamic>{
            'p_appointment_id': appointmentId,
            'p_new_starts_at': newStartsAt.toUtc().toIso8601String(),
            'p_new_ends_at': newEndsAt.toUtc().toIso8601String(),
            'p_idempotency_key': idempotencyKey,
          },
        );
    return AppointmentRescheduleEnvelopeDto.fromJson(
      SchedulingEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<AppointmentDto> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) => _guard(() async {
    final Map<String, dynamic> response = await supabase
        .rpc<Map<String, dynamic>>(
          'appointment_cancel',
          params: <String, dynamic>{
            'p_appointment_id': appointmentId,
            'p_reason': ?reason,
          },
        );
    return AppointmentDto.fromJson(
      SchedulingEnvelopeParser.unwrap(response),
    );
  });

  @override
  Future<AppointmentDto> getAppointment(String appointmentId) =>
      _guard(() async {
        final Map<String, dynamic>? row = await supabase
            .from('appointments')
            .select()
            .eq('id', appointmentId)
            .maybeSingle();
        if (row == null) {
          throw const ApiException(
            kind: ApiExceptionKind.notFound,
            message: 'Appointment not found.',
            code: 'PLT004',
          );
        }
        return AppointmentDto.fromJson(row);
      });

  @override
  Future<List<AppointmentEventDto>> listAppointmentEvents(
    String appointmentId,
  ) => _guard(() async {
    final List<dynamic> rows = await supabase
        .from('appointment_events')
        .select()
        .eq('appointment_id', appointmentId)
        .order('created_at', ascending: true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AppointmentEventDto.fromJson)
        .toList(growable: false);
  });

  @override
  Future<AppointmentPageDto> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  }) => _guard(() async {
    final int clamped = limit < 1 ? 20 : (limit > 100 ? 100 : limit);
    // Unknown cursors yield an empty page (no oracle).
    DateTime? boundary;
    if (cursor != null) {
      boundary = DateTime.tryParse(cursor);
      if (boundary == null) {
        return const AppointmentPageDto(
          items: <AppointmentDto>[],
          hasMore: false,
        );
      }
    }
    // Opaque cursor carries the boundary `starts_at` ISO instant; ids break
    // ties client-side. Each branch keeps the concrete PostgREST builder
    // type (no `dynamic` locals) so `avoid_dynamic_calls` stays clean.
    final String? boundaryIso = boundary?.toUtc().toIso8601String();
    final List<dynamic> rows;
    if (boundaryIso == null && status == null) {
      rows =
          await supabase
              .from('appointments')
              .select()
              .eq('contract_id', contractId)
              .order('starts_at', ascending: false)
              .order('id', ascending: false)
              .limit(clamped + 1)
          as List<dynamic>;
    } else if (boundaryIso == null) {
      rows =
          await supabase
              .from('appointments')
              .select()
              .eq('contract_id', contractId)
              .eq('status', status!)
              .order('starts_at', ascending: false)
              .order('id', ascending: false)
              .limit(clamped + 1)
          as List<dynamic>;
    } else if (status == null) {
      rows =
          await supabase
              .from('appointments')
              .select()
              .eq('contract_id', contractId)
              .lt('starts_at', boundaryIso)
              .order('starts_at', ascending: false)
              .order('id', ascending: false)
              .limit(clamped + 1)
          as List<dynamic>;
    } else {
      rows =
          await supabase
              .from('appointments')
              .select()
              .eq('contract_id', contractId)
              .eq('status', status)
              .lt('starts_at', boundaryIso)
              .order('starts_at', ascending: false)
              .order('id', ascending: false)
              .limit(clamped + 1)
          as List<dynamic>;
    }
    final List<AppointmentDto> items = rows
        .whereType<Map<String, dynamic>>()
        .map(AppointmentDto.fromJson)
        .toList(growable: false);
    final bool hasMore = items.length > clamped;
    final List<AppointmentDto> page = hasMore
        ? items.sublist(0, clamped)
        : items;
    return AppointmentPageDto(
      items: page,
      hasMore: hasMore,
      nextCursor: hasMore
          ? page.last.startsAt?.toUtc().toIso8601String()
          : null,
    );
  });
}
