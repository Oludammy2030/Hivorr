import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/shared/widgets/hivorr_celebration.dart';
import 'package:hivorr/shared/widgets/hivorr_success_state.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('HivorrCelebration', () {
    testWidgets('plays once and settles on the mark', (tester) async {
      await tester.pumpWidget(
        _harness(
          const HivorrCelebration(
            child: Icon(Icons.check_circle_outline),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('HivorrSuccessState celebrate flag', () {
    testWidgets('celebrate wraps the mark, default does not', (tester) async {
      await tester.pumpWidget(
        _harness(
          const HivorrSuccessState(title: 'Done', celebrate: true),
        ),
      );
      expect(find.byType(HivorrCelebration), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _harness(const HivorrSuccessState(title: 'Done')),
      );
      expect(find.byType(HivorrCelebration), findsNothing);
      await tester.pumpAndSettle();
    });
  });
}
