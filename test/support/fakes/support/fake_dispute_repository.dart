// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';

/// In-memory [DisputeRepository] for provider/widget tests (EP-02-17).
///
/// Serves scripted cases/details with call counters. Mirrors the real
/// repository's 5-method surface (`listDisputes`, `getCase`, `fileDispute`,
/// `submitEvidence`, `withdrawDispute`) — with **no resolve method**.
class FakeDisputeRepository implements DisputeRepository {
  FakeDisputeRepository({
    List<DisputeCase> cases = const <DisputeCase>[],
    DisputeCaseDetail? detail,
  })  : _cases = List<DisputeCase>.of(cases),
        _detail = detail;

  List<DisputeCase> _cases;
  DisputeCaseDetail? _detail;

  ApiException? nextError;
  int listCallCount = 0;
  int getCaseCallCount = 0;
  int fileCallCount = 0;
  int submitEvidenceCallCount = 0;
  int withdrawCallCount = 0;

  /// The last `status` passed to [listDisputes].
  String? lastStatusFilter;

  /// The last case id passed to [getCase]/[submitEvidence]/[withdrawDispute].
  String? lastCaseId;

  /// The last fields passed to [fileDispute].
  String? lastEscrowId;
  String? lastDisputeType;
  String? lastReason;
  String? lastDesiredOutcome;
  String? lastPriority;

  /// The last evidence title passed to [submitEvidence].
  String? lastTitle;

  /// The last evidence type code passed to [submitEvidence].
  String? lastEvidenceTypeCode;

  /// The last evidence description passed to [submitEvidence].
  String? lastDescription;

  /// The last file metadata map passed to [submitEvidence].
  Map<String, dynamic>? lastFileMetadata;

  /// The last evidence `fileUrl` passed to [submitEvidence].
  String? lastFileUrl;

  void setCases(List<DisputeCase> cases) => _cases = List<DisputeCase>.of(cases);

  void setDetail(DisputeCaseDetail? detail) => _detail = detail;

  @override
  Future<List<DisputeCase>> listDisputes({String? status}) async {
    listCallCount++;
    lastStatusFilter = status;
    if (nextError != null) throw nextError!;
    if (status != null) {
      return _cases.where((DisputeCase c) => c.status == status).toList();
    }
    return List<DisputeCase>.of(_cases);
  }

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async {
    getCaseCallCount++;
    lastCaseId = caseId;
    if (nextError != null) throw nextError!;
    return _detail ?? seedDisputeDetailEntity(id: caseId);
  }

  @override
  Future<DisputeCase> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  }) async {
    fileCallCount++;
    lastEscrowId = escrowId;
    lastDisputeType = disputeType;
    lastReason = reason;
    lastDesiredOutcome = desiredOutcome;
    lastPriority = priority;
    if (nextError != null) throw nextError!;
    return seedDisputeCaseEntity(
      id: 'dispute-filed-1',
      escrowId: escrowId,
      disputeType: disputeType,
      reason: reason,
      desiredOutcome: desiredOutcome,
      priority: priority,
      status: 'open',
    );
  }

  @override
  Future<DisputeEvidence> submitEvidence({
    required String caseId,
    required String evidenceType,
    required String title,
    String? description,
    String? fileUrl,
    Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  }) async {
    submitEvidenceCallCount++;
    lastCaseId = caseId;
    lastTitle = title;
    lastEvidenceTypeCode = evidenceType;
    lastDescription = description;
    lastFileUrl = fileUrl;
    lastFileMetadata = fileMetadata;
    if (nextError != null) throw nextError!;
    return seedDisputeEvidenceEntity(
      id: 'evidence-1',
      caseId: caseId,
      evidenceType: evidenceType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      fileMetadata: fileMetadata,
    );
  }

  @override
  Future<DisputeCase> withdrawDispute(String caseId) async {
    withdrawCallCount++;
    lastCaseId = caseId;
    if (nextError != null) throw nextError!;
    return seedDisputeCaseEntity(
      id: caseId,
      status: 'withdrawn',
      withdrawnAt: DateTime.fromMillisecondsSinceEpoch(3000),
    );
  }
}

/// Fixture builders shared across the dispute tests (EP-02-17).
DisputeCase seedDisputeCaseEntity({
  String id = 'dispute-1',
  String escrowId = 'escrow-1',
  String filerEntityId = 'entity-filer',
  String counterpartyEntityId = 'entity-counterparty',
  String disputeType = 'service_quality',
  String status = 'open',
  String reason = 'Work did not match the agreed milestone description.',
  String? desiredOutcome = 'release_to_payee',
  String priority = 'medium',
  DateTime? filedAt,
  DateTime? resolvedAt,
  DateTime? closedAt,
  DateTime? withdrawnAt,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) =>
    DisputeCase(
      id: id,
      escrowId: escrowId,
      filerEntityId: filerEntityId,
      counterpartyEntityId: counterpartyEntityId,
      disputeType: disputeType,
      status: status,
      reason: reason,
      desiredOutcome: desiredOutcome,
      priority: priority,
      filedAt: filedAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
      resolvedAt: resolvedAt,
      closedAt: closedAt,
      withdrawnAt: withdrawnAt,
      metadata: metadata,
    );

DisputeEvidence seedDisputeEvidenceEntity({
  String id = 'evidence-1',
  String caseId = 'dispute-1',
  String submittedBy = 'entity-filer',
  String evidenceType = 'screenshot',
  String title = 'Mismatch screenshot',
  String? description,
  String? fileUrl,
  Map<String, dynamic> fileMetadata = const <String, dynamic>{},
  DateTime? createdAt,
}) =>
    DisputeEvidence(
      id: id,
      caseId: caseId,
      submittedBy: submittedBy,
      evidenceType: evidenceType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      fileMetadata: fileMetadata,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(1000),
    );

DisputeResolution seedDisputeResolutionEntity({
  String id = 'resolution-1',
  String caseId = 'dispute-1',
  String? resolvedBy = 'admin-1',
  String resolutionType = 'release_to_payee',
  String reasoning =
      'Both parties submitted evidence; funds are released to the provider.',
  double payerRefundAmount = 0.0,
  double payeeReleaseAmount = 0.0,
  String? notes,
  DateTime? resolvedAt,
}) =>
    DisputeResolution(
      id: id,
      caseId: caseId,
      resolvedBy: resolvedBy,
      resolutionType: resolutionType,
      reasoning: reasoning,
      payerRefundAmount: payerRefundAmount,
      payeeReleaseAmount: payeeReleaseAmount,
      notes: notes,
      resolvedAt: resolvedAt ?? DateTime.fromMillisecondsSinceEpoch(2000),
      createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );

DisputeCaseDetail seedDisputeDetailEntity({
  String id = 'dispute-1',
  String status = 'open',
  List<DisputeEvidence> evidence = const <DisputeEvidence>[],
  DisputeResolution? resolution,
}) =>
    DisputeCaseDetail(
      disputeCase: seedDisputeCaseEntity(id: id, status: status),
      evidence: evidence,
      resolution: resolution,
    );