import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/systems/finance/models/deposit_name_match_status.dart';
import 'package:hivorr/systems/finance/widgets/deposit_name_match_indicator.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  AppThemeExtension extension() =>
      AppTheme.lightTheme.extension<AppThemeExtension>()!;

  Color chipColor(WidgetTester tester) {
    final Container container = tester.widget<Container>(
      find.descendant(
        of: find.byType(DepositNameMatchIndicator),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  group('DepositNameMatchIndicator (4-state tone map)', () {
    testWidgets('matched → "Match: Verified" on successContainer',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const DepositNameMatchIndicator(
          status: DepositNameMatchStatus.matched,
        ),
      );
      expect(find.text('Match: Verified'), findsOneWidget);
      expect(chipColor(tester), extension().successContainer);
    });

    testWidgets('mismatched → "Match: Failed" on errorContainer',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const DepositNameMatchIndicator(
          status: DepositNameMatchStatus.mismatched,
        ),
      );
      expect(find.text('Match: Failed'), findsOneWidget);
      expect(
        chipColor(tester),
        AppTheme.lightTheme.colorScheme.errorContainer,
      );
    });

    testWidgets('pending → "Match: Pending" on warningContainer',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const DepositNameMatchIndicator(
          status: DepositNameMatchStatus.pending,
        ),
      );
      expect(find.text('Match: Pending'), findsOneWidget);
      expect(chipColor(tester), extension().warningContainer);
    });

    testWidgets('unverified → "Match: Unverified" on surfaceContainerHighest',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const DepositNameMatchIndicator(
          status: DepositNameMatchStatus.unverified,
        ),
      );
      expect(find.text('Match: Unverified'), findsOneWidget);
      expect(
        chipColor(tester),
        AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('renders a status icon alongside the label',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const DepositNameMatchIndicator(
          status: DepositNameMatchStatus.matched,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DepositNameMatchIndicator),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('draws on the dark theme without custom colors',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const DepositNameMatchIndicator(
          status: DepositNameMatchStatus.matched,
        ),
        dark: true,
      );
      expect(find.text('Match: Verified'), findsOneWidget);
    });
  });
}