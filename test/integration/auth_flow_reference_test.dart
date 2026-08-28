import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/support.dart';

void main() {
  group('Auth flow (reference scaffold)', () {
    late SupabaseClient supabaseClient;
    late FakeSupabaseAuthService authService;

    setUp(() {
      // Canonical one-call Supabase fake creation.
      supabaseClient = MockSupabaseClientFactory.create();
      authService = FakeSupabaseAuthService(
        authClient: (supabaseClient as ScriptedSupabaseClient).goTrue,
        supabaseClient: supabaseClient,
        config: const AuthConfig(),
      );
    });

    test('factory creates a signed-out client by default', () {
      final SupabaseClient client = MockSupabaseClientFactory.create();
      final FakeGoTrueClient goTrue =
          (client as ScriptedSupabaseClient).goTrue;
      expect(goTrue.currentUser, isNull);
      expect(goTrue.currentSession, isNull);
    });

    test('factory configures signed-in state from a user', () {
      final SupabaseClient client =
          MockSupabaseClientFactory.create(currentUser: fakeUser('u1'));
      final FakeGoTrueClient goTrue =
          (client as ScriptedSupabaseClient).goTrue;
      expect(goTrue.currentUser?.id, 'u1');
    });

    test('scaffold: sign-in accepts credentials', () {
      // TODO(EP-01-20): wire the auth framework's sign-in entrypoint and assert
      // post-sign-in navigation. The fake backend is configured signed-in to
      // demonstrate the canonical setup.
      final SupabaseClient client =
          MockSupabaseClientFactory.create(currentUser: fakeUser('u1'));
      final FakeGoTrueClient goTrue =
          (client as ScriptedSupabaseClient).goTrue;
      expect(authService, isA<FakeSupabaseAuthService>());
      expect(goTrue.currentUser?.id, 'u1');
    });

    test('scaffold: invalid credentials rejected', () {
      // TODO(EP-01-20): configure the fake to reject credentials and assert an
      // error message is surfaced by the UI.
      expect(authService, isA<FakeSupabaseAuthService>());
    });

    test('scaffold: sign-out returns to login', () async {
      // TODO(EP-01-20): start signed-in, trigger sign-out, assert navigation
      // to the login route. Here we verify the fake auth client resets state.
      final FakeGoTrueClient goTrue =
          (supabaseClient as ScriptedSupabaseClient).goTrue;
      await goTrue.signOut();
      expect(goTrue.currentUser, isNull);
    });
  });
}
