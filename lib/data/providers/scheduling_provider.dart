// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/appointment.dart';
import 'package:hivorr/data/entities/appointment_event.dart';
import 'package:hivorr/data/entities/availability_slot.dart';
import 'package:hivorr/data/mappers/scheduling_mapper.dart';
import 'package:hivorr/systems/scheduling/services/scheduling_service.dart';

/// Load lifecycle of the scheduling provider (EP-03-14 §8 D5).
enum SchedulingLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing scheduling state to the widget tree (EP-03-14).
///
/// Depends only on the [SchedulingService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized availability template +
/// per-contract appointment list + selection (appointment with events), keyset
/// pagination (`(starts_at DESC, id DESC)` via opaque cursor), an optional
/// status filter, and a [WidgetsBindingObserver] lifecycle gate (no background
/// refreshes — [pausePolling]/[resumePolling]). Mirrors
/// `ServiceContractProvider` list/select/refresh shape.
class SchedulingProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  SchedulingProvider({required SchedulingService service, HivorrLogger? logger})
    : _service = service,
      _logger = logger {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final SchedulingService _service;
  final HivorrLogger? _logger;

  List<AvailabilitySlot> _slots = const <AvailabilitySlot>[];
  List<Appointment> _appointments = const <Appointment>[];
  Appointment? _selected;
  List<AppointmentEvent> _selectedEvents = const <AppointmentEvent>[];
  SchedulingLoadState _loadState = SchedulingLoadState.idle;
  ApiException? _error;
  String? _statusFilter;
  String? _contractId;
  bool _hasMore = false;
  String? _nextCursor;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Template slots in server order (verbatim).
  List<AvailabilitySlot> get slots => _slots;

  /// Appointments for the current contract in server order (verbatim).
  List<Appointment> get appointments => _appointments;

  /// The selected appointment, or `null`.
  Appointment? get selected => _selected;

  /// Events for the selection in `created_at` order (verbatim).
  List<AppointmentEvent> get selectedEvents => _selectedEvents;

  /// The load lifecycle state.
  SchedulingLoadState get loadState => _loadState;

  /// Whether a load is in flight.
  bool get isLoading => _loadState == SchedulingLoadState.loading;

  /// Whether the latest load succeeded.
  bool get isLoaded => _loadState == SchedulingLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// Whether the current appointment page is empty.
  bool get isEmpty =>
      _loadState == SchedulingLoadState.loaded && _appointments.isEmpty;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// The active status filter (`null` means all).
  String? get statusFilter => _statusFilter;

  /// Whether another page exists.
  bool get hasMore => _hasMore;

  /// Opaque cursor for the next page.
  String? get nextCursor => _nextCursor;

  /// Fetches template slots without touching load state (for auxiliary
  /// lookups such as the detail timezone caption).
  Future<List<AvailabilitySlot>> fetchSlots({
    String? entityId,
    String? professionId,
  }) => _service.listSlots(entityId: entityId, professionId: professionId);

  /// Loads the template for [entityId] (self when `null`), optionally scoped
  /// to [professionId].
  Future<void> loadSlots({String? entityId, String? professionId}) async {
    if (isLoading) return;
    _loadState = SchedulingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _slots = await _service.listSlots(
        entityId: entityId,
        professionId: professionId,
      );
      _loadState = SchedulingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = SchedulingLoadState.error;
      _logger?.warning('Scheduling slots load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads appointments for [contractId], optionally filtered by [status].
  Future<void> loadAppointments({
    required String contractId,
    String? status,
    bool refresh = false,
  }) async {
    if (isLoading) return;
    if (!refresh) {
      _contractId = contractId;
      _statusFilter = status;
    }
    _loadState = SchedulingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final AppointmentPage page = await _service.listAppointments(
        contractId: _contractId ?? contractId,
        status: _statusFilter,
        limit: 20,
      );
      _appointments = page.items;
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = SchedulingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = SchedulingLoadState.error;
      _logger?.warning('Scheduling appointments load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the next page using [nextCursor] (no-op when exhausted).
  Future<void> loadMore() async {
    final String? contractId = _contractId;
    if (_hasMore == false ||
        _nextCursor == null ||
        contractId == null ||
        _loadState == SchedulingLoadState.loading) {
      return;
    }
    final String cursor = _nextCursor!;
    _loadState = SchedulingLoadState.loading;
    notifyListeners();
    try {
      final AppointmentPage page = await _service.listAppointments(
        contractId: contractId,
        status: _statusFilter,
        limit: 20,
        cursor: cursor,
      );
      _appointments = <Appointment>[..._appointments, ...page.items];
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
      _loadState = SchedulingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = SchedulingLoadState.error;
      _logger?.warning('Scheduling appointments load-more failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail (appointment + events) for [appointmentId].
  Future<void> select(String appointmentId) async {
    if (isLoading) return;
    if (_selected?.id == appointmentId && isLoaded) return;
    _loadState = SchedulingLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _selected = await _service.getAppointment(appointmentId);
      _selectedEvents = await _service.listAppointmentEvents(appointmentId);
      _loadState = SchedulingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = SchedulingLoadState.error;
      _logger?.warning('Scheduling appointment detail load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final Appointment? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      _selected = await _service.getAppointment(current.id);
      _selectedEvents = await _service.listAppointmentEvents(current.id);
      _loadState = SchedulingLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = SchedulingLoadState.error;
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Saves a template row and refreshes the memoized template.
  Future<List<AvailabilitySlot>> upsertSlot({
    required String professionId,
    required int weekday,
    required String startTime,
    required String endTime,
    int slotDurationMin = 60,
    String timezone = 'Africa/Lagos',
    bool isActive = true,
  }) async {
    final List<AvailabilitySlot> slots = await _service.upsertSlot(
      professionId: professionId,
      weekday: weekday,
      startTime: startTime,
      endTime: endTime,
      slotDurationMin: slotDurationMin,
      timezone: timezone,
      isActive: isActive,
    );
    _slots = slots;
    if (!_disposed) notifyListeners();
    return slots;
  }

  /// Books a window and prepends the authoritative appointment.
  Future<Appointment> book({
    required String contractId,
    String? slotId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? idempotencyKey,
  }) async {
    final Appointment created = await _service.bookAppointment(
      contractId: contractId,
      slotId: slotId,
      startsAt: startsAt,
      endsAt: endsAt,
      idempotencyKey: idempotencyKey,
    );
    _appointments = <Appointment>[created, ..._appointments];
    _selected = created;
    if (!_disposed) notifyListeners();
    return created;
  }

  /// Reschedules the selected/known appointment and syncs memoized state.
  Future<Appointment> reschedule(
    String appointmentId, {
    required DateTime newStartsAt,
    required DateTime newEndsAt,
    String? idempotencyKey,
  }) async {
    final Appointment updated = await _service.rescheduleAppointment(
      appointmentId: appointmentId,
      newStartsAt: newStartsAt,
      newEndsAt: newEndsAt,
      idempotencyKey: idempotencyKey,
    );
    _applyUpdated(updated);
    return updated;
  }

  /// Cancels the selected/known appointment and syncs memoized state.
  Future<Appointment> cancel(String appointmentId, {String? reason}) async {
    final Appointment updated = await _service.cancelAppointment(
      appointmentId,
      reason: reason,
    );
    _applyUpdated(updated);
    return updated;
  }

  void _applyUpdated(Appointment updated) {
    _appointments = _appointments
        .map((Appointment a) => a.id == updated.id ? updated : a)
        .toList(growable: false);
    if (_selected?.id == updated.id) _selected = updated;
    if (!_disposed) notifyListeners();
  }

  /// Suspends background refresh (lifecycle pause).
  void pausePolling() => _paused = true;

  /// Resumes background refresh (lifecycle resume).
  void resumePolling() => _paused = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      resumePolling();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // No binding attached — nothing to detach.
    }
    super.dispose();
  }
}
