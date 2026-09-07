// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/dispute_remote_data_source.dart';
import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_resolution_dto.dart';

/// In-memory [DisputeRemoteDataSource] for repository tests (EP-02-17).
///
/// Serves scripted case/details keyed by id with call counters. The 5-RPC
/// surface is mirrored exactly — `listDisputes`, `getCase`, `fileDispute`,
/// `submitEvidence`, `withdrawDispute` — with **no resolve method** (the
/// server-granted `dispute_resolve` is absent from the client contract).
class FakeDisputeRemoteDataSource implements DisputeRemoteDataSource {
  FakeDisputeRemoteDataSource({
    Map<String, DisputeCaseDetailEnvelopeDto> details =
        const <String, DisputeCaseDetailEnvelopeDto>{},
    List<DisputeCaseDto> list = const <DisputeCaseDto>[],
    this.fileId = 'dispute-filed-1',
    this.withdrawId = 'dispute-withdrawn-1',
    this.evidenceId = 'evidence-1',
  })  : _details = Map<String, DisputeCaseDetailEnvelopeDto>.from(details),
        _list = List<DisputeCaseDto>.of(list);

  final Map<String, DisputeCaseDetailEnvelopeDto> _details;
  List<DisputeCaseDto> _list;

  /// Id returned by [fileDispute].
  String fileId;

  /// Id returned by [withdrawDispute].
  String withdrawId;

  /// Id returned by [submitEvidence].
  String evidenceId;

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

  /// The last file metadata passed to [submitEvidence].
  Map<String, dynamic>? lastFileMetadata;

  /// The last `fileUrl` passed to [submitEvidence].
  String? lastFileUrl;

  /// The last fields passed to [fileDispute] for assertion.
  String? lastEscrowId;
  String? lastDisputeType;
  String? lastReason;
  String? lastDesiredOutcome;
  String? lastPriority;

  /// The last title passed to [submitEvidence].
  String? lastTitle;

  void setDetail(DisputeCaseDetailEnvelopeDto detail) =>
      _details[detail.caseDto.id] = detail;

  void setList(List<DisputeCaseDto> list) => _list = List<DisputeCaseDto>.of(list);

  @override
  Future<DisputeListEnvelopeDto> listDisputes({String? status}) async {
    listCallCount++;
    lastStatusFilter = status;
    if (nextError != null) throw nextError!;
    final List<DisputeCaseDto> filtered = status == null
        ? _list
        : _list.where((DisputeCaseDto c) => c.status == status).toList();
    return DisputeListEnvelopeDto(disputes: filtered);
  }

  @override
  Future<DisputeCaseDetailEnvelopeDto> getCase(String caseId) async {
    getCaseCallCount++;
    lastCaseId = caseId;
    if (nextError != null) throw nextError!;
    final DisputeCaseDetailEnvelopeDto? detail = _details[caseId];
    if (detail == null) {
      throw const ApiException(
        kind: ApiExceptionKind.notFound,
        message: 'Dispute not found.',
        code: 'PLT004',
      );
    }
    return detail;
  }

  @override
  Future<DisputeCaseDto> fileDispute({
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
    return seedDisputeCaseDto(
      id: fileId,
      escrowId: escrowId,
      disputeType: disputeType,
      reason: reason,
      desiredOutcome: desiredOutcome,
      priority: priority,
      status: 'open',
    );
  }

  @override
  Future<DisputeEvidenceDto> submitEvidence({
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
    lastFileUrl = fileUrl;
    lastFileMetadata = fileMetadata;
    if (nextError != null) throw nextError!;
    return seedDisputeEvidenceDto(
      id: evidenceId,
      caseId: caseId,
      evidenceType: evidenceType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      fileMetadata: fileMetadata,
    );
  }

  @override
  Future<DisputeCaseDto> withdrawDispute(String caseId) async {
    withdrawCallCount++;
    lastCaseId = caseId;
    if (nextError != null) throw nextError!;
    return seedDisputeCaseDto(
      id: withdrawId,
      escrowId: 'escrow-1',
      status: 'withdrawn',
    );
  }
}

DisputeCaseDto seedDisputeCaseDto({
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
}) =>
    DisputeCaseDto(
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
      metadata: const <String, dynamic>{},
    );

DisputeEvidenceDto seedDisputeEvidenceDto({
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
    DisputeEvidenceDto(
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

DisputeResolutionDto seedDisputeResolutionDto({
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
    DisputeResolutionDto(
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

DisputeCaseDetailEnvelopeDto seedDisputeDetailDto({
  DisputeCaseDto? caseDto,
  List<DisputeEvidenceDto> evidence = const <DisputeEvidenceDto>[],
  DisputeResolutionDto? resolution,
}) =>
    DisputeCaseDetailEnvelopeDto(
      caseDto: caseDto ?? seedDisputeCaseDto(),
      evidence: evidence,
      resolution: resolution,
    );