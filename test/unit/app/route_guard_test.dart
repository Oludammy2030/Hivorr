import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_guard.dart';
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
}
