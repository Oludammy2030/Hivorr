/// A business identity hirable on Hivorr (identity audit Phase 2a).
///
/// Mirrors `businesses` (`supabase/migrations/20261011090004_business_verification_lane.sql`).
/// `tradingName` is the public face; `registeredLegalName` + `cacNumber` are
/// the registered identity (never proof by themselves). `status` spans
/// `pending | approved | rejected`; it moves only via the verification review
/// RPC (never client-written). Pure Dart domain — no DTO leakage.
///
/// A business approval never touches personal KYC tiers or trade bindings
/// (no cross-grant, `AGENT.md` Rule 4); the `canAct` hints below are
/// view-intent only and never enforcement.
class Business {
  const Business({
    required this.id,
    required this.tradingName,
    required this.registeredLegalName,
    this.cacNumber,
    required this.status,
    this.membership,
  });

  /// The business row id.
  final String id;

  /// Public-facing trading name.
  final String tradingName;

  /// Registered legal business name.
  final String registeredLegalName;

  /// CAC registration number, when supplied.
  final String? cacNumber;

  /// Verification lifecycle state.
  final String status;

  /// The caller's membership, when listed through the member roster.
  final BusinessMembership? membership;

  /// Whether the business passed verification.
  bool get isVerified => status == 'approved';

  /// Whether verification concluded without approval.
  bool get isRejected => status == 'rejected';

  /// Whether review is still outstanding.
  bool get isPending => status == 'pending';

  /// View-intent hint: the caller may act for this business (authorized
  /// representative of a verified business).
  bool get canAct =>
      isVerified &&
      (membership?.isAuthorized ?? false);
}

/// A caller's link to a business (identity audit Phase 2a).
///
/// Mirrors `business_memberships`. `role` spans `representative | member`;
/// `isAuthorized` is granted only by business approval (submitter) or admin.
class BusinessMembership {
  const BusinessMembership({
    required this.businessId,
    required this.entityId,
    required this.role,
    required this.isAuthorized,
  });

  /// The business row id.
  final String businessId;

  /// The member entity id.
  final String entityId;

  /// Membership role.
  final String role;

  /// Whether the member may act for the business.
  final bool isAuthorized;

  /// Whether this membership represents (vs merely belongs to).
  bool get isRepresentative => role == 'representative';
}
