import 'package:hivorr/data/models/hire_dto.dart';
import 'package:hivorr/data/models/job_application_dto.dart';
import 'package:hivorr/data/models/job_dto.dart';
import 'package:hivorr/data/models/job_quotation_dto.dart';

/// Envelope for `hire_list_mine` (EP-04-02).
///
/// `data` shape: `{items: Hire[] (+job_title/job_status), has_more,
/// next_cursor}`.
class HireListEnvelopeDto {
  const HireListEnvelopeDto({
    required this.hires,
    required this.hasMore,
    this.nextCursor,
  });

  factory HireListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? rawItems = json['items'];
    return HireListEnvelopeDto(
      hires: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(HireDto.fromJson)
                .toList(growable: false)
          : const <HireDto>[],
      hasMore: (json['has_more'] as bool?) ?? false,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<HireDto> hires;
  final bool hasMore;
  final String? nextCursor;
}

/// Envelope for `hire_get` (EP-04-02).
///
/// `data` shape: `{hire, effective_status, job, application,
/// quotation|null, contract|null}`. `contract` is a passthrough row map —
/// contract reads stay owned by the escrow/contract providers.
class HireDetailEnvelopeDto {
  const HireDetailEnvelopeDto({
    required this.hire,
    required this.effectiveStatus,
    required this.job,
    required this.application,
    this.quotation,
    this.contract,
  });

  factory HireDetailEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? hireRaw = json['hire'];
    final Object? jobRaw = json['job'];
    final Object? appRaw = json['application'];
    final Object? quoteRaw = json['quotation'];
    final Object? contractRaw = json['contract'];
    return HireDetailEnvelopeDto(
      hire: HireDto.fromJson(
        hireRaw is Map<String, dynamic> ? hireRaw : const <String, dynamic>{},
      ),
      effectiveStatus: (json['effective_status'] as String?) ?? 'pending',
      job: JobDto.fromJson(
        jobRaw is Map<String, dynamic> ? jobRaw : const <String, dynamic>{},
      ),
      application: JobApplicationDto.fromJson(
        appRaw is Map<String, dynamic> ? appRaw : const <String, dynamic>{},
      ),
      quotation: quoteRaw is Map<String, dynamic>
          ? JobQuotationDto.fromJson(quoteRaw)
          : null,
      contract: contractRaw is Map<String, dynamic>
          ? Map<String, dynamic>.from(contractRaw)
          : null,
    );
  }

  final HireDto hire;
  final String effectiveStatus;
  final JobDto job;
  final JobApplicationDto application;
  final JobQuotationDto? quotation;
  final Map<String, dynamic>? contract;
}

/// Envelope for the `hire_accept` write (EP-04-02).
///
/// `data` shape: `{hire, contract_id}`.
class HireAcceptEnvelopeDto {
  const HireAcceptEnvelopeDto({required this.hire, required this.contractId});

  factory HireAcceptEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final Object? hireRaw = json['hire'];
    return HireAcceptEnvelopeDto(
      hire: HireDto.fromJson(
        hireRaw is Map<String, dynamic> ? hireRaw : const <String, dynamic>{},
      ),
      contractId: (json['contract_id'] as String?) ?? '',
    );
  }

  final HireDto hire;
  final String contractId;
}
