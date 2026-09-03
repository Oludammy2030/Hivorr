import 'package:hivorr/integrations/kyc/kyc_verification_result.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Abstract seam for external KYC verification providers (EP-02-12 §5.6).
///
/// A provider verifies identity/trade evidence for a target tier. The in-memory
/// [MockKycProvider] proves the seam without live NIN/BVN credentials; a future
/// SmileID/Dojah adapter adds a `dio.post(...)` behind this same interface with
/// zero `systems/` change (Open/Closed for EP-08).
///
/// Providers **never** grant local state — the server re-reads
/// `getKycLevel()` after the provider signals approval.
abstract interface class KycVerificationProvider {
  /// Stable provider identifier used in redacted logs (`mock`, `smile_id`, ...).
  String get providerName;

  /// Verifies the current entity for [targetTier].
  ///
  /// [entityId] is the owning entity; [payload] is optional provider-specific
  /// data (e.g. `{bvn, nin, dob, documentType}`), validated per-provider and
  /// not persisted by this task.
  Future<KycVerificationResult> verify({
    required String entityId,
    required KycTier targetTier,
    Map<String, dynamic>? payload,
  });
}
