import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_sidebar.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_mode_toggle.dart';
import 'package:provider/provider.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('DashboardViewModeProvider (UI-only)', () {
    test('defaults to professional and filters both without touching roles', () {
      final DashboardViewModeProvider provider = DashboardViewModeProvider();
      expect(provider.mode, DashboardViewMode.professional);
      expect(
        provider.effectiveShowsWork(DashboardCapability.both),
        isTrue,
      );
      expect(
        provider.effectiveShowsHiring(DashboardCapability.both),
        isFalse,
      );
      // Single-role capabilities pass through unchanged.
      expect(
        provider.effectiveShowsHiring(DashboardCapability.hire),
        isTrue,
      );
      expect(
        provider.effectiveShowsWork(DashboardCapability.offer),
        isTrue,
      );
    });

    test('setMode switches effective visibility', () {
      final DashboardViewModeProvider provider = DashboardViewModeProvider();
      provider.setMode(DashboardViewMode.client);
      expect(provider.mode, DashboardViewMode.client);
      expect(
        provider.effectiveShowsHiring(DashboardCapability.both),
        isTrue,
      );
      expect(
        provider.effectiveShowsWork(DashboardCapability.both),
        isFalse,
      );
    });
  });

  group('DashboardSidebar mode filtering', () {
    Future<void> pumpModeSidebar(
      WidgetTester tester,
      DashboardViewMode mode,
    ) =>
        pumpApp(
          tester,
          ChangeNotifierProvider<DashboardViewModeProvider>(
            create: (_) => DashboardViewModeProvider()..setMode(mode),
            child: SizedBox(
              width: 300,
              height: 1600,
              child: Builder(
                builder: (BuildContext context) {
                  final DashboardViewMode current = context
                      .watch<DashboardViewModeProvider>()
                      .mode;
                  return DashboardSidebar(
                    location: '/dashboard',
                    capability: DashboardCapability.both,
                    viewMode: current,
                  );
                },
              ),
            ),
          ),
        );

    testWidgets('professional mode shows the reference nav, hides hiring', (
      WidgetTester tester,
    ) async {
      // Tall viewport: the MORE overflow sits below the default fold.
      final Size previousPhysical = tester.view.physicalSize;
      final double previousDpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = previousPhysical;
        tester.view.devicePixelRatio = previousDpr;
      });
      await pumpModeSidebar(tester, DashboardViewMode.professional);
      expect(find.text('Professional Dashboard'), findsOneWidget);
      expect(find.text('Find Work'), findsOneWidget);
      expect(find.text('My Jobs'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Portfolio'), findsNothing);
      expect(find.text('Post a Job'), findsNothing);
      expect(find.text('Payments'), findsNothing);
      // Toggle itself is visible with a clear active state.
      expect(find.text('Professional'), findsWidgets);
      expect(find.text('Client'), findsOneWidget);
    });

    testWidgets('client mode shows hiring, hides work', (
      WidgetTester tester,
    ) async {
      await pumpModeSidebar(tester, DashboardViewMode.client);
      expect(find.text('Post a Job'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Find Jobs'), findsNothing);
      expect(find.text('Earnings'), findsNothing);
      expect(find.text('Professional'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
    });
  });

  group('DashboardModeToggle', () {
    testWidgets('tapping Client switches operating mode', (
      WidgetTester tester,
    ) async {
      final DashboardViewModeProvider provider = DashboardViewModeProvider();
      await pumpApp(
        tester,
        ChangeNotifierProvider<DashboardViewModeProvider>.value(
          value: provider,
          child: const Scaffold(body: DashboardModeToggle()),
        ),
      );
      expect(provider.mode, DashboardViewMode.professional);
      await tester.tap(find.text('Client'));
      await tester.pumpAndSettle();
      expect(provider.mode, DashboardViewMode.client);
    });
  });
}
