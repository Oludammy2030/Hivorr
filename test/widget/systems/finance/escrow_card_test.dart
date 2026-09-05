import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/finance/widgets/escrow_card.dart';

import '../../../support/fakes/finance/fake_escrow_repository.dart';
import '../../../support/harnesses/widget_harness.dart';

void main() {
  group('EscrowCard.truncateReference', () {
    test('hides short and absent references behind the mask', () {
      expect(EscrowCard.truncateReference(null), '***');
      expect(EscrowCard.truncateReference(''), '***');
      expect(EscrowCard.truncateReference('AB'), '***AB');
    });

    test('masks longer references to last 4 characters', () {
      expect(
        EscrowCard.truncateReference('ORD-2026-000123'),
        '***0123',
      );
    });
  });

  group('EscrowCard', () {
    testWidgets('renders badge, formatted amount, held value and masked ref',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        EscrowCard(escrow: seedEscrowEntity()),
      );

      expect(find.text('\u20A650,000.00'), findsOneWidget);
      expect(find.text('Held: \u20A650,000.00'), findsOneWidget);
      expect(find.text('Funded & held'), findsOneWidget);
      expect(find.text('Ref ***0123'), findsOneWidget);
      expect(find.text('ORD-2026-000123'), findsNothing);
    });

    testWidgets('includes the created date', (WidgetTester tester) async {
      await pumpTheme(
        tester,
        EscrowCard(escrow: seedEscrowEntity()),
      );

      final DateTime created = DateTime.fromMillisecondsSinceEpoch(1000);
      expect(
        find.text(
          '${created.day}/${created.month}/${created.year}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders released_held split when amounts differ',
        (WidgetTester tester) async {
      await pumpTheme(
        tester,
        EscrowCard(
          escrow: seedEscrowEntity(
            totalAmount: 50000,
            releasedAmount: 20000,
          ),
        ),
      );

      expect(find.text('\u20A650,000.00'), findsOneWidget);
      expect(find.text('Held: \u20A630,000.00'), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (WidgetTester tester) async {
      var tapped = false;
      await pumpTheme(
        tester,
        EscrowCard(
          escrow: seedEscrowEntity(),
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.text('Funded & held'));
      expect(tapped, isTrue);
    });
  });
}