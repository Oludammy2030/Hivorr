import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Immutable security configuration for the Hivorr client.
///
/// Carries only non-secret, deployment-sourced security metadata: the SSL
/// pinning toggle + SPKI SHA-256 pins, and the PBKDF2 parameters used to
/// derive at-rest encryption keys. All values are sourced exclusively from
/// [EnvironmentConfig] (EP-01-03); nothing here is a hardcoded secret.
///
/// Pinning is **opt-in**: when absent from the environment it defaults to
/// disabled, so Development/CI builds remain functional. Production builds
/// supply real pins via the compile-time defines.
class SecurityConfig {
  const SecurityConfig({
    required this.pinningEnabled,
    required this.pinnedSpkiSha256Hashes,
    required this.kdfSalt,
    required this.kdfIterations,
    required this.kdfKeyLength,
  });

  /// Whether SSL certificate pinning is active for this environment.
  final bool pinningEnabled;

  /// SPKI SHA-256 (base64) hashes of the certificates to pin.
  final List<String> pinnedSpkiSha256Hashes;

  /// Non-secret PBKDF2 salt used to derive encryption keys.
  final String kdfSalt;

  /// PBKDF2 iteration count used to derive encryption keys.
  final int kdfIterations;

  /// Derived encryption key length in bytes (must be 16/24/32 for AES).
  final int kdfKeyLength;

  /// Builds [SecurityConfig] from a [EnvironmentValueSource].
  ///
  /// Missing values fall back to safe defaults (pinning disabled, empty pins,
  /// standard KDF parameters) so the loader stays fail-closed on the core
  /// Supabase/schema contract while security hardening remains opt-in per
  /// environment (EP-01-10 §5.1, §6).
  static SecurityConfig fromSource(EnvironmentValueSource source) {
    final bool pinningEnabled = _parseBool(
      source,
      AppConstants.securityPinningEnabled,
    );
    final List<String> hashes = _parseHashes(source);
    final String salt =
        source.read(AppConstants.securityKdfSalt) ?? AppConstants.defaultKdfSalt;
    final int iterations = _parseInt(
      source,
      AppConstants.securityKdfIterations,
      AppConstants.defaultKdfIterations,
    );
    final int keyLength = _parseInt(
      source,
      AppConstants.securityKdfKeyLength,
      AppConstants.defaultKdfKeyLength,
    );

    return SecurityConfig(
      pinningEnabled: pinningEnabled,
      pinnedSpkiSha256Hashes: hashes,
      kdfSalt: salt,
      kdfIterations: iterations,
      kdfKeyLength: keyLength,
    );
  }

  /// Reads comma-separated pins; absent/empty yields an empty list.
  static List<String> _parseHashes(EnvironmentValueSource source) {
    final String? raw = source.read(AppConstants.securityPinnedSpkiHashes);
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }
    return raw
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  /// Strict boolean parse; absent → `false`, malformed → throws.
  static bool _parseBool(EnvironmentValueSource source, String key) {
    final String? raw = source.read(key);
    if (raw == null) {
      return false;
    }
    return switch (raw) {
      'true' => true,
      'false' => false,
      _ => throw EnvironmentConfigException(
        variableName: key,
        reason: 'Malformed security flag. Accepted values: true, false.',
      ),
    };
  }

  /// Integer parse with a safe fallback; malformed → throws.
  static int _parseInt(EnvironmentValueSource source, String key, int fallback) {
    final String? raw = source.read(key);
    if (raw == null) {
      return fallback;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Security value must be an integer.',
      );
    }
    return parsed;
  }

  @override
  String toString() {
    return 'SecurityConfig('
        'pinningEnabled: $pinningEnabled, '
        'pinnedSpkiSha256Hashes: ${pinnedSpkiSha256Hashes.length} pin(s), '
        'kdfIterations: $kdfIterations, '
        'kdfKeyLength: $kdfKeyLength)';
  }
}
