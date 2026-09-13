import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/auth/screens/login_screen.dart';
import 'package:hivorr/app/auth/screens/register_screen.dart';
import 'package:hivorr/app/public/screens/about_screen.dart';
import 'package:hivorr/app/public/screens/contact_screen.dart';
import 'package:hivorr/app/public/screens/features_screen.dart';
import 'package:hivorr/app/public/screens/help_screen.dart';
import 'package:hivorr/app/public/screens/how_it_works_screen.dart';
import 'package:hivorr/app/public/screens/pricing_screen.dart';
import 'package:hivorr/app/public/screens/security_screen.dart';
import 'package:hivorr/app/public/widgets/public_nav_bar.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_auth.dart';
import '../../../support/harnesses/router_harness.dart';
import '../../../support/harnesses/widget_harness.dart';

/// The single vertical body list under the public chrome (the horizontal nav
/// scroll and any nested lists are excluded).
Finder bodyScroll() =>
    find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

/// Scopes a [text] lookup to a screen type so nav/footer duplicates don't
/// match.
Finder textIn(Type screen, String text) => find.descendant(
      of: find.byType(screen),
      matching: find.text(text),
    );

Future<void> pumpPublic(
  WidgetTester tester,
  MaterialApp app, {
  double width = 1280,
  double height = 800,
}) async {
  await pumpScreen(
    tester,
    app,
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AuthProvider>.value(
        value: FakeAuthProvider(),
      ),
    ],
    width: width,
    height: height,
  );
}

/// Hosts the nav on its own route so tests exercise the widget under test
/// without the landing page's (intentionally long) content.
GoRouter navRouter() {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: PublicNavBar()),
      ),
      GoRoute(
        path: '/help',
        name: RouteNames.help,
        builder: (BuildContext context, GoRouterState state) =>
            const HelpScreen(),
      ),
      GoRoute(
        path: '/how-it-works',
        name: RouteNames.howItWorks,
        builder: (BuildContext context, GoRouterState state) =>
            const HowItWorksScreen(),
      ),
      GoRoute(
        path: '/pricing',
        name: RouteNames.pricing,
        builder: (BuildContext context, GoRouterState state) =>
            const PricingScreen(),
      ),
      GoRoute(
        path: '/about',
        name: RouteNames.about,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutScreen(),
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
    ],
  );
  addTearDown(router.dispose);
  return router;
}

void main() {
  group('PublicNavBar', () {
    testWidgets('desktop shows the site navigation and auth CTAs',
        (tester) async {
      final GoRouter router = navRouter();
      await pumpPublic(
        tester,
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        width: 1280,
      );

      final Finder inNav = find.descendant(
        of: find.byType(PublicNavBar),
        matching: find.byType(TextButton),
      );
      expect(inNav, findsWidgets);
      for (final String label in <String>[
        'How it works',
        'Features',
        'Pricing',
        'Security',
        'Contact',
        'Help',
        'Sign in',
      ]) {
        expect(
          find.descendant(
            of: find.byType(PublicNavBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '$label not found in the desktop nav',
        );
      }
      expect(
        find.descendant(
          of: find.byType(PublicNavBar),
          matching: find.text('Get started'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.menu), findsNothing);
    });

    testWidgets('mobile collapses the site links behind a menu', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: navRouter(),
        ),
        width: 390,
      );

      final Finder inNav = find.descendant(
        of: find.byType(PublicNavBar),
        matching: find.byType(TextButton),
      );
      expect(find.text('Pricing'), findsNothing);
      expect(inNav, findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('menu navigation resolves the tapped destination',
        (tester) async {
      final GoRouter router = navRouter();
      await pumpPublic(
        tester,
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        width: 390,
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/help');
    });

    testWidgets('Get started routes to the sign-up door', (tester) async {
      final GoRouter router = navRouter();
      await pumpPublic(
        tester,
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        width: 1280,
      );

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/signup');
    });

    testWidgets('desktop link navigates to the public page', (tester) async {
      final GoRouter router = navRouter();
      await pumpPublic(
        tester,
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        width: 1280,
      );

      await tester.tap(find.widgetWithText(TextButton, 'How it works'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/how-it-works');
    });
  });

  group('PublicFooter', () {
    testWidgets('renders the columns and entity statement', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/welcome'),
        ),
        width: 1280,
      );

      await tester.scrollUntilVisible(
        find.text('© Hivorr · AfriNova Digital Limited'),
        400,
        scrollable: bodyScroll(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Company'), findsOneWidget);
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Get started'), findsWidgets);
      expect(
        find.text('© Hivorr · AfriNova Digital Limited'),
        findsOneWidget,
      );
    });

    testWidgets('footer link navigates to its destination', (tester) async {
      final GoRouter router = doorRouter(initialLocation: '/welcome');
      await pumpPublic(
        tester,
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        width: 1280,
      );

      await tester.scrollUntilVisible(
        find.text('About'),
        400,
        scrollable: bodyScroll(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/about');
    });
  });

  group('Public information pages', () {
    testWidgets('About is a self-contained public page', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/about'),
        ),
      );

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.byType(PublicPageScaffold), findsOneWidget);
      expect(textIn(AboutScreen, 'About Hivorr'), findsOneWidget);
      expect(
        textIn(AboutScreen, 'The Universal Entity Principle'),
        findsOneWidget,
      );
    });

    testWidgets('How it works explains the one-account journey', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/how-it-works'),
        ),
      );

      expect(find.byType(HowItWorksScreen), findsOneWidget);
      expect(textIn(HowItWorksScreen, 'How it works'), findsWidgets);
      expect(
        find.text('Get operating in three steps'),
        findsOneWidget,
      );
      expect(
        find.text('The trust flywheel'),
        findsOneWidget,
      );
      expect(
        textIn(HowItWorksScreen, 'Create your free account'),
        findsOneWidget,
      );
    });

    testWidgets('Features maps the capability set', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/features'),
        ),
      );

      expect(find.byType(FeaturesScreen), findsOneWidget);
      expect(textIn(FeaturesScreen, 'Every role, one account'), findsOneWidget);
      expect(
        textIn(FeaturesScreen, 'Escrow-protected payments'),
        findsOneWidget,
      );
      expect(
        textIn(FeaturesScreen, 'AI-assisted operations'),
        findsOneWidget,
      );
    });

    testWidgets('Pricing stays honest about structure', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/pricing'),
        ),
      );

      expect(find.byType(PricingScreen), findsOneWidget);
      expect(textIn(PricingScreen, 'Always free to start'), findsOneWidget);
      expect(textIn(PricingScreen, 'Pay when value moves'), findsOneWidget);
      expect(find.text('No hidden charges.'), findsNothing);
    });

    testWidgets('Security describes the trust architecture', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/security'),
        ),
      );

      expect(find.byType(SecurityScreen), findsOneWidget);
      expect(textIn(SecurityScreen, 'Security & trust'), findsOneWidget);
      expect(
        textIn(SecurityScreen, 'Trade verification gates'),
        findsOneWidget,
      );
    });

    testWidgets('Contact routes through honest channels', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/contact'),
        ),
      );

      expect(find.byType(ContactScreen), findsOneWidget);
      expect(find.text('Contact'), findsWidgets);
      expect(textIn(ContactScreen, 'Help center'), findsOneWidget);
      expect(textIn(ContactScreen, 'Open the Help center'), findsOneWidget);
      expect(textIn(ContactScreen, 'See our trust model'), findsOneWidget);
      expect(
        textIn(ContactScreen, 'Create your free account'),
        findsOneWidget,
      );
    });

    testWidgets('Help hub points visitors to the next step', (tester) async {
      await pumpPublic(
        tester,
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: doorRouter(initialLocation: '/help'),
        ),
      );

      expect(find.byType(HelpScreen), findsOneWidget);
      expect(textIn(HelpScreen, 'Help center'), findsOneWidget);
      expect(textIn(HelpScreen, 'Getting started'), findsOneWidget);
      expect(textIn(HelpScreen, 'Still stuck?'), findsOneWidget);
    });
  });
}