import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/public/widgets/public_nav_bar.dart';
import 'package:hivorr/app/public/widgets/public_page_scaffold.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_auth.dart';
import '../../../support/harnesses/router_harness.dart';
import '../../../support/harnesses/widget_harness.dart';

/// The single vertical body list under the public chrome (the horizontal nav
/// scroll and any nested lists are excluded).
Finder bodyScroll() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> pumpWelcome(
  WidgetTester tester,
  GoRouter router, {
  double width = 1280,
  double height = 800,
}) async {
  await pumpScreen(
    tester,
    MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AuthProvider>.value(value: FakeAuthProvider()),
    ],
    width: width,
    height: height,
  );
}

void main() {
  group('WelcomeScreen (web landing)', () {
    testWidgets('renders the brand lockup, hero and sectioned content', (
      tester,
    ) async {
      await pumpWelcome(tester, doorRouter(initialLocation: '/welcome'));

      expect(find.byType(PublicPageScaffold), findsOneWidget);
      expect(find.byType(PublicNavBar), findsOneWidget);
      expect(find.byType(LogoHorizontal), findsOneWidget);
      expect(
        find.text('Run your whole life on one operating system.'),
        findsOneWidget,
      );
      expect(find.text('I already have an account — sign in'), findsOneWidget);
      expect(find.text('Create your free account'), findsWidgets);
      expect(
        find.text('Trust is the foundation, not a feature'),
        findsOneWidget,
      );
    });

    testWidgets('primary CTA navigates to /signup preserving ?next', (
      tester,
    ) async {
      final GoRouter router = doorRouter(
        initialLocation: '/welcome?next=/p/acme/1',
      );
      await pumpWelcome(tester, router);

      await tester.tap(find.text('Create your free account').first);
      await tester.pumpAndSettle();

      final GoRouterState state = router.routerDelegate.state;
      expect(state.matchedLocation, '/signup');
      expect(state.uri.queryParameters['next'], '/p/acme/1');
    });

    testWidgets('sign-in CTA navigates to /login when no ?next is present', (
      tester,
    ) async {
      final GoRouter router = doorRouter(initialLocation: '/welcome');
      await pumpWelcome(tester, router);

      await tester.tap(find.text('I already have an account — sign in'));
      await tester.pumpAndSettle();

      final GoRouterState state = router.routerDelegate.state;
      expect(state.matchedLocation, '/login');
      expect(state.uri.queryParameters.containsKey('next'), isFalse);
    });

    testWidgets('closing band drives back to registration with ?next intact', (
      tester,
    ) async {
      final GoRouter router = doorRouter(
        initialLocation: '/welcome?next=/p/acme/1',
      );
      await pumpWelcome(tester, router);

      await tester.scrollUntilVisible(
        find.text('One account. Every role your life needs.'),
        400,
        scrollable: bodyScroll(),
      );
      await tester.ensureVisible(find.text('Create your free account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create your free account').last);
      await tester.pumpAndSettle();

      final GoRouterState state = router.routerDelegate.state;
      expect(state.matchedLocation, '/signup');
      expect(state.uri.queryParameters['next'], '/p/acme/1');
    });

    testWidgets('how-it-works teaser links to the full public page', (
      tester,
    ) async {
      final GoRouter router = doorRouter(initialLocation: '/welcome');
      await pumpWelcome(tester, router);

      await tester.scrollUntilVisible(
        find.text('Learn how it works'),
        400,
        scrollable: bodyScroll(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learn how it works'));
      await tester.pumpAndSettle();

      expect(router.routerDelegate.state.matchedLocation, '/how-it-works');
    });
  });
}
