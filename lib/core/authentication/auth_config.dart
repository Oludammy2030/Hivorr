import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_config.dart';

/// Tunables for the authentication framework.
///
/// Sourced only from [EnvironmentConfig]; never reads compile-time variables
/// directly (EP-01-03, EP-01-09 §5.1).
class AuthConfig {
  const AuthConfig({
    this.emailConfirmationRequired = true,
    this.sessionExpiryBuffer = const Duration(minutes: 5),
    this.recoveryRedirectBase,
  });

  /// Whether the active environment requires email confirmation before a
  /// session is issued (used to decide post-sign-up UX; the authoritative
  /// signal remains whether a session is returned by the auth backend).
  final bool emailConfirmationRequired;

  /// Buffer applied when considering a session expired. Reserved for future
  /// proactive-refresh tuning.
  final Duration sessionExpiryBuffer;

  /// Origin of the password-reset landing page for the active environment.
  ///
  /// `null` (development) falls back to the current page origin ([Uri.base]),
  /// matching whatever web server the developer is running. Staging and
  /// production resolve to the fixed public Web origins below.
  final String? recoveryRedirectBase;

  /// The absolute password-reset landing URL embedded in recovery emails as
  /// GoTrue's `redirect_to`.
  ///
  /// The recovery link must terminate on `/reset-password` so the web client
  /// can exchange the PKCE `code` and present the set-a-new-password UI
  /// (password-reset flow — not the OTP flow).
  String get recoveryRedirectUrl =>
      '${recoveryRedirectBase ?? Uri.base.origin}/reset-password';

  /// Fixed public origins for the hosted environments.
  static const String _productionRecoveryOrigin = 'https://hivorr.com';
  static const String _stagingRecoveryOrigin = 'https://staging.hivorr.com';

  /// Builds [AuthConfig] from the active [EnvironmentConfig].
  ///
  /// Email confirmation is required in every environment so the OTP
  /// verification gate is exercised in development as well as production: the
  /// register flow always sends a 6-digit verification code before the account
  /// is activated (email-OTP provider). Delivery still depends on the Supabase
  /// project enabling the `email_otp` provider for numeric codes.
  factory AuthConfig.fromEnvironment(EnvironmentConfig config) => AuthConfig(
    emailConfirmationRequired: true,
    recoveryRedirectBase: switch (config.environment) {
      AppEnvironment.production => _productionRecoveryOrigin,
      AppEnvironment.staging => _stagingRecoveryOrigin,
      AppEnvironment.development => null,
    },
  );
}
