import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/services/auth_service.dart';
import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_fakes.dart';

AuthService buildService({
  required FakeGoTrueClient authClient,
  SupabaseClient? supabaseClient,
  bool recordProvisioning = false,
}) {
  if (recordProvisioning) {
    return FakeSupabaseAuthService(
      authClient: authClient,
      supabaseClient: supabaseClient ?? FakeSupabaseClient(),
      config: const AuthConfig(),
    );
  }
  return SupabaseAuthService(
    authClient: authClient,
    supabaseClient: supabaseClient ?? FakeSupabaseClient(),
    config: const AuthConfig(),
  );
}

void main() {
  group('SupabaseAuthService', () {
    late FakeGoTrueClient authClient;

    setUp(() => authClient = FakeGoTrueClient());
    tearDown(() async => authClient.close());

    test('signUp returns authenticated when a session is issued', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.returnSessionOnSignUp = true;

      final AuthResult result = await service.signUp(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(result.status, AuthStatus.authenticated);
      expect(result.session?.entityId, 'u1');
      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      expect(service.isSignedIn, isTrue);
      await service.dispose();
    });

    test('signUp returns awaitingEmailConfirmation when no session', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.returnSessionOnSignUp = false;

      final AuthResult result = await service.signUp(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(result.status, AuthStatus.awaitingEmailConfirmation);
      expect(service.status, AuthStatus.awaitingEmailConfirmation);
      expect(service.isSignedIn, isFalse);
      await service.dispose();
    });

    test('signIn returns authenticated and exposes the entity id', () async {
      final AuthService service = buildService(authClient: authClient);

      final AuthResult result = await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(result.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      expect(service.currentSession?.entityId, 'u1');
      await service.dispose();
    });

    test('signOut transitions to unauthenticated', () async {
      final AuthService service = buildService(authClient: authClient);
      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );
      expect(service.isSignedIn, isTrue);

      await service.signOut();

      expect(service.status, AuthStatus.unauthenticated);
      expect(service.currentEntityId, isNull);
      expect(service.isSignedIn, isFalse);
      await service.dispose();
    });

    test('initialize restores a persisted session as authenticated', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.seedSession(fakeSession('u1'));

      await service.initialize();

      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      await service.dispose();
    });

    test('initialize with no session yields unauthenticated', () async {
      final AuthService service = buildService(authClient: authClient);

      await service.initialize();

      expect(service.status, AuthStatus.unauthenticated);
      await service.dispose();
    });

    test('invalid credentials surface a typed ApiException', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.nextError = const AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );

      expect(
        () => service.signIn(
          AuthCredentials(email: 'a@b.com', password: 'wrong'),
        ),
        throwsA(isA<ApiException>()),
      );
      await service.dispose();
    });

    test('onAuthStateChange signedIn drives authenticated state', () async {
      final AuthService service = buildService(authClient: authClient);
      await service.initialize();
      expect(service.status, AuthStatus.unauthenticated);

      authClient.emit(AuthChangeEvent.signedIn, fakeSession('u1'));
      await pumpEventQueue();

      expect(service.status, AuthStatus.authenticated);
      expect(service.currentEntityId, 'u1');
      await service.dispose();
    });

    test('onAuthStateChange signedOut drives unauthenticated state', () async {
      final AuthService service = buildService(authClient: authClient);
      authClient.seedSession(fakeSession('u1'));
      await service.initialize();
      expect(service.status, AuthStatus.authenticated);

      authClient.emit(AuthChangeEvent.signedOut);
      await pumpEventQueue();

      expect(service.status, AuthStatus.unauthenticated);
      await service.dispose();
    });

    test('ensureEntityExists is idempotent per signed-in user', () async {
      final FakeSupabaseAuthService service = buildService(
        authClient: authClient,
        recordProvisioning: true,
      ) as FakeSupabaseAuthService;

      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );
      await pumpEventQueue();
      await service.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );
      await pumpEventQueue();

      expect(service.provisionCallCount, 1);
      await service.dispose();
    });
  });
}
