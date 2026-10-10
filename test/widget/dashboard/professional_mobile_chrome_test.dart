import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/systems/dashboard/shell/professional_mobile_chrome.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('ProfessionalMobileAppBar (shared mobile chrome)', () {
    Future<void> pumpBar(
      WidgetTester tester,
      String title, {
      double width = 390,
    }) async {
      await pumpScreen(
        tester,
        Scaffold(appBar: ProfessionalMobileAppBar(title: title)),
        width: width,
        height: 844,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('single 48dp bar: title + bell + pill + avatar, no menu', (
      tester,
    ) async {
      await pumpBar(tester, 'Dashboard');
      expect(find.byType(AppBar), findsOneWidget);
      final AppBar bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.toolbarHeight, 48);
      expect(bar.preferredSize.height, 48);
      expect(find.text('Dashboard'), findsOneWidget);
      // Professional chrome carries no drawer.
      expect(find.byTooltip('Menu'), findsNothing);
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('professional-indicator')),
        findsOneWidget,
      );
      expect(find.text('Professional'), findsWidgets);
      expect(find.byTooltip('Profile'), findsOneWidget);
      // Client chrome never leaks into the professional bar.
      expect(
        find.byKey(const ValueKey<String>('client-indicator')),
        findsNothing,
      );
    });

    testWidgets('pill + avatar use the professional green identity', (
      tester,
    ) async {
      await pumpBar(tester, 'Find Work');
      const RoleThemeExtension roles = RoleThemeExtension.light;
      final Container pill = tester.widget<Container>(
        find.byKey(const ValueKey<String>('professional-indicator')),
      );
      final BoxDecoration pillDecor = pill.decoration! as BoxDecoration;
      expect(pillDecor.color, roles.professionalContainer);
    });

    testWidgets('dark theme resolves the dark professional container', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(appBar: ProfessionalMobileAppBar(title: 'Earnings')),
        width: 390,
        height: 844,
        dark: true,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final Container pill = tester.widget<Container>(
        find.byKey(const ValueKey<String>('professional-indicator')),
      );
      final BoxDecoration pillDecor = pill.decoration! as BoxDecoration;
      expect(
        pillDecor.color,
        RoleThemeExtension.dark.professionalContainer,
      );
    });

    for (final double width in <double>[320, 360, 390]) {
      testWidgets('no overflow at ${width.toInt()}px', (tester) async {
        await pumpBar(tester, 'My Applications', width: width);
        expect(tester.takeException(), isNull);
        expect(find.text('My Applications'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('professional-indicator')),
          findsOneWidget,
        );
      });
    }
  });
}
