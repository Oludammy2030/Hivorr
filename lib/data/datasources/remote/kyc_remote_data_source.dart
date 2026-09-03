import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';

/// Abstract contract for the KYC-specific remote data source (EP-02-12 §5.2).
///
/// Thin dedicated wrapper over the 3 frozen RPCs:
/// - `verification_kyc_level_get` → [KycLevelDto]
/// - `verification_limits_get` → [KycLimitsDto]
/// - `verification_status_get` → [VerificationStatusDto] (KYC slice)
///
/// Distinct from [SupabaseVerificationRemoteDataSource] which wraps the same
/// RPCs for the broader verification system. The KYC layer evolves
/// independently per the seam principle.
abstract interface class KycRemoteDataSource {
  /// Fetches the current KYC level (tier + status + limits) for the caller.
  Future<KycLevelDto> getKycLevel();

  /// Fetches the KYC tier limits for the caller.
  Future<KycLimitsDto> getLimits();

  /// Fetches the full verification aggregate (KYC slice included).
  ///
  /// [entityId] is optional — when omitted (null) the RPC resolves the caller
  /// via `auth.uid()` (self). Supply it only for authorized admin reads; any
  /// cross-entity value it cannot resolve maps to `PLT004` on the server.
  Future<VerificationStatusDto> getStatus({String? entityId});
}
