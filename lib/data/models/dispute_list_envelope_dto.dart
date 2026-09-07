import 'package:hivorr/data/models/dispute_case_dto.dart';

/// Data Transfer Object for the `dispute_list` envelope `data` object.
///
/// Mirrors `dispute_list` return shape
/// (`supabase/migrations/20260829120005_dispute_resolution_schema.sql:830-859`):
/// `{disputes: [...]}`.
class DisputeListEnvelopeDto {
  const DisputeListEnvelopeDto({required this.disputes});

  factory DisputeListEnvelopeDto.fromJson(Map<String, dynamic> json) =>
      DisputeListEnvelopeDto(
        disputes: _parseDisputes(json['disputes']),
      );

  final List<DisputeCaseDto> disputes;

  static List<DisputeCaseDto> _parseDisputes(dynamic value) {
    if (value is! List) return const <DisputeCaseDto>[];
    return value
        .map((e) => DisputeCaseDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}