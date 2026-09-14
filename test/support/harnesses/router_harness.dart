import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/auth/screens/auth_confirmation_gate_screen.dart';
import 'package:hivorr/app/auth/screens/forgot_password_screen.dart';
import 'package:hivorr/app/auth/screens/login_screen.dart';
import 'package:hivorr/app/auth/screens/register_screen.dart';
import 'package:hivorr/app/auth/screens/reset_password_screen.dart';
import 'package:hivorr/app/entry/screens/welcome_screen.dart';
import 'package:hivorr/app/public/screens/about_screen.dart';
import 'package:hivorr/app/public/screens/contact_screen.dart';
import 'package:hivorr/app/public/screens/features_screen.dart';
import 'package:hivorr/app/public/screens/help_screen.dart';
import 'package:hivorr/app/public/screens/how_it_works_screen.dart';
import 'package:hivorr/app/public/screens/pricing_screen.dart';
import 'package:hivorr/app/public/screens/security_screen.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';

/// Builds a [GoRouter] hosting the public Website and auth door screens so
/// widget tests can drive real navigation ([PublicNavBar], footer, auth forms)
/// and assert the resulting [GoRouterState] (e.g. preserved `?next=`).
///
/// The router registers the real screens under their [RouteNames]; destinations
/// outside the doors resolve to a labelled placeholder scaffld.
GoRouter doorRouter({String initialLocation = RoutePaths.welcome}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: _placeholder('Home'),
      ),
      GoRoute(
        path: RoutePaths.welcome,
        name: RouteNames.welcome,
        builder: (BuildContext context, GoRouterState state) =>
            const WelcomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.about,
        name: RouteNames.about,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutScreen(),
      ),
      GoRoute(
        path: RoutePaths.howItWorks,
        name: RouteNames.howItWorks,
        builder: (BuildContext context, GoRouterState state) =>
            const HowItWorksScreen(),
      ),
      GoRoute(
        path: RoutePaths.features,
        name: RouteNames.features,
        builder: (BuildContext context, GoRouterState state) =>
            const FeaturesScreen(),
      ),
      GoRoute(
        path: RoutePaths.pricing,
        name: RouteNames.pricing,
        builder: (BuildContext context, GoRouterState state) =>
            const PricingScreen(),
      ),
      GoRoute(
        path: RoutePaths.security,
        name: RouteNames.security,
        builder: (BuildContext context, GoRouterState state) =>
            const SecurityScreen(),
      ),
      GoRoute(
        path: RoutePaths.contact,
        name: RouteNames.contact,
        builder: (BuildContext context, GoRouterState state) =>
            const ContactScreen(),
      ),
      GoRoute(
        path: RoutePaths.help,
        name: RouteNames.help,
        builder: (BuildContext context, GoRouterState state) =>
            const HelpScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signup,
        name: RouteNames.signup,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.authConfirmation,
        name: RouteNames.authConfirmation,
        builder: (BuildContext context, GoRouterState state) =>
            AuthConfirmationGateScreen(
          email: state.uri.queryParameters['email'],
          next: state.uri.queryParameters['next'],
          mode: state.uri.queryParameters['mode'],
        ),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        name: RouteNames.resetPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ResetPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.publicProfileRoute,
        name: RouteNames.publicProfile,
        builder: _placeholder('Public profile'),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Widget Function(BuildContext, GoRouterState) _placeholder(String title) =>
    (BuildContext context, GoRouterState state) => Scaffold(
          body: Center(child: Text(title)),
        );