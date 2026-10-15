import 'package:hivorr/data/models/dispute_case_dto.dart';

/// Envelope DTO for the `service_dispute_admin_list` response (R3 follow-up).
///
/// Shape: `{disputes: [...], total_count: n}`. Rows carry the server-joined
/// `contract_status`, `contract_escrow_id`, `contract_total`,
/// `contract_currency`, `listing_title`, and `escrow_status` aliases alongside
/// the base `dispute_cases` columns; the aliases are exposed raw here and
/// interpreted by the admin read model. A missing envelope degrades to an
/// empty page with `totalCount` 0 — never throws on partial envelopes.
class DisputeAdminListEnvelopeDto {
  const DisputeAdminListEnvelopeDto({
    required this.disputes,
    required this.totalCount,
  });

  factory DisputeAdminListEnvelopeDto.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['disputes'];
    final List<DisputeCaseDto> items = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(DisputeCaseDto.fromJson)
              .toList(growable: false)
        : const <DisputeCaseDto>[];
    final dynamic total = json['total_count'];
    return DisputeAdminListEnvelopeDto(
      disputes: items,
      totalCount: total is num
          ? total.toInt()
          : int.tryParse(total?.toString() ?? '') ?? 0,
    );
  }

  final List<DisputeCaseDto> disputes;
  final int totalCount;
}
