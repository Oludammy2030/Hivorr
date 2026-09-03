import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Abstract contract for KYC data operations (EP-02-12 §5.3).
///
/// Depends only on domain entities and the [KycTier] vocabulary — never on
/// concrete backend types — so business systems and UI consume this interface,
/// not a Supabase implementation (ARCHITECTURE.md / EP-01-08 §5.6).
abstract class KycRepository {
  /// Fetches the assigned KYC level (tier + limits) for the current entity.
  ///
  /// Returns a `tier_0` all-zero level when no `entity_kyc_levels` row exists —
  /// never throws for unassigned.
  Future<KycLevel> getKycLevel();

  /// Fetches the KYC tier limits for the current entity.
  Future<KycLimits> getLimits();

  /// Fetches the full verification aggregate (KYC + identity + trades).
  Future<VerificationStatus> getStatus();

  /// Requests an upgrade to [targetTier] through the configured KYC provider
  /// seam.
  ///
  /// Validates `targetTier.code > current.tier_code` (string compare) first —
  /// an invalid/non-upgrade target throws an [ApiException] with
  /// `kind == validation` (`PLT003`) **before** the provider is invoked. Never
  /// writes `entity_kyc_levels` (server-authoritative, `AGENT.md` Rule 4).
  ///
  /// If no live provider is configured, returns the [KycLevel] unchanged and
  /// surfaces guidance — no network beyond the already-fetched RPC.
  Future<KycLevel> requestUpgrade({
    required KycTier targetTier,
    Map<String, dynamic>? payload,
  });

  /// The pure upgrade path from the current tier:
  /// `tier_0 → [tier1, tier2, tier3]`, `tier_1 → [tier2, tier3]`,
  /// `tier_2 → [tier3]`, `tier_3 → []`.
  List<KycTier> eligibleUpgradePath(KycLevel current);
}
