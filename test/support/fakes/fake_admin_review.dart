// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';

/// In-memory [AdminReviewRepository] for provider/widget tests.
///
/// Surfaces scripted queue entries with call counters; set [nextError] to
/// exercise failure paths exactly as the real RPC layer throws [ApiException].
class FakeAdminReviewRepository implements AdminReviewRepository {
  FakeAdminReviewRepository({
    bool isAdmin = true,
    List<AdminReviewQueueEntry>? queue,
    ApiException? nextError,
  }) : isAdminResult = isAdmin,
       _queue = queue ?? const <AdminReviewQueueEntry>[],
       nextError = nextError;

  bool isAdminResult;
  List<AdminReviewQueueEntry> _queue;
  List<AdminReviewAuditEntry> _auditTrail = const <AdminReviewAuditEntry>[];

  ApiException? nextError;
  int checkAdminCallCount = 0;
  int queueCallCount = 0;
  int approveCallCount = 0;
  int rejectCallCount = 0;
  int startCallCount = 0;
  int auditCallCount = 0;
  String? lastApprovedId;
  String? lastRejectedId;
  String? lastNotes;
  bool? lastRequiresResubmission;

  /// Mutates the queue the fake serves (e.g. after an admin decision).
  void setQueue(List<AdminReviewQueueEntry> queue) => _queue = queue;

  /// Mutates the audit trail the fake serves.
  void setAuditTrail(List<AdminReviewAuditEntry> trail) => _auditTrail = trail;

  @override
  Future<bool> checkAdmin() async {
    checkAdminCallCount++;
    if (nextError != null) throw _consumeError();
    return isAdminResult;
  }

  @override
  Future<List<AdminReviewQueueEntry>> getReviewQueue({
    String? submissionType,
    int limit = 50,
    int offset = 0,
  }) async {
    queueCallCount++;
    if (nextError != null) throw _consumeError();
    if (offset >= _queue.length) return const <AdminReviewQueueEntry>[];
    final int end = (offset + limit).clamp(0, _queue.length);
    return _queue.sublist(offset, end);
  }

  @override
  Future<void> startReview(String submissionId) async {
    startCallCount++;
    if (nextError != null) throw _consumeError();
  }

  @override
  Future<void> approveSubmission(
    String submissionId, {
    String notes = '',
  }) async {
    approveCallCount++;
    lastApprovedId = submissionId;
    lastNotes = notes;
    if (nextError != null) throw _consumeError();
  }

  @override
  Future<void> rejectSubmission(
    String submissionId, {
    String notes = '',
    bool requiresResubmission = false,
  }) async {
    rejectCallCount++;
    lastRejectedId = submissionId;
    lastNotes = notes;
    lastRequiresResubmission = requiresResubmission;
    if (nextError != null) throw _consumeError();
  }

  @override
  Future<List<AdminReviewAuditEntry>> getAuditTrail(String submissionId) async {
    auditCallCount++;
    if (nextError != null) throw _consumeError();
    return _auditTrail;
  }

  @override
  Future<String> createDocumentSignedUrl(
    String credentialId, {
    int expiresIn = 60,
  }) async {
    if (nextError != null) throw _consumeError();
    return 'https://example.com/sign/$credentialId';
  }

  ApiException _consumeError() {
    final ApiException e = nextError!;
    nextError = null;
    return e;
  }
}

/// A queue entry fixture with the given id.
AdminReviewQueueEntry adminQueueEntry({
  String submissionId = 'sub-1',
  String entityId = 'u1',
  String entityName = 'Test Entity',
  String credentialId = 'cred-1',
  String credentialType = 'trade_proof',
  String credentialName = 'Trade cert',
  String submissionType = 'trade_proof',
  String status = 'pending',
  DateTime? submittedAt,
}) => AdminReviewQueueEntry(
  submissionId: submissionId,
  entityId: entityId,
  entityName: entityName,
  credentialId: credentialId,
  credentialType: credentialType,
  credentialName: credentialName,
  submissionType: submissionType,
  status: status,
  submittedAt: submittedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
);

/// An audit entry fixture.
AdminReviewAuditEntry adminAuditEntry({
  String id = 'audit-1',
  String eventType = 'submitted',
  String? fromState,
  String? toState,
  String actorId = 'u1',
  DateTime? createdAt,
}) => AdminReviewAuditEntry(
  id: id,
  eventType: eventType,
  fromState: fromState,
  toState: toState,
  actorId: actorId,
  createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
);
