import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_loader.dart';

/// Compile-time define tests.
///
/// These tests verify that [EnvironmentLoader.load] with the default
/// [CompileTimeEnvironmentValueSource] behaves consistently with the
/// injected test source used in [environment_loader_test.dart].
///
/// Run with:
///   flutter test test/unit/environment_compile_time_test.dart \
///     --dart-define=HIVORR_ENV=development \
///     --dart-define=HIVORR_SUPABASE_URL=https://dev.hivorr.supabase.co \
///     --dart-define=HIVORR_SUPABASE_ANON_KEY=test-anon-key \
///     --dart-define=HIVORR_CONFIG_SCHEMA_VERSION=1
///
/// When run without --dart-define flags (normal `flutter test`), these
/// tests are skipped because the compile-time values are absent.
void main() {
  // Detect whether --dart-define values were supplied at compile time.
  final envDefined =
      const String.fromEnvironment(AppConstants.envEnvironment).isNotEmpty;

  group('Compile-time define loading', skip: envDefined ? false : 'Run with --dart-define flags', () {
    test('loads configuration from compile-time defines', () {
      final config = EnvironmentLoader.load();

      expect(config.environment, AppEnvironment.development);
      expect(config.supabaseConfig.url, 'https://dev.hivorr.supabase.co');
      expect(config.schemaVersion, 1);
    });

    test('environment-derived metadata is correct', () {
      final config = EnvironmentLoader.load();

      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.isStaging, isFalse);
    });
  });
}
