import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/config/app_config/app_config.dart';
import 'package:hivorr/core/authentication/authentication.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _step(String label) {
  // ignore: avoid_print
  print('STEP: $label');
}

/// Real [HttpClient] provider so live staging requests are not stubbed to 400
/// by the default test binding's [HttpOverrides].
///
/// `HttpClient(context)` re-consults [HttpOverrides.global]; we temporarily
/// clear it while constructing the genuine client to avoid infinite recursion.
class _RealHttpOverrides extends HttpOverrides {
  _RealHttpOverrides();

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpOverrides? previous = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      return HttpClient(context: context);
    } finally {
      HttpOverrides.global = previous;
    }
  }
}

/// In-memory [GotrueAsyncStorage] so GoTrue's PKCE flow works without
/// `Supabase.initialize` (which awaits a Realtime WebSocket blocked in this
/// headless sandbox). No real persistence is needed for a single test run.
class _MemoryAsyncStorage implements GotrueAsyncStorage {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }
}

/// Live-environment verification of EP-01-09 (staging target).
///
/// Verifies, against the real Supabase project:
///   - signUp returns a session (or correctly lands in awaitingEmailConfirmation),
///   - exactly one `entities` row exists for the signed-in identity (RLS-scoped),
///   - exactly one active `consumer` `entity_roles` row exists,
///   - re-sign-in is idempotent (no duplicate entity/role rows).
///
/// Production bootstrap (EP-01-15) is ApiConfig -> ApiInitializer ->
/// initializeAuth; here we build [SupabaseClient] with an in-memory
/// [GotrueAsyncStorage] and skip [Supabase.initialize] (its Realtime WebSocket
/// is blocked headlessly). The auth + provisioning paths under test are
/// identical.
///
/// Run (staging) with the public anon key only — never the service-role key:
///   flutter test test/integration/auth_flow_test.dart \
///     --dart-define=HIVORR_ENV=staging \
///     --dart-define=HIVORR_SUPABASE_URL=https://YOURPROJECT.supabase.co \
///     --dart-define=HIVORR_SUPABASE_ANON_KEY=eyJ...ANON \
///     --dart-define=HIVORR_CONFIG_SCHEMA_VERSION=1
///
/// `flutter test` stubs HttpClient and virtualizes time (FakeAsync), so all
/// real network I/O is wrapped in [WidgetTester.runAsync] with a real
/// [HttpOverrides] override. When no staging keys are supplied the test skips
/// (passes) so it never breaks the default unit suite. A 120s timeout fails
/// fast if unreachable.
void main() {
  testWidgets(
    'EP-01-09: signUp provisions entity + consumer role, idempotent on re-sign-in',
    (WidgetTester tester) async {
      _step('start');
      const String supabaseUrl = String.fromEnvironment('HIVORR_SUPABASE_URL');
      const String anonKey = String.fromEnvironment('HIVORR_SUPABASE_ANON_KEY');
      const String env = String.fromEnvironment('HIVORR_ENV');
      const String schemaVersion =
          String.fromEnvironment('HIVORR_CONFIG_SCHEMA_VERSION');

      // Skip when no staging credentials are supplied (default unit run).
      if (supabaseUrl.isEmpty ||
          anonKey.isEmpty ||
          env.isEmpty ||
          schemaVersion.isEmpty) {
        _step('skipped: no staging keys');
        return;
      }

      // Allow real network sockets for the live staging calls below.
      HttpOverrides.global = _RealHttpOverrides();

      // Real I/O must run outside FakeAsync via runAsync.
      await tester.runAsync(() async {
        // Load + validate config (mirrors production), then build the client
        // directly with an in-memory GotrueAsyncStorage to avoid the blocked
        // Realtime WebSocket inside Supabase.initialize.
        final AppConfig appConfig = AppConfig.load();
        _step('config loaded');
        final SupabaseClient supabaseClient = SupabaseClient(
          supabaseUrl,
          anonKey,
          authOptions: AuthClientOptions(
            pkceAsyncStorage: _MemoryAsyncStorage(),
          ),
        );
        final AuthLayer auth = initializeAuth(
          authClient: supabaseClient.auth,
          supabaseClient: supabaseClient,
          config: AuthConfig.fromEnvironment(appConfig.environmentConfig),
        );
        _step('auth initialized');

        await auth.provider.initialize();
        _step('provider initialized');

        // Optional pre-existing test user. When supplied, the harness uses
        // sign-IN instead of sign-UP, bypassing Supabase's per-IP signup rate
        // limit (e.g. for a user created via the dashboard). Create one at
        // Auth -> Users -> Add user, then pass its credentials here.
        const String existingEmail =
            String.fromEnvironment('HIVORR_TEST_USER_EMAIL');
        const String existingPassword =
            String.fromEnvironment('HIVORR_TEST_USER_PASSWORD');

        final String email;
        final String password;
        final bool signUpMode =
            existingEmail.isEmpty || existingPassword.isEmpty;
        if (signUpMode) {
          // Unique, disposable test identity (do not reuse real user emails).
          // Plain addresses only — GoTrue rejects '+' plus-tag local parts.
          // Override the domain if the target project restricts signup domains.
          const String emailDomain = String.fromEnvironment(
            'HIVORR_TEST_EMAIL_DOMAIN',
            defaultValue: 'example.com',
          );
          email = 'ep0109${DateTime.now().microsecondsSinceEpoch}@$emailDomain';
          password = 'Test@12345678';
        } else {
          email = existingEmail;
          password = existingPassword;
          _step('sign-in mode (pre-existing user; bypasses signup rate limit)');
        }

        // Verify the framework's status machine against the live project.
        // If staging enforces email confirmation, GoTrue withholds the session
        // and the framework must report awaitingEmailConfirmation (no entity is
        // provisioned). Enable autoconfirm in staging to exercise the full
        // DB-provisioning path below.
        final AuthResult result;
        if (signUpMode) {
          result = await auth.service.signUp(
            AuthCredentials(email: email, password: password),
          );
          _step('signUp returned ${result.status}');
          if (result.status == AuthStatus.awaitingEmailConfirmation) {
            _step(
              'awaitingEmailConfirmation (staging email confirmation enabled) '
              '— DB-provisioning assertions skipped; enable autoconfirm to '
              'verify entity + consumer-role provisioning.',
            );
            await auth.service.dispose();
            return;
          }
        } else {
          result = await auth.service.signIn(
            AuthCredentials(email: email, password: password),
          );
          _step('signIn returned ${result.status}');
        }

        expect(result.status, AuthStatus.authenticated);

        final String userId = auth.service.currentEntityId!;
        expect(userId, isNotEmpty);

        // One entity row, RLS-scoped to the signed-in identity (DoD §4).
        final List<Map<String, dynamic>> entities = await supabaseClient
            .from('entities')
            .select('id')
            .eq('id', userId);
        _step('entities query: ${entities.length} row(s)');
        expect(entities.length, 1, reason: 'exactly one entities row');
        expect(entities.first['id'], userId);

        // One active consumer role (DoD §4).
        final List<Map<String, dynamic>> roles = await supabaseClient
            .from('entity_roles')
            .select('role, is_active')
            .eq('entity_id', userId)
            .eq('role', 'consumer');
        _step('roles query: ${roles.length} row(s)');
        expect(roles.length, 1, reason: 'exactly one consumer role');
        expect(roles.first['is_active'], isTrue);

        // Idempotency: sign out, sign back in; counts must not grow (DoD §4/§9).
        await auth.service.signOut();
        expect(auth.service.status, AuthStatus.unauthenticated);
        _step('signed out');

        await auth.service.signIn(
          AuthCredentials(email: email, password: password),
        );
        expect(auth.service.status, AuthStatus.authenticated);
        _step('signed back in');

        final List<Map<String, dynamic>> rolesAfter = await supabaseClient
            .from('entity_roles')
            .select('role')
            .eq('entity_id', userId)
            .eq('role', 'consumer');
        expect(rolesAfter.length, 1,
            reason:
                'consumer role provisioning is idempotent across re-sign-in');
        _step('idempotency verified');

        await auth.service.dispose();
      });
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
