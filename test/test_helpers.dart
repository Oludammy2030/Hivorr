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
import 'package:hivorr/core/database/storage_engine.dart';
import 'package:hivorr/core/localization/localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Inert [AuthService] for bootstrap tests.
class FakeAuthService implements AuthService {
  @override
  AuthStatus get status => AuthStatus.unauthenticated;

  @override
  String? get currentEntityId => null;

  @override
  AuthSession? get currentSession => null;

  @override
  bool get isSignedIn => false;

  @override
  Stream<AuthStatus> get onStatusChanged =>
      const Stream<AuthStatus>.empty();

  @override
  Future<AuthResult> signUp(AuthCredentials credentials) async =>
      AuthResult(status: AuthStatus.unauthenticated);

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async =>
      AuthResult(status: AuthStatus.unauthenticated);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureEntityExists() async {}

  @override
  Future<void> dispose() async {}
}

/// [AuthProvider] whose [status] is directly controllable for routing tests.
class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider({AuthStatus initialStatus = AuthStatus.unauthenticated})
      : _status = initialStatus,
        super(service: FakeAuthService());

  AuthStatus _status;

  @override
  AuthStatus get status => _status;

  @override
  bool get isSignedIn => _status == AuthStatus.authenticated;

  /// Drives the provider's reported status (and notifies listeners).
  void setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
}

/// In-memory [StorageEngine] for bootstrap and locale-provider tests.
///
/// Stores values as nested maps keyed by `box` then `key`, matching the
/// [StorageEngine] contract without touching the filesystem.
class FakeStorageEngine implements StorageEngine {
  final Map<String, Map<String, dynamic>> _data =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    _data.putIfAbsent(box, () => <String, dynamic>{});
    _data[box]![key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    final Map<String, dynamic>? boxData = _data[box];
    if (boxData == null) {
      return null;
    }
    final dynamic value = boxData[key];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<void> delete(String box, String key) async {
    _data[box]?.remove(key);
  }

  @override
  Future<void> clearBox(String box) async {
    _data.remove(box);
  }

  @override
  Future<List<String>> keys(String box) async =>
      (_data[box]?.keys ?? <String>[]).toList();

  @override
  Future<void> writeBatch(String box, List<WriteOp> ops) async {
    for (final WriteOp op in ops) {
      if (op is PutOp) {
        await put(box, op.key, op.value);
      } else if (op is DeleteOp) {
        await delete(box, op.key);
      }
    }
  }
}

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
