import 'package:hivorr/data/models/business_dto.dart';
import 'package:hivorr/data/models/verification_submission_dto.dart';

/// Abstract contract for the remote (Supabase) side of business identity.
///
/// Implementations access businesses and memberships through RLS-CRUD only
/// (member-scoped policies; `verification_status` is RPC-only server-side)
/// and route evidence through `entity_credentials_submit` /
/// `verification_submit` — never writing verification state directly
/// (`AGENT.md` Rule 4).
abstract class BusinessRemoteDataSource {
  /// Lists the caller's businesses with their membership (role +
  /// authorization) attached, in no guaranteed order.
  Future<List<BusinessDto>> listMine({required String entityId});

  /// Creates a business row (starts `pending`). The caller joins separately.
  Future<BusinessDto> createBusiness({
    required String tradingName,
    required String registeredLegalName,
    String? cacNumber,
  });

  /// Inserts the caller's representative membership for [businessId].
  Future<void> joinBusiness({
    required String businessId,
    required String entityId,
  });

  /// Deletes the caller's membership row (leave).
  Future<void> leaveBusiness({
    required String businessId,
    required String entityId,
  });

  /// Submits a business-document credential via `entity_credentials_submit`.
  ///
  /// Returns the created credential row. Throws [ApiException] with
  /// `kind == notFound` (`PLT004`) for foreign/unknown businesses.
  Future<Map<String, dynamic>> submitCredential({
    required String businessId,
    required String title,
    required String documentPath,
  });

  /// Queues the credential into the `business_verification` lane.
  ///
  /// Backed by `verification_submit`. Returns the queued submission DTO.
  Future<VerificationSubmissionDto> queueSubmission({
    required String credentialId,
  });
}
