import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_loader.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';

/// Integration test (EP-01-20 §5.13) verifying that the three deployment
/// environments — Development, Staging, and Production — load through the real
/// [EnvironmentLoader] as fully isolated configurations with no
/// cross-contamination and a working switch mechanism.
///
/// All values are non-secret placeholders (distinct fabricated Supabase URLs,
/// project references, and anon keys). No real credentials are used.
void main() {
  // Distinct placeholder per-environment values. None of these contain the
  // blocked placeholder tokens, so the fail-closed loader accepts them.
  const String devUrl = 'https://dev-abc1234.supabase.co';
  const String stagingUrl = 'https://staging-def5678.supabase.co';
  const String prodUrl = 'https://prod-ghi9012.supabase.co';

  const String devKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJyb2xlIjoiYW5vbiIsImVudiI6ImRldiJ9'
      '.devsig00000000000000000000000000000000';
  const String stagingKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJyb2xlIjoiYW5vbiIsImVudiI6InN0YWdpbmcifQ'
      '.stgsig00000000000000000000000000000000';
  const String prodKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJyb2xlIjoiYW5vbiIsImVudiI6InByb2QifQ'
      '.prodsig00000000000000000000000000000';

  /// Derives the Supabase project reference from a project URL host.
  ///
  /// Supabase URLs follow `https://<projectRef>.supabase.co`, so the project
  /// reference is the leading host label.
  String projectRef(String url) {
    final Uri uri = Uri.parse(url);
    return uri.host.split('.').first;
  }

  /// Builds a real [EnvironmentConfig] for [envName] from placeholder values.
  EnvironmentConfig loadEnv(
    String envName,
    String url,
    String key,
  ) {
    return EnvironmentLoader.load(
      source: MapEnvironmentValueSource(<String, String>{
        AppConstants.envEnvironment: envName,
        AppConstants.envSupabaseUrl: url,
        AppConstants.envSupabaseAnonKey: key,
        AppConstants.envConfigSchemaVersion: '1',
      }),
    );
  }

  group('§5.13 Environment Isolation — config loading', () {
    test('dev, staging, and prod load with distinct URL/anonKey/projectRef', () {
      final EnvironmentConfig dev = loadEnv('development', devUrl, devKey);
      final EnvironmentConfig staging =
          loadEnv('staging', stagingUrl, stagingKey);
      final EnvironmentConfig prod = loadEnv('production', prodUrl, prodKey);

      // Environment identity is correctly resolved.
      expect(dev.environment, AppEnvironment.development);
      expect(staging.environment, AppEnvironment.staging);
      expect(prod.environment, AppEnvironment.production);

      // Each environment exposes a unique Supabase URL.
      expect(dev.supabaseConfig.url, devUrl);
      expect(staging.supabaseConfig.url, stagingUrl);
      expect(prod.supabaseConfig.url, prodUrl);
      expect(dev.supabaseConfig.url, isNot(staging.supabaseConfig.url));
      expect(dev.supabaseConfig.url, isNot(prod.supabaseConfig.url));
      expect(staging.supabaseConfig.url, isNot(prod.supabaseConfig.url));

      // Each environment exposes a unique anon key.
      expect(dev.supabaseConfig.anonKey, devKey);
      expect(staging.supabaseConfig.anonKey, stagingKey);
      expect(prod.supabaseConfig.anonKey, prodKey);
      expect(dev.supabaseConfig.anonKey, isNot(staging.supabaseConfig.anonKey));
      expect(dev.supabaseConfig.anonKey, isNot(prod.supabaseConfig.anonKey));
      expect(staging.supabaseConfig.anonKey, isNot(prod.supabaseConfig.anonKey));

      // Each environment exposes a unique project reference.
      final String devRef = projectRef(dev.supabaseConfig.url);
      final String stagingRef = projectRef(staging.supabaseConfig.url);
      final String prodRef = projectRef(prod.supabaseConfig.url);
      expect(devRef, 'dev-abc1234');
      expect(stagingRef, 'staging-def5678');
      expect(prodRef, 'prod-ghi9012');
      expect(devRef, isNot(stagingRef));
      expect(devRef, isNot(prodRef));
      expect(stagingRef, isNot(prodRef));
    });
  });

  group('§5.13 Environment Isolation — no cross-contamination', () {
    test('Dev config contains no staging/prod values', () {
      final EnvironmentConfig dev = loadEnv('development', devUrl, devKey);

      expect(dev.environment, AppEnvironment.development);
      expect(dev.supabaseConfig.url, devUrl);
      expect(dev.supabaseConfig.url, isNot(contains('staging')));
      expect(dev.supabaseConfig.url, isNot(contains('prod')));
      expect(dev.supabaseConfig.url, isNot(stagingUrl));
      expect(dev.supabaseConfig.url, isNot(prodUrl));
      expect(dev.supabaseConfig.anonKey, devKey);
      expect(dev.supabaseConfig.anonKey, isNot(contains('staging')));
      expect(dev.supabaseConfig.anonKey, isNot(contains('prod')));
      expect(dev.supabaseConfig.anonKey, isNot(stagingKey));
      expect(dev.supabaseConfig.anonKey, isNot(prodKey));
    });

    test('Staging config contains no dev/prod values', () {
      final EnvironmentConfig staging =
          loadEnv('staging', stagingUrl, stagingKey);

      expect(staging.environment, AppEnvironment.staging);
      expect(staging.supabaseConfig.url, stagingUrl);
      expect(staging.supabaseConfig.url, isNot(contains('dev')));
      expect(staging.supabaseConfig.url, isNot(contains('prod')));
      expect(staging.supabaseConfig.url, isNot(devUrl));
      expect(staging.supabaseConfig.url, isNot(prodUrl));
      expect(staging.supabaseConfig.anonKey, stagingKey);
      expect(staging.supabaseConfig.anonKey, isNot(contains('dev')));
      expect(staging.supabaseConfig.anonKey, isNot(contains('prod')));
      expect(staging.supabaseConfig.anonKey, isNot(devKey));
      expect(staging.supabaseConfig.anonKey, isNot(prodKey));
    });

    test('Prod config contains no dev/staging values', () {
      final EnvironmentConfig prod = loadEnv('production', prodUrl, prodKey);

      expect(prod.environment, AppEnvironment.production);
      expect(prod.supabaseConfig.url, prodUrl);
      expect(prod.supabaseConfig.url, isNot(contains('dev')));
      expect(prod.supabaseConfig.url, isNot(contains('staging')));
      expect(prod.supabaseConfig.url, isNot(devUrl));
      expect(prod.supabaseConfig.url, isNot(stagingUrl));
      expect(prod.supabaseConfig.anonKey, prodKey);
      expect(prod.supabaseConfig.anonKey, isNot(contains('dev')));
      expect(prod.supabaseConfig.anonKey, isNot(contains('staging')));
      expect(prod.supabaseConfig.anonKey, isNot(devKey));
      expect(prod.supabaseConfig.anonKey, isNot(stagingKey));
    });
  });

  group('§5.13 Environment Isolation — switching mechanism', () {
    test('switching dev -> staging updates all values and drops dev state', () {
      // Load the initial (dev) configuration and capture its isolated values.
      final EnvironmentConfig dev = loadEnv('development', devUrl, devKey);
      final String capturedDevUrl = dev.supabaseConfig.url;
      final String capturedDevKey = dev.supabaseConfig.anonKey;
      final AppEnvironment capturedDevEnv = dev.environment;

      expect(capturedDevEnv, AppEnvironment.development);
      expect(capturedDevUrl, devUrl);
      expect(capturedDevKey, devKey);

      // Switch by reloading with the staging source (a fresh, immutable
      // EnvironmentConfig is produced — no shared mutable state).
      final EnvironmentConfig staging =
          loadEnv('staging', stagingUrl, stagingKey);

      // Every value must reflect the new environment.
      expect(staging.environment, AppEnvironment.staging);
      expect(staging.environment, isNot(capturedDevEnv));
      expect(staging.supabaseConfig.url, stagingUrl);
      expect(staging.supabaseConfig.url, isNot(capturedDevUrl));
      expect(staging.supabaseConfig.anonKey, stagingKey);
      expect(staging.supabaseConfig.anonKey, isNot(capturedDevKey));

      // No cached dev values persist: reloading again yields staging again,
      // and the previously captured dev values are nowhere present.
      final EnvironmentConfig reloadedStaging =
          loadEnv('staging', stagingUrl, stagingKey);
      expect(reloadedStaging.supabaseConfig.url, stagingUrl);
      expect(reloadedStaging.supabaseConfig.anonKey, stagingKey);
      expect(reloadedStaging.supabaseConfig.url, isNot(capturedDevUrl));
      expect(reloadedStaging.supabaseConfig.anonKey, isNot(capturedDevKey));
    });

    test('switching staging -> prod updates all values and drops staging state',
        () {
      final EnvironmentConfig staging =
          loadEnv('staging', stagingUrl, stagingKey);
      final String capturedStagingUrl = staging.supabaseConfig.url;
      final String capturedStagingKey = staging.supabaseConfig.anonKey;

      final EnvironmentConfig prod = loadEnv('production', prodUrl, prodKey);

      expect(prod.environment, AppEnvironment.production);
      expect(prod.supabaseConfig.url, prodUrl);
      expect(prod.supabaseConfig.url, isNot(capturedStagingUrl));
      expect(prod.supabaseConfig.anonKey, prodKey);
      expect(prod.supabaseConfig.anonKey, isNot(capturedStagingKey));
    });
  });
}
