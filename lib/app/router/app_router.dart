import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';

/// Builds the application [GoRouter] with the full route tree.
///
/// Route protection is delegated to [RouteGuard] (which wraps the EP-01-09
/// [AuthGuard]). [refreshListenable] is bound to [AuthProvider] so route
/// re-evaluation fires on every auth-state change.
class AppRouter {
  const AppRouter._();

  static GoRouter create({required AuthProvider authProvider}) {
    final RouteGuard routeGuard = RouteGuard(authProvider: authProvider);

    return GoRouter(
      initialLocation: RoutePaths.home,
      refreshListenable: authProvider,
      redirect: (BuildContext context, GoRouterState state) =>
          routeGuard.redirectResolver(state.matchedLocation),
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Home'),
        ),
        GoRoute(
          path: RoutePaths.login,
          name: RouteNames.login,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Login'),
        ),
        GoRoute(
          path: RoutePaths.signup,
          name: RouteNames.signup,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Sign Up'),
        ),
        GoRoute(
          path: RoutePaths.forgotPassword,
          name: RouteNames.forgotPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Forgot Password'),
        ),
        GoRoute(
          path: RoutePaths.resetPassword,
          name: RouteNames.resetPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Reset Password'),
        ),
        GoRoute(
          path: RoutePaths.profile,
          name: RouteNames.profile,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Profile'),
        ),
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const PlaceholderScreen(title: 'Settings'),
        ),
        GoRoute(
          path: RoutePaths.publicProfileRoute,
          name: RouteNames.publicProfile,
          builder: (BuildContext context, GoRouterState state) =>
              PlaceholderScreen(
                title: 'Public Profile — ${state.pathParameters['slug'] ?? ''}'
                    '/${state.pathParameters['id'] ?? ''}',
              ),
        ),
        GoRoute(
          path: RoutePaths.publicStoreRoute,
          name: RouteNames.publicStore,
          builder: (BuildContext context, GoRouterState state) =>
              PlaceholderScreen(
                title: 'Store — ${state.pathParameters['storeId'] ?? ''}',
              ),
        ),
      ],
    );
  }
}

/// Minimal route-target placeholder.
///
/// Stub only — EP-02+ replaces these with real feature screens. Must not
/// contain business logic (EP-01-15 §3).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
