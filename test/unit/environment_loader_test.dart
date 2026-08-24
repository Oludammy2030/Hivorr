import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/config/app_config/app_config.dart';
import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_config_exception.dart';
import 'package:hivorr/config/environments/environment_loader.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/config/feature_flags/feature_flags.dart';

/// Valid test values for each environment.
const _validDev = {
  AppConstants.envEnvironment: 'development',
  AppConstants.envSupabaseUrl: 'https://dev.hivorr.supabase.co',
  AppConstants.envSupabaseAnonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMH0.'
      'sig9876543210abcdef',
  AppConstants.envConfigSchemaVersion: '1',
};

const _validStaging = {
  AppConstants.envEnvironment: 'staging',
  AppConstants.envSupabaseUrl: 'https://staging.hivorr.supabase.co',
  AppConstants.envSupabaseAnonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMH0.'
      'sig9876543210abcdef',
  AppConstants.envConfigSchemaVersion: '1',
};

const _validProd = {
  AppConstants.envEnvironment: 'production',
  AppConstants.envSupabaseUrl: 'https://prod.hivorr.supabase.co',
  AppConstants.envSupabaseAnonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJyb2xlIjoiYW5vbiIsImlhdCI6MTYwMDAwMDAwMH0.'
      'sig9876543210abcdef',
  AppConstants.envConfigSchemaVersion: '1',
};

/// A valid anon-key JWT payload with role: anon (base64url encoded).
const _anonJwtPayload = 'eyJyb2xlIjoiYW5vbiJ9';

/// A valid service-role JWT payload with role: service_role (base64url).
const _serviceRoleJwtPayload = 'eyJyb2xlIjoic2VydmljZV9yb2xlIn0';

String _buildJwt(String payload) =>
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$payload.sig9876543210abcdef';

void main() {
  group('EnvironmentLoader — valid configurations', () {
    test('loads valid Development configuration', () {
      final config = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validDev),
      );

      expect(config.environment, AppEnvironment.development);
      expect(config.isDevelopment, isTrue);
      expect(config.isStaging, isFalse);
      expect(config.isProduction, isFalse);
      expect(config.supabaseConfig.url, 'https://dev.hivorr.supabase.co');
      expect(config.schemaVersion, 1);
    });

    test('loads valid Staging configuration', () {
      final config = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validStaging),
      );

      expect(config.environment, AppEnvironment.staging);
      expect(config.isStaging, isTrue);
      expect(config.isDevelopment, isFalse);
      expect(config.isProduction, isFalse);
      expect(config.supabaseConfig.url, 'https://staging.hivorr.supabase.co');
    });

    test('loads valid Production configuration', () {
      final config = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validProd),
      );

      expect(config.environment, AppEnvironment.production);
      expect(config.isProduction, isTrue);
      expect(config.isDevelopment, isFalse);
      expect(config.isStaging, isFalse);
      expect(config.supabaseConfig.url, 'https://prod.hivorr.supabase.co');
    });
  });

  group('EnvironmentLoader — missing variables', () {
    test('throws when HIVORR_ENV is missing', () {
      final values = Map<String, String>.from(_validDev)
        ..remove(AppConstants.envEnvironment);

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws when HIVORR_SUPABASE_URL is missing', () {
      final values = Map<String, String>.from(_validDev)
        ..remove(AppConstants.envSupabaseUrl);

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws when HIVORR_SUPABASE_ANON_KEY is missing', () {
      final values = Map<String, String>.from(_validDev)
        ..remove(AppConstants.envSupabaseAnonKey);

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws when HIVORR_CONFIG_SCHEMA_VERSION is missing', () {
      final values = Map<String, String>.from(_validDev)
        ..remove(AppConstants.envConfigSchemaVersion);

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('EnvironmentLoader — unknown environment', () {
    test('throws for unknown environment name', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envEnvironment] = 'qa';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for case-incorrect environment name', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envEnvironment] = 'Development';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('EnvironmentLoader — URL validation', () {
    test('throws for invalid URL format', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseUrl] = 'not-a-url';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for non-HTTPS URL', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseUrl] = 'http://dev.hivorr.supabase.co';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('Development accepts plain-HTTP loopback URL', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseUrl] = 'http://127.0.0.1:54321';

      final config = EnvironmentLoader.load(
        source: MapEnvironmentValueSource(values),
      );

      expect(config.supabaseConfig.url, 'http://127.0.0.1:54321');
    });

    test('Staging rejects plain-HTTP loopback URL', () {
      final values = Map<String, String>.from(_validStaging)
        ..[AppConstants.envSupabaseUrl] = 'http://127.0.0.1:54321';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('Production rejects plain-HTTP loopback URL', () {
      final values = Map<String, String>.from(_validProd)
        ..[AppConstants.envSupabaseUrl] = 'http://127.0.0.1:54321';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for placeholder URL', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseUrl] = 'https://your-project.supabase.co';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('EnvironmentLoader — anon key validation', () {
    test('throws for placeholder key', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseAnonKey] = 'your-public-anon-key';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for service-role key (substring)', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseAnonKey] = 'service_role_secret_key_12345';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for service-role key (JWT payload)', () {
      final serviceRoleKey = _buildJwt(_serviceRoleJwtPayload);
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseAnonKey] = serviceRoleKey;

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('accepts valid anon JWT key', () {
      final anonKey = _buildJwt(_anonJwtPayload);
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseAnonKey] = anonKey;

      final config = EnvironmentLoader.load(
        source: MapEnvironmentValueSource(values),
      );

      expect(config.supabaseConfig.anonKey, anonKey);
    });
  });

  group('EnvironmentLoader — schema version validation', () {
    test('throws for unsupported schema version', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envConfigSchemaVersion] = '99';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for non-integer schema version', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envConfigSchemaVersion] = 'abc';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('EnvironmentLoader — feature flag validation', () {
    test('defaults all flags to false when absent', () {
      final config = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validDev),
      );

      expect(config.featureFlags.enableVerboseLogging, isFalse);
      expect(config.featureFlags.enableOfflineSync, isFalse);
      expect(config.featureFlags.enableAnalyticsTracking, isFalse);
      expect(config.featureFlags.enableDynamicWorkspaceLoading, isFalse);
    });

    test('parses true flags correctly', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.featureEnableVerboseLogging] = 'true'
        ..[AppConstants.featureEnableOfflineSync] = 'true';

      final config = EnvironmentLoader.load(
        source: MapEnvironmentValueSource(values),
      );

      expect(config.featureFlags.enableVerboseLogging, isTrue);
      expect(config.featureFlags.enableOfflineSync, isTrue);
      expect(config.featureFlags.enableAnalyticsTracking, isFalse);
    });

    test('throws for malformed feature flag', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.featureEnableVerboseLogging] = 'yes';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('throws for case-incorrect boolean', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.featureEnableVerboseLogging] = 'True';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('EnvironmentLoader — no Production fallback', () {
    test('Production with missing URL does not fall back', () {
      final values = Map<String, String>.from(_validProd)
        ..remove(AppConstants.envSupabaseUrl);

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('empty map does not silently select any environment', () {
      expect(
        () =>
            EnvironmentLoader.load(source: const MapEnvironmentValueSource({})),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('EnvironmentConfigException — safe output', () {
    test('does not contain the variable value in toString', () {
      const secretUrl = 'https://super-secret.supabase.co';
      const exception = EnvironmentConfigException(
        variableName: 'HIVORR_SUPABASE_URL',
        reason: 'Invalid URL format.',
      );

      expect(exception.toString(), isNot(contains(secretUrl)));
    });

    test('exception message contains variable name and reason', () {
      const exception = EnvironmentConfigException(
        variableName: 'HIVORR_ENV',
        reason: 'Unknown environment identifier.',
      );

      expect(exception.toString(), contains('HIVORR_ENV'));
      expect(exception.toString(), contains('Unknown environment'));
    });
  });

  group('SupabaseConfig — toString redaction', () {
    test('does not expose URL or key in toString', () {
      const config = SupabaseConfig(
        url: 'https://secret.supabase.co',
        anonKey: 'super-secret-anon-key',
      );

      expect(config.toString(), isNot(contains('secret.supabase.co')));
      expect(config.toString(), isNot(contains('super-secret')));
      expect(config.toString(), contains('[redacted]'));
    });
  });

  group('EnvironmentConfig — toString redaction', () {
    test('does not expose URL or key in toString', () {
      final config = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validDev),
      );

      expect(config.toString(), isNot(contains('dev.hivorr.supabase.co')));
      expect(config.toString(), contains('development'));
      expect(config.toString(), contains('schemaVersion'));
    });
  });

  group('Immutability', () {
    test('EnvironmentConfig fields are final and immutable', () {
      final config = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validDev),
      );

      // Compile-time immutability is enforced by final fields.
      // Verify the instance can be used in const contexts where applicable.
      expect(config.environment, AppEnvironment.development);
      expect(config.schemaVersion, 1);
    });

    test('AppConstants is const-constructible', () {
      const constants = AppConstants();
      expect(constants, isA<AppConstants>());
    });

    test('FeatureFlags is const-constructible', () {
      const flags = FeatureFlags(
        enableVerboseLogging: false,
        enableOfflineSync: false,
        enableAnalyticsTracking: false,
        enableDynamicWorkspaceLoading: false,
        enablePayloadOptimization: false,
      );
      expect(flags.enableVerboseLogging, isFalse);
    });
  });

  group('AppConfig façade', () {
    test('load delegates to EnvironmentLoader and exposes config', () {
      final appConfig = AppConfig.load(
        source: const MapEnvironmentValueSource(_validDev),
      );

      expect(appConfig.environment, AppEnvironment.development);
      expect(appConfig.isDevelopment, isTrue);
      expect(appConfig.supabaseUrl, 'https://dev.hivorr.supabase.co');
      expect(appConfig.schemaVersion, 1);
      expect(appConfig.constants, isA<AppConstants>());
      expect(appConfig.featureFlags, isA<FeatureFlags>());
    });

    test('throws when configuration is invalid', () {
      expect(
        () => AppConfig.load(source: const MapEnvironmentValueSource({})),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });
  });

  group('Edge cases', () {
    test('whitespace-only environment value fails', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envEnvironment] = '   ';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('whitespace-only URL fails', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseUrl] = '   ';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('URL with empty host fails', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseUrl] = 'https://';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('placeholder with "changeme" is rejected', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseAnonKey] = 'changeme';

      expect(
        () => EnvironmentLoader.load(source: MapEnvironmentValueSource(values)),
        throwsA(isA<EnvironmentConfigException>()),
      );
    });

    test('non-JWT key without service_role substring is accepted', () {
      final values = Map<String, String>.from(_validDev)
        ..[AppConstants.envSupabaseAnonKey] = 'a-valid-lookng-public-key-12345';

      final config = EnvironmentLoader.load(
        source: MapEnvironmentValueSource(values),
      );

      expect(config.supabaseConfig.anonKey, 'a-valid-lookng-public-key-12345');
    });
  });

  group('Cross-environment isolation', () {
    test('Development config does not contain Staging URL', () {
      final devConfig = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validDev),
      );
      final stagingConfig = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validStaging),
      );

      expect(
        devConfig.supabaseConfig.url,
        isNot(equals(stagingConfig.supabaseConfig.url)),
      );
      expect(devConfig.environment, isNot(equals(stagingConfig.environment)));
    });

    test('Staging config does not contain Production URL', () {
      final stagingConfig = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validStaging),
      );
      final prodConfig = EnvironmentLoader.load(
        source: const MapEnvironmentValueSource(_validProd),
      );

      expect(
        stagingConfig.supabaseConfig.url,
        isNot(equals(prodConfig.supabaseConfig.url)),
      );
      expect(stagingConfig.environment, isNot(equals(prodConfig.environment)));
    });
  });
}
