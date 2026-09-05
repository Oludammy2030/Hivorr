import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/finance/widgets/escrow_write_cta_panel.dart';

import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('EscrowWriteCtaPanel — write seam off (production default)', () {
    testWidgets('shows support guidance and no write action buttons',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const EscrowWriteCtaPanel(writeAvailable: false),
      );

      expect(
        find.text('Escrow actions are handled by our support team'),
        findsOneWidget,
      );
      expect(find.text('Complete milestone'), findsNothing);
      expect(find.text('Release milestone'), findsNothing);
      expect(find.text('Release final payment'), findsNothing);
      expect(find.text('Refund escrow'), findsNothing);
    });

    testWidgets('renders a Contact support action when a handler is provided',
        (WidgetTester tester) async {
      var contacted = false;
      await pumpTheme(
        tester,
        EscrowWriteCtaPanel(
          writeAvailable: false,
          onContactSupport: () => contacted = true,
        ),
      );

      await tester.tap(find.text('Contact support'));
      expect(contacted, isTrue);
    });

    testWidgets('omits the Contact support action without a handler',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const EscrowWriteCtaPanel(writeAvailable: false),
      );
      expect(find.text('Contact support'), findsNothing);
    });
  });

  group('EscrowWriteCtaPanel — write seam on (future)', () {
    testWidgets('renders the four provider actions as HivorrButtons',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const EscrowWriteCtaPanel(writeAvailable: true),
      );

      expect(find.text('Complete milestone'), findsOneWidget);
      expect(find.text('Release milestone'), findsOneWidget);
      expect(find.text('Release final payment'), findsOneWidget);
      expect(find.text('Refund escrow'), findsOneWidget);
      expect(find.byType(HivorrButton), findsNWidgets(4));
    });

    testWidgets('enabled actions fire their callbacks',
        (WidgetTester tester) async {
      var completed = false;
      var finalReleased = false;
      await pumpTheme(
        tester,
        EscrowWriteCtaPanel(
          writeAvailable: true,
          onCompleteMilestone: () => completed = true,
          onReleaseFinal: () => finalReleased = true,
        ),
      );

      await tester.tap(find.text('Complete milestone'));
      await tester.tap(find.text('Release final payment'));
      expect(completed, isTrue);
      expect(finalReleased, isTrue);
    });

    testWidgets('disputed escrow disables every action even when writable',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const EscrowWriteCtaPanel(writeAvailable: true, isDisputed: true),
      );

      final List<HivorrButton> buttons =
          tester.widgetList<HivorrButton>(find.byType(HivorrButton)).toList();
      expect(buttons, hasLength(4));
      expect(
        buttons.map((HivorrButton b) => b.onPressed),
        everyElement(isNull),
      );
    });

    testWidgets('isBusy marks the primary action as loading and disabled',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        const EscrowWriteCtaPanel(
          writeAvailable: true,
          isBusy: true,
          onCompleteMilestone: null,
        ),
      );

      final HivorrButton primary = tester.widget<HivorrButton>(
        find.byType(HivorrButton).first,
      );
      expect(primary.isLoading, isTrue);
      expect(primary.onPressed, isNull);
    });
  });
}