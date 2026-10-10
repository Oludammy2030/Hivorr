import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/hire_repository.dart';
import 'package:hivorr/data/repositories/job_repository.dart';
import 'package:hivorr/systems/dashboard/screens/opportunities_screen.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_more_sheet.dart';
import 'package:hivorr/systems/dashboard/shell/hivorr_dashboard_shell.dart';
import 'package:hivorr/systems/dashboard/shell/professional_mobile_chrome.dart';
import 'package:hivorr/systems/jobs/services/hire_service.dart';
import 'package:hivorr/systems/jobs/services/job_service.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fakes/fake_auth.dart';
import '../../support/harnesses/widget_harness.dart';

/// Phase 5 interaction proofs for the Phase 2 shell/chrome work: real
/// `go_router` navigation (not just rendering) for the professional chrome
/// actions, the offer bottom bar (destination switch + selected index +
/// green scoping that leaves hire blue), the role-tinted More sheet, and
/// opportunity-card → detail navigation.
class _NavJobService implements JobService {
  @override
  Future<JobPage> listJobs({
    String? professionId,
    String? search,
    int limit = 20,
    String? cursor,
  }) async {
    final DateTime now = DateTime.now();
    return JobPage(
      jobs: <Job>[
        Job(
          id: 'job-1',
          clientEntityId: 'client-1',
          title: 'Senior React Developer',
          description: 'Build fintech platforms for African startups.',
          budgetMin: 3000,
          budgetMax: 5000,
          currencyCode: 'USD',
          location: 'Remote',
          status: 'open',
          applicationsCount: 2,
          postedAt: now.subtract(const Duration(hours: 3)),
          createdAt: now.subtract(const Duration(hours: 3)),
          updatedAt: now,
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<JobPage> listMyJobs({
    String role = 'posted',
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const JobPage(jobs: [], hasMore: false);

  @override
  Future<ApplicationPage> listMyApplications({
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const ApplicationPage(applications: [], hasMore: false);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NavHireService implements HireService {
  @override
  Future<HirePage> listMyHires({
    String? role,
    String? status,
    int limit = 20,
    String? cursor,
  }) async => const HirePage(hires: [], hasMore: false);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _NavOnboardingService implements OnboardingService {
  _NavOnboardingService(this.capability);

  final EntityCapability? capability;
  OnboardingProgress? _progress;

  @override
  OnboardingProgress? get progress => _progress;

  @override
  Future<OnboardingStepCode> resume(String entityId) async {
    if (capability != null) {
      _progress = OnboardingProgress(
        entityId: entityId,
        capability: capability!,
      );
    }
    return OnboardingStepCode.capability;
  }

  @override
  void disposeProgress() => _progress = null;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<OnboardingProvider> _onboarding(EntityCapability? capability) async {
  final OnboardingProvider provider = OnboardingProvider(
    service: _NavOnboardingService(capability),
  );
  if (capability != null) {
    await provider.loadProgress('entity-1');
  }
  return provider;
}

List<SingleChildWidget> _baseProviders(OnboardingProvider onboarding) {
  final JobProvider jobs = JobProvider(service: _NavJobService());
  final HireProvider hires = HireProvider(service: _NavHireService());
  final AuthProvider auth = AuthProvider(service: FakeAuthService());
  return <SingleChildWidget>[
    ChangeNotifierProvider<JobProvider>.value(value: jobs),
    ChangeNotifierProvider<HireProvider>.value(value: hires),
    ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ];
}

Widget _page(String label) =>
    Scaffold(body: Center(child: Text(label)));

void main() {
  group('Professional chrome actions navigate', () {
    late GoRouter router;

    Future<void> pumpChrome(WidgetTester tester) async {
      final OnboardingProvider onboarding = await _onboarding(
        EntityCapability.offer,
      );
      addTearDown(onboarding.dispose);
      router = GoRouter(
        initialLocation: '/dashboard',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard',
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(
                  body: Center(
                    child: ProfessionalMobileAppBar(title: 'Dashboard'),
                  ),
                ),
          ),
          GoRoute(
            path: '/dashboard/notifications',
            builder: (BuildContext context, GoRouterState state) =>
                _page('Notifications page'),
          ),
          GoRoute(
            path: '/dashboard/account',
            builder: (BuildContext context, GoRouterState state) =>
                _page('Account page'),
          ),
        ],
      );
      addTearDown(router.dispose);
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: _baseProviders(onboarding),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('bell opens notifications', (tester) async {
      await pumpChrome(tester);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.matchedLocation, '/dashboard/notifications');
      expect(find.text('Notifications page'), findsOneWidget);
    });

    testWidgets('avatar opens the account page', (tester) async {
      await pumpChrome(tester);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.matchedLocation, '/dashboard/account');
      expect(find.text('Account page'), findsOneWidget);
    });
  });

  group('Offer bottom bar navigates with green scoping', () {
    late GoRouter router;

    Future<void> pumpShell(
      WidgetTester tester,
      EntityCapability? capability,
    ) async {
      final OnboardingProvider onboarding = await _onboarding(capability);
      addTearDown(onboarding.dispose);
      router = GoRouter(
        initialLocation: '/dashboard',
        routes: <RouteBase>[
          ShellRoute(
            builder:
                (BuildContext context, GoRouterState state, Widget child) =>
                    HivorrDashboardShell(child: child),
            routes: <RouteBase>[
              GoRoute(
                path: '/dashboard',
                builder: (BuildContext context, GoRouterState state) =>
                    _page('Home body'),
              ),
              GoRoute(
                path: '/dashboard/opportunities',
                builder: (BuildContext context, GoRouterState state) =>
                    _page('Jobs body'),
              ),
              GoRoute(
                path: '/dashboard/messages',
                builder: (BuildContext context, GoRouterState state) =>
                    _page('Messages body'),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: _baseProviders(onboarding),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Theme barTheme(WidgetTester tester) {
      final Element bar = tester.element(find.byType(NavigationBar));
      Theme? scoped;
      bar.visitAncestorElements((Element e) {
        if (e.widget is Theme) {
          scoped = e.widget as Theme;
          return false;
        }
        return true;
      });
      return scoped!;
    }

    testWidgets('tapping Jobs switches destination and selection', (
      tester,
    ) async {
      await pumpShell(tester, EntityCapability.offer);
      expect(find.text('Home body'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.matchedLocation, '/dashboard/opportunities');
      expect(find.text('Jobs body'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
    });

    testWidgets('offer bar is green-scoped, hire bar keeps the default', (
      tester,
    ) async {
      await pumpShell(tester, EntityCapability.offer);
      expect(
        barTheme(tester).data.colorScheme.primary,
        RoleThemeExtension.light.professionalPrimary,
      );
      expect(
        barTheme(tester).data.colorScheme.secondaryContainer,
        RoleThemeExtension.light.professionalContainer,
      );
    });

    testWidgets('hire bar keeps brand-blue scoping', (tester) async {
      await pumpShell(tester, EntityCapability.hire);
      expect(
        barTheme(tester).data.colorScheme.primary,
        AppTheme.lightTheme.colorScheme.primary,
      );
      expect(find.text('More'), findsNothing);
    });
  });

  group('More sheet role tint', () {
    testWidgets('offer selection renders green', (tester) async {
      await pumpScreen(
        tester,
        const DashboardMoreSheet(
          location: '/dashboard/earnings',
          hire: false,
          offer: true,
        ),
        width: 390,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Icon check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.color, RoleThemeExtension.light.professionalPrimary);
    });

    testWidgets('hire selection stays brand-blue', (tester) async {
      await pumpScreen(
        tester,
        const DashboardMoreSheet(
          location: '/dashboard/account',
          hire: true,
          offer: false,
        ),
        width: 390,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Icon check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.color, AppTheme.lightTheme.colorScheme.primary);
    });
  });

  group('Opportunity card opens its detail', () {
    testWidgets('tapping the card header navigates to the job', (
      tester,
    ) async {
      final OnboardingProvider onboarding = await _onboarding(
        EntityCapability.offer,
      );
      addTearDown(onboarding.dispose);
      final GoRouter cardRouter = GoRouter(
        initialLocation: '/dashboard/opportunities',
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard/opportunities',
            builder: (BuildContext context, GoRouterState state) =>
                const OpportunitiesScreen(),
          ),
          GoRoute(
            path: '/dashboard/jobs/:id',
            builder: (BuildContext context, GoRouterState state) =>
                _page('Job ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(cardRouter.dispose);
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: _baseProviders(onboarding),
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            routerConfig: cardRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Senior React Developer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        cardRouter.state.matchedLocation,
        '/dashboard/jobs/job-1',
      );
      expect(find.text('Job job-1'), findsOneWidget);
    });
  });
}
