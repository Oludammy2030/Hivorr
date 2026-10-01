import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_sidebar.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('DashboardSidebar capability filtering', () {
    Future<void> pumpSidebar(
      WidgetTester tester,
      DashboardCapability capability,
    ) => pumpApp(
      tester,
      SizedBox(
        width: 300,
        height: 1600,
        child: DashboardSidebar(location: '/dashboard', capability: capability),
      ),
    );

    testWidgets('hire sees hiring + shared sections', (
      WidgetTester tester,
    ) async {
      await pumpSidebar(tester, DashboardCapability.hire);
      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.text('My Jobs'), findsOneWidget);
      expect(find.text('Applications'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('MY HIRING'), findsOneWidget);
      expect(find.text('Find Jobs'), findsNothing);
      expect(find.text('My Applications'), findsNothing);
      expect(find.text('Earnings'), findsNothing);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('offer sees the Professional Dashboard reference nav', (
      WidgetTester tester,
    ) async {
      // Tall viewport: the sidebar ListView lazily builds only visible
      // children, and the MORE overflow sits below the default fold.
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      await pumpSidebar(tester, DashboardCapability.offer);
      // Reference primaries (green Professional identity).
      expect(find.text('Professional Dashboard'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Find Work'), findsOneWidget);
      expect(find.text('My Jobs'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Portfolio'), findsNothing);
      // Preserved overflow: remaining work/shared destinations live under
      // MORE instead of being removed.
      expect(find.text('MORE'), findsOneWidget);
      expect(find.text('My Applications'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      // Hiring-side destinations stay hidden for professional-only.
      expect(find.text('Post a Job'), findsNothing);
      expect(find.text('Applications'), findsNothing);
      expect(find.text('Payments'), findsNothing);
    });

    testWidgets('both sees the combined navigation with headers', (
      WidgetTester tester,
    ) async {
      // Tall viewport: the sidebar ListView lazily builds only visible
      // children, and the SHARED section sits below the default fold.
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      await pumpSidebar(tester, DashboardCapability.both);
      expect(find.text('Find Jobs'), findsOneWidget);
      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.text('MY WORK'), findsOneWidget);
      expect(find.text('MY HIRING'), findsOneWidget);
      expect(find.text('SHARED'), findsOneWidget);
      expect(find.text('CLIENT'), findsNothing);
      expect(find.text('BOTH'), findsOneWidget);
    });
  });

  group('HiringStatusBadge', () {
    testWidgets('renders known codes with labels', (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Column(
          children: <Widget>[
            HiringStatusBadge(code: 'open'),
            HiringStatusBadge(code: 'shortlisted'),
            HiringStatusBadge(code: 'completed'),
          ],
        ),
      );
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Shortlisted'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('falls back to the raw code when unknown', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const HiringStatusBadge(code: 'mystery'));
      expect(find.text('mystery'), findsOneWidget);
    });
  });
}
