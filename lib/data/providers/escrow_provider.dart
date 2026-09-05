// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_detail.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/models/escrow_milestone_input.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/services/escrow_service.dart';

/// Notification channel used for escrow lifecycle events (EP-02-14 §7.5).
abstract final class EscrowNotificationChannel {
  const EscrowNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Load lifecycle of the escrow provider (EP-02-14 §5.5).
enum EscrowLoadState {
  /// No load attempted yet.
  idle,

  /// A load/refresh is in flight.
  loading,

  /// The latest load/refresh succeeded.
  loaded,

  /// The latest load/refresh failed.
  error,
}

/// Provider exposing escrow list/detail state to the widget tree (EP-02-14).
///
/// Depends only on the [EscrowService] abstraction and surfaces a single
/// [ApiException] on failure. Owns the memoized escrow list + selection
/// (escrow, milestones, transactions), a [WidgetsBindingObserver] lifecycle
/// gate (no background refreshes), and a local "milestone released" /
/// "escrow released" [HivorrNotification] hook on flag-on write success
/// (mirrors `FinancialProvider`).
class EscrowProvider extends ChangeNotifier with WidgetsBindingObserver {
  /// Creates the provider bound to [service].
  ///
  /// [notificationProvider] enables the release notification hook; [logger]
  /// enables PII-safe structured logging; [clock] is injectable for
  /// deterministic tests.
  EscrowProvider({
    required EscrowService service,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    DateTime Function()? clock,
  })  : _service = service,
        _logger = logger,
        _notificationProvider = notificationProvider,
        _clock = clock ?? DateTime.now,
        _writeAvailable = service.escrowWriteAvailable {
    // `AppBootstrap.initialize` constructs this provider in a pure data-layer
    // context where no binding exists yet; the observer only attaches when the
    // widget binding is live (guard is idempotent in the app).
    try {
      WidgetsBinding.instance.addObserver(this);
    } on Object {
      // No binding yet — the lifecycle pause gate will not be attached.
    }
  }

  final EscrowService _service;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final DateTime Function() _clock;

  /// Read once at construction from the proxy seam (EP-02-14 §5.5).
  final bool _writeAvailable;

  List<Escrow> _escrows = const <Escrow>[];
  Escrow? _selected;
  List<EscrowMilestone> _milestones = const <EscrowMilestone>[];
  Map<String, List<EscrowTransaction>> _transactionsByEscrowId =
      const <String, List<EscrowTransaction>>{};
  EscrowLoadState _loadState = EscrowLoadState.idle;
  ApiException? _error;
  bool _refreshing = false;
  bool _paused = false;
  bool _disposed = false;

  /// Escrow headers loaded for the current project.
  List<Escrow> get escrows => _escrows;

  /// The selected escrow, or `null` before [select].
  Escrow? get selected => _selected;

  /// Milestones of the selected escrow, ordered by the server.
  List<EscrowMilestone> get milestones => _milestones;

  /// Escrow-scoped ledger summaries keyed by escrow id (currently empty).
  Map<String, List<EscrowTransaction>> get transactionsByEscrowId =>
      _transactionsByEscrowId;

  /// The load lifecycle state.
  EscrowLoadState get loadState => _loadState;

  /// Whether a load/refresh is in flight.
  bool get isLoading => _loadState == EscrowLoadState.loading;

  /// Whether the latest load/refresh succeeded.
  bool get isLoaded => _loadState == EscrowLoadState.loaded;

  /// Whether a refresh is in flight (pull-to-refresh).
  bool get isRefreshing => _refreshing;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Whether the escrow write seam is active (read once).
  bool get writeAvailable => _writeAvailable;

  /// Loads escrow headers for a project (enumerated known escrow ids).
  Future<void> loadForProject({
    required String projectId,
    required List<String> escrowIds,
  }) async {
    if (isLoading) return;
    _loadState = EscrowLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _escrows = await _service.getByProject(
        projectId: projectId,
        escrowIds: escrowIds,
      );
      _loadState = EscrowLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = EscrowLoadState.error;
      _logger?.warning('Escrow list load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the detail (escrow + milestones + transactions) for [escrowId].
  Future<void> select(String escrowId) async {
    if (isLoading) return;
    _loadState = EscrowLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _applyDetail(await _service.getById(escrowId));
      _loadState = EscrowLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = EscrowLoadState.error;
      _logger?.warning('Escrow detail load failed', <String, Object?>{
        'escrowId': escrowId,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Re-reads the current selection (pull-to-refresh / lifecycle resume).
  Future<void> refresh() async {
    final Escrow? current = _selected;
    if (current == null || _refreshing || _paused) return;
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      _applyDetail(await _service.getById(current.id));
      _loadState = EscrowLoadState.loaded;
    } on ApiException catch (e) {
      _error = e;
      _loadState = EscrowLoadState.error;
      _logger?.warning('Escrow refresh failed', <String, Object?>{
        'escrowId': current.id,
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Creates an escrow via the write seam; applies the re-read result.
  Future<EscrowDetail> createEscrow({
    required String payerEntityId,
    required String payeeEntityId,
    required String currencyCode,
    required double totalAmount,
    required List<EscrowMilestoneInput> milestones,
  }) async {
    final EscrowDetail detail = await _service.createEscrow(
      payerEntityId: payerEntityId,
      payeeEntityId: payeeEntityId,
      currencyCode: currencyCode,
      totalAmount: totalAmount,
      milestones: milestones,
    );
    _applyDetail(detail);
    return detail;
  }

  /// Marks a milestone complete via the write seam.
  Future<EscrowDetail> completeMilestone({
    required String milestoneId,
  }) async {
    final String? escrowId = _selected?.id;
    if (escrowId == null) throw _noSelectionError;
    final EscrowDetail detail = await _service.completeMilestone(
      escrowId: escrowId,
      milestoneId: milestoneId,
    );
    _applyDetail(detail);
    _maybeNotifyRelease(detail, milestoneId);
    return detail;
  }

  /// Releases a single milestone via the write seam.
  Future<EscrowDetail> releaseMilestone({
    required String milestoneId,
  }) async {
    final String? escrowId = _selected?.id;
    if (escrowId == null) throw _noSelectionError;
    final EscrowDetail detail = await _service.releaseMilestone(
      escrowId: escrowId,
      milestoneId: milestoneId,
    );
    _applyDetail(detail);
    _maybeNotifyRelease(detail, milestoneId);
    return detail;
  }

  /// Releases all remaining held funds via the write seam.
  Future<EscrowDetail> releaseFinal() async {
    final String? escrowId = _selected?.id;
    if (escrowId == null) throw _noSelectionError;
    final EscrowDetail detail =
        await _service.releaseFinal(escrowId: escrowId);
    _applyDetail(detail);
    _maybeNotifyRelease(detail, null);
    return detail;
  }

  /// Refunds remaining held funds to the payer via the write seam.
  Future<EscrowDetail> refundEscrow({required String reason}) async {
    final String? escrowId = _selected?.id;
    if (escrowId == null) throw _noSelectionError;
    final EscrowDetail detail = await _service.refundEscrow(
      escrowId: escrowId,
      reason: reason,
    );
    _applyDetail(detail);
    return detail;
  }

  static ApiException get _noSelectionError => const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'No escrow is currently selected.',
        code: 'PLT003',
      );

  void _applyDetail(EscrowDetail detail) {
    _selected = detail.escrow;
    _milestones = detail.milestones;
    _transactionsByEscrowId = <String, List<EscrowTransaction>>{
      ..._transactionsByEscrowId,
      detail.escrow.id: detail.transactions,
    };
  }

  void _maybeNotifyRelease(EscrowDetail detail, String? milestoneId) {
    final NotificationProvider? notifications = _notificationProvider;
    if (notifications == null) return;
    final Escrow escrow = detail.escrow;
    final bool finalRelease = escrow.status == 'released';
    final int totalCount = detail.milestones.length;
    final String released = BalanceFormatter.formatBalance(
      escrow.releasedAmount,
      escrow.currencyCode,
    );
    final String body = totalCount == 0
        ? '$released released to provider'
        : '$released released to provider — milestone ${_milestoneNumber(detail, milestoneId)} of $totalCount';
    final int id = escrow.id.hashCode & 0x7fffffff;
    unawaited(
      notifications.showLocal(
        HivorrNotification(
          id: id,
          title: finalRelease ? 'Milestone released' : 'Escrow updated',
          body: body,
          channelId: EscrowNotificationChannel.system,
          priority: NotificationPriority.normal,
          timestamp: _clock(),
          actionRoute: '/finance/escrow/${escrow.id}',
        ),
      ),
    );
  }

  static int _milestoneNumber(EscrowDetail detail, String? milestoneId) {
    if (milestoneId == null) return detail.milestones.length;
    for (int i = 0; i < detail.milestones.length; i++) {
      if (detail.milestones[i].id == milestoneId) {
        return detail.milestones[i].milestoneNumber;
      }
    }
    return detail.milestones.length;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause refreshes while backgrounded; no wasted RPCs (EP-02-14 §5.5).
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