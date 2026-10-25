import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/providers/verification_provider.dart';
import 'package:hivorr/systems/onboarding/screens/professional_requirements_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/fakes/fake_verification.dart';
import '../../../support/onboarding/onboarding_test_support.dart';

void main() {
  Future<OnboardingTestStack> pumpRequirements(
    WidgetTester tester, {
    OnboardingTestStack? stack,
    VerificationProvider? verification,
  }) async {
    final OnboardingTestStack s = stack ?? buildOnboardingStack();
    await s.hydrate('u1');
    final VerificationProvider v =
        verification ??
        VerificationProvider(repo: FakeVerificationRepository());
    addTearDown(v.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: <SingleChildWidget>[
          ...s.buildProviders(),
          ChangeNotifierProvider<VerificationProvider>.value(value: v),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: ProfessionalRequirementsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return s;
  }

  group('ProfessionalRequirementsScreen', () {
    testWidgets('fresh professional sees actionable checklist', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = await pumpRequirements(tester);
      expect(find.text('Professional requirements'), findsOneWidget);
      expect(find.text('Earn focus active'), findsOneWidget);
      expect(find.text('Profession linked'), findsOneWidget);
      expect(find.text('Identity verified'), findsOneWidget);
      expect(find.text('Trade approved'), findsOneWidget);
      expect(find.text('Continue →'), findsWidgets);
      expect(tester.takeException(), isNull);
      stack.provider.dispose();
    });

    testWidgets('actionable rows open the wizard step with a return marker', (
      WidgetTester tester,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      final VerificationProvider v = VerificationProvider(
        repo: FakeVerificationRepository(),
      );
      addTearDown(v.dispose);
      await pumpOnboardingScreen(
        tester,
        const ProfessionalRequirementsScreen(),
        path: RoutePaths.professionalRequirements,
        providers: <SingleChildWidget>[
          ...stack.buildProviders(),
          ChangeNotifierProvider<VerificationProvider>.value(value: v),
        ],
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Identity verified'));
      await tester.tap(find.text('Identity verified'));
      await tester.pumpAndSettle();

      expect(find.text('ONBOARDING-IDENTITY'), findsOneWidget);
      final Uri uri = GoRouterState.of(
        tester.element(find.text('ONBOARDING-IDENTITY')),
      ).uri;
      expect(uri.path, RoutePaths.onboardingIdentity);
      expect(uri.queryParameters['from'], 'requirements');
      stack.provider.dispose();
    });

    testWidgets('failed refresh with no data surfaces error', (tester) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      final FakeVerificationRepository repo = FakeVerificationRepository();
      repo.nextError = const ApiException(
        kind: ApiExceptionKind.server,
        message: 'boom',
        code: 'PLT999',
      );
      final VerificationProvider v = VerificationProvider(repo: repo);
      addTearDown(v.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: <SingleChildWidget>[
            ...stack.buildProviders(),
            ChangeNotifierProvider<VerificationProvider>.value(value: v),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(body: ProfessionalRequirementsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not check requirements'), findsOneWidget);
      expect(find.text('boom'), findsOneWidget);
      expect(tester.takeException(), isNull);
      stack.provider.dispose();
    });
  });
}
