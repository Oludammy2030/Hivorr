import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/shared/components/hivorr_entrance.dart';

Widget _harness({required int index}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: HivorrEntrance(
        key: ValueKey<String>('entrance-$index'),
        index: index,
        child: const Text('card body'),
      ),
    ),
  );
}

void main() {
  group('HivorrEntrance', () {
    testWidgets('renders the child through the entrance', (tester) async {
      await tester.pumpWidget(_harness(index: 0));
      expect(find.text('card body'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('card body'), findsOneWidget);
    });

    testWidgets('late items settle without throwing', (tester) async {
      await tester.pumpWidget(_harness(index: 99));
      expect(find.text('card body'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('card body'), findsOneWidget);
    });
  });
}
