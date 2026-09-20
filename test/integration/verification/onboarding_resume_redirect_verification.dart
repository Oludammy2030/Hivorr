// EP-02-20 DoD-C6: Onboarding Resume Redirect Verification.
//
// Verifies the `_onboardingResumeRedirect` contract in RouteGuard by driving
// the real guard through the real OnboardingProvider/OnboardingService stack
// (faked transport, real composition):
//  1. Home + incomplete + !exited → redirect to resume step
//  2. Onboarding route + complete → redirect to home
//  3. Home + exited → no redirect (stay at home, "Continue registration")
//  4. currentStep == null (un-hydrated provider) → no redirect
//  5. _isPublicContentView allows /p/ + /store/ signed-out
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
import 'package:hivorr/data/providers/onboarding_provider.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/onboarding/onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RouteGuard guardFor(OnboardingProvider provider) => RouteGuard(
    authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
    onboardingProvider: provider,
  );

  group('DoD-C6: Onboarding resume redirect contract', () {
    test(
      'home → resume step for an incomplete entity (force-resume)',
      () async {
        final OnboardingTestStack stack = buildOnboardingStack();
        await stack.hydrate('u1');
        await stack.provider.advance();
        expect(stack.provider.exited, isFalse);

        final RouteGuard guard = guardFor(stack.provider);
        expect(
          guard.redirectResolver(RoutePaths.home),
          RoutePaths.onboardingCapability,
          reason: 'home with an incomplete wizard resumes at the saved step',
        );
        stack.provider.dispose();
      },
    );

    test('completed wizard at an onboarding route → home', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      for (int i = 0; i < 5; i++) {
        await stack.provider.advance();
      }
      expect(stack.provider.isComplete, isTrue);
      expect(stack.provider.isCompleteAuthoritative, isTrue);

      final RouteGuard guard = guardFor(stack.provider);
      expect(
        guard.redirectResolver(RoutePaths.onboarding),
        RoutePaths.home,
        reason: 'a completed wizard bounces away from onboarding routes',
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        isNull,
        reason: 'home stays reachable for a completed wizard',
      );
      stack.provider.dispose();
    });

    test(
      'exited flag honored — home stays reachable, no force-resume',
      () async {
        final OnboardingTestStack stack = buildOnboardingStack();
        await stack.hydrate('u1');
        await stack.provider.advance();
        await stack.provider.exitWizard();
        expect(stack.provider.exited, isTrue);

        final RouteGuard guard = guardFor(stack.provider);
        expect(
          guard.redirectResolver(RoutePaths.home),
          isNull,
          reason: 'exited wizard keeps home reachable (Continue registration)',
        );
        stack.provider.dispose();
      },
    );

    test('currentStep == null (un-hydrated provider) → no redirect', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      expect(stack.provider.currentStep, isNull);

      final RouteGuard guard = guardFor(stack.provider);
      expect(
        guard.redirectResolver(RoutePaths.home),
        isNull,
        reason: 'no hydration → no resume target → no forced redirect',
      );
      stack.provider.dispose();
    });

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
