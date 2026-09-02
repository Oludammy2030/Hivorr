// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/data/repositories/trade_verification_repository.dart';
import 'package:hivorr/systems/verification/models/trade_proof_type.dart';

/// Notification channel used for trade-verification decisions.
abstract final class TradeVerificationNotificationChannel {
  const TradeVerificationNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Provider exposing trade-verification state to the widget tree (EP-02-11
/// §5.5).
///
/// Depends only on the [TradeVerificationRepository] abstraction and surfaces a
/// single [ApiException] on failure. Owns the status snapshot, the submit
/// lifecycle, and a 15s polling timer (no `supabase_realtime` — a designed
/// poller is the source of truth).
///
/// On a terminal per-profession transition (approved / rejected) it emits a
/// [HivorrNotification] via the injected [NotificationProvider] (optional,
/// domain-layer only).
class TradeVerificationProvider extends ChangeNotifier {
  /// Creates the provider bound to [repo].
  ///
  /// [notificationProvider] enables the terminal-transition notification hook;
  /// [logger] enables PII-safe structured logging. [pollInterval] defaults to
  /// 15s; [clock] is injectable for deterministic tests.
  TradeVerificationProvider({
    required TradeVerificationRepository repo,
    NotificationProvider? notificationProvider,
    HivorrLogger? logger,
    Duration? pollInterval,
    DateTime Function()? clock,
  })  : _repo = repo,
        _notificationProvider = notificationProvider,
        _logger = logger,
        _pollInterval = pollInterval ?? const Duration(seconds: 15),
        _clock = clock ?? DateTime.now;

  final TradeVerificationRepository _repo;
  final NotificationProvider? _notificationProvider;
  final HivorrLogger? _logger;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  TradeVerificationStatus? _status;
  SubmitState _submitState = SubmitState.idle;
  ApiException? _submitError;
  ApiException? _error;
  Timer? _pollTimer;
  final Set<String> _notifiedApproved = <String>{};
  final Set<String> _notifiedRejected = <String>{};
  bool _refreshing = false;
  bool _pollingEnabled = false;
  bool _paused = false;
  bool _disposed = false;

  /// The latest trade-verification aggregate, or `null` before the first fetch.
  TradeVerificationStatus? get status => _status;

  /// The current submit lifecycle state.
  SubmitState get submitState => _submitState;

  /// The error from the last failed submit.
  ApiException? get submitError => _submitError;

  /// The error from the last status refresh.
  ApiException? get lastError => _error;

  /// Whether a status refresh is in flight.
  bool get isRefreshing => _refreshing;

  /// Convenience "is submitting" flag consumed by the UI button.
  bool get isSubmitting => _submitState == SubmitState.submitting;

  /// Whether any bound profession is still awaiting a decision (poll-worthy).
  bool get isAwaitingDecision {
    final TradeVerificationStatus? s = _status;
    if (s == null) return true;
    return s.tradeVerifications.any(
      (TradeVerification t) => !t.statusKind.isTerminal,
    );
  }

  /// Submits a trade proof for [professionId] and refreshes status on success.
  Future<void> submitTradeProof({
    required TradeProofType type,
    required String professionId,
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (isSubmitting) return;
    _submitState = SubmitState.submitting;
    _submitError = null;
    notifyListeners();
    try {
      await _repo.submitTradeProof(
        type: type,
        professionId: professionId,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      );
      _submitState = SubmitState.success;
      _logger?.info('Trade proof submitted', <String, Object?>{
        'tradeType': type.name,
        'professionId': professionId,
      });
      await refreshStatus();
    } on ApiException catch (e) {
      _submitError = e;
      _submitState = SubmitState.error;
      _logger?.warning('Trade proof submission failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      notifyListeners();
    }
  }

  /// Refreshes status from the repository and emits a notification on any
  /// new terminal per-profession transition.
  Future<void> refreshStatus() async {
    _refreshing = true;
    notifyListeners();
    try {
      final TradeVerificationStatus next = await _repo.getStatus();
      _status = next;
      _error = null;
      _maybeNotify(next);
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Trade verification status refresh failed',
          <String, Object?>{'kind': e.kind.name, 'code': e.code});
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Starts 15s polling while any profession is awaiting a decision, stopping
  /// once every profession is terminal.
  ///
  /// Idempotent — repeated calls do not stack timers. The owning screen calls
  /// [pausePolling]/[resumePolling] on app-background/foreground.
  void startPolling() {
    _pollingEnabled = true;
    _paused = false;
    _ensurePollTimer();
  }

  /// Cancels any active polling timer (safe to call multiple times).
  void stopPolling() {
    _pollingEnabled = false;
    _paused = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Pauses polling without forgetting that it was requested (app background).
  void pausePolling() {
    if (!_pollingEnabled || _paused) return;
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes a [pausePolling]-d ticker, unless everything is now terminal.
  void resumePolling() {
    if (!_paused) return;
    _paused = false;
    if (_shouldPoll) _ensurePollTimer();
  }

  void _ensurePollTimer() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_onPollTick()));
  }

  Future<void> _onPollTick() async {
    if (!_shouldPoll) {
      stopPolling();
      return;
    }
    await refreshStatus();
    if (!_shouldPoll) stopPolling();
  }

  bool get _shouldPoll {
    final TradeVerificationStatus? s = _status;
    if (s == null) return true;
    return s.tradeVerifications.any(
      (TradeVerification t) => !t.statusKind.isTerminal,
    );
  }

  /// Emits a high-priority [HivorrNotification] once per new terminal outcome
  /// (approved / rejected) per profession. Idempotent — fires only on the first
  /// observation of each transition.
  void _maybeNotify(TradeVerificationStatus next) {
    if (_notificationProvider == null) return;
    for (final TradeVerification entry in next.tradeVerifications) {
      final String professionId = entry.professionId;
      if (entry.statusKind == TradeVerificationStatusKind.approved &&
          !_notifiedApproved.contains(professionId)) {
        _notifiedApproved.add(professionId);
        unawaited(_maybeShowNotification(
          id: _notificationId('approved', professionId),
          title: 'Trade verification approved',
          body: 'Your trade proof has been approved. You can now bid.',
        ));
      } else if (entry.statusKind == TradeVerificationStatusKind.rejected &&
          !_notifiedRejected.contains(professionId)) {
        _notifiedRejected.add(professionId);
        unawaited(_maybeShowNotification(
          id: _notificationId('rejected', professionId),
          title: 'Trade verification requires attention',
          body: 'Your trade proof was not approved. Please review and resubmit.',
        ));
      }
    }
  }

  Future<void> _maybeShowNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final NotificationProvider? provider = _notificationProvider;
    if (provider == null || _disposed) return;
    await provider.showLocal(HivorrNotification(
      id: id,
      title: title,
      body: body,
      channelId: TradeVerificationNotificationChannel.system,
      priority: NotificationPriority.high,
      timestamp: _clock(),
      actionRoute: '/verification/trade/status',
    ));
  }

  int _notificationId(String kind, String professionId) =>
      ('$kind:$professionId').hashCode & 0x7fffffff;

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
