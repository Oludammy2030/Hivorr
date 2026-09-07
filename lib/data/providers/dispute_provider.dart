// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';

/// Notification channel used for dispute lifecycle events (EP-02-17 §5.6).
abstract final class DisputeNotificationChannel {
  const DisputeNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the dispute provider (EP-02-17 §5.6).
enum DisputeLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing dispute list/detail state to the widget tree (EP-02-17).
///
/// Depends only on the [DisputeService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized dispute list + selection
/// (case, evidence, resolution), a [WidgetsBindingObserver] lifecycle gate
/// (no background refreshes — [pausePolling]/[resumePolling]), and a local
/// "dispute filed"/"dispute withdrawn" [HivorrNotification] hook (mirrors
/// `EscrowProvider`). `select` performs exactly one `dispute_get` RPC per case.
class DisputeProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the dispute notification hook; [logger]
  /// enables PII-safe structured logging; [clock] is injectable for
  /// deterministic tests.
  DisputeProvider({
    required DisputeService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  })  : _service = service,
        _logger = logger,
        _notificationProvider = notificationProvider,
        _clock = clock ?? DateTime.now {
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final DisputeService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final DateTime Function() _clock;

  List<DisputeCase> _disputes = const <DisputeCase>[];
  DisputeCase? _selected;
  List<DisputeEvidence> _evidence = const <DisputeEvidence>[];
  DisputeResolution? _resolution;
  DisputeLoadState _loadState = DisputeLoadState.idle;
  ApiException? _error;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Dispute cases loaded for the current list scope.
  List<DisputeCase> get disputes => _disputes;

  /// The selected dispute case, or `null` before [select].
  DisputeCase? get selected => _selected;

  /// Evidence of the selected dispute case, ordered by the server.
  List<DisputeEvidence> get evidence => _evidence;

  /// Resolution of the selected dispute case, when resolved.
  DisputeResolution? get resolution => _resolution;

  /// The load lifecycle state.
  DisputeLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == DisputeLoadState.loading;

  /// Whether the latest load/refresh succeeded.
  bool get isLoaded => _loadState == DisputeLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Loads the dispute list, optionally filtered by [status].
  Future<void> loadList({String? status}) async {
    if (isLoading) return;
    _loadState = DisputeLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _disputes = await _service.listDisputes(status: status);
      _loadState = DisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = DisputeLoadState.error;
      _logger?.warning('Dispute list load failed', <String, Object?>{
        'statusFilter': status,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail (case + evidence + resolution) for [caseId] in one RPC.
  Future<void> select(String caseId) async {
    if (isLoading) return;
    if (_selected?.id == caseId && isLoaded) return;
    _loadState = DisputeLoadState.loading;
    _error = null;
    notifyListeners();
    try {
final detail = await _service.getCase(caseId);
      _selected = detail.disputeCase;
      _evidence = detail.evidence;
      _resolution = detail.resolution;
      _loadState = DisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = DisputeLoadState.error;
      _logger?.warning('Dispute detail load failed', <String, Object?>{
        'caseId': caseId,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final DisputeCase? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
final detail = await _service.getCase(current.id);
      _selected = detail.disputeCase;
      _evidence = detail.evidence;
      _resolution = detail.resolution;
      _loadState = DisputeLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = DisputeLoadState.error;
      _logger?.warning('Dispute refresh failed', <String, Object?>{
        'caseId': current.id,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Files a dispute and re-reads the authoritative case (escrow held).
  Future<DisputeCase> file({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  }) async {
    final DisputeCase filed = await _service.fileDispute(
      escrowId: escrowId,
      disputeType: disputeType,
      reason: reason,
      desiredOutcome: desiredOutcome,
      priority: priority,
    );
    _selected = filed;
    _evidence = const <DisputeEvidence>[];
    _resolution = null;
    _maybeNotify(filed, filedAction: 'filed');
    if (!_disposed) notifyListeners();
    return filed;
  }

  /// Submits evidence and appends it to the selected case.
  Future<DisputeEvidence> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  }) async {
    final DisputeEvidence submitted = await _service.submitEvidence(
      caseId: caseId,
      evidenceType: evidenceType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      fileMetadata: fileMetadata,
    );
    _evidence = <DisputeEvidence>[..._evidence, submitted];
    if (!_disposed) notifyListeners();
    return submitted;
  }

  /// Withdraws the dispute and updates the selected case (escrow released).
  Future<DisputeCase> withdraw(String caseId) async {
    final DisputeCase updated = await _service.withdrawDispute(caseId);
    _selected = updated;
    _maybeNotify(updated, filedAction: 'withdrawn');
    if (!_disposed) notifyListeners();
    return updated;
  }

  /// Pauses background refreshes (lifecycle gate).
  void pausePolling() {
    _paused = true;
  }

  /// Resumes background refreshes (lifecycle gate).
  void resumePolling() {
    _paused = false;
  }

  void _maybeNotify(DisputeCase case_, {required String filedAction}) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final bool withdrawn = filedAction == 'withdrawn';
    final int id = case_.id.hashCode & 0x7fffffff;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: id,
          title: withdrawn ? 'Dispute withdrawn' : 'Dispute filed',
          body: withdrawn
              ? 'Escrow ${_shortId(case_.escrowId)} is unfrozen.'
              : 'Escrow ${_shortId(case_.escrowId)} is now frozen pending '
                    'resolution.',
          channelId: DisputeNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/support/disputes/${case_.id}',
        ),
      ),
    );
  }

  /// `***` + last 4 chars of an id — never the full id on screen or in a
  /// notification (EP-02-17 §11).
  static String _shortId(String id) {
    if (id.length <= 4) return '***$id';
    return '***${id.substring(id.length - 4)}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause refreshes while backgrounded; no wasted RPCs (EP-02-17 §5.6).
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
