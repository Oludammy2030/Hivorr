import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job_quotation.dart';
import 'package:hivorr/data/models/hire_dto.dart';
import 'package:hivorr/data/models/hire_envelopes_dto.dart';
import 'package:hivorr/data/models/job_quotation_dto.dart';

/// Transformations between the hiring transport DTOs and the pure-Dart domain
/// entities (EP-04-02).
///
/// The single transformation boundary between the RPC layer and the domain —
/// no I/O and no business logic, only null-safe field copying (EP-01-08 §5.3).
abstract final class HireMapper {
  /// Maps a `job_quotations` DTO into a domain [JobQuotation].
  static JobQuotation quotationToEntity(JobQuotationDto dto) => JobQuotation(
    id: dto.id,
    applicationId: dto.applicationId,
    proposedBy: dto.proposedBy,
    proposedAmount: dto.proposedAmount,
    currencyCode: dto.currencyCode,
    durationDays: dto.durationDays,
    message: dto.message,
    revisionNumber: dto.revisionNumber,
    status: dto.status,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
    decidedAt: dto.decidedAt,
  );

  /// Maps a `hires` DTO into a domain [Hire].
  static Hire hireToEntity(HireDto dto) => Hire(
    id: dto.id,
    jobId: dto.jobId,
    applicationId: dto.applicationId,
    quotationId: dto.quotationId,
    clientEntityId: dto.clientEntityId,
    professionalEntityId: dto.professionalEntityId,
    contractId: dto.contractId,
    status: dto.status,
    hiredAt: dto.hiredAt,
    completedAt: dto.completedAt,
    cancelledAt: dto.cancelledAt,
    effectiveStatus: dto.effectiveStatus,
    jobTitle: dto.jobTitle,
    jobStatus: dto.jobStatus,
  );

  /// Maps a `hire_list_mine` envelope into domain [Hire]s.
  static List<Hire> listEnvelopeToEntities(HireListEnvelopeDto dto) =>
      dto.hires.map(hireToEntity).toList(growable: false);
}
