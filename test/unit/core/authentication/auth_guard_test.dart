import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/core/authentication/guards/auth_guard.dart';

void main() {
  group('AuthGuard', () {
    test('allows protected routes when authenticated', () {
      final AuthGuard guard = AuthGuard(isAuthenticated: () => true);
      expect(guard.redirectResolver('/home'), isNull);
      expect(guard.redirectResolver('/dashboard'), isNull);
    });

    test('fails closed: protected route without auth redirects to login', () {
      final AuthGuard guard = AuthGuard(isAuthenticated: () => false);
      expect(guard.redirectResolver('/home'), '/login');
      expect(guard.redirectResolver('/dashboard/settings'), '/login');
    });

    test('public routes bypass the guard even when unauthenticated', () {
      final AuthGuard guard = AuthGuard(isAuthenticated: () => false);
      expect(guard.redirectResolver('/login'), isNull);
      expect(guard.redirectResolver('/signup'), isNull);
      expect(guard.redirectResolver('/forgot-password'), isNull);
      expect(guard.redirectResolver('/auth/callback'), isNull);
    });

    test('requiresAuth matches public prefixes', () {
      final AuthGuard guard = AuthGuard(isAuthenticated: () => false);
      expect(guard.requiresAuth('/login'), isFalse);
      expect(guard.requiresAuth('/home'), isTrue);
    });

    test('custom public prefixes are honored', () {
      final AuthGuard guard = AuthGuard(
        isAuthenticated: () => false,
        publicRoutePrefixes: <String>['/public', '/landing'],
      );
      expect(guard.redirectResolver('/public/about'), isNull);
      expect(guard.redirectResolver('/landing'), isNull);
      expect(guard.redirectResolver('/private'), '/login');
    });
  });
}
