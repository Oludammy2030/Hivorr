import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/router/route_guard.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/state/auth_status.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';

import '../../support/fakes/fake_admin_review.dart';
import '../../support/onboarding/onboarding_test_support.dart';
import '../../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('super admin at home is redirected to admin dashboard', () async {
    final OnboardingTestStack stack = buildOnboardingStack();
    await stack.hydrate('u1');
    for (int i = 0; i < 4; i++) {
      await stack.provider.advance();
    }
    final adminProvider = AdminReviewProvider(
      repo: FakeAdminReviewRepository(isAdmin: true),
    );
    await adminProvider.checkAdmin();
    final guard = RouteGuard(
      authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
      onboardingProvider: stack.provider,
      adminReviewProvider: adminProvider,
    );
    expect(guard.redirectResolver(RoutePaths.home), RoutePaths.adminDashboard);
    expect(guard.redirectResolver(RoutePaths.adminDashboard), isNull);
    stack.provider.dispose();
    adminProvider.dispose();
  });

  test('non-admin at home stays at home', () async {
    final OnboardingTestStack stack = buildOnboardingStack();
    await stack.hydrate('u1');
    for (int i = 0; i < 4; i++) {
      await stack.provider.advance();
    }
    final adminProvider = AdminReviewProvider(
      repo: FakeAdminReviewRepository(isAdmin: false),
    );
    await adminProvider.checkAdmin();
    final guard = RouteGuard(
      authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
      onboardingProvider: stack.provider,
      adminReviewProvider: adminProvider,
    );
    expect(guard.redirectResolver(RoutePaths.home), isNull);
    stack.provider.dispose();
    adminProvider.dispose();
  });

  test('super admin with incomplete onboarding still goes to onboarding first', () async {
    final OnboardingTestStack stack = buildOnboardingStack();
    await stack.hydrate('u1');
    await stack.provider.advance(); // now at industry, incomplete, not exited
    final adminProvider = AdminReviewProvider(
      repo: FakeAdminReviewRepository(isAdmin: true),
    );
    await adminProvider.checkAdmin();
    final guard = RouteGuard(
      authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
      onboardingProvider: stack.provider,
      adminReviewProvider: adminProvider,
    );
    expect(guard.redirectResolver(RoutePaths.home), RoutePaths.onboardingIndustry);
    stack.provider.dispose();
    adminProvider.dispose();
  });

  test('super admin refresh at dashboard stays', () async {
    final OnboardingTestStack stack = buildOnboardingStack();
    await stack.hydrate('u1');
    for (int i = 0; i < 4; i++) {
      await stack.provider.advance();
    }
    final adminProvider = AdminReviewProvider(
      repo: FakeAdminReviewRepository(isAdmin: true),
    );
    await adminProvider.checkAdmin();
    final guard = RouteGuard(
      authProvider: FakeAuthProvider(initialStatus: AuthStatus.authenticated),
      onboardingProvider: stack.provider,
      adminReviewProvider: adminProvider,
    );
    expect(guard.redirectResolver(RoutePaths.adminDashboard), isNull);
    expect(guard.redirectResolver(RoutePaths.adminManageUsers), isNull);
    stack.provider.dispose();
    adminProvider.dispose();
  });

  test('unauthenticated admin route goes to login with next', () {
    final adminProvider = AdminReviewProvider(
      repo: FakeAdminReviewRepository(isAdmin: true),
    );
    final guard = RouteGuard(
      authProvider: FakeAuthProvider(initialStatus: AuthStatus.unauthenticated),
      adminReviewProvider: adminProvider,
    );
    expect(guard.redirectResolver(RoutePaths.adminDashboard), '/login?next=/admin/dashboard');
  });
}
