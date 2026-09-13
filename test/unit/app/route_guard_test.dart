import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/entry/entry_state_provider.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/local/entry_state_store.dart';

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
}