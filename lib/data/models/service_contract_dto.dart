/// Data Transfer Object for a `service_contracts` row (EP-03-10).
///
/// Mirrors the `service_contract_get` / `service_contract_list_mine`
/// projections
/// (`supabase/migrations/20260923090001_service_contract_schema.sql`).
/// `listing_slug/title`, `profession_slug/name`, and `industry_slug/name` are
/// denormalized join fields present only in the `service_contract_get`
/// envelope.
class ServiceContractDto {
  const ServiceContractDto({
    required this.id,
    required this.serviceListingId,
    required this.clientEntityId,
    required this.professionalEntityId,
    required this.status,
    this.escrowId,
    required this.totalAmount,
    required this.currencyCode,
    this.offerExpiresAt,
    this.offeredAt,
    this.acceptedAt,
    this.completedAt,
    this.closedAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.listingSlug,
    this.listingTitle,
    this.professionSlug,
    this.professionName,
    this.industrySlug,
    this.industryName,
  });

  factory ServiceContractDto.fromJson(Map<String, dynamic> json) =>
      ServiceContractDto(
        id: (json['id'] as String?) ?? '',
        serviceListingId: (json['service_listing_id'] as String?) ?? '',
        clientEntityId: (json['client_entity_id'] as String?) ?? '',
        professionalEntityId:
            (json['professional_entity_id'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'offered',
        escrowId: json['escrow_id'] as String?,
        totalAmount: _parseDouble(json['total_amount']) ?? 0,
        currencyCode: (json['currency_code'] as String?) ?? 'NGN',
        offerExpiresAt: _parseDate(json['offer_expires_at']),
        offeredAt: _parseDate(json['offered_at']),
        acceptedAt: _parseDate(json['accepted_at']),
        completedAt: _parseDate(json['completed_at']),
        closedAt: _parseDate(json['closed_at']),
        cancelledAt: _parseDate(json['cancelled_at']),
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
        listingSlug: json['listing_slug'] as String?,
        listingTitle: json['listing_title'] as String?,
        professionSlug: json['profession_slug'] as String?,
        professionName: json['profession_name'] as String?,
        industrySlug: json['industry_slug'] as String?,
        industryName: json['industry_name'] as String?,
      );

  final String id;
  final String serviceListingId;
  final String clientEntityId;
  final String professionalEntityId;
  final String status;
  final String? escrowId;
  final double totalAmount;
  final String currencyCode;
  final DateTime? offerExpiresAt;
  final DateTime? offeredAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? closedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? listingSlug;
  final String? listingTitle;
  final String? professionSlug;
  final String? professionName;
  final String? industrySlug;
  final String? industryName;

  static double? _parseDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
