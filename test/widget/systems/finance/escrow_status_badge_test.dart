import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';
import 'package:hivorr/systems/finance/widgets/escrow_status_badge.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  AppThemeExtension extension() =>
      AppTheme.lightTheme.extension<AppThemeExtension>()!;

  Color chipColor(WidgetTester tester, Type badgeType) {
    final Container container = tester.widget<Container>(
      find.descendant(
        of: find.byType(badgeType),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  group('EscrowStatusBadge (7-state tone map)', () {
    testWidgets('created → "Awaiting funding" on warningContainer',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[0]));
      expect(find.text('Awaiting funding'), findsOneWidget);
      expect(chipColor(tester, EscrowStatusBadge), extension().warningContainer);
    });

    testWidgets('funded → "Funded & held" on primaryContainer',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[1]));
      expect(find.text('Funded & held'), findsOneWidget);
      expect(
        chipColor(tester, EscrowStatusBadge),
        AppTheme.lightTheme.colorScheme.primaryContainer,
      );
    });

    testWidgets('partially_released → "Milestones releasing" on primaryContainer',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[2]));
      expect(find.text('Milestones releasing'), findsOneWidget);
      expect(
        chipColor(tester, EscrowStatusBadge),
        AppTheme.lightTheme.colorScheme.primaryContainer,
      );
    });

    testWidgets('released → "Released to provider" on successContainer',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[3]));
      expect(find.text('Released to provider'), findsOneWidget);
      expect(chipColor(tester, EscrowStatusBadge), extension().successContainer);
    });

    testWidgets('refunded → "Refunded to payer" on surfaceVariant neutral',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[4]));
      expect(find.text('Refunded to payer'), findsOneWidget);
      expect(
        chipColor(tester, EscrowStatusBadge),
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('cancelled → "Cancelled" on surfaceVariant neutral',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[5]));
      expect(find.text('Cancelled'), findsOneWidget);
      expect(
        chipColor(tester, EscrowStatusBadge),
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('disputed → "In dispute — frozen" on errorContainer',
        (WidgetTester tester) async {
      await pumpTheme(tester, EscrowStatusBadge(status: escrowStatuses[6]));
      expect(find.text('In dispute — frozen'), findsOneWidget);
      expect(
        chipColor(tester, EscrowStatusBadge),
        AppTheme.lightTheme.colorScheme.errorContainer,
      );
    });
  });

  group('MilestoneStatusBadge (3-state tone map)', () {
    testWidgets('pending → "Pending" on surfaceContainerHighest',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        MilestoneStatusBadge(status: milestoneStatuses[0]),
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(
        chipColor(tester, MilestoneStatusBadge),
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('completed → "Completed — awaiting release" on primaryContainer',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        MilestoneStatusBadge(status: milestoneStatuses[1]),
      );
      expect(find.text('Completed — awaiting release'), findsOneWidget);
      expect(
        chipColor(tester, MilestoneStatusBadge),
        AppTheme.lightTheme.colorScheme.primaryContainer,
      );
    });

    testWidgets('released → "Released" on successContainer',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        MilestoneStatusBadge(status: milestoneStatuses[2]),
      );
      expect(find.text('Released'), findsOneWidget);
      expect(
        chipColor(tester, MilestoneStatusBadge),
        extension().successContainer,
      );
    });
  });
}