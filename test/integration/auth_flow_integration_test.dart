import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/api_client/auth_interceptor.dart';
import 'package:hivorr/core/api/api_client/retry_interceptor.dart';
import 'package:hivorr/core/api/auth/access_token_provider.dart';
import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/factories/mock_supabase_client_factory.dart';
import '../support/fakes/fake_api.dart';
import '../support/fakes/fake_supabase.dart';

class _GoTrueAccessTokenProvider implements AccessTokenProvider {
  _GoTrueAccessTokenProvider(this._authClient);

  final GoTrueClient _authClient;
  int refreshCount = 0;

  @override
  String? get currentToken => _authClient.currentSession?.accessToken;

  @override
  Future<String?> refresh() async {
    refreshCount++;
    final AuthResponse response = await _authClient.refreshSession();
    return response.session?.accessToken;
  }
}

class _RefreshingFakeGoTrueClient extends FakeGoTrueClient {
  _RefreshingFakeGoTrueClient(this.refreshedToken);

  final String refreshedToken;
  Session? _refreshed;

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    _refreshed = Session(
      accessToken: refreshedToken,
      tokenType: 'bearer',
      user: fakeUser('u1'),
    );
    return AuthResponse(session: _refreshed, user: _refreshed!.user);
  }

  @override
  Session? get currentSession => _refreshed ?? super.currentSession;
}

class _ApiHarness {
  _ApiHarness({
    required AccessTokenProvider tokenProvider,
    bool retry = false,
    this.failWith = 0,
  }) {
    _dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'));
    _dio.httpClientAdapter = ScriptedAdapter(_onFetch);
    _dio.interceptors.add(AuthInterceptor(tokenProvider: tokenProvider));
    if (retry) {
      _dio.interceptors.add(
        RetryInterceptor(
          dio: _dio,
          retryPolicy: const RetryPolicy(),
          tokenProvider: tokenProvider,
          maxRetries: 3,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
        ),
      );
    }
  }

  final int failWith;
  int requestCount = 0;
  String? lastAuthHeader;
  late final Dio _dio;

  Future<ResponseBody> _onFetch(RequestOptions options) async {
    requestCount++;
    if (requestCount == 1 && failWith > 0) {
      return errorBody(failWith);
    }
    lastAuthHeader = options.headers['Authorization'] as String?;
    return successBody();
  }

  Future<void> call(String path) async {
    await _dio.get<dynamic>(path);
  }
}

void main() {
  group('Auth flow integration', () {
    test(
        'sign-up flow: session created, provider authenticated, token injected',
        () async {
      final SupabaseClient supabase =
          MockSupabaseClientFactory.create(currentUser: fakeUser('u1'));
      final FakeGoTrueClient goTrue =
          (supabase as ScriptedSupabaseClient).goTrue;
      final AuthService service = SupabaseAuthService(
        authClient: goTrue,
        supabaseClient: supabase,
        config: const AuthConfig(),
      );
      final AuthProvider provider = AuthProvider(service: service);
      final _GoTrueAccessTokenProvider tokenProvider =
          _GoTrueAccessTokenProvider(goTrue);
      final _ApiHarness api = _ApiHarness(tokenProvider: tokenProvider);

      await provider.initialize();
      await pumpEventQueue();

      final AuthResult result = await service.signUp(
        AuthCredentials(email: 'user@example.com', password: 'password'),
      );
      await pumpEventQueue();

      expect(result.status, AuthStatus.authenticated);
      expect(service.currentSession, isNotNull);
      expect(provider.status, AuthStatus.authenticated);
      expect(tokenProvider.currentToken, isNotNull);
      expect(tokenProvider.currentToken?.isNotEmpty, isTrue);

      await api.call('/me');
      expect(api.lastAuthHeader, 'Bearer ${tokenProvider.currentToken}');

      await service.dispose();
      await goTrue.close();
    });

    test(
        'sign-in flow: session restored, provider transitions, token valid',
        () async {
      final SupabaseClient supabase = MockSupabaseClientFactory.create();
      final FakeGoTrueClient goTrue =
          (supabase as ScriptedSupabaseClient).goTrue;
      final AuthService service = SupabaseAuthService(
        authClient: goTrue,
        supabaseClient: supabase,
        config: const AuthConfig(),
      );
      final AuthProvider provider = AuthProvider(service: service);
      final _GoTrueAccessTokenProvider tokenProvider =
          _GoTrueAccessTokenProvider(goTrue);

      await provider.initialize();
      await pumpEventQueue();

      final AuthResult result = await service.signIn(
        AuthCredentials(email: 'user@example.com', password: 'password'),
      );
      await pumpEventQueue();

      expect(result.status, AuthStatus.authenticated);
      expect(service.currentSession, isNotNull);
      expect(provider.status, AuthStatus.authenticated);
      expect(tokenProvider.currentToken, 'fake-access-token');

      await service.dispose();
      await goTrue.close();
    });

    test(
        'token refresh: 401 triggers refresh and retry with new token',
        () async {
      final _RefreshingFakeGoTrueClient goTrue =
          _RefreshingFakeGoTrueClient('refreshed-token');
      goTrue.seedSession(fakeSession('u1'));
      final _GoTrueAccessTokenProvider tokenProvider =
          _GoTrueAccessTokenProvider(goTrue);
      final _ApiHarness api = _ApiHarness(
        tokenProvider: tokenProvider,
        retry: true,
        failWith: 401,
      );

      expect(tokenProvider.currentToken, 'fake-access-token');

      await api.call('/secure');
      await pumpEventQueue();

      expect(tokenProvider.refreshCount, 1);
      expect(api.requestCount, 2);
      expect(api.lastAuthHeader, 'Bearer refreshed-token');

      await goTrue.close();
    });

    test(
        'session persistence: recreate service with same auth client restores session',
        () async {
      final SupabaseClient supabase = MockSupabaseClientFactory.create();
      final FakeGoTrueClient goTrue =
          (supabase as ScriptedSupabaseClient).goTrue;
      final AuthService service1 = SupabaseAuthService(
        authClient: goTrue,
        supabaseClient: supabase,
        config: const AuthConfig(),
      );
      final AuthProvider provider1 = AuthProvider(service: service1);
      await provider1.initialize();
      await pumpEventQueue();
      await service1.signIn(
        AuthCredentials(email: 'user@example.com', password: 'password'),
      );
      await pumpEventQueue();
      expect(provider1.status, AuthStatus.authenticated);
      await service1.dispose();

      final AuthService service2 = SupabaseAuthService(
        authClient: goTrue,
        supabaseClient: supabase,
        config: const AuthConfig(),
      );
      final AuthProvider provider2 = AuthProvider(service: service2);
      await provider2.initialize();
      await pumpEventQueue();

      expect(goTrue.currentSession, isNotNull);
      expect(provider2.status, AuthStatus.authenticated);

      await service2.dispose();
      await goTrue.close();
    });

    test(
        'logout: provider unauthenticated and interceptor stops injecting token',
        () async {
      final SupabaseClient supabase = MockSupabaseClientFactory.create();
      final FakeGoTrueClient goTrue =
          (supabase as ScriptedSupabaseClient).goTrue;
      final AuthService service = SupabaseAuthService(
        authClient: goTrue,
        supabaseClient: supabase,
        config: const AuthConfig(),
      );
      final AuthProvider provider = AuthProvider(service: service);
      final _GoTrueAccessTokenProvider tokenProvider =
          _GoTrueAccessTokenProvider(goTrue);
      final _ApiHarness api = _ApiHarness(tokenProvider: tokenProvider);

      await provider.initialize();
      await pumpEventQueue();
      await service.signIn(
        AuthCredentials(email: 'user@example.com', password: 'password'),
      );
      await pumpEventQueue();

      await api.call('/me');
      expect(api.lastAuthHeader, 'Bearer fake-access-token');

      await service.signOut();
      await pumpEventQueue();
      expect(provider.status, AuthStatus.unauthenticated);
      expect(tokenProvider.currentToken, isNull);

      await api.call('/me');
      expect(api.lastAuthHeader, isNull);

      await service.dispose();
      await goTrue.close();
    });

    test(
        'auth state propagation: guard permits when signed-in, redirects when signed-out',
        () async {
      final SupabaseClient supabase = MockSupabaseClientFactory.create();
      final FakeGoTrueClient goTrue =
          (supabase as ScriptedSupabaseClient).goTrue;
      final AuthService service = SupabaseAuthService(
        authClient: goTrue,
        supabaseClient: supabase,
        config: const AuthConfig(),
      );
      final AuthProvider provider = AuthProvider(service: service);
      final RouteGuard routeGuard = RouteGuard(authProvider: provider);

      await provider.initialize();
      await pumpEventQueue();

      expect(provider.isSignedIn, isFalse);
      expect(routeGuard.redirectResolver('/profile'), '/login');

      await service.signIn(
        AuthCredentials(email: 'user@example.com', password: 'password'),
      );
      await pumpEventQueue();
      expect(provider.isSignedIn, isTrue);
      expect(routeGuard.redirectResolver('/profile'), isNull);
      expect(routeGuard.redirectResolver('/'), isNull);
      expect(routeGuard.redirectResolver('/login'), RoutePaths.home);

      await service.signOut();
      await pumpEventQueue();
      expect(provider.isSignedIn, isFalse);
      expect(routeGuard.redirectResolver('/profile'), '/login');
      expect(routeGuard.redirectResolver('/dashboard'), '/login');

      await service.dispose();
      await goTrue.close();
    });
  });
}
