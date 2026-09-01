/// The KYC (Know Your Customer) tier and its associated limits (EP-02-10).
///
/// Mirrors `kyc_tiers` / `entity_kyc_levels` read models
/// (`supabase/migrations/20260829090003_verification_admin_review_schema.sql:45-112`)
/// surfaced through the `verification_kyc_level_get` RPC. Pure Dart domain —
/// no RPC JSON shape leaks. This task only **reads** tier_1; it never writes
/// `kyc_tiers` (server-authoritative, EP-02-12 seam).
class KycLevel {
  const KycLevel({
    required this.tierCode,
    required this.status,
    required this.limits,
  });

  /// The assigned tier code, e.g. `tier_0`..`tier_3`.
  final String tierCode;

  /// Lifecycle status: `pending | active | expired`.
  final String status;

  /// Transaction limits bound to this tier.
  final KycLimits limits;

  /// Whether the identity is considered verified (active + tier >= tier_1).
  bool get isVerified => status == 'active' && tierCodeCompare('tier_1');

  /// Lexicographic comparison is safe because tiers are `tier_0..tier_3`.
  bool tierCodeCompare(String atLeast) => tierCode.compareTo(atLeast) >= 0;
}

/// Numeric transaction limits bound to a KYC tier (EP-02-10).
///
/// Mirror of `kyc_tiers.daily/weekly/monthly/cashout` (all `numeric`).
class KycLimits {
  const KycLimits({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.cashout,
  });

  /// Daily limit (NGN).
  final num daily;

  /// Weekly limit (NGN).
  final num weekly;

  /// Monthly limit (NGN).
  final num monthly;

  /// Cashout limit (NGN).
  final num cashout;
}
