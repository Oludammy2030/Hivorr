import 'dart:convert';

import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/environments/security_config.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';
import 'package:hivorr/core/cache/cache_config.dart';
import 'package:hivorr/core/database/database_config.dart';
import 'package:hivorr/core/network/network_config.dart';
import 'package:hivorr/core/sync/sync_config.dart';

/// Loads and validates environment configuration from a value source.
///
/// This is the single loader that reads configuration values, applies
/// strict validation, and constructs the immutable [EnvironmentConfig].
///
/// Validation is fail-closed: missing, invalid, or ambiguous values cause
/// [EnvironmentConfigException]. There is no fallback to Production or to
/// any other environment (EP-01-03 §5.5).
///
/// `String.fromEnvironment` is confined to
/// [CompileTimeEnvironmentValueSource] in `environment_value_source.dart`.
/// This loader consumes the [EnvironmentValueSource] abstraction, keeping
/// compile-time access bounded and testable.
class EnvironmentLoader {
  const EnvironmentLoader._();

  /// Loads and validates configuration from [source].
  ///
  /// Defaults to [CompileTimeEnvironmentValueSource] for production use.
  /// Unit tests inject [MapEnvironmentValueSource] to supply values without
  /// compile-time flags.
  static EnvironmentConfig load({
    EnvironmentValueSource source = const CompileTimeEnvironmentValueSource(),
  }) {
    // 1. Environment identity (validated first — no Production fallback).
    final envName = _require(source, AppConstants.envEnvironment);
    final environment = AppEnvironment.fromName(envName);

    // 2. Supabase URL — must be valid HTTPS, not a placeholder.
    //    Development additionally accepts plain-HTTP loopback URLs so the
    //    app can target a local `supabase start` stack (EP-01-05).
    final url = _require(source, AppConstants.envSupabaseUrl);
    _validateUrl(url, environment);

    // 3. Supabase anon key — must be public, not service-role, not placeholder.
    final anonKey = _require(source, AppConstants.envSupabaseAnonKey);
    _validateAnonKey(anonKey);

    // 4. Configuration schema version — must be supported.
    final schemaVersionStr = _require(
      source,
      AppConstants.envConfigSchemaVersion,
    );
    final schemaVersion = _validateSchemaVersion(schemaVersionStr);

    // 5. Feature flags — strict boolean parsing, safe defaults.
    final featureFlags = FeatureFlags.fromSource(source);

    // 6. Security configuration — pinning + KDF parameters (opt-in defaults).
    final securityConfig = SecurityConfig.fromSource(source);

    // 7. Local storage + cache configuration (EP-01-11; opt-in defaults).
    final databaseConfig = DatabaseConfig.fromSource(source);
    final cacheConfig = CacheConfig.fromSource(source);

    // 8. Offline sync configuration (EP-01-12; opt-in defaults).
    final syncConfig = SyncConfig.fromSource(source);

    // 9. Network management configuration (EP-01-13; opt-in defaults).
    final networkConfig = NetworkConfig.fromSource(source);

    return EnvironmentConfig(
      environment: environment,
      supabaseConfig: SupabaseConfig(url: url, anonKey: anonKey),
      featureFlags: featureFlags,
      securityConfig: securityConfig,
      databaseConfig: databaseConfig,
      cacheConfig: cacheConfig,
      syncConfig: syncConfig,
      networkConfig: networkConfig,
      constants: const AppConstants(),
      schemaVersion: schemaVersion,
    );
  }

  // ─── Required value extraction ──────────────────────────────────────

  /// Returns a trimmed, non-empty value for [key] or throws.
  ///
  /// Null, empty, and whitespace-only values are treated as missing.
  static String _require(EnvironmentValueSource source, String key) {
    final value = source.read(key);
    if (value == null || value.trim().isEmpty) {
      throw EnvironmentConfigException(
        variableName: key,
        reason: 'Required configuration variable is missing or empty.',
      );
    }
    return value.trim();
  }

  // ─── URL validation ─────────────────────────────────────────────────

  /// Loopback hosts permitted to use plain HTTP in Development only.
  static const Set<String> _loopbackHosts = {
    '127.0.0.1',
    'localhost',
    '::1',
  };

  /// Validates that [url] is a valid HTTPS URL with a host and is not a
  /// known placeholder.
  ///
  /// Development builds may target a local Supabase stack (`supabase start`)
  /// over plain HTTP, but only on loopback hosts. Staging and Production
  /// remain HTTPS-only.
  static void _validateUrl(String url, AppEnvironment environment) {
    if (_isPlaceholder(url)) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envSupabaseUrl,
        reason: 'Placeholder value is not allowed.',
      );
    }

    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envSupabaseUrl,
        reason: 'Invalid URL format.',
      );
    }

    if (!uri.hasScheme || uri.scheme != 'https') {
      final isLoopbackHttp =
          uri.scheme == 'http' && _loopbackHosts.contains(uri.host);
      if (!(environment.isDevelopment && isLoopbackHttp)) {
        throw EnvironmentConfigException(
          variableName: AppConstants.envSupabaseUrl,
          reason: 'Supabase URL must use HTTPS.',
        );
      }
    }

    if (uri.host.isEmpty) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envSupabaseUrl,
        reason: 'Supabase URL must include a valid host.',
      );
    }
  }

  // ─── Anon key validation ────────────────────────────────────────────

  /// Validates that [key] is not a placeholder and not a service-role key.
  static void _validateAnonKey(String key) {
    if (_isPlaceholder(key)) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envSupabaseAnonKey,
        reason: 'Placeholder value is not allowed.',
      );
    }

    if (_isServiceRoleKey(key)) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envSupabaseAnonKey,
        reason:
            'Service-role keys are not accepted by the client '
            'configuration. Only the public anon key is allowed.',
      );
    }
  }

  // ─── Schema version validation ──────────────────────────────────────

  /// Validates that [value] is an integer matching the supported version.
  static int _validateSchemaVersion(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envConfigSchemaVersion,
        reason: 'Configuration schema version must be an integer.',
      );
    }
    if (parsed != AppConstants.supportedConfigSchemaVersion) {
      throw EnvironmentConfigException(
        variableName: AppConstants.envConfigSchemaVersion,
        reason:
            'Unsupported configuration schema version. '
            'Supported version: ${AppConstants.supportedConfigSchemaVersion}.',
      );
    }
    return parsed;
  }

  // ─── Placeholder detection ──────────────────────────────────────────

  /// Known placeholder tokens that must never pass validation.
  static const Set<String> _placeholderTokens = {
    'your-project',
    'your_supabase',
    'your-supabase',
    'your-anon',
    'your_anon',
    'your-public',
    'your_public',
    'your-key',
    'your_key',
    'placeholder',
    'changeme',
    'change-me',
    'example.com',
    'todo',
    'tbd',
    'xxx',
  };

  /// Returns `true` if [value] contains a known placeholder token.
  static bool _isPlaceholder(String value) {
    final lower = value.toLowerCase();
    for (final token in _placeholderTokens) {
      if (lower.contains(token)) {
        return true;
      }
    }
    return false;
  }

  // ─── Service-role key detection ─────────────────────────────────────

  /// Returns `true` if [key] is identified as a Supabase service-role key.
  ///
  /// Detection strategy:
  /// 1. Substring check for `service_role` or `service-role`.
  /// 2. JWT payload decode — Supabase keys are JWTs. If the payload
  ///    contains `"role": "service_role"`, the key is rejected.
  ///
  /// If the key is not a valid JWT, the check passes (the key may be a
  /// non-JWT format in future Supabase versions).
  static bool _isServiceRoleKey(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('service_role') || lower.contains('service-role')) {
      return true;
    }

    final segments = key.split('.');
    if (segments.length != 3) {
      return false;
    }

    try {
      final payload = _decodeJwtPayload(segments[1]);
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final role = decoded['role'];
        if (role == 'service_role') {
          return true;
        }
      }
    } catch (_) {
      // Not a decodable JWT payload — cannot confirm service-role.
    }
    return false;
  }

  /// Decodes a base64url-encoded JWT payload segment to a UTF-8 string.
  static String _decodeJwtPayload(String segment) {
    final normalized = segment.replaceAll('-', '+').replaceAll('_', '/');
    final padding = (4 - normalized.length % 4) % 4;
    final padded = normalized + '=' * padding;
    return utf8.decode(base64.decode(padded));
  }
}
