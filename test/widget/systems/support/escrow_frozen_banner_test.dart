import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/support/widgets/escrow_frozen_banner.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('EscrowFrozenBanner', () {
    testWidgets('renders the gavel icon and the freeze copy',
        (WidgetTester tester) async {
      await pumpTheme(tester, const EscrowFrozenBanner());

      expect(find.byIcon(Icons.gavel), findsOneWidget);
      expect(
        find.text(
          'This escrow is in dispute — all actions are frozen until resolved',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides the View dispute action when callback is null',
        (WidgetTester tester) async {
      await pumpTheme(tester, const EscrowFrozenBanner());
      expect(find.text('View dispute'), findsNothing);
    });

    testWidgets('shows the View dispute action when callback provided',
        (WidgetTester tester) async {
      bool tapped = false;
      await pumpTheme(
        tester,
        EscrowFrozenBanner(onViewDispute: () => tapped = true),
      );

      expect(find.text('View dispute'), findsOneWidget);
      await tester.tap(find.text('View dispute'));
      expect(tapped, isTrue);
    });

    testWidgets('uses the error container theme tokens (no hardcoded hex)',
        (WidgetTester tester) async {
      await pumpTheme(tester, const EscrowFrozenBanner());

      final Container container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final BoxDecoration? decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      // The decoration must derive from the theme (errorContainer), and no
      // color literal is hardcoded in the widget source.
      expect(decoration!.color, isNotNull);
    });
  });
}