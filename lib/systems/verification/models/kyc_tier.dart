import 'package:hivorr/data/entities/kyc_level.dart';

/// KYC verification tier (EP-02-12 §16).
///
/// Server-authoritative enum mirroring `kyc_tiers.tier_code` from the frozen
/// schema. Pure Dart — no I/O, no Flutter dependency. Used by [KycLimitGuard]
/// and [KycProvider] to enforce tier-based access control.
enum KycTier {
  tier0('tier_0', 'Unverified', false),
  tier1('tier_1', 'Basic', true),
  tier2('tier_2', 'Standard', true),
  tier3('tier_3', 'Premium', true);

  const KycTier(this.code, this.displayLabel, this.isVerified);

  /// The server tier code (`tier_0`..`tier_3`).
  final String code;

  /// Human-readable tier label for UI display.
  final String displayLabel;

  /// Whether this tier satisfies identity verification requirements.
  final bool isVerified;

  /// Resolves a server tier code to the corresponding [KycTier].
  ///
  /// Falls back to [KycTier.tier0] if the code is unknown.
  static KycTier fromCode(String code) {
    return KycTier.values.firstWhere(
      (tier) => tier.code == code,
      orElse: () => KycTier.tier0,
    );
  }

  /// Whether this tier is at least [other] (lexicographic comparison).
  ///
  /// Safe because tier codes are `tier_0`..`tier_3`.
  bool isAtLeast(KycTier other) => code.compareTo(other.code) >= 0;

  /// Whether this tier is at least `tier_1` (verified).
  bool get isAtLeastVerified => isAtLeast(KycTier.tier1);

  /// Returns the cashout limit for this tier from the given [KycLimits].
  num cashoutLimit(KycLimits limits) => limits.cashout;
}
