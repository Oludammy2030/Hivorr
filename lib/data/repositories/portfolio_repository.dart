import 'package:hivorr/data/entities/public_profile.dart';

/// Abstract contract for portfolio data operations (EP-02-19).
///
/// Depends only on domain entities — never on concrete backend types — so
/// business systems and UI consume this interface, not a Supabase
/// implementation (ARCHITECTURE.md / EP-01-08 §5.6).
abstract class PortfolioRepository {
  /// Returns the public professional profile for [entityId].
  ///
  /// The server enforces the approved-gate (entity active + ≥1 approved trade
  /// profession) and returns `PLT004` for unknown/inactive/unapproved entities.
  Future<PublicProfile?> getPublicProfile(String entityId);
}
