import 'package:hivorr/config/environments/environment_config.dart';

/// Tunables for the authentication framework.
///
/// Sourced only from [EnvironmentConfig]; never reads compile-time variables
/// directly (EP-01-03, EP-01-09 §5.1).
class AuthConfig {
  const AuthConfig({
    this.emailConfirmationRequired = true,
    this.sessionExpiryBuffer = const Duration(minutes: 5),
  });

  /// Whether the active environment requires email confirmation before a
  /// session is issued (used to decide post-sign-up UX; the authoritative
  /// signal remains whether a session is returned by the auth backend).
  final bool emailConfirmationRequired;

  /// Buffer applied when considering a session expired. Reserved for future
  /// proactive-refresh tuning.
  final Duration sessionExpiryBuffer;

  /// Builds [AuthConfig] from the active [EnvironmentConfig].
  ///
  /// Email confirmation is required in every environment so the OTP
  /// verification gate is exercised in development as well as production: the
  /// register flow always sends a 6-digit verification code before the account
  /// is activated (email-OTP provider). Delivery still depends on the Supabase
  /// project enabling the `email_otp` provider for numeric codes.
  factory AuthConfig.fromEnvironment(EnvironmentConfig config) =>
      const AuthConfig(emailConfirmationRequired: true);
}
