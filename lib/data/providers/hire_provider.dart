// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';

/// Notification channel used for hiring lifecycle events (EP-04-02).
abstract final class HireNotificationChannel {
  const HireNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the hiring provider (EP-04-02).
enum HireLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing quotations and hires state to the widget tree (EP-04-02).
///
/// Depends only on the [HireService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized hire list + selection
/// (hire, effective status, quotation, contract), a [WidgetsBindingObserver]
/// lifecycle gate (no background refreshes), and a local "hired" / "hire
/// completed" [HivorrNotification] hook (mirrors `DisputeProvider`).
class HireProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the hiring notification hook; [logger]
  /// enables PII-safe structured logging; [clock] is injectable for
  /// deterministic tests.
  HireProvider({
    required HireService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  }) : _service = service,
       _logger = logger,
       _notificationProvider = notificationProvider,
       _clock = clock ?? DateTime.now {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final HireService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final DateTime Function() _clock;

  List<Hire> _hires = const <Hire>[];
  Hire? _selected;
  String? _selectedEffectiveStatus;
  JobQuotation? _selectedQuotation;
  String? _selectedContractId;
  String? _selectedContractStatus;
  HireLoadState _loadState = HireLoadState.idle;
  ApiException? _error;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Hires loaded for the current list scope.
  List<Hire> get hires => _hires;

  /// The selected hire, or `null` before [select].
  Hire? get selected => _selected;

  /// Contract-derived live status of the selected hire.
  String? get selectedEffectiveStatus => _selectedEffectiveStatus;

  /// The chosen quotation of the selected hire, when the hire used one.
  JobQuotation? get selectedQuotation => _selectedQuotation;

  /// The linked contract id of the selected hire, when set.
  String? get selectedContractId => _selectedContractId;

  /// The linked contract status of the selected hire, when present.
  String? get selectedContractStatus => _selectedContractStatus;

  /// The load lifecycle state.
  HireLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == HireLoadState.loading;

  /// Whether the latest load/refresh succeeded.
  bool get isLoaded => _loadState == HireLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Loads the hire list, optionally filtered by [role] and [status].
  Future<void> loadList({String? role, String? status}) async {
    if (isLoading) return;
    _loadState = HireLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      final HirePage page = await _service.listMyHires(
        role: role,
        status: status,
      );
      _hires = page.hires;
      _loadState = HireLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = HireLoadState.error;
      _logger?.warning('Hire list load failed', <String, Object?>{
        'role': role,
        'statusFilter': status,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail for [hireId] in one RPC.
  Future<void> select(String hireId) async {
    if (isLoading) return;
    if (_selected?.id == hireId && isLoaded) return;
    _loadState = HireLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _applyDetail(await _service.getHire(hireId));
      _loadState = HireLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = HireLoadState.error;
      _logger?.warning('Hire detail load failed', <String, Object?>{
        'hireId': hireId,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final Hire? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      _applyDetail(await _service.getHire(current.id));
      _loadState = HireLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = HireLoadState.error;
      _logger?.warning('Hire refresh failed', <String, Object?>{
        'hireId': current.id,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Hires a shortlisted application and selects the created hire.
  Future<HireAcceptResult> acceptHire(
    String applicationId, {
    String? quotationId,
  }) async {
    final HireAcceptResult result = await _service.acceptHire(
      applicationId,
      quotationId: quotationId,
    );
    _hires = <Hire>[result.hire, ..._hires];
    _selected = result.hire;
    _selectedEffectiveStatus = result.hire.liveStatus;
    _maybeNotify(result.hire, hiredAction: 'hired');
    if (!_disposed) notifyListeners();
    return result;
  }

  /// Cancels a pending hire and updates local state.
  Future<Hire> cancelHire(String hireId, {String? reason}) async {
    final Hire updated = await _service.cancelHire(hireId, reason: reason);
    _replaceHire(updated);
    if (_selected?.id == hireId) {
      _selected = updated;
      _selectedEffectiveStatus = updated.liveStatus;
    }
    if (!_disposed) notifyListeners();
    return updated;
  }

  /// Completes a hire and updates local state.
  Future<Hire> completeHire(String hireId) async {
    final Hire updated = await _service.completeHire(hireId);
    _replaceHire(updated);
    if (_selected?.id == hireId) {
      _selected = updated;
      _selectedEffectiveStatus = updated.liveStatus;
    }
    _maybeNotify(updated, hiredAction: 'completed');
    if (!_disposed) notifyListeners();
    return updated;
  }

  /// Proposes (or revises) a quotation; records it on the selection when it
  /// belongs to the selected hire's application.
  Future<JobQuotation> proposeQuotation({
    required String applicationId,
    required double amount,
    String currencyCode = 'NGN',
    int? durationDays,
    String? message,
  }) async {
    final JobQuotation quotation = await _service.proposeQuotation(
      applicationId: applicationId,
      amount: amount,
      currencyCode: currencyCode,
      durationDays: durationDays,
      message: message,
    );
    if (_selected?.applicationId == applicationId) {
      _selectedQuotation = quotation;
      if (!_disposed) notifyListeners();
    }
    return quotation;
  }

  /// Withdraws a quotation; clears it from the selection when current.
  Future<JobQuotation> withdrawQuotation(String quotationId) async {
    final JobQuotation quotation = await _service.withdrawQuotation(
      quotationId,
    );
    if (_selectedQuotation?.id == quotationId) {
      _selectedQuotation = quotation;
      if (!_disposed) notifyListeners();
    }
    return quotation;
  }

  /// Accepts a quotation; records it on the selection when current.
  Future<JobQuotation> acceptQuotation(String quotationId) async {
    final JobQuotation quotation = await _service.acceptQuotation(quotationId);
    if (_selectedQuotation?.id == quotationId) {
      _selectedQuotation = quotation;
      if (!_disposed) notifyListeners();
    }
    return quotation;
  }

  void _applyDetail(HireDetail detail) {
    _selected = detail.hire;
    _selectedEffectiveStatus = detail.effectiveStatus;
    _selectedQuotation = detail.quotation;
    _selectedContractId = detail.contractId;
    _selectedContractStatus = detail.contractStatus;
  }

  void _replaceHire(Hire updated) {
    _hires = _hires
        .map((Hire h) => h.id == updated.id ? updated : h)
        .toList(growable: false);
  }

  void _maybeNotify(Hire hire, {required String hiredAction}) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final bool completed = hiredAction == 'completed';
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: hire.id.hashCode & 0x7fffffff,
          title: completed ? 'Hire completed' : 'Professional hired',
          body: completed
              ? 'The hire is now complete.'
              : 'Work can now start on the linked contract.',
          channelId: HireNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/dashboard/hires/${hire.id}',
        ),
      ),
    );
  }

  /// Pauses background refreshes (lifecycle gate).
  void pausePolling() {
    _paused = true;
  }

  /// Resumes background refreshes (lifecycle gate).
  void resumePolling() {
    _paused = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause refreshes while backgrounded; no wasted RPCs (EP-04-02).
    _paused = state != AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // Observer was never attached (no live binding).
    }
    super.dispose();
  }
}
