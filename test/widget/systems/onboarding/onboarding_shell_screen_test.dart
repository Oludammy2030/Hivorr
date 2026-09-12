import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/onboarding/screens/onboarding_shell_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_progress_indicator.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OnboardingTestStack> pumpShell(
    WidgetTester tester, {
    OnboardingTestStack? stack,
    int advances = 0,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    await s.hydrate('u1');
    for (int i = 0; i < advances; i++) {
      await s.provider.advance();
    }
    await pumpOnboardingScreen(
      tester,
      const OnboardingShellScreen(),
      path: '/onboarding/profile',
      providers: s.buildProviders(),
    );
    await tester.pump();
    return s;
  }

  group('OnboardingShellScreen (FV-28)', () {
    testWidgets('shows the app bar, progress tracker, and bottom bar',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester);
      expect(find.text('Registration'), findsOneWidget);
      expect(find.byType(OnboardingProgressIndicator), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(
        find.text('Wizard progress is saved automatically.'),
        findsNothing,
        reason: 'profile step configures the primary CTA',
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('profile step shows the disabled Save & continue CTA',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester);
      expect(find.text('Save & continue'), findsOneWidget);
      final HivorrButton button = tester.widget<HivorrButton>(
        find.widgetWithText(HivorrButton, 'Save & continue'),
      );
      expect(button.onPressed, isNull, reason: 'names not yet provided');
      stack.provider.dispose();
    });

    testWidgets('back opens the exit dialog; Stay keeps the wizard',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Save my progress and exit?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.text('Save my progress and exit?'), findsNothing);
      expect(find.text('Registration'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('Save & exit persists progress and routes home',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 2);
      expect(stack.provider.progress!.step, OnboardingStepCode.industry);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & exit'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(stack.provider.progress!.step, OnboardingStepCode.industry,
          reason: 'exit saves the current position without moving');
      stack.provider.dispose();
    });

    testWidgets('industry step shows the disabled Save & continue CTA',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 2);
      expect(find.text('Save & continue'), findsOneWidget);
      final HivorrButton button = tester.widget<HivorrButton>(
        find.widgetWithText(HivorrButton, 'Save & continue'),
      );
      expect(button.onPressed, isNull, reason: 'no industry selected yet');
      expect(find.bySemanticsLabel('Step 3 of 5'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('a trade-proof step without a bound profession falls back',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 4);
      expect(stack.provider.currentStep, OnboardingStepCode.tradeProof);
      // taxonomy selection was never made in this stack.
      expect(find.text('Which industry best describes you?'), findsOneWidget,
          reason: 'defensive index 2 renders the combined selection step');
      stack.provider.dispose();
    });

    testWidgets('complete state renders success + no back affordance',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 5);
      expect(stack.provider.isComplete, isTrue);
      expect(find.text('You’re registered'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Back'), findsNothing);
      expect(find.text('Save & continue'), findsNothing);
      stack.provider.dispose();
    });

    testWidgets('system back on the terminal step routes home',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 5);
      final bool popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('ProgressIndicator reflects the active step via the provider',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 2);
      expect(find.bySemanticsLabel('Step 3 of 5'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('dark theme builds without exceptions',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack();
      await s.hydrate('u1');
      await pumpOnboardingScreen(
        tester,
        const OnboardingShellScreen(),
        path: '/onboarding/profile',
        providers: s.buildProviders(),
        dark: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Registration'), findsOneWidget);
      s.provider.dispose();
    });
  });
}