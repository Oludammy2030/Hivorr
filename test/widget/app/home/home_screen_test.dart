import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/home/home_screen.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';

import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen (exit-and-continue gate, B1)', () {
    testWidgets('offers Continue registration after a deliberate exit',
        (WidgetTester tester) async {
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
      expect(stack.provider.exited, isFalse,
          reason: 'continue clears the exit flag so the guard resumes');
      expect(find.text('ONBOARDING-CAPABILITY'), findsOneWidget,
          reason: 'registration resumes at the saved step');
      stack.provider.dispose();
    });

    testWidgets('fresh session shows the plain home state', (WidgetTester tester) async {
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

    testWidgets('an auto-resuming wizard gets no Continue card',
        (WidgetTester tester) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.advance();
      await pumpOnboardingScreen(
        tester,
        const HomeScreen(),
        path: '/',
        providers: stack.buildProviders(),
      );
      expect(find.text('Continue registration'), findsNothing,
          reason: 'the guard force-resumes; the card is only for explicit exits');
      stack.provider.dispose();
    });

    testWidgets('a completed wizard gets no Continue card',
        (WidgetTester tester) async {
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
}