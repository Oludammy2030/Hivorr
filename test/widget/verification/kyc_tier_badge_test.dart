import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/systems/verification/widgets/kyc_tier_badge.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  KycLevel level(String tier, String status, {KycLimits? limits}) => KycLevel(
        tierCode: tier,
        status: status,
        limits: limits ??
            const KycLimits(daily: 0, weekly: 0, monthly: 0, cashout: 0),
      );

  Future<void> pumpBadge(WidgetTester tester, KycLevel l) =>
      pumpTheme(tester, KycTierBadge(level: l));

  group('KycTierBadge label', () {
    testWidgets('renders the tier display label', (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'active'));
      expect(find.text('Basic'), findsOneWidget);
    });

    testWidgets('renders the raw tier code', (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'active'));
      expect(find.text('tier_1'), findsOneWidget);
    });
  });

  group('KycTierBadge status chip', () {
    testWidgets('active status shows the Active chip', (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'active'));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('pending status shows the Pending chip', (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'pending'));
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('expired status shows the Expired chip', (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'expired'));
      expect(find.text('Expired'), findsOneWidget);
    });
  });

  group('KycTierBadge icon', () {
    testWidgets('verified tiers render a verified icon',
        (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'active'));
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('unverified tiers render a lock icon',
        (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_0', 'pending'));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('KycTierBadge design tokens', () {
    testWidgets('uses rounded medium corners from the theme extension',
        (WidgetTester tester) async {
      await pumpBadge(tester, level('tier_1', 'active'));
      final Container container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final BorderRadiusGeometry radius =
          container.decoration is BoxDecoration
              ? ((container.decoration as BoxDecoration?)?.borderRadius ??
                  BorderRadius.zero)
              : BorderRadius.zero;
      expect(
        radius,
        isA<BorderRadius>().having(
          (BorderRadius r) => r.topLeft.x,
          'topLeft.x',
          greaterThan(0),
        ),
      );
    });
  });
}
