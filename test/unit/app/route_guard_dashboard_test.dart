import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

import '../../support/onboarding/onboarding_test_support.dart';
import '../../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteGuard dashboard capability gates (EP-04-03)', () {
    Future<RouteGuard> guardFor(EntityCapability capability) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.selectCapability(capability);
      // Walk the capability path to completion (hire finishes at the
      // capability step; offer/both traverse industry/identity/trade-proof).
      for (int i = 0; i < 6 && !stack.provider.isComplete; i++) {
        await stack.provider.advance();
      }
      expect(
        stack.provider.progress?.capability,
        capability,
        reason: 'wizard capability resolves for gating',
      );
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      addTearDown(stack.provider.dispose);
      return guard;
    }

    test('hire cannot reach work-only routes', () async {
      final RouteGuard guard = await guardFor(EntityCapability.hire);
      expect(
        guard.redirectResolver(RoutePaths.dashboardOpportunities),
        RoutePaths.dashboard,
      );
      expect(
        guard.redirectResolver(RoutePaths.dashboardApplications),
        RoutePaths.dashboard,
      );
      expect(
        guard.redirectResolver(RoutePaths.dashboardEarnings),
        RoutePaths.dashboard,
      );
      // Hiring + shared routes stay open.
      expect(guard.redirectResolver(RoutePaths.dashboardJobs), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboard), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboardMessages), isNull);
    });

    test('offer cannot reach hiring-only routes', () async {
      final RouteGuard guard = await guardFor(EntityCapability.offer);
      expect(
        guard.redirectResolver(RoutePaths.dashboardJobs),
        RoutePaths.dashboard,
      );
      expect(
        guard.redirectResolver(RoutePaths.dashboardJobNew),
        RoutePaths.dashboard,
      );
      expect(
        guard.redirectResolver('/dashboard/jobs/abc/edit'),
        RoutePaths.dashboard,
      );
      expect(
        guard.redirectResolver(RoutePaths.dashboardPayments),
        RoutePaths.dashboard,
      );
      // Work + shared routes stay open.
      expect(guard.redirectResolver(RoutePaths.dashboardOpportunities), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboard), isNull);
    });

    test('both reaches every dashboard route', () async {
      final RouteGuard guard = await guardFor(EntityCapability.both);
      for (final String path in <String>[
        RoutePaths.dashboard,
        RoutePaths.dashboardJobs,
        RoutePaths.dashboardJobNew,
        RoutePaths.dashboardOpportunities,
        RoutePaths.dashboardApplications,
        RoutePaths.dashboardHires,
        RoutePaths.dashboardMessages,
        RoutePaths.dashboardPayments,
        RoutePaths.dashboardEarnings,
      ]) {
        expect(
          guard.redirectResolver(path),
          isNull,
          reason: '$path should be open for both',
        );
      }
    });

    test('job detail stays shared (owner and applicant both view)', () async {
      final RouteGuard hireGuard = await guardFor(EntityCapability.hire);
      final RouteGuard offerGuard = await guardFor(EntityCapability.offer);
      expect(hireGuard.redirectResolver('/dashboard/jobs/job-1'), isNull);
      expect(offerGuard.redirectResolver('/dashboard/jobs/job-1'), isNull);
    });
  });
}
