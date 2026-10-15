/// Transport shapes for the business verification lane (identity Phase 2a).
///
/// Businesses and memberships are RLS-CRUD rows (no dedicated RPC); evidence
/// flows through the extended `entity_credentials_submit` /
/// `verification_submit` RPCs. Null-safe parsing with server-matching
/// defaults; never throws on unknown columns.
class BusinessDto {
  const BusinessDto({
    required this.id,
    required this.tradingName,
    required this.registeredLegalName,
    this.cacNumber,
    required this.status,
    this.membership,
  });

  factory BusinessDto.fromJson(Map<String, dynamic> json) {
    BusinessMembershipDto? membership;
    final Object? embedded = json['business_memberships'];
    if (embedded is List && embedded.isNotEmpty) {
      final Object? first = embedded.first;
      if (first is Map<String, dynamic>) {
        membership = BusinessMembershipDto.fromJson(first);
      }
    } else if (embedded is Map<String, dynamic>) {
      membership = BusinessMembershipDto.fromJson(embedded);
    }
    return BusinessDto(
      id: (json['id'] as String?) ?? '',
      tradingName: (json['trading_name'] as String?) ?? '',
      registeredLegalName: (json['registered_legal_name'] as String?) ?? '',
      cacNumber: (json['cac_number'] as String?)?.trim(),
      status: (json['verification_status'] as String?) ?? 'pending',
      membership: membership,
    );
  }

  final String id;
  final String tradingName;
  final String registeredLegalName;
  final String? cacNumber;
  final String status;
  final BusinessMembershipDto? membership;
}

/// Transport shape for a business membership row.
class BusinessMembershipDto {
  const BusinessMembershipDto({
    required this.businessId,
    required this.entityId,
    required this.role,
    required this.isAuthorized,
    this.business,
  });

  factory BusinessMembershipDto.fromJson(Map<String, dynamic> json) {
    BusinessDto? business;
    final Object? embedded = json['businesses'];
    if (embedded is Map<String, dynamic>) {
      business = BusinessDto.fromJson(embedded);
    }
    return BusinessMembershipDto(
      businessId: (json['business_id'] as String?) ?? '',
      entityId: (json['entity_id'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'member',
      isAuthorized: (json['is_authorized'] as bool?) ?? false,
      business: business,
    );
  }

  final String businessId;
  final String entityId;
  final String role;
  final bool isAuthorized;
  final BusinessDto? business;
}
