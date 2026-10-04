// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/core/notifications/models/hivorr_notification.dart';
import 'package:hivorr/core/notifications/models/notification_priority.dart';
import 'package:hivorr/core/notifications/providers/notification_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';

/// Notification channel for admin review pings (mirrors the verification
/// channel convention). Reuses the app default channel id.
abstract final class AdminReviewNotificationChannel {
  const AdminReviewNotificationChannel._();

  /// Reuses the app default channel id.
  static const String system = 'hivorr_default';
}

/// Provider exposing admin review state to the widget tree (EP-02-11 §5.5).
///
/// Depends only on the [AdminReviewRepository] abstraction. Owns the admin
/// flag, the queue list, the detail audit trail, and the approve/reject
/// lifecycle. UI consumes this provider, never the repository directly.
///
/// When the pending total grows between metrics refreshes it emits one
/// [HivorrNotification] via the injected [NotificationProvider] (optional,
/// domain-layer only) — never a direct `flutter_local_notifications` call.
/// A 60s poller refreshes the lightweight metrics RPC (never the queue
/// page, so triage selection and filters are undisturbed).
class AdminReviewProvider extends ChangeNotifier {
  AdminReviewProvider({
    required AdminReviewRepository repo,
    NotificationProvider? notificationProvider,
    HivorrLogger? logger,
    Duration? pollInterval,
  }) : _repo = repo,
       _notificationProvider = notificationProvider,
       _logger = logger,
       _pollInterval = pollInterval ?? const Duration(seconds: 60);

  final AdminReviewRepository _repo;
  final NotificationProvider? _notificationProvider;
  final HivorrLogger? _logger;
  final Duration _pollInterval;

  bool? _isAdmin;
  List<AdminReviewQueueEntry> _queue = const <AdminReviewQueueEntry>[];
  List<AdminReviewAuditEntry> _auditTrail = const <AdminReviewAuditEntry>[];
  ApiException? _error;
  bool _loadingQueue = false;
  bool _loadingAudit = false;
  bool _acting = false;
  int _currentOffset = 0;
  bool _hasMore = true;
  String? _activeSubmissionId;
  int? _serverTotalCount;
  AdminReviewMetrics? _metrics;
  bool _loadingMetrics = false;
  AdminReviewProfile _profile = const AdminReviewProfile();
  bool _loadingProfile = false;
  String? _profileSubmissionId;
  Timer? _pollTimer;
  bool _pollingEnabled = false;
  bool _paused = false;
  int? _lastSeenPending;
  static const int _pageSize = 50;

  /// Whether the current user is a platform admin. `null` before the first
  /// check.
  bool? get isAdmin => _isAdmin;

  /// The current review queue.
  List<AdminReviewQueueEntry> get queue => _queue;

  /// The audit trail for the currently selected submission.
  List<AdminReviewAuditEntry> get auditTrail => _auditTrail;

  /// The error from the last failed operation.
  ApiException? get lastError => _error;

  /// Whether the queue is currently loading.
  bool get isLoadingQueue => _loadingQueue;

  /// Whether an audit trail is currently loading.
  bool get isLoadingAudit => _loadingAudit;

  /// Whether an approve/reject/start action is in flight.
  bool get isActing => _acting;

  /// Whether more pages are available.
  bool get hasMore => _hasMore;

  /// The server `total_count` from the last queue fetch, or `null` before
  /// the first successful load. The metrics row prefers this over the
  /// loaded-page length so the pending total stays honest across pages.
  int? get serverTotalCount => _serverTotalCount;

  /// Real pending total for the metrics row: the metrics RPC value when
  /// known, else the queue `total_count`, else the loaded length (the UI
  /// labels which source backs the number).
  int get pendingTotal =>
      _metrics?.pendingTotal ?? _serverTotalCount ?? _queue.length;

  /// Throughput metrics from `verification_review_metrics_get`, or `null`
  /// before the first successful load. Null averages/rates inside mean the
  /// trailing window holds no decided rows.
  AdminReviewMetrics? get metrics => _metrics;

  /// Whether throughput metrics are currently loading.
  bool get isLoadingMetrics => _loadingMetrics;

  /// The applicant profile depth for the last requested submission.
  AdminReviewProfile get reviewProfile => _profile;

  /// Whether the applicant profile is currently loading.
  bool get isLoadingProfile => _loadingProfile;

  /// Loads dashboard throughput metrics (trailing 30-day window by default).
  /// Best-effort: failures leave the previous value and surface through
  /// [lastError] without disturbing the queue. On success the pending total
  /// is compared against the last seen value for the new-submission ping.
  Future<void> loadMetrics({int periodDays = 30, String? submissionType}) async {
    _loadingMetrics = true;
    notifyListeners();
    try {
      _metrics = await _repo.getReviewMetrics(
        periodDays: periodDays,
        submissionType: submissionType,
      );
      _maybeNotifyNewSubmissions();
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Admin metrics load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _loadingMetrics = false;
      notifyListeners();
    }
  }

  /// Emits one local notification when the pending total grows since the
  /// last successful refresh. The first load only sets the baseline, and
  /// flat or shrinking totals stay silent — the bell badge already shows
  /// the live count.
  void _maybeNotifyNewSubmissions() {
    final AdminReviewMetrics? current = _metrics;
    if (current == null) return;
    final int pending = current.pendingTotal;
    final int? previous = _lastSeenPending;
    _lastSeenPending = pending;
    if (previous == null || pending <= previous) return;
    final int added = pending - previous;
    unawaited(
      _notificationProvider?.showLocal(
        HivorrNotification(
          id: 'admin-review-queue'.hashCode & 0x7fffffff,
          title: 'New verification submissions',
          body: added == 1
              ? '1 new submission is awaiting review.'
              : '$pending submissions are awaiting review.',
          channelId: AdminReviewNotificationChannel.system,
          priority: NotificationPriority.high,
          timestamp: DateTime.now(),
          actionRoute: '/admin/review-queue',
        ),
      ),
    );
    _logger?.info('Admin review queue grew', <String, Object?>{
      'pending': pending,
      'added': added,
    });
  }

  /// Starts the 60s metrics poller while the admin queue is on screen.
  /// Idempotent — repeated calls do not stack timers. The tick refreshes
  /// metrics only, so table selection and filters are never disturbed.
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

  /// Pauses polling without forgetting that it was requested.
  void pausePolling() {
    if (!_pollingEnabled || _paused) return;
    _paused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes a [pausePolling]-paused ticker.
  void resumePolling() {
    if (!_paused) return;
    _paused = false;
    if (_pollingEnabled) _ensurePollTimer();
  }

  void _ensurePollTimer() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_onPollTick()));
  }

  Future<void> _onPollTick() async {
    if (!_pollingEnabled || _paused) {
      stopPolling();
      return;
    }
    await loadMetrics();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  /// How many loaded rows are currently claimed (`in_review`). Real data
  /// from the loaded page, shown as the pending-card sub-line.
  int get inReviewCount {
    int count = 0;
    for (final AdminReviewQueueEntry e in _queue) {
      final String s = e.status;
      if (s == 'in_review' || s == 'inReview') count++;
    }
    return count;
  }

  /// The currently selected submission id (for detail view).
  String? get activeSubmissionId => _activeSubmissionId;

  /// Checks admin status and caches it. Fails closed (isAdmin = false) on
  /// error.
  Future<void> checkAdmin() async {
    try {
      _isAdmin = await _repo.checkAdmin();
    } on ApiException catch (e) {
      _logger?.warning('Admin check failed', <String, Object?>{'code': e.code});
      _isAdmin = false;
    } catch (_) {
      _isAdmin = false;
    }
    notifyListeners();
  }

  /// Fetches the first page of the review queue (resets pagination).
  ///
  /// [search], [professionId], and [sort] (`newest`/`oldest`/`name`) narrow
  /// and order server-side; the screen mirrors them client-side over the
  /// loaded page so behavior stays consistent before the first reload.
  Future<void> loadQueue({
    String? submissionType,
    String? search,
    String? professionId,
    String? sort,
  }) async {
    _loadingQueue = true;
    _error = null;
    _currentOffset = 0;
    _hasMore = true;
    notifyListeners();
    try {
      final List<AdminReviewQueueEntry> items = await _repo.getReviewQueue(
        submissionType: submissionType,
        limit: _pageSize,
        offset: 0,
        search: search,
        professionId: professionId,
        sort: sort,
      );
      _queue = items;
      _serverTotalCount = _repo.lastTotalCount;
      _hasMore = items.length >= _pageSize;
      _currentOffset = items.length;
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Admin queue load failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _loadingQueue = false;
      notifyListeners();
    }
  }

  /// Appends the next page to the queue (same filters as [loadQueue]).
  Future<void> loadMore({
    String? submissionType,
    String? search,
    String? professionId,
    String? sort,
  }) async {
    if (_loadingQueue || !_hasMore) return;
    _loadingQueue = true;
    notifyListeners();
    try {
      final List<AdminReviewQueueEntry> items = await _repo.getReviewQueue(
        submissionType: submissionType,
        limit: _pageSize,
        offset: _currentOffset,
        search: search,
        professionId: professionId,
        sort: sort,
      );
      _queue = [..._queue, ...items];
      _serverTotalCount = _repo.lastTotalCount ?? _serverTotalCount;
      _hasMore = items.length >= _pageSize;
      _currentOffset += items.length;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loadingQueue = false;
      notifyListeners();
    }
  }

  /// Claims a submission for review.
  Future<void> startReview(String submissionId) async {
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.startReview(submissionId);
      _activeSubmissionId = submissionId;
      // Update the queue entry status in-place.
      _queue = _queue
          .map((AdminReviewQueueEntry e) {
            if (e.submissionId == submissionId) {
              return AdminReviewQueueEntry(
                submissionId: e.submissionId,
                entityId: e.entityId,
                entityName: e.entityName,
                credentialId: e.credentialId,
                credentialType: e.credentialType,
                credentialName: e.credentialName,
                submissionType: e.submissionType,
                // Server vocabulary (`in_review`), not the enum camelCase:
                // rows arrive snake_case and UI must compare one language.
                status: 'in_review',
                submittedAt: e.submittedAt,
                entityAvatarPath: e.entityAvatarPath,
                entityLegalName: e.entityLegalName,
                documentPath: e.documentPath,
                professionId: e.professionId,
                professionName: e.professionName,
                assignedReviewer: e.assignedReviewer,
                decisionNotes: e.decisionNotes,
              );
            }
            return e;
          })
          .toList(growable: false);
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Start review failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  /// Approves a submission and refreshes the queue.
  Future<void> approveSubmission(
    String submissionId, {
    String notes = '',
  }) async {
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.approveSubmission(submissionId, notes: notes);
      // Remove from queue (terminal decision).
      _queue = _queue
          .where((AdminReviewQueueEntry e) => e.submissionId != submissionId)
          .toList(growable: false);
      if (_serverTotalCount != null && _serverTotalCount! > 0) {
        _serverTotalCount = _serverTotalCount! - 1;
      }
      if (_activeSubmissionId == submissionId) {
        _activeSubmissionId = null;
      }
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Approve failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  /// Rejects a submission and refreshes the queue.
  Future<void> rejectSubmission(
    String submissionId, {
    String notes = '',
    bool requiresResubmission = false,
  }) async {
    _acting = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.rejectSubmission(
        submissionId,
        notes: notes,
        requiresResubmission: requiresResubmission,
      );
      // Remove from queue (terminal decision).
      _queue = _queue
          .where((AdminReviewQueueEntry e) => e.submissionId != submissionId)
          .toList(growable: false);
      if (_serverTotalCount != null && _serverTotalCount! > 0) {
        _serverTotalCount = _serverTotalCount! - 1;
      }
      if (_activeSubmissionId == submissionId) {
        _activeSubmissionId = null;
      }
    } on ApiException catch (e) {
      _error = e;
      _logger?.warning('Reject failed', <String, Object?>{
        'kind': e.kind.name,
        'code': e.code,
      });
    } finally {
      _acting = false;
      notifyListeners();
    }
  }

  /// Loads the audit trail for a submission.
  Future<void> loadAuditTrail(String submissionId) async {
    _loadingAudit = true;
    _error = null;
    _activeSubmissionId = submissionId;
    notifyListeners();
    try {
      _auditTrail = await _repo.getAuditTrail(submissionId);
    } on ApiException catch (e) {
      _error = e;
      _auditTrail = const <AdminReviewAuditEntry>[];
    } finally {
      _loadingAudit = false;
      notifyListeners();
    }
  }

  /// Loads the applicant profile depth for a submission. Empty sections
  /// mean the applicant recorded nothing — the panels render explicit
  /// empty states, never errors.
  Future<void> loadReviewProfile(String submissionId) async {
    if (_loadingProfile && _profileSubmissionId == submissionId) return;
    _loadingProfile = true;
    _profileSubmissionId = submissionId;
    notifyListeners();
    try {
      _profile = await _repo.getReviewProfile(submissionId);
    } on ApiException catch (e) {
      _error = e;
      _profile = const AdminReviewProfile();
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  /// Creates a signed URL for a credential document.
  Future<String> createDocumentSignedUrl(String credentialId) async {
    return _repo.createDocumentSignedUrl(credentialId);
  }
}
