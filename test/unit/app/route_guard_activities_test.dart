import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/environments/app_environment.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

import '../../support/onboarding/onboarding_test_support.dart';
import '../../test_helpers.dart';

void main() {
  group('RouteGuard (unified-account launcher)', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('fresh wizard at the capability decision resumes into /activities',
        () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.authenticated,
        ),
        onboardingProvider: stack.provider,
      );
      expect(guard.redirectResolver(RoutePaths.home), RoutePaths.activities);
      expect(
        guard.redirectResolver(RoutePaths.dashboard),
        RoutePaths.activities,
      );
      stack.provider.dispose();
    });

    test('deeper steps still resume in place (not the launcher)', () async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.selectCapability(EntityCapability.offer);
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.authenticated,
        ),
        onboardingProvider: stack.provider,
      );
      expect(
        guard.redirectResolver(RoutePaths.home),
        RoutePaths.onboardingIndustry,
      );
      stack.provider.dispose();
    });

    test('the launcher stays reachable while incomplete and when complete',
        () async {
      final OnboardingTestStack incomplete = buildOnboardingStack();
      await incomplete.hydrate('u1');
      final RouteGuard incompleteGuard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.authenticated,
        ),
        onboardingProvider: incomplete.provider,
      );
      expect(
        incompleteGuard.redirectResolver(RoutePaths.activities),
        isNull,
      );
      incomplete.provider.dispose();

      final OnboardingTestStack complete = buildOnboardingStack();
      await complete.hydrate('u1');
      await complete.provider.selectCapability(EntityCapability.offer);
      for (int i = 0; i < 3; i++) {
        await complete.provider.advance();
      }
      final RouteGuard completeGuard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.authenticated,
        ),
        onboardingProvider: complete.provider,
      );
      expect(
        completeGuard.redirectResolver(RoutePaths.activities),
        isNull,
        reason: 'persistent Explore-more entry after onboarding',
      );
      complete.provider.dispose();
    });

    test('unauthenticated /activities resolves to the login door with ?next=',
        () {
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.unauthenticated,
        ),
      );
      expect(
        guard.redirectResolver(RoutePaths.activities),
        '/login?next=/activities',
      );
    });

    test('development preview covers the launcher like onboarding routes', () {
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(
          initialStatus: AuthStatus.unauthenticated,
        ),
        environment: AppEnvironment.development,
      );
      expect(guard.redirectResolver(RoutePaths.activities), isNull);
    });
  });
}
