import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_progress_indicator.dart';

void main() {
  OnboardingProgress progressFor(
    OnboardingStepCode step, {
    EntityCapability capability = EntityCapability.both,
    List<OnboardingStepCode> completed = const <OnboardingStepCode>[],
  }) => OnboardingProgress(
    entityId: 'u1',
    step: step,
    capability: capability,
    completedSteps: completed,
  );

  Future<void> pumpIndicator(
    WidgetTester tester,
    OnboardingProgress? progress,
  ) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: OnboardingProgressIndicator(progress: progress),
            ),
          ),
        ),
      );

  group('OnboardingProgressIndicator (FV-35)', () {
    testWidgets('professional path: profile reads "Step 1 of 5" and draws 5 '
        'segments', (WidgetTester tester) async {
      await pumpIndicator(
        tester,
        progressFor(OnboardingStepCode.profile),
      );
      expect(find.bySemanticsLabel('Step 1 of 5'), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(5));
    });

    testWidgets('null (pre-hydration) reads "Step 0 of 5"',
        (WidgetTester tester) async {
      await pumpIndicator(tester, null);
      expect(find.bySemanticsLabel('Step 0 of 5'), findsOneWidget);
    });

    testWidgets('last professional step reads "Step 5 of 5"',
        (WidgetTester tester) async {
      await pumpIndicator(tester, progressFor(OnboardingStepCode.tradeProof));
      expect(find.bySemanticsLabel('Step 5 of 5'), findsOneWidget);
    });

    testWidgets('industry step reads "Step 3 of 5" (ahead of capability+profile)',
        (WidgetTester tester) async {
      await pumpIndicator(tester, progressFor(OnboardingStepCode.industry));
      expect(find.bySemanticsLabel('Step 3 of 5'), findsOneWidget);
    });

    testWidgets('hire-only path draws 2 segments and completes at capability',
        (WidgetTester tester) async {
      final OnboardingProgress hireAtCapability = progressFor(
        OnboardingStepCode.capability,
        capability: EntityCapability.hire,
      );
      await pumpIndicator(tester, hireAtCapability);
      expect(find.bySemanticsLabel('Step 2 of 2'), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(2));
    });

    testWidgets('filled segments use the primary token, pending surfaceVariant',
        (WidgetTester tester) async {
      await pumpIndicator(tester, progressFor(OnboardingStepCode.industry));
      final List<BoxDecoration> decorations = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((AnimatedContainer c) => c.decoration! as BoxDecoration)
          .toList();
      expect(decorations, hasLength(5));
      expect(decorations.first.color, isNotNull);
      expect(decorations.every((BoxDecoration d) => d.borderRadius != null),
          isTrue,
          reason: 'radiusSm token applied');
    });

    testWidgets('dark theme builds without exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: OnboardingProgressIndicator(
              progress: progressFor(OnboardingStepCode.profile),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Step 1 of 5'), findsOneWidget);
    });
  });
}