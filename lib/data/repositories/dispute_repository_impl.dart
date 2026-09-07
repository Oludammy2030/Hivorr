// ignore_for_file: prefer_initializing_formals

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/datasources/remote/dispute_remote_data_source.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/mappers/dispute_mapper.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/repositories/dispute_repository.dart';

/// Default implementation of [DisputeRepository].
///
/// Implements the server-authoritative dispute flow (EP-02-17 §5.4): reads via
/// `dispute_list`/`dispute_get` mapped through [DisputeMapper]; writes via the
/// three client-callable RPCs. Known CHECK constraints are pre-validated
/// client-side (reason 10–2000, title 1–255, description ≤2000, and the frozen
/// vocabularies) so a preventable `PLT003` never round-trips. This
/// implementation never writes dispute tables directly and never references
/// `dispute_resolve` (AGENT.md Rule 4, EP-02-17 §9.2).
class DisputeRepositoryImpl implements DisputeRepository {
  DisputeRepositoryImpl({required DisputeRemoteDataSource remote})
      : _remote = remote;

  final DisputeRemoteDataSource _remote;

  // Validation mirrors of the frozen CHECK constraints
  // (`20260829120005_dispute_resolution_schema.sql:62-75,112-117`) and the
  // systems-layer vocabulary (`lib/systems/support/models/dispute_status.dart`).
  // The server remains the single authority; the repository mirrors the codes
  // for fail-fast UX only.
  static const Set<String> _disputeTypes = <String>{
    'service_quality',
    'non_delivery',
    'milestone_disagreement',
    'fraud',
    'other',
  };
  static const Set<String> _desiredOutcomes = <String>{
    'release_to_payee',
    'refund_to_payer',
    'split',
    'other',
  };
  static const Set<String> _priorities = <String>{
    'low',
    'medium',
    'high',
    'critical',
  };
  static const Set<String> _evidenceTypes = <String>{
    'document',
    'screenshot',
    'description',
    'photo',
  };
  static const Set<String> _statuses = <String>{
    'open',
    'under_review',
    'resolved',
    'closed',
    'withdrawn',
  };

  @override
  Future<List<DisputeCase>> listDisputes({String? status}) async {
    if (status != null) {
      _requireInVocabulary(status, _statuses, 'status');
    }
    final dto = await _remote.listDisputes(status: status);
    return DisputeMapper.listEnvelopeToEntities(dto);
  }

  @override
  Future<DisputeCaseDetail> getCase(String caseId) async {
    final dto = await _remote.getCase(caseId);
    return DisputeMapper.caseDetailToEntity(dto);
  }

  @override
  Future<DisputeCase> fileDispute({
    required String escrowId,
    required String disputeType,
    required String reason,
    String? desiredOutcome,
    String priority = 'medium',
  }) async {
    _requireNonEmpty(escrowId, 'escrowId');
    _requireInVocabulary(disputeType, _disputeTypes, 'disputeType');
    if (desiredOutcome != null) {
      _requireInVocabulary(desiredOutcome, _desiredOutcomes, 'desiredOutcome');
    }
    _requireInVocabulary(priority, _priorities, 'priority');
    _requireLength(reason, min: 10, max: 2000, field: 'reason');
    final DisputeCaseDto filed = await _remote.fileDispute(
      escrowId: escrowId,
      disputeType: disputeType,
      reason: reason,
      desiredOutcome: desiredOutcome,
      priority: priority,
    );
    // Re-read the authoritative case (server holds + status transitions).
    return (await getCase(filed.id)).disputeCase;
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
    _requireNonEmpty(caseId, 'caseId');
    _requireInVocabulary(evidenceType, _evidenceTypes, 'evidenceType');
    _requireLength(title, min: 1, max: 255, field: 'title');
    if (description != null) {
      _requireLength(description, min: 0, max: 2000, field: 'description');
    }
    final dto = await _remote.submitEvidence(
      caseId: caseId,
      evidenceType: evidenceType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      fileMetadata: fileMetadata,
    );
    return DisputeMapper.evidenceToEntity(dto);
  }

  @override
  Future<DisputeCase> withdrawDispute(String caseId) async {
    _requireNonEmpty(caseId, 'caseId');
    final dto = await _remote.withdrawDispute(caseId);
    return DisputeMapper.caseToEntity(dto);
  }

  static void _requireNonEmpty(String value, String field) {
    if (value.trim().isEmpty) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: '$field is required.',
        code: 'PLT003',
      );
    }
  }

  static void _requireInVocabulary(String value, Set<String> vocabulary, String field) {
    if (!vocabulary.contains(value)) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Invalid $field value: $value.',
        code: 'PLT003',
      );
    }
  }

  static void _requireLength(
    String value, {
    required int min,
    required int max,
    required String field,
  }) {
    final int length = value.trim().length;
    if (length < min || length > max) {
      throw ApiException(
        kind: ApiExceptionKind.validation,
        message: '$field must be between $min and $max characters.',
        code: 'PLT003',
      );
    }
  }
}
