import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';

/// Supported environment identities for the Hivorr platform.
///
/// Environment selection is build-time only. Runtime users cannot switch
/// environments. There is no fallback to Production (EP-01-03 §5.5).
///
/// Production-state metadata is derived from this enum, not from `kDebugMode`.
enum AppEnvironment {
  development,
  staging,
  production;

  /// Parses an exact, case-sensitive environment name.
  ///
  /// Throws [EnvironmentConfigException] for unknown, misspelled, or
  /// case-incorrect identifiers. Only `development`, `staging`, and
  /// `production` are accepted.
  static AppEnvironment fromName(String name) {
    return switch (name) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw EnvironmentConfigException(
          variableName: AppConstants.envEnvironment,
          reason:
              'Unknown environment identifier. '
              'Supported values: development, staging, production.',
        ),
    };
  }

  /// Whether this environment is Production.
  bool get isProduction => this == AppEnvironment.production;

  /// Whether this environment is Staging.
  bool get isStaging => this == AppEnvironment.staging;

  /// Whether this environment is Development.
  bool get isDevelopment => this == AppEnvironment.development;
}
