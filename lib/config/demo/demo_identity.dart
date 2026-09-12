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
  /// but only in Development and only when no session is active.
  ///
  /// Safe to call repeatedly (idempotent). Completes silently on failure so
  /// a non-critical dev preview seam never blocks app startup.
  static Future<void> signInIfUnauthenticated({
    required AuthLayer authLayer,
    required AppEnvironment environment,
  }) async {
    if (!environment.isDevelopment) {
      return;
    }
    if (authLayer.provider.isSignedIn) {
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
}
