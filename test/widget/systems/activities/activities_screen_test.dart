import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/systems/activities/screens/activities_screen.dart';
import 'package:provider/provider.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  group('ActivitiesScreen (Explore / Earn launcher)', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    Future<OnboardingTestStack> pumpLauncher(
      WidgetTester tester, {
      double width = 390,
    }) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MultiProvider(
          providers: stack.buildProviders(),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: const ActivitiesScreen(),
          ),
        ),
      );
      await tester.pump();
      return stack;
    }

    testWidgets('renders both shelves with all six activities', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpLauncher(tester);
      expect(find.text('Welcome to Hivorr'), findsOneWidget);
      expect(find.text('Explore with Hivorr'), findsOneWidget);
      expect(find.text('Earn with Hivorr'), findsOneWidget);
      for (final String title in <String>[
        'I Want to Buy',
        'I Want to Hire',
        'Explore Services',
        'I Want to Sell',
        'I Want to Offer My Services',
        'I Want to Provide Logistics',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      // Honest coming-soon states never imply a backend exists.
      expect(find.text('Coming soon'), findsNWidgets(3));
      expect(find.text('Continue to dashboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
      stack.provider.dispose();
    });

    testWidgets('coming-soon cards stay in place with an honest notice', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpLauncher(tester);
      final Finder sellCard = find.text('I Want to Sell');
      await tester.scrollUntilVisible(sellCard, 200);
      await tester.pump();
      await tester.tap(sellCard);
      await tester.pump();
      expect(find.textContaining('coming soon'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('renders without overflow across breakpoints', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[320, 390, 600, 1024]) {
        final OnboardingTestStack stack = await pumpLauncher(
          tester,
          width: width,
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at ${width.toInt()}dp',
        );
        stack.provider.dispose();
      }
    });

    testWidgets('live Hire card ensures capability then routes to job posting',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.activities,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.activities,
            builder: (BuildContext context, GoRouterState state) =>
                const ActivitiesScreen(),
          ),
          GoRoute(
            path: RoutePaths.dashboardJobNew,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('JOB-NEW')),
          ),
          GoRoute(
            path: RoutePaths.serviceDiscovery,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('SERVICES')),
          ),
          GoRoute(
            path: RoutePaths.onboardingIndustry,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('ONBOARDING-INDUSTRY')),
          ),
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: stack.buildProviders(),
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('I Want to Hire'));
      await tester.pumpAndSettle();
      expect(find.text('JOB-NEW'), findsOneWidget);
      expect(tester.takeException(), isNull);
      stack.provider.dispose();
    });
  });
}
