import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';

import '../../test_helpers.dart';

void main() {
  group('RouteGuard', () {
    test('unauthenticated user is redirected from protected routes to /login',
        () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/'), '/login');
      expect(guard.redirectResolver('/profile'), '/login');
      expect(guard.redirectResolver('/settings'), '/login');
    });

    test('unauthenticated user may access public auth routes', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/login'), isNull);
      expect(guard.redirectResolver('/signup'), isNull);
      expect(guard.redirectResolver('/forgot-password'), isNull);
      expect(guard.redirectResolver('/reset-password'), isNull);
    });

    test('unauthenticated user may access public content routes', () {
      final provider = FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
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
      expect(guard.redirectResolver('/profile'), '/login');
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
      expect(guard.redirectResolver('/profile'), '/login');
      expect(guard.redirectResolver('/settings'), '/login');
    });

    test('default (production) guard stays fail-closed on onboarding routes',
        () {
      final provider =
          FakeAuthProvider(initialStatus: AuthStatus.unauthenticated);
      final guard = RouteGuard(authProvider: provider);
      expect(guard.redirectResolver('/onboarding'), '/login');
      expect(guard.redirectResolver('/onboarding/profile'), '/login');
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
      expect(guard.redirectResolver('/onboarding'), '/login');
    });
  });
}
