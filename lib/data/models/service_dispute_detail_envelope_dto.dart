import 'package:hivorr/data/models/dispute_case_detail_envelope_dto.dart';
import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_resolution_dto.dart';
import 'package:hivorr/data/models/service_dispute_contract_summary_dto.dart';

/// Envelope DTO for the `service_dispute_get` response (EP-03-17 §5).
///
/// Shape: `{case, evidence: [...], resolution: {...}|null, contract: {...}|null}`.
/// Evidence degrades to `[]` and both `resolution` and `contract` degrade to
/// `null` when absent — never throws on partial envelopes.
class ServiceDisputeDetailEnvelopeDto {
  const ServiceDisputeDetailEnvelopeDto({
    required this.caseDto,
    required this.evidence,
    this.resolution,
    this.contract,
  });

  factory ServiceDisputeDetailEnvelopeDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic>? caseData = json['case'] as Map<String, dynamic>?;
    final Map<String, dynamic>? resolutionData =
        json['resolution'] as Map<String, dynamic>?;
    final Map<String, dynamic>? contractData =
        json['contract'] as Map<String, dynamic>?;
    return ServiceDisputeDetailEnvelopeDto(
      caseDto: DisputeCaseDto.fromJson(caseData ?? <String, dynamic>{}),
      evidence: _parseEvidence(json['evidence']),
      resolution: resolutionData == null
          ? null
          : DisputeResolutionDto.fromJson(resolutionData),
      contract: contractData == null
          ? null
          : ServiceDisputeContractSummaryDto.fromJson(contractData),
    );
  }

  /// Reuses the base detail envelope parser so both read paths share one
  /// evidence/resolution mapping implementation.
  factory ServiceDisputeDetailEnvelopeDto.fromBase(
    DisputeCaseDetailEnvelopeDto base, {
    ServiceDisputeContractSummaryDto? contract,
  }) =>
      ServiceDisputeDetailEnvelopeDto(
        caseDto: base.caseDto,
        evidence: base.evidence,
        resolution: base.resolution,
        contract: contract,
      );

  final DisputeCaseDto caseDto;
  final List<DisputeEvidenceDto> evidence;
  final DisputeResolutionDto? resolution;
  final ServiceDisputeContractSummaryDto? contract;

  static List<DisputeEvidenceDto> _parseEvidence(dynamic value) {
    if (value is! List) return const <DisputeEvidenceDto>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(DisputeEvidenceDto.fromJson)
        .toList(growable: false);
  }
}
