import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/authentication/auth_config.dart';
import 'package:hivorr/core/authentication/models/auth_credentials.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/core/authentication/services/supabase_auth_service.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_fakes.dart';

void main() {
  group('AuthProvider', () {
    late FakeGoTrueClient authClient;

    setUp(() => authClient = FakeGoTrueClient());
    tearDown(() async => authClient.close());

    AuthProvider buildProvider() => AuthProvider(
          service: SupabaseAuthService(
            authClient: authClient,
            supabaseClient: FakeSupabaseClient(),
            config: const AuthConfig(),
          ),
        );

    test('initialize mirrors the service status', () async {
      final AuthProvider provider = buildProvider();
      authClient.seedSession(fakeSession('u1'));

      await provider.initialize();

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.currentEntityId, 'u1');
      expect(provider.isSignedIn, isTrue);
      await provider.service.dispose();
    });

    test('signIn updates status and notifies listeners', () async {
      final AuthProvider provider = buildProvider();
      await provider.initialize();
      expect(provider.status, AuthStatus.unauthenticated);

      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.signIn(
        AuthCredentials(email: 'a@b.com', password: 'password'),
      );

      expect(provider.isSignedIn, isTrue);
      expect(provider.currentEntityId, 'u1');
      expect(notified, isTrue);
      await provider.service.dispose();
    });

    test('signOut clears entity and notifies listeners', () async {
      final AuthProvider provider = buildProvider();
      await provider.initialize();
      authClient.emit(AuthChangeEvent.signedIn, fakeSession('u1'));
      await pumpEventQueue();
      expect(provider.isSignedIn, isTrue);

      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.signOut();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.currentEntityId, isNull);
      expect(notified, isTrue);
      await provider.service.dispose();
    });

    test('failed signIn records error without throwing', () async {
      final AuthProvider provider = buildProvider();
      await provider.initialize();
      authClient.nextError = const AuthException(
        'Invalid login credentials',
        statusCode: '400',
      );

      await provider.signIn(
        AuthCredentials(email: 'a@b.com', password: 'wrong'),
      );

      expect(provider.lastError, isNotNull);
      expect(provider.isSignedIn, isFalse);
      await provider.service.dispose();
    });

    test('exposes auth status stream passthrough', () async {
      final AuthProvider provider = buildProvider();
      await provider.initialize();
      authClient.emit(AuthChangeEvent.signedIn, fakeSession('u1'));
      await pumpEventQueue();
      expect(provider.status, AuthStatus.authenticated);
      await provider.service.dispose();
    });
  });
}
