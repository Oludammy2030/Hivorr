import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/home/home_screen.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_admin_review.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

class _HangingAdminReviewRepository extends FakeAdminReviewRepository {
  _HangingAdminReviewRepository() : super(isAdmin: true);

  @override
  Future<bool> checkAdmin() {
    checkAdminCallCount++;
    return Completer<bool>().future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen (exit-and-continue gate, B1)', () {
    testWidgets('offers Continue registration after a deliberate exit', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      // Offer focus: the decision advances to industry, still incomplete.
      await stack.provider.selectCapability(EntityCapability.offer);
      await stack.provider.exitWizard();
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: stack.buildProviders(),
      );
      expect(find.text('Continue registration'), findsOneWidget);

      await tester.tap(find.text('Continue registration'));
      await tester.pumpAndSettle();
      expect(
        stack.provider.exited,
        isFalse,
        reason: 'continue clears the exit flag so the guard resumes',
      );
      expect(
        find.text('ONBOARDING-INDUSTRY'),
        findsOneWidget,
        reason: 'registration resumes at the saved step',
      );
      stack.provider.dispose();
    });

    testWidgets('fresh session forwards to the dashboard', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: stack.buildProviders(),
      );
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Continue registration'), findsNothing);
      expect(find.text('Welcome to Hivorr'), findsNothing);
      stack.provider.dispose();
    });

    testWidgets('an auto-resuming wizard forwards to the dashboard', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: stack.buildProviders(),
      );
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(
        find.text('Continue registration'),
        findsNothing,
        reason: 'the guard force-resumes; the card is only for explicit exits',
      );
      stack.provider.dispose();
    });

    testWidgets('a completed wizard forwards to the dashboard', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      for (int i = 0; i < OnboardingStepCode.values.length; i++) {
        await stack.provider.advance();
      }
      expect(stack.provider.isComplete, isTrue);
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: stack.buildProviders(),
      );
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Continue registration'), findsNothing);
      stack.provider.dispose();
    });
  });

  group('HomeScreen legacy gateway removed', () {
    Future<void> pumpHomeAsAdmin(
      WidgetTester tester, {
      required bool isAdmin,
    }) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      addTearDown(stack.provider.dispose);
      final AdminReviewProvider provider = AdminReviewProvider(
        repo: FakeAdminReviewRepository(isAdmin: isAdmin),
      );
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: <SingleChildWidget>[
          ...stack.buildProviders(),
          ChangeNotifierProvider<AdminReviewProvider>.value(value: provider),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('forwards non-admins to the dashboard (gateway removed)', (
      WidgetTester tester,
    ) async {
      await pumpHomeAsAdmin(tester, isAdmin: false);
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Super Admin Dashboard'), findsNothing);
      expect(find.text('Verification & Approvals'), findsNothing);
      expect(find.text('Manage users'), findsNothing);
    });

    testWidgets('forwards platform admins to the dashboard (gateway removed)', (
      WidgetTester tester,
    ) async {
      await pumpHomeAsAdmin(tester, isAdmin: true);
      // Incomplete wizard: Home forwards to the dashboard so RouteGuard can
      // resume onboarding. Admin landing applies once the wizard is complete.
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('Super Admin Dashboard'), findsNothing);
      expect(find.text('Verification & Approvals'), findsNothing);
      expect(find.text('Manage users'), findsNothing);
    });
  });

  group('HomeScreen super-admin landing (completed wizard)', () {
    List<RouteBase> adminRoutes() => <RouteBase>[
      GoRoute(
        path: RoutePaths.adminDashboard,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingMarkerScreen(label: 'ADMIN-DASHBOARD'),
      ),
    ];

    Future<OnboardingTestStack> completedStack() async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      for (int i = 0; i < OnboardingStepCode.values.length; i++) {
        await stack.provider.advance();
      }
      expect(stack.provider.isComplete, isTrue);
      addTearDown(stack.provider.dispose);
      return stack;
    }

    testWidgets('completed super-admin lands on admin dashboard', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await completedStack();
      final AdminReviewProvider admin = AdminReviewProvider(
        repo: FakeAdminReviewRepository(isAdmin: true),
      );
      await admin.checkAdmin();
      addTearDown(admin.dispose);
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: <SingleChildWidget>[
          ...stack.buildProviders(),
          ChangeNotifierProvider<AdminReviewProvider>.value(value: admin),
        ],
        routes: adminRoutes(),
      );
      await tester.pumpAndSettle();
      expect(find.text('ADMIN-DASHBOARD'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
    });

    testWidgets('completed non-admin lands on dashboard', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await completedStack();
      final AdminReviewProvider admin = AdminReviewProvider(
        repo: FakeAdminReviewRepository(isAdmin: false),
      );
      await admin.checkAdmin();
      addTearDown(admin.dispose);
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: <SingleChildWidget>[
          ...stack.buildProviders(),
          ChangeNotifierProvider<AdminReviewProvider>.value(value: admin),
        ],
        routes: adminRoutes(),
      );
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('ADMIN-DASHBOARD'), findsNothing);
    });

    testWidgets('pending admin check holds on loading, never flashes dashboard', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await completedStack();
      // Hanging repo: checkAdmin never completes, so isAdmin stays null
      // even though HomeScreen auto-triggers checkAdmin() in initState.
      final AdminReviewProvider admin = AdminReviewProvider(
        repo: _HangingAdminReviewRepository(),
      );
      addTearDown(admin.dispose);
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: <SingleChildWidget>[
          ...stack.buildProviders(),
          ChangeNotifierProvider<AdminReviewProvider>.value(value: admin),
        ],
        routes: adminRoutes(),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text('ADMIN-DASHBOARD'), findsNothing);
    });
  });
}
