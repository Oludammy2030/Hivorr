import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/security_config.dart';

/// Module-level resolver that adapts the environment-sourced [SecurityConfig]
/// into the typed inputs the security components consume.
///
/// Lives in [lib/core/security] but reads only from the EP-01-03
/// [EnvironmentConfig] contract (EP-01-10 §5.1, §5.2). All pinning hashes
/// and KDF parameters therefore remain environment-driven and never hardcoded.
class SecurityConfiguration {
  const SecurityConfiguration(this.securityConfig);

  /// The underlying immutable environment security configuration.
  final SecurityConfig securityConfig;

  /// Resolves the module configuration from the validated [EnvironmentConfig].
  factory SecurityConfiguration.fromEnvironment(EnvironmentConfig config) {
    return SecurityConfiguration(config.securityConfig);
  }

  /// Whether SSL certificate pinning is active.
  bool get pinningEnabled => securityConfig.pinningEnabled;

  /// SPKI SHA-256 (base64) certificate pins to enforce.
  List<String> get pinnedSpkiSha256Hashes =>
      securityConfig.pinnedSpkiSha256Hashes;

  /// Non-secret PBKDF2 salt used to derive encryption keys.
  String get kdfSalt => securityConfig.kdfSalt;

  /// PBKDF2 iteration count used to derive encryption keys.
  int get kdfIterations => securityConfig.kdfIterations;

  /// Derived encryption key length in bytes (16/24/32 for AES).
  int get kdfKeyLength => securityConfig.kdfKeyLength;

  @override
  String toString() => securityConfig.toString();
}
