import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/models/dispute_case_detail.dart';
import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_list_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_resolution_dto.dart';

/// Transformations between the dispute transport DTOs and the pure-Dart domain
/// entities (EP-02-17 §5.3/§5.4).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
/// Missing lists degrade to `[]` and a missing resolution to `null`.
abstract final class DisputeMapper {
  /// Maps a `dispute_cases` DTO into a domain [DisputeCase].
  static DisputeCase caseToEntity(DisputeCaseDto dto) => DisputeCase(
        id: dto.id,
        escrowId: dto.escrowId,
        filerEntityId: dto.filerEntityId,
        counterpartyEntityId: dto.counterpartyEntityId,
        disputeType: dto.disputeType,
        status: dto.status,
        reason: dto.reason,
        desiredOutcome: dto.desiredOutcome,
        priority: dto.priority,
        filedAt: dto.filedAt,
        resolvedAt: dto.resolvedAt,
        closedAt: dto.closedAt,
        withdrawnAt: dto.withdrawnAt,
        metadata: dto.metadata,
      );

  /// Maps a `dispute_evidence` DTO into a domain [DisputeEvidence].
  static DisputeEvidence evidenceToEntity(DisputeEvidenceDto dto) =>
      DisputeEvidence(
        id: dto.id,
        caseId: dto.caseId,
        submittedBy: dto.submittedBy,
        evidenceType: dto.evidenceType,
        title: dto.title,
        description: dto.description,
        fileUrl: dto.fileUrl,
        fileMetadata: dto.fileMetadata,
        createdAt: dto.createdAt,
      );

  /// Maps a `dispute_resolutions` DTO into a domain [DisputeResolution].
  static DisputeResolution resolutionToEntity(DisputeResolutionDto dto) =>
      DisputeResolution(
        id: dto.id,
        caseId: dto.caseId,
        resolvedBy: dto.resolvedBy,
        resolutionType: dto.resolutionType,
        reasoning: dto.reasoning,
        payerRefundAmount: dto.payerRefundAmount,
        payeeReleaseAmount: dto.payeeReleaseAmount,
        notes: dto.notes,
        resolvedAt: dto.resolvedAt,
        createdAt: dto.createdAt,
      );

  /// Maps the `dispute_list` envelope into a list of [DisputeCase].
  static List<DisputeCase> listEnvelopeToEntities(
    DisputeListEnvelopeDto dto,
  ) =>
      dto.disputes.map(caseToEntity).toList(growable: false);

  /// Maps the `dispute_get` envelope into a [DisputeCaseDetail] value object.
  static DisputeCaseDetail caseDetailToEntity(
    DisputeCaseDetailEnvelopeDto dto,
  ) =>
      DisputeCaseDetail(
        disputeCase: caseToEntity(dto.caseDto),
        evidence: dto.evidence.map(evidenceToEntity).toList(growable: false),
        resolution: dto.resolution == null
            ? null
            : resolutionToEntity(dto.resolution!),
      );
}