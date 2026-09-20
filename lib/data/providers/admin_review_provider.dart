// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/logging/hivorr_logger.dart';
import 'package:hivorr/data/entities/verification_submission.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';

/// Provider exposing admin review state to the widget tree (EP-02-11 §5.5).
///
/// Depends only on the [AdminReviewRepository] abstraction. Owns the admin
/// flag, the queue list, the detail audit trail, and the approve/reject
/// lifecycle. UI consumes this provider, never the repository directly.
class AdminReviewProvider extends ChangeNotifier {
  AdminReviewProvider({
    required AdminReviewRepository repo,
    HivorrLogger? logger,
  }) : _repo = repo,
       _logger = logger;

  final AdminReviewRepository _repo;
  final HivorrLogger? _logger;

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
  Future<void> loadQueue({String? submissionType}) async {
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
      );
      _queue = items;
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

  /// Appends the next page to the queue.
  Future<void> loadMore({String? submissionType}) async {
    if (_loadingQueue || !_hasMore) return;
    _loadingQueue = true;
    notifyListeners();
    try {
      final List<AdminReviewQueueEntry> items = await _repo.getReviewQueue(
        submissionType: submissionType,
        limit: _pageSize,
        offset: _currentOffset,
      );
      _queue = [..._queue, ...items];
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
                status: VerificationStatusKind.inReview.name,
                submittedAt: e.submittedAt,
                entityAvatarPath: e.entityAvatarPath,
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

  /// Creates a signed URL for a credential document.
  Future<String> createDocumentSignedUrl(String credentialId) async {
    return _repo.createDocumentSignedUrl(credentialId);
  }
}
