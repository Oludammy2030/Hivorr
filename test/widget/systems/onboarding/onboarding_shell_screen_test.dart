import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/screens/onboarding_shell_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_progress_indicator.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OnboardingTestStack> pumpShell(
    WidgetTester tester, {
    OnboardingTestStack? stack,
    int advances = 1,
    String? path,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    await s.hydrate('u1');
    if (advances > 0) {
      // The launcher owns the focus decision; selecting offer starts the
      // professional path at industry, so `advances: 1` is the first wizard
      // step (identity is 2, trade 3, complete 4).
      await s.provider.selectCapability(EntityCapability.offer);
      for (int i = 1; i < advances; i++) {
        await s.provider.advance();
      }
    }
    // The single `/onboarding/:step` route means the URL stays aligned with the
    // provider step; pump at the canonical location unless a test explicitly
    // injects a stale path or a checklist deep link.
    final String canonical =
        path ??
        (s.provider.isComplete
            ? RoutePaths.onboardingComplete
            : RoutePaths.onboardingRouteFor(
                s.provider.currentStep ?? OnboardingStepCode.capability,
              ));
    await pumpOnboardingScreen(
      tester,
      const OnboardingShellScreen(),
      path: canonical,
      providers: s.buildProviders(),
    );
    await tester.pump();
    return s;
  }

  group('OnboardingShellScreen (FV-28)', () {
    testWidgets('shows the app bar, progress tracker, and bottom bar', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(tester);
      expect(find.text('Registration'), findsOneWidget);
      expect(find.byType(OnboardingProgressIndicator), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Save & continue'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets(
      'a saved capability position redirects to the launcher, never rendering '
      'an account-intent screen',
      (WidgetTester tester) async {
        final OnboardingTestStack stack = await pumpShell(
          tester,
          advances: 0,
          path: RoutePaths.onboardingCapability,
        );
        await tester.pumpAndSettle();
        expect(find.text('ACTIVITIES'), findsOneWidget);
        expect(find.text('What will you do on Hivorr?'), findsNothing);
        expect(find.text('Registration'), findsNothing);
        stack.provider.dispose();
      },
    );

    testWidgets('back on the first wizard step opens the exit dialog', (
      WidgetTester tester,
    ) async {
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

    testWidgets(
      'Save & exit persists progress, marks exited, and routes home',
      (WidgetTester tester) async {
        final OnboardingTestStack stack = await pumpShell(tester);
        expect(stack.provider.progress!.step, OnboardingStepCode.industry);
        await tester.tap(find.text('Exit'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save & exit'));
        await tester.pumpAndSettle();
        expect(find.text('HOME'), findsOneWidget);
        expect(
          stack.provider.progress!.step,
          OnboardingStepCode.industry,
          reason: 'exit saves the current position without moving',
        );
        expect(
          stack.provider.exited,
          isTrue,
          reason: 'an explicit exit must not be force-resumed by the guard',
        );
        stack.provider.dispose();
      },
    );

    testWidgets('industry step shows the disabled Save & continue CTA', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(tester);
      expect(find.text('Save & continue'), findsOneWidget);
      final HivorrButton button = tester.widget<HivorrButton>(
        find.widgetWithText(HivorrButton, 'Save & continue'),
      );
      expect(button.onPressed, isNull, reason: 'no industry selected yet');
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('a trade-proof step without a bound profession falls back', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 3);
      expect(stack.provider.currentStep, OnboardingStepCode.tradeProof);
      // taxonomy selection was never made in this stack.
      expect(
        find.text('Which industry best describes you?'),
        findsOneWidget,
        reason: 'defensive index 0 renders the combined selection step',
      );
      stack.provider.dispose();
    });

    testWidgets('complete state renders success + no back affordance', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 4);
      expect(stack.provider.isComplete, isTrue);
      expect(find.text('You’re registered'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Back'), findsNothing);
      expect(find.text('Save & continue'), findsNothing);
      stack.provider.dispose();
    });

    testWidgets('system back on the terminal step routes home', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(tester, advances: 4);
      final bool popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('ProgressIndicator reflects the active step via the provider', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(tester);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets(
      'identity deep link opens the identity interface directly, not industry',
      (WidgetTester tester) async {
        final OnboardingTestStack stack = await pumpShell(
          tester,
          advances: 1,
          path: RoutePaths.onboardingIdentity,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Verify your identity with a government-issued document.'),
          findsOneWidget,
        );
        expect(find.text('Which industry best describes you?'), findsNothing);
        expect(stack.provider.currentStep, OnboardingStepCode.identityDocument);
        expect(stack.provider.progress!.completedSteps, <OnboardingStepCode>[
          OnboardingStepCode.capability,
        ], reason: 'opening a deep link never marks the skipped step complete');
        stack.provider.dispose();
      },
    );

    testWidgets(
      'trade-proof deep link opens the proof interface with the bound profession',
      (WidgetTester tester) async {
        final OnboardingTestStack stack = await pumpShell(
          tester,
          advances: 2,
          path:
              '${RoutePaths.onboardingTradeProof}'
              '?professionId=prof-sw&professionLabel=Software%20Engineer',
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Proof of your trade unlocks bidding. Choose a proof type, then '
            'upload a clear photo or PDF.',
          ),
          findsOneWidget,
        );
        expect(find.text('Software Engineer'), findsOneWidget);
        expect(find.text('Which industry best describes you?'), findsNothing);
        expect(stack.provider.currentStep, OnboardingStepCode.tradeProof);
        stack.provider.dispose();
      },
    );

    testWidgets('checklist deep link returns to requirements on Back', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpShell(
        tester,
        advances: 1,
        path: '${RoutePaths.onboardingIdentity}?from=requirements',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Verify your identity with a government-issued document.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('PROFESSIONAL-REQUIREMENTS'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('dark theme builds without exceptions', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack s = buildOnboardingStack();
      await s.hydrate('u1');
      await s.provider.selectCapability(EntityCapability.offer);
      await pumpOnboardingScreen(
        tester,
        const OnboardingShellScreen(),
        path: RoutePaths.onboardingIndustry,
        providers: s.buildProviders(),
        dark: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Registration'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
      s.provider.dispose();
    });

    testWidgets('a stale /onboarding URL is re-aligned to the provider step', (
      WidgetTester tester,
    ) async {
      // Simulates a cold/deep link that bookmarks an outdated step while the
      // saved wizard sits further along.
      final OnboardingTestStack stack = await pumpShell(
        tester,
        path: RoutePaths.onboardingCapability,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('ONBOARDING-INDUSTRY'),
        findsOneWidget,
        reason: 'the shell realigns the URL to the resumed step',
      );
      stack.provider.dispose();
    });
  });
}
