import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/onboarding/screens/industry_profession_selection_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';
import 'package:provider/provider.dart';

import '../../../support/fakes/fake_taxonomy.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(OnboardingTestStack, OnboardingStepController)> pumpCombined(
    WidgetTester tester, {
    OnboardingTestStack? stack,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    final OnboardingStepController controller = OnboardingStepController();
    await s.hydrate('u1');
    await pumpOnboardingScreen(
      tester,
      IndustryProfessionSelectionScreen(active: true, controller: controller),
      path: '/onboarding/industry',
      providers: s.buildProviders(),
    );
    return (s, controller);
  }

  group('IndustryProfessionSelectionScreen (FV-19..FV-21, merged)', () {
    testWidgets('renders both questions, the connector, and both dropdowns',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, _) = await pumpCombined(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Which industry best describes you?'),
        findsOneWidget,
      );
      expect(
        find.text('Which profession best describes you?'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget,
          reason: 'the ↓ connector visually links industry to profession');
      expect(find.byType(DropdownMenu<Industry>), findsOneWidget);
      expect(find.byType(DropdownMenu<Profession>), findsOneWidget);
      expect(
        find.text(
          'Your profession unlocks trade verification — you must be approved '
          'to place bids (marketplace Rule 2).',
        ),
        findsOneWidget,
      );
      stack.provider.dispose();
    });

    testWidgets('profession stays disabled until an industry is selected',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpCombined(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('First choose an industry to pick a profession.'),
        findsOneWidget,
      );
      expect(controller.primaryLabel, 'Save & continue');
      expect(controller.canPrimary, isFalse,
          reason: 'both selections are required before continuing');
      stack.provider.dispose();
    });

    testWidgets('industry-only selection shows a validation message',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpCombined(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Industry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology').last);
      await tester.pumpAndSettle();
      expect(stack.taxonomy.selectedIndustry?.id, 'ind-tech');
      expect(
        find.text('Select a profession to continue.'),
        findsOneWidget,
        reason: 'the missing dependent selection is surfaced inline',
      );
      expect(controller.canPrimary, isFalse);
      stack.provider.dispose();
    });

    testWidgets('industry + profession then Save & continue bind + advance',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpCombined(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Industry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Profession>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Software Engineer').last);
      await tester.pumpAndSettle();
      expect(stack.taxonomy.selectedProfession?.id, 'prof-sw');
      expect(controller.canPrimary, isTrue);
      controller.onPrimary!.call();
      await tester.pumpAndSettle();
      expect(stack.remote.bindProfessionCallCount, 1);
      expect(stack.remote.lastBoundProfessionId, 'prof-sw');
      expect(find.text('ONBOARDING-IDENTITY'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('PLT005 conflict keeps the wizard on the combined step',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack();
      s.remote.throwConflictOnBind = true;
      final (OnboardingTestStack stack, OnboardingStepController controller) =
          await pumpCombined(tester, stack: s);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Industry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Technology').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Profession>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Software Engineer').last);
      await tester.pumpAndSettle();
      controller.onPrimary!.call();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This profession is already linked to your account. Choose another '
          'one or continue with your selection.',
        ),
        findsOneWidget,
      );
      expect(stack.provider.submitState, SubmitState.error);
      stack.provider.dispose();
    });

    testWidgets('changing the industry clears a previously chosen profession',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack(
        taxonomyRepo: FakeTaxonomyRepository(
          industries: <Industry>[
            const Industry(
              id: 'ind-tech',
              slug: 'technology',
              name: 'Technology',
              isActive: true,
              sortOrder: 20,
            ),
            const Industry(
              id: 'ind-legal',
              slug: 'legal',
              name: 'Legal',
              isActive: true,
              sortOrder: 10,
            ),
          ],
          professionsByIndustry: <String, List<Profession>>{
            'ind-tech': <Profession>[seedProfession()],
            'ind-legal': <Profession>[
              const Profession(
                id: 'prof-law',
                industryId: 'ind-legal',
                slug: 'lawyer',
                name: 'Lawyer',
                isActive: true,
                sortOrder: 10,
              ),
            ],
          },
        ),
      );
      await s.hydrate('u1');
      await selectTechnologyProfession(s.taxonomy);
      final OnboardingStepController controller = OnboardingStepController();
      await pumpOnboardingScreen(
        tester,
        IndustryProfessionSelectionScreen(active: true, controller: controller),
        path: '/onboarding/industry',
        providers: s.buildProviders(),
      );
      await tester.pumpAndSettle();
      expect(s.taxonomy.selectedIndustry?.id, 'ind-tech');
      expect(s.taxonomy.selectedProfession?.id, 'prof-sw',
          reason: 'the preserved selection is carried back into the dropdown');
      await tester.tap(find.byType(DropdownMenu<Industry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legal').last);
      await tester.pumpAndSettle();
      expect(s.taxonomy.selectedIndustry?.id, 'ind-legal');
      expect(s.taxonomy.selectedProfession, isNull,
          reason: 'the profession is the dependent value — re-selecting the '
              'industry invalidates it');
      expect(controller.canPrimary, isFalse);
      controller.dispose();
      s.provider.dispose();
    });

    testWidgets('industries render sorted by sortOrder then name in the menu',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack(
        taxonomyRepo: FakeTaxonomyRepository(
          industries: <Industry>[
            const Industry(
              id: 'ind-tech',
              slug: 'technology',
              name: 'Technology',
              isActive: true,
              sortOrder: 30,
            ),
            const Industry(
              id: 'ind-legal',
              slug: 'legal',
              name: 'Legal',
              isActive: true,
              sortOrder: 10,
            ),
          ],
          professionsByIndustry: const <String, List<Profession>>{},
        ),
      );
      final (OnboardingTestStack stack, _) =
          await pumpCombined(tester, stack: s);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Industry>));
      await tester.pumpAndSettle();
      final Offset legal = tester.getTopLeft(find.text('Legal').last);
      final Offset tech = tester.getTopLeft(find.text('Technology').last);
      expect(legal.dy, lessThan(tech.dy),
          reason: 'sortOrder 10 (Legal) lists before 30 (Technology)');
      stack.provider.dispose();
    });

    testWidgets('shows the loading state before industries resolve',
        (WidgetTester tester) async {
      final OnboardingTestStack s = buildOnboardingStack();
      await s.hydrate('u1');
      final OnboardingStepController controller = OnboardingStepController();
      // First frame renders before the post-frame load completes, so the
      // loader is visible exactly once.
      await tester.pumpWidget(
        MultiProvider(
          providers: s.buildProviders(),
          child: MaterialApp.router(
            routerConfig: onboardingTestRouter(
              path: '/onboarding/industry',
              child: IndustryProfessionSelectionScreen(
                active: true,
                controller: controller,
              ),
            ),
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      expect(find.text('Loading industries…'), findsOneWidget);
      controller.dispose();
      s.provider.dispose();
    });
  });
}