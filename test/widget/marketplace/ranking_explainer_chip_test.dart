import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/systems/marketplace/widgets/ranking_explainer_chip.dart';

import '../../support/harnesses/widget_harness.dart';

void main() {
  group('RankingExplainerChip', () {
    testWidgets('opens the explainability dialog on tap', (
      WidgetTester tester,
    ) async {
      await pumpTheme(tester, const RankingExplainerChip());
      await tester.pumpAndSettle();

      expect(find.text('Ranked fairly · Why?'), findsOneWidget);

      await tester.tap(find.byType(RankingExplainerChip));
      await tester.pumpAndSettle();

      expect(find.text('How ranking works'), findsOneWidget);
      expect(find.textContaining('verifiable signals'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('How ranking works'), findsNothing);
    });
  });
}
