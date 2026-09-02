import 'package:hivorr/data/models/verification_status_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';

/// Abstract contract for the remote (Supabase) side of trade verification
/// (EP-02-11 §5.2).
///
/// Implementations access the backend only through the EP-01-07
/// [BaseApiService] channel and the `verification_*` RPCs — never writing
/// `verification_submissions.status` or
/// `entity_professions.trade_verification_status` directly (server-authoritative,
/// `AGENT.md` Rule 4). The client only ever reads its own scoped aggregate.
abstract class TradeVerificationRemoteDataSource {
  /// Queues a trade-proof verification for [credentialId].
  ///
  /// Backed by `verification_submit` with `p_submission_type = 'trade_proof'`.
  /// Returns the queued submission DTO.
  ///
  /// Throws [ApiException] with `kind == conflict` (`PLT005`) when an active
  /// submission already exists for the credential.
  Future<VerificationSubmissionDto> submit({
    required String credentialId,
    String submissionType,
  });

  /// Fetches the verification aggregate used to derive per-profession trade
  /// status.
  ///
  /// Backed by `verification_status_get`. When [entityId] is `null` (the
  /// normal client path), the server scopes to the caller via `auth.uid()`;
  /// passing a cross-entity [entityId] yields `PLT004` forbidden.
  Future<VerificationStatusDto> getStatus({String? entityId});
}
