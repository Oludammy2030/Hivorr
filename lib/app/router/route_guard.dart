import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/guards/auth_guard.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';

/// Adapts the EP-01-09 [AuthGuard] to the GoRouter redirect flow.
///
/// This is the single point where EP-01-09 authorization decisions are applied
/// to navigation. No business logic lives here (AGENT.md Rule 4) — it wraps
/// [AuthGuard] and adds the EP-01-15 rule that authenticated users are bounced
/// off public-only auth screens (e.g. `/login`).
class RouteGuard {
  RouteGuard({required this.authProvider})
      : guard = AuthGuard(
          isAuthenticated: () => authProvider.isSignedIn,
        );

  final AuthProvider authProvider;
  final AuthGuard guard;

  /// Resolves a redirect target for the given [location].
  ///
  /// Returns `null` to allow the navigation, or a path string to redirect to.
  /// Delegates public-route classification to [AuthGuard.publicRoutePrefixes]
  /// and the unauthenticated→`/login` decision to [AuthGuard.redirectResolver].
  String? redirectResolver(String location) {
    final bool authenticated = authProvider.isSignedIn;

    // Authenticated users should not land on public-only auth screens.
    if (authenticated) {
      if (guard.isPublicRoute(location)) {
        return RoutePaths.home;
      }
      return null;
    }

    // Public auth screens and public content routes are always allowed.
    if (guard.isPublicRoute(location) || _isPublicContentView(location)) {
      return null;
    }

    // Fail-closed: any other (protected) route redirects to login.
    return guard.redirectResolver(location);
  }

  static bool _isPublicContentView(String location) =>
      location.startsWith('/p/') || location.startsWith('/store/');
}
