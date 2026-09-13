import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/authentication.dart';

/// Development-only demo identity for the UAT onboarding preview.
///
/// The credentials correspond to the seeded `auth.users` row
/// (`supabase/migrations/20260911090002_demo_identity_seed.sql`).
/// Production and staging never reference this file or its credentials.
///
/// The `signInIfUnauthenticated` seam is intentionally kept outside the core
/// [AuthService] so production/staging code paths never depend on it.
class DemoIdentity {
  const DemoIdentity._();

  /// Local-only demo account credentials.
  static const String email = 'demo@hivorr.local';
  static const String password = 'H1v0rr_D3m0!';

  /// Signs in with the demo identity and ensures the entity row exists,
  /// but only in Development, only when no session is active, and only when
  /// the web page was opened at an onboarding deep link (the EP-02-18 UAT
  /// preview — `route_guard.dart` development bypass). On a plain launch at
  /// `/` or any entry door, no session is created so the pre-onboarding
  /// experience (`/welcome`, `/intro`) stays first.
  ///
  /// Safe to call repeatedly (idempotent). Completes silently on failure so
  /// a non-critical dev preview seam never blocks app startup.
  static Future<void> signInIfUnauthenticated({
    required AuthLayer authLayer,
    required AppEnvironment environment,
    Uri? requestedBootUri,
  }) async {
    if (!environment.isDevelopment) {
      return;
    }
    if (authLayer.provider.isSignedIn) {
      return;
    }
    if (!_wasOnboardingRequested(requestedBootUri ?? Uri.base)) {
      return;
    }
    try {
      await authLayer.provider.signIn(
        const AuthCredentials(email: email, password: password),
      );
      if (!authLayer.provider.isSignedIn) {
        return;
      }
      await authLayer.service.ensureEntityExists();
    } catch (_) {
      // Dev-only preview seam — failure must not block app startup.
    }
  }

  /// Whether the boot URL asked for an onboarding wizard route. Both the
  /// path strategy (`/onboarding/...`) and the legacy hash strategy
  /// (`#/onboarding/...`) are honoured so the dev preview keeps working
  /// either way.
  static bool _wasOnboardingRequested(Uri boot) =>
      _isOnboardingRoute(boot.path) || _isOnboardingRoute(boot.fragment);

  static bool _isOnboardingRoute(String location) =>
      location == RoutePaths.onboarding ||
      location.startsWith('${RoutePaths.onboarding}/');
}
