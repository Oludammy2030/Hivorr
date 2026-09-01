import 'package:hivorr/data/models/kyc_level_dto.dart';
import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';

/// Abstract contract for the remote (Supabase) side of identity verification.
///
/// Implementations must access the backend only through the EP-01-07
/// [BaseApiService] channel and the verification RPCs — never directly writing
/// `verification_submissions.status`, `entity_kyc_levels`, or
/// `entity_professions.trade_verification_status` (server-authoritative,
/// `AGENT.md` Rule 4). All reads pass through the `verification_*` RPCs.
abstract class VerificationRemoteDataSource {
  /// Queues a verification submission for [credentialId].
  ///
  /// Backed by `verification_submit`. Returns the queued submission DTO.
  ///
  /// Throws [ApiException] with `kind == conflict` (`PLT005`) when an active
  /// submission already exists for the credential.
  Future<VerificationSubmissionDto> submit({
    required String credentialId,
    String? submissionType,
  });

  /// Fetches the full verification aggregate.
  ///
  /// Backed by `verification_status_get`. When [entityId] is `null` (the
  /// normal client path), the server scopes to the caller via `auth.uid()`.
  /// Passing a cross-entity [entityId] yields `PLT004` forbidden.
  Future<VerificationStatusDto> getStatus({String? entityId});

  /// Fetches the assigned KYC level.
  ///
  /// Backed by `verification_kyc_level_get`.
  Future<KycLevelDto> getKycLevel();

  /// Fetches the KYC tier limits.
  ///
  /// Backed by `verification_limits_get`. `status` is not part of this RPC, so
  /// it defaults to `pending` in the returned DTO.
  Future<KycLevelDto> getLimits();
}
