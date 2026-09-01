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
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/providers/submit_state.dart';
import 'package:hivorr/data/providers/verification_stage.dart';
import 'package:hivorr/data/repositories/verification_repository.dart';
import 'package:hivorr/systems/verification/models/document_type.dart';

// Re-exported for UI convenience (kept in the data layer for the ChangeNotifier).
export 'package:hivorr/data/providers/submit_state.dart';
export 'package:hivorr/data/providers/verification_stage.dart';

/// Notification channel used for verification decisions (EP-02-10 §7.4).
abstract final class VerificationNotificationChannel {
  const VerificationNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Provider exposing identity-verification state to the widget tree (EP-02-10).
///
/// Depends only on the [VerificationRepository] abstraction and surfaces a
/// single [ApiException] on failure. Owns the status/kyc snapshot, the submit
/// lifecycle, and a 15s polling timer (no `supabase_realtime` — the queue table
/// is excluded from realtime, so a designed poller is the source of truth).
///
/// On a terminal transition (identity becomes verified) it emits a
/// [HivorrNotification] via the injected [NotificationProvider] (optional,
/// domain-layer only) — never a direct `flutter_local_notifications` call.
class VerificationProvider extends ChangeNotifier {
  /// Creates the provider bound to [repo].
  ///
  /// [notificationProvider] enables the terminal-transition notification hook;
  /// [logger] enables PII-safe structured logging. [pollInterval] defaults to
  /// 15s per the plan; [clock] is injectable for deterministic tests.
  VerificationProvider({
    required VerificationRepository repo,
    NotificationProvider? notificationProvider,
    HivorrLogger? logger,
    Duration? pollInterval,
    DateTime Function()? clock,
  })  : _repo = repo,
        _notificationProvider = notificationProvider,
        _logger = logger,
        _pollInterval = pollInterval ?? const Duration(seconds: 15),
        _clock = clock ?? DateTime.now;

  final VerificationRepository _repo;
  final NotificationProvider? _notificationProvider;
  final HivorrLogger? _logger;
  final Duration _pollInterval;
  final DateTime Function() _clock;

  VerificationStatus? _status;
  KycLevel? _kycLevel;
  SubmitState _submitState = SubmitState.idle;
  VerificationSubmission? _lastSubmission;
  ApiException? _submitError;
  ApiException? _error;
  Timer? _pollTimer;
  bool _wasVerified = false;
  bool _notifiedActionRequired = false;
  bool _refreshing = false;
  bool _pollingEnabled = false;
  bool _paused = false;

  /// The latest verification aggregate, or `null` before the first fetch.
  VerificationStatus? get status => _status;

  /// The assigned KYC level (also embedded in [status]).
  KycLevel? get kycLevel => _kycLevel;

  /// The current submit lifecycle state.
  SubmitState get submitState => _submitState;

  /// The submission created by the last successful submit, if any.
  VerificationSubmission? get lastSubmission => _lastSubmission;

  /// The error from the last failed submit.
  ApiException? get submitError => _submitError;

  /// The error from the last status/kyc refresh.
  ApiException? get lastError => _error;

  /// Whether a status refresh is in flight.
  bool get isRefreshing => _refreshing;

  /// Convenience "is submitting" flag consumed by the UI button.
  bool get isSubmitting => _submitState == SubmitState.submitting;

  /// Whether a submit is currently in flight.
  bool get isBusy => isSubmitting;

  /// The derived lifecycle stage from the latest aggregate, or [idle] when no
  /// aggregate has been loaded yet.
  ///
  /// `actionRequired` (rejected / requires resubmission) is derived because the
  /// server aggregate only reports counts, not the review outcome — see
  /// [VerificationStage].
  VerificationStage get stage {
    final VerificationStatus? s = _status;
    if (s == null) return VerificationStage.idle;
    if (s.identityVerified) return VerificationStage.approved;
    if (s.totalSubmissions == 0) return VerificationStage.pending;
    if (s.pendingSubmissions > 0) return VerificationStage.inReview;
    return VerificationStage.actionRequired;
  }

  /// Submits an identity document and refreshes status on success.
  Future<void> submitIdentityDocument({
    required DocumentType documentType,
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
      final VerificationSubmission submission = await _repo.submitIdentityDocument(
        documentType: documentType,
        bytes: bytes,
        mimeType: mimeType,
        fileName: fileName,
        onProgress: onProgress,
      );
      _lastSubmission = submission;
      _submitState = SubmitState.success;
      _logger?.info('Identity document submitted', <String, Object?>{
        'documentType': documentType.name,
        'submissionId': submission.id,
      });
      await refreshStatus();
    } on ApiException catch (e) {
      _submitError = e;
      _submitState = SubmitState.error;
      _logger?.warning('Identity document submission failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
      notifyListeners();
    }
  }

  /// Refreshes status + KYC from the repository and emits a notification on a
  /// terminal transition.
  Future<void> refreshStatus() async {
    _refreshing = true;
    notifyListeners();
    try {
      final VerificationStatus next = await _repo.getStatus();
      KycLevel? kyc;
      try {
        kyc = await _repo.getKycLevel();
      } on ApiException {
        // status is authoritative; kyc is best-effort.
      }
      _status = next;
      if (kyc != null) _kycLevel = kyc;
      _error = null;
      _maybeNotify(next);
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Verification status refresh failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Starts 15s polling while a submission is under active review, stopping
  /// once identity is verified or the pending submission is gone (decided).
  ///
  /// Lifecycle-aware per TV-10: the owning screen pauses the timer via
  /// [pausePolling] when the app backgrounds and resumes it via [resumePolling]
  /// on foreground. Idempotent — repeated calls do not stack timers.
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

  /// Pauses polling without forgetting that it was requested (app background);
  /// a later [resumePolling] restarts the ticker.
  void pausePolling() {
    if (!_pollingEnabled || _paused) return;
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes a [pausePolling]-d paused ticker, unless the submission is now
  /// terminal (in which case polling stays stopped).
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

  /// Whether the submission is still worth polling: no decision yet and an
  /// active (pending) review exists. `null` status polls once to learn state.
  bool get _shouldPoll {
    final VerificationStatus? s = _status;
    if (s == null) return true;
    return !s.identityVerified && s.pendingSubmissions > 0;
  }

  /// Emits a high-priority [HivorrNotification] once per terminal outcome:
  /// approved, or action-required (rejected / requires resubmission). Terminal
  /// notifications are idempotent — they fire only on the first observation of
  /// each outcome (FV-26; server-authoritative status is never mutated).
  void _maybeNotify(VerificationStatus next) {
    if (next.identityVerified && !_wasVerified) {
      final KycLevel level = next.kycLevel;
      final int id = next.entityId.hashCode & 0x7fffffff;
      unawaited(
        _notificationProvider?.showLocal(
          HivorrNotification(
            id: id,
            title: 'Verification approved',
            body: level.tierCode == 'tier_0'
                ? 'Your identity has been verified.'
                : 'Your identity has been verified. You are now ${level.tierCode}.',
            channelId: VerificationNotificationChannel.system,
            priority: NotificationPriority.high,
            timestamp: _clock(),
            actionRoute: '/verification/status',
          ),
        ),
      );
      _logger?.info('Verification terminal transition detected', <String, Object?>{
        'identityVerified': true,
        'tierCode': level.tierCode,
      });
    } else if (!next.identityVerified &&
        next.totalSubmissions > 0 &&
        next.pendingSubmissions == 0 &&
        !_notifiedActionRequired) {
      _notifiedActionRequired = true;
      final int id = next.entityId.hashCode & 0x7fffffff;
      unawaited(
        _notificationProvider?.showLocal(
          HivorrNotification(
            id: id,
            title: 'Verification action required',
            body: 'Your verification was not approved. Please review and '
                'resubmit your document.',
            channelId: VerificationNotificationChannel.system,
            priority: NotificationPriority.high,
            timestamp: _clock(),
            actionRoute: '/verification/status',
          ),
        ),
      );
      _logger?.info('Verification needs attention', <String, Object?>{
        'entityId': next.entityId.hashCode,
        'totalSubmissions': next.totalSubmissions,
      });
    }
    _wasVerified = next.identityVerified;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

