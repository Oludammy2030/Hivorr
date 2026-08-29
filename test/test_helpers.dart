import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale, LocalizationsDelegate;

import 'package:hivorr/config/app_config/app_config.dart';
import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fakes/fake_auth.dart';
import 'support/fakes/fake_storage.dart';

export 'support/fakes/fake_auth.dart';
export 'support/fakes/fake_storage.dart';
export 'support/harnesses/widget_harness.dart';

/// Non-secret, non-service-role fake anon key for tests.
const String fakeAnonKey = 'public-anon-key-abcdef123456';

/// Builds an [AppConfig] backed by an in-memory value source (no compile-time
/// flags). Suitable for bootstrap unit tests.
AppConfig fakeAppConfig() => AppConfig.load(
      source: const MapEnvironmentValueSource(<String, String>{
        AppConstants.envEnvironment: 'development',
        AppConstants.envSupabaseUrl: 'https://example.supabase.co',
        AppConstants.envSupabaseAnonKey: fakeAnonKey,
        AppConstants.envConfigSchemaVersion: '1',
      }),
    );

/// No-arg loader matching [AppBootstrap.initialize]'s [loadConfig] signature.
AppConfig fakeLoadConfig() => fakeAppConfig();

/// Builds a fully wired but network-free [ApiLayer] for bootstrap tests.
ApiLayer fakeApiLayer() => ApiLayer(
      dio: Dio(),
      supabaseClient: SupabaseClient(
        'https://example.supabase.co',
        fakeAnonKey,
      ),
      tokenProvider: const SupabaseAccessTokenProvider(),
      exceptionMapper: const ApiExceptionMapper(),
    );

/// API initializer stub returning [fakeApiLayer].
Future<ApiLayer> fakeInitializeApi(EnvironmentConfig _) async => fakeApiLayer();

/// Auth-layer initializer stub returning fakes (no Supabase interaction).
AuthLayer fakeInitializeAuthLayer(
  GoTrueClient _,
  SupabaseClient _,
  AuthConfig _,
) =>
    AuthLayer(service: FakeAuthService(), provider: FakeAuthProvider());

/// [LocaleProvider] backed by [FakeStorageEngine], for app shell tests.
class FakeLocaleProvider extends LocaleProvider {
  FakeLocaleProvider()
      : super(
          config: defaultLocalizationConfig,
          storage: FakeStorageEngine(),
        );
}

/// [LocalizationsDelegate] that returns pre-loaded [HivorrLocalizations] without
/// touching [rootBundle], so widget tests avoid the test-binding quirk where
/// `rootBundle.loadString` hangs on the second `testWidgets` in a file.
class FakeLocalizationsDelegate
    extends LocalizationsDelegate<HivorrLocalizations> {
  const FakeLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<HivorrLocalizations> load(Locale locale) async =>
      HivorrLocalizations(
        <String, String>{
          'common.ok': locale.languageCode == 'fr' ? 'DACCORD' : 'OK',
          'common.cancel': 'Cancel',
          'validation.required': '{field} is required',
          'common.itemCount.zero': 'No items',
          'common.itemCount.one': '1 item',
          'common.itemCount.other': '{count} items',
        },
        <String, String>{},
        locale,
      );

  @override
  bool shouldReload(FakeLocalizationsDelegate old) => true;
}
