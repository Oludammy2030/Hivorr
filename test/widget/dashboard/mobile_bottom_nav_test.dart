import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/data/entities/onboarding_progress.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_more_sheet.dart';
import 'package:hivorr/systems/dashboard/shell/hivorr_dashboard_shell.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:hivorr/systems/onboarding/services/onboarding_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/harnesses/widget_harness.dart';

class _ShellOnboardingService implements OnboardingService {
  _ShellOnboardingService(this.capability);

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<OnboardingProvider> _shellOnboarding(
  EntityCapability? capability,
) async {
  final OnboardingProvider provider = OnboardingProvider(
    service: _ShellOnboardingService(capability),
  );
  if (capability != null) {
    await provider.loadProgress('entity-1');
  }
  return provider;
}

Future<void> _pumpShell(
  WidgetTester tester,
  OnboardingProvider onboarding, {
  double width = 390,
}) async {
  final Size previousPhysical = tester.view.physicalSize;
  final double previousDpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1.0;
  final GoRouter router = GoRouter(
    initialLocation: '/dashboard',
    routes: <RouteBase>[
      GoRoute(
        path: '/dashboard',
        builder: (BuildContext context, GoRouterState state) =>
            const HivorrDashboardShell(child: Text('body')),
      ),
    ],
  );
  addTearDown(() {
    tester.view.physicalSize = previousPhysical;
    tester.view.devicePixelRatio = previousDpr;
    router.dispose();
    onboarding.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<OnboardingProvider>.value(value: onboarding),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('mobilePrimaryNavItems', () {
    test('hire-only sees Home + My Jobs + Post Job + Services + Messages',
        () {
      final List<DashboardNavItem> items = mobilePrimaryNavItems(
        hire: true,
        offer: false,
      );
      expect(
        items.map((DashboardNavItem e) => e.location).toList(),
        <String>[
          '/dashboard',
          '/dashboard/jobs',
          '/dashboard/jobs/new',
          '/dashboard/services',
          '/dashboard/messages',
        ],
      );
    });

    test('offer-only sees Home + Jobs + Messages', () {
      final List<DashboardNavItem> items = mobilePrimaryNavItems(
        hire: false,
        offer: true,
      );
      expect(
        items.map((DashboardNavItem e) => e.location).toList(),
        <String>[
          '/dashboard',
          '/dashboard/opportunities',
          '/dashboard/messages',
        ],
      );
    });

    test('unhydrated fail-open keeps four primaries; services lives in More',
        () {
      final List<DashboardNavItem> items = mobilePrimaryNavItems(
        hire: true,
        offer: true,
      );
      expect(
        items.map((DashboardNavItem e) => e.location).toList(),
        <String>[
          '/dashboard',
          '/dashboard/jobs',
          '/dashboard/opportunities',
          '/dashboard/messages',
        ],
      );
      final List<DashboardNavItem> overflow = mobileOverflowNavItems(
        hire: true,
        offer: true,
      );
      expect(
        overflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/services',
        ),
        isTrue,
      );
    });

    test('offer never sees the hiring-side services entry', () {
      final List<DashboardNavItem> items = mobilePrimaryNavItems(
        hire: false,
        offer: true,
      );
      expect(
        items.any(
          (DashboardNavItem e) => e.location == '/dashboard/services',
        ),
        isFalse,
      );
      final List<DashboardNavItem> overflow = mobileOverflowNavItems(
        hire: false,
        offer: true,
      );
      expect(
        overflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/services',
        ),
        isFalse,
      );
    });

    test('overflow excludes primaries and stays mode-filtered', () {
      final List<DashboardNavItem> hireOverflow = mobileOverflowNavItems(
        hire: true,
        offer: false,
      );
      expect(
        hireOverflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/opportunities',
        ),
        isFalse,
      );
      expect(
        hireOverflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/account',
        ),
        isTrue,
      );

      final List<DashboardNavItem> offerOverflow = mobileOverflowNavItems(
        hire: false,
        offer: true,
      );
      expect(
        offerOverflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/jobs',
        ),
        isFalse,
      );
      expect(
        offerOverflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/earnings',
        ),
        isTrue,
      );
    });

    test('primary location matching covers detail routes', () {
      expect(
        isMobilePrimaryLocation(
          '/dashboard/jobs/abc',
          hire: true,
          offer: false,
        ),
        isTrue,
      );
      expect(
        isMobilePrimaryLocation(
          '/dashboard/services',
          hire: true,
          offer: false,
        ),
        isTrue,
      );
      expect(
        isMobilePrimaryLocation(
          '/dashboard/account',
          hire: true,
          offer: false,
        ),
        isFalse,
      );
    });

    test('hire overflow excludes the services primary tab', () {
      final List<DashboardNavItem> hireOverflow = mobileOverflowNavItems(
        hire: true,
        offer: false,
      );
      expect(
        hireOverflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/services',
        ),
        isFalse,
      );
      expect(
        hireOverflow.any(
          (DashboardNavItem e) => e.location == '/dashboard/jobs/new',
        ),
        isFalse,
      );
    });
  });

  group('shell bottom bar More visibility', () {
    testWidgets('hire focus renders primaries with no More tab', (
      tester,
    ) async {
      await _pumpShell(tester, await _shellOnboarding(EntityCapability.hire));
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Jobs'), findsOneWidget);
      expect(find.text('Post Job'), findsOneWidget);
      expect(find.text('Services'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      // The client drawer covers every destination — no More tab.
      expect(find.text('More'), findsNothing);
    });

    testWidgets('hire bar keeps single-line labels down to 320px', (
      tester,
    ) async {
      for (final double width in <double>[320, 360]) {
        await _pumpShell(
          tester,
          await _shellOnboarding(EntityCapability.hire),
          width: width,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'Overflow at ${width.toInt()}px');
        for (final String label in <String>[
          'Home',
          'My Jobs',
          'Post Job',
          'Services',
          'Messages',
        ]) {
          expect(find.text(label), findsOneWidget,
              reason: '$label missing at ${width.toInt()}px');
        }
      }
    });

    testWidgets('offer focus keeps More for its overflow destinations', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        await _shellOnboarding(EntityCapability.offer),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('More'), findsOneWidget);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('My Applications'), findsOneWidget);
    });

    testWidgets('fail-open keeps More while focus is unknown', (
      tester,
    ) async {
      await _pumpShell(tester, await _shellOnboarding(null));
      expect(tester.takeException(), isNull);
      expect(find.text('More'), findsOneWidget);
    });
  });

  group('DashboardMoreSheet responsive', () {
    for (final double width in <double>[320, 360, 375, 390, 414, 480, 599]) {
      testWidgets('renders without overflow at ${width.toInt()}px', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          const DashboardMoreSheet(
            location: '/dashboard/account',
            hire: true,
            offer: false,
          ),
          width: width,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('More'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        // Overflow sheet must not repeat the primary tabs.
        expect(find.text('My Jobs'), findsNothing);
      });
    }

    testWidgets('respects bottom safe area', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: DashboardMoreSheet(
            location: '/dashboard',
            hire: false,
            offer: true,
          ),
        ),
        width: 390,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SafeArea), findsWidgets);
    });
  });
}
