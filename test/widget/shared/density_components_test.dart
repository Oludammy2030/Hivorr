import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_capability_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('HivorrStatCard', () {
    testWidgets('renders label, value and sub', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const HivorrStatCard(
          icon: Icons.people_outlined,
          iconBackground: Colors.blue,
          iconForeground: Colors.white,
          label: 'Total Users',
          value: '52,381',
          sub: '+12% MTD',
        ),
      );
      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('52,381'), findsOneWidget);
      expect(find.text('+12% MTD'), findsOneWidget);
    });

    testWidgets('fires onTap', (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrStatCard(
          icon: Icons.people_outlined,
          iconBackground: Colors.blue,
          iconForeground: Colors.white,
          label: 'Total Users',
          value: '52,381',
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.byType(HivorrStatCard));
      expect(tapped, isTrue);
    });

    testWidgets('compact uses the 22sp titleLarge value', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const HivorrStatCard(
          compact: true,
          icon: Icons.people_outlined,
          iconBackground: Colors.blue,
          iconForeground: Colors.white,
          label: 'Total Users',
          value: '52,381',
        ),
      );
      final Text value = tester.widget(find.text('52,381'));
      expect(value.style?.fontSize, 22);
      expect(value.style?.fontWeight, FontWeight.w700);
    });
  });

  group('HivorrStatGrid', () {
    testWidgets('lays out one card per column', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        HivorrStatGrid(
          columns: 3,
          maxWidth: 1200,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              const HivorrStatCard(
                icon: Icons.star_outline,
                iconBackground: Colors.blue,
                iconForeground: Colors.white,
                label: 'L',
                value: '1',
              ),
          ],
        ),
      );
      expect(find.byType(HivorrStatCard), findsNWidgets(3));
    });
  });

  group('HivorrTableAction', () {
    testWidgets('renders label and fires onTap', (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrTableAction(
          label: 'View',
          foreground: Colors.blue,
          background: Colors.lightBlue,
          onTap: () => tapped = true,
        ),
      );
      expect(find.text('View'), findsOneWidget);
      await tester.tap(find.text('View'));
      expect(tapped, isTrue);
    });
  });

  group('HivorrCapabilityBadge', () {
    testWidgets('maps hire/offer vocabularies; retired both is neutral', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const Column(
          children: <Widget>[
            HivorrCapabilityBadge(capability: 'hire'),
            HivorrCapabilityBadge(capability: 'offer'),
            HivorrCapabilityBadge(capability: 'both'),
          ],
        ),
      );
      expect(find.text('Employer'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);
      // The retired value renders raw in a neutral badge — never hidden.
      expect(find.text('both'), findsOneWidget);
      expect(find.text('Both'), findsNothing);
    });

    testWidgets('falls back to dash and raw labels', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const Column(
          children: <Widget>[
            HivorrCapabilityBadge(capability: null),
            HivorrCapabilityBadge(capability: 'custom-role'),
          ],
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('custom-role'), findsOneWidget);
    });
  });

  group('HivorrBadge neutral', () {
    testWidgets('renders a non-semantic label', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const HivorrBadge(
          label: 'Deactivated',
          variant: HivorrBadgeVariant.neutral,
        ),
      );
      expect(find.text('Deactivated'), findsOneWidget);
    });
  });

  group('HivorrDashboardTopBar', () {
    testWidgets('renders title, mode pill, avatar and bell', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        HivorrDashboardTopBar(
          title: 'Dashboard',
          accentPrimary: Colors.blue,
          accentContainer: Colors.lightBlue,
          modeLabel: 'Client',
          initials: 'TV',
          showDot: true,
          onMenu: () {},
          onNotifications: () {},
          onAvatar: () {},
        ),
      );
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('hides menu and bell when callbacks are null', (
      WidgetTester tester,
    ) async {
      await pumpTheme(
        tester,
        const HivorrDashboardTopBar(
          title: 'Dashboard',
          accentPrimary: Colors.blue,
          accentContainer: Colors.lightBlue,
          modeLabel: 'Client',
          initials: 'TV',
        ),
      );
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.text('Client'), findsOneWidget);
    });

    testWidgets('HivorrTopBarTile fires onTap', (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        HivorrTopBarTile(
          tooltip: 'Menu',
          icon: Icons.menu,
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.byType(HivorrTopBarTile));
      expect(tapped, isTrue);
    });
  });

  group('HivorrTextField search support', () {
    testWidgets('fires onSubmitted on search action', (
      WidgetTester tester,
    ) async {
      String? submitted;
      await pumpTheme(
        tester,
        HivorrTextField(
          hint: 'Search users...',
          textInputAction: TextInputAction.search,
          onSubmitted: (String value) => submitted = value,
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, 'ada');
    });
  });
}
