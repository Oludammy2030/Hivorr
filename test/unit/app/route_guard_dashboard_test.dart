import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';

import '../../support/onboarding/onboarding_test_support.dart';
import '../../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RouteGuard dashboard focus gates (EP-04-03)', () {
    Future<({RouteGuard guard, OnboardingTestStack stack})> guardFor(
      EntityCapability capability,
    ) async {
      final OnboardingTestStack stack = buildOnboardingStack();
      await stack.hydrate('u1');
      await stack.provider.selectCapability(capability);
      // Walk the focus path to completion (hire finishes at the
      // capability step; offer traverses industry/identity/trade-proof).
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
      return (guard: guard, stack: stack);
    }

    test('hire cannot reach work-only routes', () async {
      final RouteGuard guard = (await guardFor(EntityCapability.hire)).guard;
      expect(
        guard.redirectResolver(RoutePaths.dashboardOpportunities),
        RoutePaths.dashboard,
      );
      expect(
        guard.redirectResolver(RoutePaths.dashboardEarnings),
        RoutePaths.dashboard,
      );
      // Hiring + shared routes stay open (applications is shared: clients
      // see the Jobs + Applicants inbox, professionals see their own list).
      expect(guard.redirectResolver(RoutePaths.dashboardApplications), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboardJobs), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboard), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboardMessages), isNull);
    });

    test('offer cannot reach hiring-only routes', () async {
      final RouteGuard guard = (await guardFor(EntityCapability.offer)).guard;
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
      // Work + shared routes stay open (applications is shared).
      expect(guard.redirectResolver(RoutePaths.dashboardOpportunities), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboardApplications), isNull);
      expect(guard.redirectResolver(RoutePaths.dashboard), isNull);
    });

    test('unhydrated focus fails open across dashboard routes', () async {
      // No loadProgress call: progress is null, so the resume gate stays out
      // and the focus gate allows navigation (server enforces per row).
      final OnboardingTestStack stack = buildOnboardingStack();
      final RouteGuard guard = RouteGuard(
        authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
        onboardingProvider: stack.provider,
      );
      addTearDown(stack.provider.dispose);
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
          reason: '$path should be open before hydration',
        );
      }
    });

    test('switching focus flips the gates', () async {
      final ({RouteGuard guard, OnboardingTestStack stack}) result =
          await guardFor(EntityCapability.hire);
      final RouteGuard guard = result.guard;
      expect(
        guard.redirectResolver(RoutePaths.dashboardOpportunities),
        RoutePaths.dashboard,
      );
      // Switch sides in the launcher: work routes stop bouncing to the
      // dashboard root (the unfinished offer wizard resumes instead).
      await result.stack.provider.selectCapability(EntityCapability.offer);
      expect(
        guard.redirectResolver(RoutePaths.dashboardOpportunities),
        isNot(RoutePaths.dashboard),
      );
      expect(
        guard.redirectResolver(RoutePaths.dashboardJobs),
        isNot(isNull),
        reason: 'hiring routes now resume the offer wizard',
      );
    });

    test('job detail stays shared (owner and applicant both view)', () async {
      final ({RouteGuard guard, OnboardingTestStack stack}) hireResult =
          await guardFor(EntityCapability.hire);
      final ({RouteGuard guard, OnboardingTestStack stack}) offerResult =
          await guardFor(EntityCapability.offer);
      expect(hireResult.guard.redirectResolver('/dashboard/jobs/job-1'), isNull);
      expect(offerResult.guard.redirectResolver('/dashboard/jobs/job-1'), isNull);
    });
  });
}
