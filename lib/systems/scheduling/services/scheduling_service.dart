// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/logging/pii_redactor.dart';
import 'package:hivorr/core/monitoring/performance_tracer.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';
import 'package:hivorr/data/repositories/scheduling_repository.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SpanStatus;
import 'package:uuid/uuid.dart';

/// Thin facade over [SchedulingRepository] consumed by [SchedulingProvider]
/// and the scheduling screens (EP-03-14 §8 D6).
///
/// Exposes the weekday/appointment/event vocabularies (compile-time const,
/// mirroring the frozen CHECK constraints) plus the fail-fast validators
/// [validateWeekday]/[validateTimeRange]/[validateDuration]/[validateTimezone]/
/// [validateWindow]/[validateReason], and delegates data operations to the
/// repository. Adds PII-safe structured [HivorrLogger] output (ids suffix-only
/// — never full `idempotency_key` chains or participant lists) and
/// `scheduling.*` [PerformanceTracer] spans.
///
/// Idempotency orchestration: [bookAppointment]/[rescheduleAppointment] accept
/// an optional caller key and mint `Uuid().v4()` when absent, so every user
/// gesture carries exactly one key that double-tap and retry reuse. This
/// service never decides overlap, status, or timezone authority — the server
/// does (`AGENT.md` Rule 4).
class SchedulingService {
  SchedulingService({
    required SchedulingRepository repository,
    HivorrLogger? logger,
    PerformanceTracer? tracer,
    PiiRedactor? redactor,
  }) : _repository = repository,
       _logger = logger,
       _tracer = tracer,
       _redactor = redactor ?? PiiRedactor();

  final SchedulingRepository _repository;
  final HivorrLogger? _logger;
  final PerformanceTracer? _tracer;
  final PiiRedactor _redactor;

  // ─── Vocabulary (matches frozen CHECK constraints) ────────────────────

  /// Weekday vocabulary (`availability_slots_weekday_range`, `0 = Sunday`).
  static const List<int> weekdays = <int>[0, 1, 2, 3, 4, 5, 6];

  /// Appointment status vocabulary (`appointments_status_allowed`).
  static const List<String> appointmentStatuses = <String>[
    'pending',
    'confirmed',
    'completed',
    'cancelled',
    'rescheduled',
  ];

  /// Appointment event vocabulary (`appointment_events_event_type_allowed`).
  static const List<String> eventTypes = <String>[
    'booked',
    'confirmed',
    'rescheduled',
    'cancelled',
    'completed',
  ];

  /// Slot duration presets offered by the editor stepper (all within
  /// the server `15–480` range).
  static const List<int> durationPresets = <int>[15, 30, 45, 60, 120];

  /// Default timezone hint for new template rows.
  static const String defaultTimezone = 'Africa/Lagos';

  // ─── Fail-fast validators (mirror CHECKs; server stays authoritative) ──

  /// `true` when [weekday] is `0–6`.
  static bool validateWeekday(int? weekday) =>
      weekday != null && weekday >= 0 && weekday <= 6;

  /// `true` when [startTime] is non-blank and strictly before [endTime].
  static bool validateTimeRange(String? startTime, String? endTime) {
    if (startTime == null ||
        endTime == null ||
        startTime.trim().isEmpty ||
        endTime.trim().isEmpty) {
      return false;
    }
    return startTime.trim().compareTo(endTime.trim()) < 0;
  }

  /// `true` when [minutes] is within the server `15–480` range.
  static bool validateDuration(int? minutes) =>
      minutes != null && minutes >= 15 && minutes <= 480;

  /// `true` when [timezone] is non-blank and IANA-shaped
  /// (`^[A-Za-z/_]+$`; server checks `pg_timezone_names`).
  static bool validateTimezone(String? timezone) {
    if (timezone == null || timezone.trim().isEmpty) return false;
    return RegExp(r'^[A-Za-z/_]+$').hasMatch(timezone.trim());
  }

  /// `true` when the window starts in the future, ends after it starts, and
  /// spans at most 24 hours.
  static bool validateWindow(DateTime? startsAt, DateTime? endsAt) {
    if (startsAt == null || endsAt == null) return false;
    if (!endsAt.isAfter(startsAt)) return false;
    if (!startsAt.isAfter(DateTime.now())) return false;
    if (endsAt.difference(startsAt) > const Duration(hours: 24)) {
      return false;
    }
    return true;
  }

  /// `true` when [reason] is absent or at most 500 chars after trim.
  static bool validateReason(String? reason) {
    if (reason == null || reason.trim().isEmpty) return true;
    return reason.trim().length <= 500;
  }

  /// Short weekday label for chip rows (`0 = Sunday`).
  static String weekdayLabel(int weekday) {
    switch (weekday) {
      case 0:
        return 'Sun';
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      default:
        return 'Day $weekday';
    }
  }

  // ─── Data operations (delegate to repository, traced + logged) ─────────

  Future<List<AvailabilitySlot>> listSlots({
    String? entityId,
    String? professionId,
  }) => _tracedAndLogged('scheduling.slots.list', () async {
    final slots = await _repository.listSlots(
      entityId: entityId,
      professionId: professionId,
    );
    _logger?.info('Scheduling slots fetched', <String, Object?>{
      'slotCount': slots.length,
    });
    return slots;
  });

  Future<List<AvailabilitySlot>> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = defaultTimezone,
    bool isActive = true,
  }) => _tracedAndLogged('scheduling.slots.upsert', () async {
    _logger?.info('Saving availability slot', <String, Object?>{
      'weekday': weekday,
      'slotDurationMin': slotDurationMin,
    });
    final slots = await _repository.upsertSlot(
      professionId: professionId,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      slotDurationMin: slotDurationMin,
      timezone: timezone,
      isActive: isActive,
    );
    _logger?.info('Availability slot saved', <String, Object?>{
      'slotCount': slots.length,
    });
    return slots;
  });

  Future<AppointmentPage> listAppointments({
    required String contractId,
    String? status,
    int limit = 20,
    String? cursor,
  }) => _tracedAndLogged('scheduling.appointments.list', () async {
    final page = await _repository.listAppointments(
      contractId: contractId,
      status: status,
      limit: limit,
      cursor: cursor,
    );
    _logger?.info('Appointments fetched', <String, Object?>{
      'contractId': _redactor.redact(contractId),
      'appointmentCount': page.items.length,
      'hasMore': page.hasMore,
    });
    return page;
  });

  Future<Appointment> getAppointment(String appointmentId) =>
      _tracedAndLogged('scheduling.appointments.get', () async {
        final appointment = await _repository.getAppointment(appointmentId);
        _logger?.info('Appointment detail fetched', <String, Object?>{
          'appointmentId': _redactor.redact(appointment.id),
          'status': appointment.status,
        });
        return appointment;
      });

  Future<List<AppointmentEvent>> listAppointmentEvents(
    String appointmentId,
  ) => _tracedAndLogged('scheduling.appointments.events', () async {
    return _repository.listAppointmentEvents(appointmentId);
  });

  /// Books a window, minting one `uuid v4` idempotency key when the caller
  /// does not supply one. Double-tap/retry must reuse the same key — the
  /// caller holds the returned appointment's key for retries.
  Future<Appointment> bookAppointment({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? idempotencyKey,
  }) => _tracedAndLogged('scheduling.appointments.book', () async {
    final String key = idempotencyKey ?? const Uuid().v4();
    _logger?.info('Booking appointment', <String, Object?>{
      'contractId': _redactor.redact(contractId),
    });
    final appointment = await _repository.bookAppointment(
      contractId: contractId,
      slotId: slotId,
      startsAt: startsAt,
      endsAt: endsAt,
      idempotencyKey: key,
    );
    _logger?.info('Appointment booked', <String, Object?>{
      'appointmentId': _redactor.redact(appointment.id),
      'status': appointment.status,
    });
    return appointment;
  });

  /// Reschedules an appointment, minting one `uuid v4` idempotency key when
  /// the caller does not supply one.
  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    String? idempotencyKey,
  }) => _tracedAndLogged('scheduling.appointments.reschedule', () async {
    final String key = idempotencyKey ?? const Uuid().v4();
    final Appointment appointment = await _repository.rescheduleAppointment(
      appointmentId: appointmentId,
      newStartsAt: newStartsAt,
      newEndsAt: newEndsAt,
      idempotencyKey: key,
    );
    _logger?.info('Appointment rescheduled', <String, Object?>{
      'appointmentId': _redactor.redact(appointment.id),
      'status': appointment.status,
    });
    return appointment;
  });

  Future<Appointment> cancelAppointment(
    String appointmentId, {
    String? reason,
  }) => _tracedAndLogged('scheduling.appointments.cancel', () async {
    final appointment = await _repository.cancelAppointment(
      appointmentId,
      reason: reason,
    );
    _logger?.info('Appointment cancelled', <String, Object?>{
      'appointmentId': _redactor.redact(appointment.id),
      'status': appointment.status,
    });
    return appointment;
  });

  /// Wraps [action] in a `scheduling.*` [PerformanceTracer] span and
  /// surfaces failures via the logger with redacted context.
  Future<T> _tracedAndLogged<T>(
    String name,
    Future<T> Function() action,
  ) async {
    final span = _tracer?.startTransaction(name, 'scheduling');
    try {
      final T result = await action();
      await _tracer?.finishSpan(span, status: const SpanStatus.ok());
      return result;
    } catch (error, stackTrace) {
      await _tracer?.finishSpan(span, status: const SpanStatus.internalError());
      _logger?.error(
        '$name failed',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{'span': name},
      );
      rethrow;
    }
  }
}
