import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_more_sheet.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('mobilePrimaryNavItems', () {
    test('hire-only sees Home + Hiring + Services + Messages', () {
      final List<DashboardNavItem> items = mobilePrimaryNavItems(
        hire: true,
        offer: false,
      );
      expect(
        items.map((DashboardNavItem e) => e.location).toList(),
        <String>[
          '/dashboard',
          '/dashboard/jobs',
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
        expect(find.text('Hiring'), findsNothing);
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
