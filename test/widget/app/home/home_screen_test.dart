import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/home/home_screen.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_admin_review.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen (exit-and-continue gate, B1)', () {
    testWidgets('offers Continue registration after a deliberate exit', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
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

    testWidgets('fresh session shows the plain home state', (
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
      expect(find.text('Continue registration'), findsNothing);
      expect(find.text('Welcome to Hivorr'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('an auto-resuming wizard gets no Continue card', (
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
      expect(
        find.text('Continue registration'),
        findsNothing,
        reason: 'the guard force-resumes; the card is only for explicit exits',
      );
      stack.provider.dispose();
    });

    testWidgets('a completed wizard gets no Continue card', (
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
      expect(find.text('Welcome to Hivorr'), findsOneWidget);
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

    testWidgets('shows only Welcome for non-admins (gateway removed)', (
      WidgetTester tester,
    ) async {
      await pumpHomeAsAdmin(tester, isAdmin: false);
      expect(find.text('Welcome to Hivorr'), findsOneWidget);
      expect(find.text('Super Admin Dashboard'), findsNothing);
      expect(find.text('Verification & Approvals'), findsNothing);
      expect(find.text('Manage users'), findsNothing);
    });

    testWidgets('shows only Welcome for platform admins (gateway removed)', (
      WidgetTester tester,
    ) async {
      await pumpHomeAsAdmin(tester, isAdmin: true);
      // Legacy gateway buttons have been removed; admin is redirected
      // by RouteGuard to /admin/dashboard instead of via Home.
      expect(find.text('Welcome to Hivorr'), findsOneWidget);
      expect(find.text('Super Admin Dashboard'), findsNothing);
      expect(find.text('Verification & Approvals'), findsNothing);
      expect(find.text('Manage users'), findsNothing);
    });
  });
}
