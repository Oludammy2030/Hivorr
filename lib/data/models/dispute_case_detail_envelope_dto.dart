import 'package:hivorr/data/models/dispute_case_dto.dart';
import 'package:hivorr/data/models/dispute_evidence_dto.dart';
import 'package:hivorr/data/models/dispute_resolution_dto.dart';

/// Data Transfer Object for the `dispute_get` envelope `data` object.
///
/// Mirrors `dispute_get` return shape
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:786-827`):
/// `{case: {...}, evidence: [...], resolution: {...} | null}`.
class DisputeCaseDetailEnvelopeDto {
  const DisputeCaseDetailEnvelopeDto({
    required this.caseDto,
    required this.evidence,
    this.resolution,
  });

  factory DisputeCaseDetailEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? caseData = json['case'] as Map<String, dynamic>?;
    final Map<String, dynamic>? resolutionData =
        json['resolution'] as Map<String, dynamic>?;
    return DisputeCaseDetailEnvelopeDto(
      caseDto: DisputeCaseDto.fromJson(caseData ?? <String, dynamic>{}),
      evidence: _parseEvidence(json['evidence']),
      resolution: resolutionData == null
          ? null
          : DisputeResolutionDto.fromJson(resolutionData),
    );
  }

  final DisputeCaseDto caseDto;
  final List<DisputeEvidenceDto> evidence;
  final DisputeResolutionDto? resolution;

  static List<DisputeEvidenceDto> _parseEvidence(dynamic value) {
    if (value is! List) return const <DisputeEvidenceDto>[];
    return value
        .map((e) => DisputeEvidenceDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}