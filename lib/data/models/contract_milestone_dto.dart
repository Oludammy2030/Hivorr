/// Data Transfer Object for a `contract_milestones` row (EP-03-10).
///
/// Mirrors the frozen migration column set
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`
/// `contract_milestones` section). `status` spans
/// `pending | completed | verified | released` (`verified` is the client
/// acceptance state; `released` is written only by the EP-03-11 escrow path).
class ContractMilestoneDto {
  const ContractMilestoneDto({
    required this.id,
    required this.contractId,
    this.escrowMilestoneId,
    required this.milestoneNumber,
    required this.title,
    this.description,
    required this.amount,
    required this.status,
    this.evidencePath,
    required this.sortOrder,
    this.completedAt,
    this.verifiedAt,
    this.releasedAt,
    this.reviewPeriodExpiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ContractMilestoneDto.fromJson(Map<String, dynamic> json) =>
      ContractMilestoneDto(
        id: (json['id'] as String?) ?? '',
        contractId: (json['contract_id'] as String?) ?? '',
        escrowMilestoneId: json['escrow_milestone_id'] as String?,
        milestoneNumber: _parseInt(json['milestone_number']),
        title: (json['title'] as String?) ?? '',
        description: json['description'] as String?,
        amount: _parseDouble(json['amount']) ?? 0,
        status: (json['status'] as String?) ?? 'pending',
        evidencePath:
            (json['evidence_path'] as String?) ??
            (json['evidencePath'] as String?),
        sortOrder: _parseInt(json['sort_order'], fallback: 0),
        completedAt: _parseDate(json['completed_at']),
        verifiedAt: _parseDate(json['verified_at']),
        releasedAt: _parseDate(json['released_at']),
        reviewPeriodExpiresAt: _parseDate(json['review_period_expires_at']),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );

  final String id;
  final String contractId;
  final String? escrowMilestoneId;
  final int milestoneNumber;
  final String title;
  final String? description;
  final double amount;
  final String status;
  final String? evidencePath;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime? verifiedAt;
  final DateTime? releasedAt;
  final DateTime? reviewPeriodExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int _parseInt(Object? v, {int fallback = 1}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
