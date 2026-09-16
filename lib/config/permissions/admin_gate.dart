import 'package:hivorr/data/providers/admin_review_provider.dart';

/// Pure gate for platform admin access (EP-02-11 §5.4).
///
/// Mirrors the D5 gate pattern: a static helper that reads the admin flag
/// from the injected [AdminReviewProvider]. The provider caches the admin
/// flag for the current session; this gate never makes network calls.
///
/// Usage in route guard:
/// ```dart
/// if (!AdminGate.isAdmin(adminProvider)) {
///   return RoutePaths.home;
/// }
/// ```
abstract final class AdminGate {
  const AdminGate._();

  /// Whether the current user is a platform admin.
  ///
  /// Returns `false` when the provider is absent or the flag is not yet
  /// hydrated (`null` before the first `checkAdmin()` call). Fail-closed.
  static bool isAdmin(AdminReviewProvider? provider) {
    return provider?.isAdmin == true;
  }
}
