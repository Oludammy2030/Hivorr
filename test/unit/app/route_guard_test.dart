import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/models/auth_session.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/local/entry_state_store.dart';
import 'package:hivorr/data/models/onboarding_status_dto.dart';

import '../../support/onboarding/onboarding_test_support.dart';
import '../../test_helpers.dart';

void main() {
  group('RouteGuard', () {
    group('entry doors', () {
      test('unauthenticated root resolves to the platform entry door',
          () async {
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final guard = RouteGuard(authProvider: provider);

        // The test binary runs in the Dart VM (kIsWeb == false). Keep both
        // expectations so the same test is valid for `flutter test --platform
        // chrome`.
        if (kIsWeb) {
          expect(guard.redirectResolver('/'), RoutePaths.welcome);
        } else {
          // Native returning visitor (intro seen) → login door.
          final entry = EntryStateProvider(
            store: InMemoryEntryStateStore(introSeen: true),
          );
          await entry.hydrate();
          final returning = RouteGuard(
            authProvider: provider,
            entryStateProvider: entry,
          );
          expect(returning.redirectResolver('/'), RoutePaths.login);
        }
      });

      test('native first launch routes the unauthenticated root to /intro', () {
        if (kIsWeb) {
          return;
        }
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final entry = EntryStateProvider(
          store: InMemoryEntryStateStore(introSeen: false),
        );
        final guard = RouteGuard(
          authProvider: provider,
          entryStateProvider: entry,
        );

        expect(guard.redirectResolver('/'), RoutePaths.intro);
        expect(guard.redirectResolver('/profile'), '/intro?next=/profile');
      });

      test('native returning visitor (intro seen) is routed to /login',
          () async {
        if (kIsWeb) {
          return;
        }
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final entry = EntryStateProvider(
          store: InMemoryEntryStateStore(introSeen: true),
        );
        await entry.hydrate();
        final guard = RouteGuard(
          authProvider: provider,
          entryStateProvider: entry,
        );

        expect(guard.redirectResolver('/'), RoutePaths.login);
        expect(guard.redirectResolver('/profile'), '/login?next=/profile');
      });

      test('protected destinations keep their context as ?next=', () {
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final guard = RouteGuard(authProvider: provider);
        expect(guard.redirectResolver('/settings'), '/login?next=/settings');
        expect(guard.redirectResolver('/p/john/123'), isNull);
      });

      test('welcome and intro are publicly accessible', () {
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final guard = RouteGuard(authProvider: provider);
        expect(guard.redirectResolver('/welcome'), isNull);
        expect(guard.redirectResolver('/intro'), isNull);
      });

      test('unauthenticated user may access all public Website pages', () {
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
        final guard = RouteGuard(authProvider: provider);
        for (final String path in <String>[
          '/welcome',
          '/about',
          '/how-it-works',
          '/features',
          '/pricing',
          '/security',
          '/contact',
          '/help',
          '/auth/confirm',
          '/auth/confirm?email=a%40b.com&next=/p/acme/1',
        ]) {
          expect(guard.redirectResolver(path), isNull,
              reason: '$path should be publicly accessible');
        }
      });

      test('authenticated user is bounced from public Website pages to home',
          () {
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.authenticated);
        final guard = RouteGuard(authProvider: provider);
        for (final String path in <String>[
          '/about',
          '/how-it-works',
          '/features',
          '/pricing',
          '/security',
          '/contact',
          '/help',
        ]) {
          expect(guard.redirectResolver(path), RoutePaths.home,
              reason: "$path should bounce to home when authenticated");
        }
      });

      test('authenticated users are bounced from public doors to home', () {
        final provider =
            FakeAuthProvider(initialStatus: AuthStatus.authenticated);
        final guard = RouteGuard(authProvider: provider);
        expect(guard.redirectResolver('/welcome'), RoutePaths.home);
        expect(guard.redirectResolver('/intro'), RoutePaths.home);
        expect(guard.redirectResolver('/'), isNull);
        expect(guard.redirectResolver('/profile'), isNull);
      });
    });

    test('unauthenticated returning user is redirected to /login', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/'), '/login');
      expect(guard.redirectResolver('/profile'), '/login?next=/profile');
      expect(guard.redirectResolver('/settings'), '/login?next=/settings');
    });

    test('unauthenticated user may access public auth routes', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/login'), isNull);
      expect(guard.redirectResolver('/signup'), isNull);
      expect(guard.redirectResolver('/forgot-password'), isNull);
      expect(guard.redirectResolver('/reset-password'), isNull);
    });

    test('unauthenticated user may access public content routes', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/p/john/123'), isNull);
      expect(guard.redirectResolver('/store/abc'), isNull);
    });

    test('authenticated user is allowed on protected and content routes', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.authenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/'), isNull);
      expect(guard.redirectResolver('/profile'), isNull);
      expect(guard.redirectResolver('/p/john/123'), isNull);
      expect(guard.redirectResolver('/store/abc'), isNull);
    });

    test('authenticated user is bounced from public-only auth routes to /', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.authenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/login'), '/');
      expect(guard.redirectResolver('/signup'), '/');
    });

    test(
        'authenticated but unverified session is confined to the verification '
        'gate (fail-closed)', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.authenticated)
        ..sessionOverride = const AuthSession(
          entityId: 'u1',
          email: 'me@example.com',
          isEmailConfirmed: false,
        );
      final guard = RouteGuard(authProvider: provider);

      // The gate itself stays reachable in resume mode.
      expect(
        guard.redirectResolver('/auth/confirm?email=me%40example.com&mode=resume'),
        isNull,
      );
      // Every other destination — home, onboarding, profile, public doors —
      // redirects to the verification gate in resume mode.
      for (final String path in <String>[
        '/',
        '/profile',
        '/onboarding',
        '/onboarding/profile',
        '/login',
        '/signup',
        '/welcome',
      ]) {
        expect(
          guard.redirectResolver(path),
          '/auth/confirm?email=me%40example.com&mode=resume',
          reason: '$path should confine an unverified session to the gate',
        );
      }
    });

    test('an unverified session without an email is left untouched', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.authenticated)
        ..sessionOverride = const AuthSession(
          entityId: 'u1',
          isEmailConfirmed: false,
        );
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/'), isNull);
    });

    test('verified sessions are unaffected by the verification gate', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.authenticated)
        ..sessionOverride = const AuthSession(
          entityId: 'u1',
          email: 'me@example.com',
          isEmailConfirmed: true,
        );
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/'), isNull);
      expect(guard.redirectResolver('/profile'), isNull);
      expect(guard.redirectResolver('/login'), '/');
    });

    test('initial (pre-init) status is fail-closed to /login', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.initial);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/profile'), '/login?next=/profile');
    });
  });

  group('RouteGuard (development-only onboarding preview)', () {
    test('development lets an unauthenticated reviewer open onboarding routes',
        () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(
        authProvider: provider,
        environment: AppEnvironment.development,
      );
      expect(guard.redirectResolver('/onboarding'), isNull);
      expect(guard.redirectResolver('/onboarding/profile'), isNull);
      expect(guard.redirectResolver('/onboarding/industry'), isNull);
      expect(guard.redirectResolver('/onboarding/trade-proof'), isNull);
      expect(guard.redirectResolver('/onboarding/complete'), isNull);
      expect(guard.redirectResolver('/login'), isNull);
    });

    test('development bypass never softens auth or protected routes', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(
        authProvider: provider,
        environment: AppEnvironment.development,
      );
      expect(guard.redirectResolver('/profile'), '/login?next=/profile');
      expect(guard.redirectResolver('/settings'), '/login?next=/settings');
    });

    test('default (production) guard stays fail-closed on onboarding routes',
        () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/onboarding'), '/login?next=/onboarding');
      expect(
        guard.redirectResolver('/onboarding/profile'),
        '/login?next=/onboarding/profile',
      );
    });

    test(
        'development boot redirect honours an #/onboarding deep link requested '
        'at page load', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(
        authProvider: provider,
        environment: AppEnvironment.development,
        baseUri: Uri.parse('http://localhost:55894/#/onboarding'),
      );
      expect(guard.redirectResolver('/'), '/onboarding');
      expect(guard.redirectResolver('/onboarding'), isNull);
      expect(guard.redirectResolver('/onboarding/profile'), isNull);
    });

    test(
        'development boot redirect supports onboarding sub-step deep links '
        'and path-based links', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final hashGuard = RouteGuard(
        authProvider: provider,
        environment: AppEnvironment.development,
        baseUri: Uri.parse('http://localhost:55894/#/onboarding/identity'),
      );
      expect(hashGuard.redirectResolver('/'), '/onboarding/identity');
      final pathGuard = RouteGuard(
        authProvider: provider,
        environment: AppEnvironment.development,
        baseUri: Uri.parse('http://localhost:55894/onboarding'),
      );
      expect(pathGuard.redirectResolver('/'), '/onboarding');
    });

    test('production ignores the onboarding boot deep link (fail-closed)', () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(
        authProvider: provider,
        baseUri: Uri.parse('http://localhost:55894/#/onboarding'),
      );
      expect(guard.redirectResolver('/'), '/login');
      expect(
        guard.redirectResolver('/onboarding'),
        '/login?next=/onboarding',
      );
    });
  });

  group('RouteGuard (exit-and-resume gate)', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('an exited incomplete wizard keeps home reachable (no force-resume)',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.exitWizard();
      expect(stack.provider.exited, isTrue);
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(guard.redirectResolver(RoutePaths.home), isNull);
      expect(
        guard.redirectResolver(RoutePaths.onboardingCapability),
        isNull,
        reason: 'onboarding routes stay reachable while the wizard resumes',
      );
      stack.provider.dispose();
    });

    test('home is force-resumed once the exit flag is cleared', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.continueRegistration();
      expect(stack.provider.exited, isFalse);
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.onboardingCapability,
        reason: 'resume re-engages after Continue registration',
      );
      stack.provider.dispose();
    });

    test('lifecycle saveAndExit never suppresses the resume redirect',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.saveAndExit();
      expect(stack.provider.exited, isFalse);
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.onboardingCapability,
      );
      stack.provider.dispose();
    });

    test('a completed exited wizard reads as complete; home stays all-clear',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      for (int i = 0; i < 5; i++) {
        await stack.provider.advance();
      }
      expect(stack.provider.isComplete, isTrue);
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(guard.redirectResolver(RoutePaths.home), isNull);
      expect(
        guard.redirectResolver(RoutePaths.onboarding),
        RoutePaths.home,
      );
      stack.provider.dispose();
    });
  });

  group('RouteGuard (server-authoritative completion)', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('server-completed relaunch with an empty store short-circuits to home',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      stack.onboardingRemote.status = OnboardingStatusDto(
        capability: 'both',
        completed: true,
        onboardingCompletedAt: DateTime.utc(2026, 9, 17),
        profileExists: true,
        professionalRoleActive: true,
        professionExists: true,
      );
      await stack.hydrate('u1');
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(guard.redirectResolver(RoutePaths.home), isNull,
          reason: 'home stays reachable for a completed wizard');
      expect(
        guard.redirectResolver(RoutePaths.onboardingCapability),
        RoutePaths.home,
        reason: 'a completed wizard bounces away from onboarding routes',
      );
      stack.provider.dispose();
    });

    test('authoritative incomplete overrides a stale cached complete',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
      await stack.provider.advance();
      await stack.provider.advance();
      await stack.provider.advance();
      await stack.provider.advance();
      expect(stack.provider.isComplete, isTrue,
          reason: 'the local cache was completed in the previous session');
      // The server (source of truth) reports the wizard is NOT complete —
      // e.g. the completion stamp was rolled back or never persisted.
      stack.onboardingRemote.status = const OnboardingStatusDto(
        completed: false,
      );
      await stack.hydrate('u1');
      expect(stack.provider.isCompleteAuthoritative, isFalse);
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.onboardingTradeProof,
        reason: 'the authoritative incomplete wins over the stale cache, '
            'routing home into the wizard at the cached trade-proof step',
      );
      stack.provider.dispose();
    });

    test('offline relaunch with cached completion degrades gracefully',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      for (int i = 0; i < 5; i++) {
        await stack.provider.advance();
      }
      expect(stack.provider.isComplete, isTrue);
      stack.onboardingRemote.nextGetError = const ApiException(
        kind: ApiExceptionKind.network,
        message: 'No connection',
        code: 'PLT-01-33',
      );
      await stack.hydrate('u1');
      expect(stack.provider.serverHydrated, isFalse);
      expect(stack.provider.isCompleteAuthoritative, isNull);
      final RouteGuard guard = RouteGuard(
        authProvider:
            FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      expect(guard.redirectResolver(RoutePaths.home), isNull,
          reason: 'offline fallback to the cached completion keeps home usable');
      stack.provider.dispose();
    });
  });

  group('RouteGuard (password recovery)', () {
    test('a recovery session is not a sign-in', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.recovery);
      expect(provider.isSignedIn, isFalse);
      expect(provider.isRecoverySession, isTrue);
    });

    test('a recovery session may occupy the public reset door', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.recovery);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver(RoutePaths.resetPassword), isNull);
      expect(
        guard.redirectResolver('${RoutePaths.resetPassword}?code=abc'),
        isNull,
      );
      expect(guard.redirectResolver(RoutePaths.forgotPassword), isNull);
    });

    test('a recovery session with an unverified email is not gated', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.recovery)
        ..sessionOverride = const AuthSession(
          entityId: 'u1',
          email: 'me@example.com',
          isEmailConfirmed: false,
        );
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver(RoutePaths.resetPassword), isNull);
      expect(guard.redirectResolver('/profile'), isNotNull);
    });

    test('a recovery session is confined to the reset door (fail-closed)',
        () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.recovery);
      final guard = RouteGuard(authProvider: provider);
      // Protected destinations never resolve to the reset flow; the guard
      // resolves them to the unauthenticated entry door.
      expect(guard.redirectResolver('/profile'), isNotNull);
      expect(guard.redirectResolver(RoutePaths.home), isNotNull);
      expect(guard.redirectResolver('/onboarding'), isNotNull);
    });
  });
}