import 'package:dio/dio.dart';

import 'package:hivorr/config/app_config/app_config.dart';
import 'package:hivorr/config/constants/app_constants.dart';
import 'package:hivorr/config/environments/environment_config.dart';
import 'package:hivorr/config/environments/environment_value_source.dart';
import 'package:hivorr/core/api/api_initializer.dart';
import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/api/exceptions/api_exception_mapper.dart';
import 'package:hivorr/core/authentication/authentication.dart';
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
