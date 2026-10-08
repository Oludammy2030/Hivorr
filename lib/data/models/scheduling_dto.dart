/// Data Transfer Objects for the scheduling slice (EP-03-14).
///
/// Mirrors the `availability_upsert` (single slot row), `availability_list`
/// (`{slots[]}` ordered `(weekday, start_time)`), `appointment_book` (single
/// appointment row), `appointment_reschedule`
/// (`{old_appointment?, new_appointment}`), and `appointment_cancel` (single
/// appointment row) projections
/// (`supabase/migrations/20260926090001_service_scheduling_schema.sql`).
/// Reads under plan §7.1 Option B reuse the same row shapes via participant
/// RLS-`SELECT` on `appointments` / `appointment_events`.
class AvailabilitySlotDto {
  const AvailabilitySlotDto({
    required this.id,
    required this.entityId,
    required this.professionId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMin,
    required this.timezone,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory AvailabilitySlotDto.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlotDto(
        id: (json['id'] as String?) ?? '',
        entityId: (json['entity_id'] as String?) ?? '',
        professionId: (json['profession_id'] as String?) ?? '',
        weekday: _parseInt(json['weekday']) ?? 0,
        startTime: _parseTime(json['start_time']),
        endTime: _parseTime(json['end_time']),
        slotDurationMin: _parseInt(json['slot_duration_min']) ?? 60,
        timezone: (json['timezone'] as String?) ?? 'Africa/Lagos',
        isActive: (json['is_active'] as bool?) ?? true,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );

  final String id;
  final String entityId;
  final String professionId;
  final int weekday;
  final String startTime;
  final String endTime;
  final int slotDurationMin;
  final String timezone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static int? _parseInt(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static String _parseTime(Object? v) {
    if (v == null) return '09:00:00';
    if (v is String && v.trim().isNotEmpty) return v;
    return '09:00:00';
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Data Transfer Object for an `appointments` row (EP-03-14).
class AppointmentDto {
  const AppointmentDto({
    required this.id,
    required this.contractId,
    this.slotId,
    required this.professionalEntityId,
    required this.clientEntityId,
    this.startsAt,
    this.endsAt,
    required this.status,
    this.rescheduleOf,
    this.idempotencyKey,
    this.createdAt,
    this.updatedAt,
  });

  factory AppointmentDto.fromJson(Map<String, dynamic> json) => AppointmentDto(
    id: (json['id'] as String?) ?? '',
    contractId: (json['contract_id'] as String?) ?? '',
    slotId: json['slot_id'] as String?,
    professionalEntityId:
        (json['professional_entity_id'] as String?) ?? '',
    clientEntityId: (json['client_entity_id'] as String?) ?? '',
    startsAt: _parseDate(json['starts_at']),
    endsAt: _parseDate(json['ends_at']),
    status: (json['status'] as String?) ?? 'pending',
    rescheduleOf: json['reschedule_of'] as String?,
    idempotencyKey: json['idempotency_key'] as String?,
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
  );

  final String id;
  final String contractId;
  final String? slotId;
  final String professionalEntityId;
  final String clientEntityId;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final String? rescheduleOf;
  final String? idempotencyKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Data Transfer Object for an `appointment_events` row (EP-03-14).
class AppointmentEventDto {
  const AppointmentEventDto({
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

  factory AppointmentEventDto.fromJson(Map<String, dynamic> json) =>
      AppointmentEventDto(
        id: (json['id'] as String?) ?? '',
        appointmentId: (json['appointment_id'] as String?) ?? '',
        contractId: (json['contract_id'] as String?) ?? '',
        eventType: (json['event_type'] as String?) ?? 'booked',
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        actorId: json['actor_id'] as String?,
        details: json['details'] is Map<String, dynamic>
            ? json['details'] as Map<String, dynamic>
            : null,
        createdAt: json['created_at'] is String
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final String appointmentId;
  final String contractId;
  final String eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? actorId;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;
}
