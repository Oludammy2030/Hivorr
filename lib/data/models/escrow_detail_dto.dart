import 'package:hivorr/data/models/escrow_dto.dart';
import 'package:hivorr/data/models/escrow_milestone_dto.dart';
import 'package:hivorr/data/models/escrow_transaction_dto.dart';

/// Data Transfer Object for the aggregated `financial_escrow_get` result.
///
/// Mirrors the envelope `data` object
/// (`supabase/migrations/20260829100004_financial_integrity_schema.sql:1142-1145`):
/// `{escrow: {...}, milestones: [...]}`. The transactions list is parsed from
/// an optional registered key so the seam is ready for future envelopes while
/// remaining empty today.
class EscrowDetailDto {
  const EscrowDetailDto({
    required this.escrow,
    required this.milestones,
    required this.transactions,
  });

  factory EscrowDetailDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? escrow = json['escrow'] as Map<String, dynamic>?;
    return EscrowDetailDto(
      escrow: EscrowDto.fromJson(escrow ?? <String, dynamic>{}),
      milestones: _parseMilestones(json['milestones']),
      transactions: _parseTransactions(json['transactions']),
    );
  }

  final EscrowDto escrow;
  final List<EscrowMilestoneDto> milestones;
  final List<EscrowTransactionDto> transactions;

  static List<EscrowMilestoneDto> _parseMilestones(dynamic value) {
    if (value is! List) return const <EscrowMilestoneDto>[];
    return value
        .map((e) => EscrowMilestoneDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static List<EscrowTransactionDto> _parseTransactions(dynamic value) {
    if (value is! List) return const <EscrowTransactionDto>[];
    return value
        .map((e) => EscrowTransactionDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}