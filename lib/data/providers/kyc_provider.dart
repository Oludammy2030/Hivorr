// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/data/repositories/kyc_repository.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Async load state for [KycProvider] (EP-02-12 §5.5).
enum KycLoadState { idle, loading, loaded, error }

/// Provider exposing KYC level + limits state to the widget tree (EP-02-12).
///
/// Mirrors [VerificationProvider]'s polling/notification pattern: depends only
/// on the [KycRepository] abstraction, owns the kyc/limits/status snapshot and
/// a 15s polling timer, and emits a [HivorrNotification] on a tier upgrade.
class KycProvider extends ChangeNotifier {
  /// Creates the provider bound to [repo].
  ///
  /// [notificationProvider] enables the tier-upgrade notification hook;
  /// [pollInterval] defaults to 15s per the plan; [clock] is injectable for
  /// deterministic tests.
  KycProvider({
    required KycRepository repo,
    HivorrLogger? logger,
    NotificationProvider? notificationProvider,
    Duration? pollInterval,
    DateTime Function()? clock,
  })  : _repo = repo,
        _logger = logger,
        _notificationProvider = notificationProvider,
        _pollInterval = pollInterval ?? const Duration(seconds: 15),
        _clock = clock ?? DateTime.now;

  final KycRepository _repo;
  final HivorrLogger? _logger;
  final NotificationProvider? _notificationProvider;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  KycLevel? _kycLevel;
  KycLimits? _limits;
  VerificationStatus? _status;
  KycLoadState _loadState = KycLoadState.idle;
  ApiException? _lastError;
  bool _isRefreshing = false;
  Timer? _pollTimer;
  String? _prevTierCode;
  bool _notifiedUpgrade = false;
  bool _pollingEnabled = false;
  bool _paused = false;

  /// The assigned KYC level (tier + limits), or `null` before first load.
  KycLevel? get kycLevel => _kycLevel;

  /// The current tier limits.
  KycLimits? get limits => _limits;

  /// The full verification aggregate, or `null` before first load.
  VerificationStatus? get status => _status;

  /// Current load lifecycle state.
  KycLoadState get loadState => _loadState;

  /// Error from the last failed refresh.
  ApiException? get lastError => _lastError;

  /// Whether a refresh is in flight.
  bool get isRefreshing => _isRefreshing;

  /// The current [KycTier] derived from the loaded level.
  KycTier get currentTier => KycTier.fromCode(_kycLevel?.tierCode ?? 'tier_0');

  /// The next eligible tier above the current one, or `null` if none.
  KycTier? get nextEligibleTier {
    final KycLevel? level = _kycLevel;
    if (level == null) return null;
    final List<KycTier> path = _repo.eligibleUpgradePath(level);
    return path.isNotEmpty ? path.first : null;
  }

  /// Loads KYC level + limits + status in parallel (EP-02-12 §5.5 [load]).
  Future<void> load() async {
    _loadState = KycLoadState.loading;
    _lastError = null;
    notifyListeners();
    try {
      final KycLevel level = await _repo.getKycLevel();
      final KycLimits limits = await _repo.getLimits();
      _status = await _repo.getStatus();
      _kycLevel = level;
      _limits = limits;
      _prevTierCode ??= level.tierCode;
      _loadState = KycLoadState.loaded;
      _logger?.info('KYC state loaded', <String, Object?>{
        'tierCode': level.tierCode,
      });
    } on ApiException catch (e) {
      _lastError = e;
      _loadState = KycLoadState.error;
      _logger?.warning('KYC state load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      notifyListeners();
    }
  }

  /// Re-reads status + KYC and emits a notification on a tier upgrade.
  Future<void> refreshStatus() async {
    _isRefreshing = true;
    notifyListeners();
    try {
      final KycLevel next = await _repo.getKycLevel();
      _kycLevel = next;
      _limits = next.limits;
      _status = await _repo.getStatus();
      _lastError = null;
      _maybeNotify(next);
    } on ApiException catch (e) {
      _lastError = e;
      _logger?.warning('KYC refresh failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Requests an upgrade to [targetTier] via the repository.
  Future<KycLevel?> requestUpgrade({
    required KycTier targetTier,
    Map<String, dynamic>? payload,
  }) async {
    _lastError = null;
    notifyListeners();
    try {
      final KycLevel next = await _repo.requestUpgrade(
        targetTier: targetTier,
        payload: payload,
      );
      _kycLevel = next;
      _limits = next.limits;
      _maybeNotify(next);
      notifyListeners();
      return next;
    } on ApiException catch (e) {
      _lastError = e;
      _logger?.warning('KYC upgrade failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      notifyListeners();
      return null;
    }
  }

  /// Starts 15s polling while a KYC assignment is pending.
  void startPolling() {
    _pollingEnabled = true;
    _paused = false;
    _ensurePollTimer();
  }

  /// Cancels any active polling timer.
  void stopPolling() {
    _pollingEnabled = false;
    _paused = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Pauses polling without forgetting it was requested (app background).
  void pausePolling() {
    if (!_pollingEnabled || _paused) return;
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes a paused ticker.
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
    final KycLevel? level = _kycLevel;
    if (level == null) return true;
    return level.status == 'pending';
  }

  /// Emits a high-priority [HivorrNotification] once per tier upgrade.
  void _maybeNotify(KycLevel next) {
    final String prev = _prevTierCode ?? '';
    if (prev.isNotEmpty &&
        next.tierCode.compareTo(prev) > 0 &&
        !_notifiedUpgrade) {
      _notifiedUpgrade = true;
      final int id = next.tierCode.hashCode & 0x7fffffff;
      unawaited(
        _notificationProvider?.showLocal(
          HivorrNotification(
            id: id,
            title: 'Verification upgraded — ${next.tierCode}',
            body: 'Your cashout limit is now ₦${next.limits.cashout}',
            channelId: VerificationNotificationChannel.system,
            priority: NotificationPriority.high,
            timestamp: _clock(),
            actionRoute: '/verification/kyc',
          ),
        ),
      );
      _logger?.info('KYC tier upgrade detected', <String, Object?>{
        'prevTierCode': prev,
        'nextTierCode': next.tierCode,
      });
    }
    _prevTierCode = next.tierCode;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
