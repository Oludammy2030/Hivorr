import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/local/onboarding_progress_store.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/screens/capability_selection_screen.dart';
import 'package:hivorr/systems/onboarding/widgets/onboarding_step_controller.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(OnboardingTestStack, OnboardingStepController)> pumpCapability(
    WidgetTester tester, {
    OnboardingTestStack? stack,
    bool active = true,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    final OnboardingStepController controller = OnboardingStepController();
    await s.hydrate('u1');
    try {
      await s.provider.advance(); // profile → capability (step 2)
    } on Object {
      // advance persists; failure-path harnesses (throwing store) still render.
    }
    await pumpOnboardingScreen(
      tester,
      CapabilitySelectionScreen(active: active, controller: controller),
      path: '/onboarding/capability',
      providers: s.buildProviders(),
    );
    return (s, controller);
  }

  group('CapabilitySelectionScreen (capability correction)', () {
    testWidgets('inactive renders nothing', (WidgetTester tester) async {
      final (OnboardingTestStack stack, _) =
          await pumpCapability(tester, active: false);
      expect(find.text('What will you do on Hivorr?'), findsNothing);
      stack.provider.dispose();
    });

    testWidgets('renders the three capability cards + helper copy',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, _) = await pumpCapability(tester);
      expect(find.text('What will you do on Hivorr?'), findsOneWidget);
      for (final String label in <String>[
        'Hire Professionals',
        'Offer Professional Services',
        'Do both',
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: '$label renders as a selectable card');
      }
      stack.provider.dispose();
    });

    testWidgets('hides the shell primary CTA', (WidgetTester tester) async {
      final (_, OnboardingStepController controller) =
          await pumpCapability(tester);
      expect(controller.primaryLabel, isEmpty);
      controller.dispose();
    });

    testWidgets('tapping Hire selects, persists, and routes to the complete step',
        (WidgetTester tester) async {
      final (OnboardingTestStack stack, _) = await pumpCapability(tester);
      await tester.tap(find.text('Hire Professionals'));
      await tester.pumpAndSettle();
      expect(stack.provider.progress!.capability, EntityCapability.hire,
          reason: 'the hire choice is the persisted decision');
      final OnboardingProgress saved = (await stack.store.read('u1'))!;
      expect(saved.capability, EntityCapability.hire);
      expect(saved.step, OnboardingStepCode.capability,
          reason: 'a hire-only entity finishes after the capability step');
      expect(stack.provider.isComplete, isTrue);
      expect(find.text('ONBOARDING-COMPLETE'), findsOneWidget);
      stack.provider.dispose();
    });

    testWidgets('tapping Offer and Both persist their decision',
        (WidgetTester tester) async {
      final (OnboardingTestStack offerStack, _) =
          await pumpCapability(tester);
      await tester.tap(find.text('Offer Professional Services'));
      await tester.pumpAndSettle();
      expect(offerStack.provider.progress!.capability, EntityCapability.offer);
      expect(offerStack.provider.progress!.step,
          OnboardingStepCode.industry,
          reason: 'offer continues into industry selection');
      expect(find.text('ONBOARDING-INDUSTRY'), findsOneWidget);
      final (OnboardingTestStack bothStack, _) =
          await pumpCapability(tester);
      await tester.tap(find.text('Do both'));
      await tester.pumpAndSettle();
      expect(bothStack.provider.progress!.capability, EntityCapability.both);
      expect(bothStack.provider.progress!.step, OnboardingStepCode.industry);
      offerStack.provider.dispose();
      bothStack.provider.dispose();
    });

    testWidgets('a failed persist surfaces the error inline and stays',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = buildOnboardingStack(
        store: _ThrowingSaveStore(),
      );
      final (_, _) = await pumpCapability(tester, stack: stack);
      await tester.tap(find.text('Hire Professionals'));
      await tester.pumpAndSettle();
      expect(find.text('ONBOARDING-COMPLETE'), findsNothing,
          reason: 'navigation only fires on a persisted decision');
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      stack.provider.dispose();
    });
  });
}

class _ThrowingSaveStore extends InMemoryOnboardingProgressStore {
  @override
  Future<void> save(OnboardingProgress progress) {
    throw StateError('persist failed');
  }
}