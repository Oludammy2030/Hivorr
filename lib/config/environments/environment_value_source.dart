import 'package:hivorr/config/constants/app_constants.dart';

/// Abstraction that decouples configuration reading from compile-time
/// defines, enabling unit tests to inject values without `--dart-define`.
///
/// [CompileTimeEnvironmentValueSource] is the production source that reads
/// Flutter compile-time defines. [MapEnvironmentValueSource] is the test
/// source backed by a simple map.
///
/// `String.fromEnvironment` is confined to [CompileTimeEnvironmentValueSource]
/// within this file. No other module in the codebase reads compile-time
/// environment variables directly (EP-01-03 §5.5).
abstract class EnvironmentValueSource {
  const EnvironmentValueSource();

  /// Returns the raw string value for [key], or `null` if absent.
  String? read(String key);
}

/// Reads configuration values from Flutter compile-time defines.
///
/// This is the single location in the codebase where
/// `String.fromEnvironment` is used. Each known variable is mapped to its
/// compile-time value via a constant expression. Unknown keys return `null`.
class CompileTimeEnvironmentValueSource extends EnvironmentValueSource {
  const CompileTimeEnvironmentValueSource();

  @override
  String? read(String key) {
    final value = switch (key) {
      AppConstants.envEnvironment => const String.fromEnvironment(
        AppConstants.envEnvironment,
      ),
      AppConstants.envSupabaseUrl => const String.fromEnvironment(
        AppConstants.envSupabaseUrl,
      ),
      AppConstants.envSupabaseAnonKey => const String.fromEnvironment(
        AppConstants.envSupabaseAnonKey,
      ),
      AppConstants.envConfigSchemaVersion => const String.fromEnvironment(
        AppConstants.envConfigSchemaVersion,
      ),
      AppConstants.featureEnableVerboseLogging => const String.fromEnvironment(
        AppConstants.featureEnableVerboseLogging,
      ),
      AppConstants.featureEnableOfflineSync => const String.fromEnvironment(
        AppConstants.featureEnableOfflineSync,
      ),
      AppConstants.featureEnableAnalyticsTracking =>
        const String.fromEnvironment(
          AppConstants.featureEnableAnalyticsTracking,
        ),
      AppConstants.featureEnableDynamicWorkspaceLoading =>
        const String.fromEnvironment(
          AppConstants.featureEnableDynamicWorkspaceLoading,
        ),
      AppConstants.securityPinningEnabled =>
        const String.fromEnvironment(AppConstants.securityPinningEnabled),
      AppConstants.securityPinnedSpkiHashes =>
        const String.fromEnvironment(AppConstants.securityPinnedSpkiHashes),
      AppConstants.securityKdfSalt =>
        const String.fromEnvironment(AppConstants.securityKdfSalt),
      AppConstants.securityKdfIterations =>
        const String.fromEnvironment(AppConstants.securityKdfIterations),
      AppConstants.securityKdfKeyLength =>
        const String.fromEnvironment(AppConstants.securityKdfKeyLength),
      _ => '',
    };
    return value.isEmpty ? null : value;
  }
}

/// Map-backed value source for unit tests.
///
/// Allows tests to supply configuration values without compile-time flags.
class MapEnvironmentValueSource extends EnvironmentValueSource {
  const MapEnvironmentValueSource(this._values);

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];
}
