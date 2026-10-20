// EP-02-20 DoD-C6: Onboarding Resume Redirect Verification.
//
// Verifies the `_onboardingResumeRedirect` contract in RouteGuard by driving
// the real guard through the real OnboardingProvider/OnboardingService stack
// (faked transport, real composition):
//  1. Home + incomplete + !exited → redirect to the saved resume step
//  2. Capability step (no track chosen yet) → Explore/Earn launcher
//  3. Onboarding route + complete → redirect to the dashboard
//  4. Home + exited → no force-resume (dashboard forward); wizard stays reachable
//  5. currentStep == null (un-hydrated provider) → no resume, dashboard forward
//  6. _isPublicContentView allows /p/ + /store/ signed-out
//
// Re-baselined (EP-03-20) for two contracts that landed after this script was
// authored: the EP-04-03 dashboard-first landing (an authenticated user at `/`
// now forwards to `/dashboard`) and the capability-first wizard shape, whose
// first step is the capability choice (resume target `/activities`) ahead of
// the offer/hire tracks. No production behaviour changed here — only the
// expectations, which now assert the current guard contract.
//
// Follows the `test/unit/app/route_guard_test.dart` composition pattern (no
// duplication — this is the EP-02-20 verification-script lens over the same
// proven guard).
//
// Run: flutter test test/integration/verification/onboarding_resume_redirect_verification.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RouteGuard guardFor(OnboardingProvider provider) => RouteGuard(
    authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
    onboardingProvider: provider,
  );

  group('RouteGuard (onboarding resume redirect)', () {
    test('home + incomplete wizard → resume at the saved step', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.selectCapability(EntityCapability.offer);
      expect(stack.provider.currentStep, OnboardingStepCode.industry);
      expect(stack.provider.exited, isFalse);
      expect(stack.provider.isComplete, isFalse);

      final RouteGuard guard = guardFor(stack.provider);
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.onboardingIndustry,
        reason: 'home with an incomplete wizard resumes at the saved step',
      );
      stack.provider.dispose();
    });

    test('home + capability step → Explore/Earn launcher', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      expect(stack.provider.currentStep, OnboardingStepCode.capability);

      final RouteGuard guard = guardFor(stack.provider);
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.activities,
        reason: 'the capability choice resumes through the activities launcher',
      );
      stack.provider.dispose();
    });

    test('completed wizard at an onboarding route → dashboard', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.selectCapability(EntityCapability.offer);
      for (int i = 0; i < 3; i++) {
        await stack.provider.advance();
      }
      expect(stack.provider.isComplete, isTrue);
      expect(stack.provider.isCompleteAuthoritative, isTrue);

      final RouteGuard guard = guardFor(stack.provider);
      expect(
        guard.redirectResolver(RoutePaths.onboarding),
        RoutePaths.dashboard,
        reason: 'a completed wizard bounces away from onboarding routes',
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.dashboard,
        reason: 'authenticated home forwards to the dashboard (EP-04-03)',
      );
      stack.provider.dispose();
    });

    test(
      'exited flag honored — no force-resume, wizard stays reachable',
      () async {
        final OnboardingTestStack stack = buildOnboardingStack();
        await stack.hydrate('u1');
        await stack.provider.selectCapability(EntityCapability.offer);
        await stack.provider.exitWizard();
        expect(stack.provider.exited, isTrue);

        final RouteGuard guard = guardFor(stack.provider);
        expect(
          guard.redirectResolver(RoutePaths.home),
          RoutePaths.dashboard,
          reason:
              'exited wizards are not force-resumed; home forwards to the '
              'dashboard while "Continue registration" resumes the wizard',
        );
        expect(
          guard.redirectResolver(RoutePaths.onboardingCapability),
          isNull,
          reason: 'the wizard stays reachable so the resume action can run',
        );
        stack.provider.dispose();
      },
    );

    test(
      'currentStep == null (un-hydrated provider) → no resume redirect',
      () async {
        final OnboardingTestStack stack = buildOnboardingStack();
        expect(stack.provider.currentStep, isNull);

        final RouteGuard guard = guardFor(stack.provider);
        expect(
          guard.redirectResolver(RoutePaths.home),
          RoutePaths.dashboard,
          reason:
              'no hydration → no resume target → no forced redirect into the '
              'wizard; authenticated home forwards to the dashboard',
        );
        expect(
          guard.redirectResolver(RoutePaths.onboardingCapability),
          isNull,
          reason: 'un-hydrated state never force-redirects into the wizard',
        );
        stack.provider.dispose();
      },
    );

    test('_isPublicContentView allows /p/ + /store/ signed-out', () {
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.unauthenticated,
        ),
      );
      expect(
        guard.redirectResolver('/p/software-engineer/entity-1'),
        isNull,
        reason: 'signed-out visitor may open a public profile',
      );
      expect(
        guard.redirectResolver('/store/some-slug'),
        isNull,
        reason: 'signed-out visitor may open a public store',
      );
      expect(
        guard.redirectResolver('/profile'),
        isNotNull,
        reason: 'protected routes still redirect to the entry door',
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.login,
        reason: 'native returning visitor lands on the login door',
      );
    });
  });
}
