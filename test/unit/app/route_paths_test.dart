import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';

void main() {
  test('route path constants match the approved route table', () {
    expect(RoutePaths.home, '/');
    expect(RoutePaths.login, '/login');
    expect(RoutePaths.signup, '/signup');
    expect(RoutePaths.forgotPassword, '/forgot-password');
    expect(RoutePaths.resetPassword, '/reset-password');
    expect(RoutePaths.profile, '/profile');
    expect(RoutePaths.settings, '/settings');
    expect(RoutePaths.publicProfileRoute, '/p/:slug/:id');
    expect(RoutePaths.publicStoreRoute, '/store/:storeId');
  });

  test('typed publicProfile builder produces a URL-encoded path', () {
    expect(
      RoutePaths.publicProfile(slug: 'electrician', id: 'abc-123'),
      '/p/electrician/abc-123',
    );
    expect(
      RoutePaths.publicProfile(slug: 'a b/c', id: 'x&y'),
      '/p/a%20b%2Fc/x%26y',
    );
  });

  test('typed publicStore builder produces a URL-encoded path', () {
    expect(
      RoutePaths.publicStore(storeId: 'xyz-456'),
      '/store/xyz-456',
    );
    expect(
      RoutePaths.publicStore(storeId: 'a b'),
      '/store/a%20b',
    );
  });

  test('named route constants match the GoRouter route names', () {
    expect(RouteNames.home, 'home');
    expect(RouteNames.login, 'login');
    expect(RouteNames.signup, 'signup');
    expect(RouteNames.forgotPassword, 'forgot-password');
    expect(RouteNames.resetPassword, 'reset-password');
    expect(RouteNames.profile, 'profile');
    expect(RouteNames.settings, 'settings');
    expect(RouteNames.publicProfile, 'public-profile');
    expect(RouteNames.publicStore, 'public-store');
  });
}

