import 'package:hivorr/data/models/public_profile_dto.dart';

/// Abstract contract for the remote (Supabase) side of portfolio data.
///
/// Implementations must access the backend only through the
/// `portfolio_public_profile_get` SECURITY DEFINER RPC — never directly
/// reading entity/portfolio tables (EP-02-19, AGENT.md Rule 4).
abstract class PortfolioRemoteDataSource {
  /// Fetches the public professional profile for [entityId].
  ///
  /// Returns the raw DTO parsed from the `{success, code, message, data}`
  /// envelope. Throws a typed [ApiException] on server error codes.
  Future<PublicProfileDto> fetchPublicProfile(String entityId);
}
