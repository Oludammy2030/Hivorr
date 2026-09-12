import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';
import 'package:hivorr/systems/onboarding/screens/onboarding_complete_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';

import '../../../support/fakes/fake_trade_verification.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(OnboardingStepController, OnboardingTestStack)> pumpComplete(
    WidgetTester tester, {
    bool active = true,
    bool dark = false,
    OnboardingTestStack? stack,
    bool approvedGate = false,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    await s.hydrate('u1');
    if (approvedGate) {
      await selectTechnologyProfession(s.taxonomy);
      await s.provider.refreshGateStatus();
    }
    final OnboardingStepController controller = OnboardingStepController();
    await pumpOnboardingScreen(
      tester,
      OnboardingCompleteScreen(active: active, controller: controller),
      path: RoutePaths.onboardingComplete,
      providers: s.buildProviders(),
      dark: dark,
    );
    return (controller, s);
  }

  group('OnboardingCompleteScreen (FV-27, FV-34)', () {
    testWidgets('inactive state renders nothing', (WidgetTester tester) async {
      final (_, OnboardingTestStack stack) =
          await pumpComplete(tester, active: false);
      expect(find.text('You’re registered'), findsNothing);
      expect(find.text('Go to home'), findsNothing);
      stack.provider.dispose();
    });

    testWidgets('active state shows the success state with the 6 done steps',
        (WidgetTester tester) async {
      final (_, OnboardingTestStack stack) = await pumpComplete(tester);
      expect(find.text('You’re registered'), findsOneWidget);
      expect(
        find.text(
          'Your profile is live. You can start work right away — bidding '
          'unlocks once your trade proof is approved.',
        ),
        findsOneWidget,
      );
      expect(find.byType(HivorrSuccessState), findsOneWidget);
      expect(find.text('Your 6 steps'), findsOneWidget);
      for (final String label in <String>[
        'What will you do?',
        'Profile',
        'Industry',
        'Profession',
        'Identity',
        'Trade proof',
      ]) {
        expect(find.text(label), findsAtLeastNWidgets(1),
            reason: '$label renders as a done step card');
      }
      expect(find.byIcon(Icons.check_circle), findsNWidgets(6),
          reason: 'every step card is marked done');
      stack.provider.dispose();
    });

    testWidgets('hides the shell primary CTA', (WidgetTester tester) async {
      final (OnboardingStepController controller, OnboardingTestStack stack) =
          await pumpComplete(tester);
      expect(controller.primaryLabel, isEmpty);
      stack.provider.dispose();
    });

    testWidgets('"Go to home" routes home', (WidgetTester tester) async {
      final (_, OnboardingTestStack stack) = await pumpComplete(tester);
      await tester.tap(find.text('Go to home'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('uses RouteNames.home for the escape (route contract)',
        (WidgetTester tester) async {
      expect(RouteNames.home, 'home');
      final (_, OnboardingTestStack stack) = await pumpComplete(tester);
      expect(find.text('Go to home'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('locked gate renders the Rule 2 education copy + next actions',
        (WidgetTester tester) async {
      final (_, OnboardingTestStack stack) = await pumpComplete(tester);
      expect(
        find.text(
          'You can start work immediately — bidding unlocks once your trade '
          'proof is approved.',
        ),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Trust loop'), findsOneWidget);
      expect(find.text('View verification status'), findsOneWidget);
      expect(find.text('Financial profile'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('approved gate renders the unlocked trust-loop copy',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack(
        tradeRepo: FakeTradeVerificationRepository(
          status: tradeStatusEntity(
            statuses: const <String, String>{'prof-sw': 'approved'},
          ),
        ),
      );
      final (_, OnboardingTestStack stack) =
          await pumpComplete(tester, approvedGate: true, stack: s);
      expect(stack.provider.isTradeGateOpen, isTrue);
      expect(
        find.text('Approved — you can place bids right away.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'You can start work immediately — bidding unlocks once your trade '
          'proof is approved.',
        ),
        findsNothing,
      );
      stack.provider.dispose();
    });

    testWidgets('dark theme builds without exceptions', (WidgetTester tester) async {
      final (_, OnboardingTestStack stack) =
          await pumpComplete(tester, dark: true);
      expect(tester.takeException(), isNull);
      expect(find.text('You’re registered'), findsOneWidget);
      stack.provider.dispose();
    });
  });
}