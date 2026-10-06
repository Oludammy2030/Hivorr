import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/shared/components/hivorr_month_bars.dart';

Widget _harness(List<HivorrMonthDatum> items) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: HivorrMonthBars(items: items)),
  );
}

void main() {
  group('HivorrMonthBars', () {
    testWidgets('renders labeled bars for a real series', (tester) async {
      await tester.pumpWidget(
        _harness(const <HivorrMonthDatum>[
          HivorrMonthDatum(label: 'Jan', value: 2),
          HivorrMonthDatum(label: 'Feb', value: 5),
        ]),
      );
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('renders the honest empty state for empty series', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const <HivorrMonthDatum>[]));
      expect(find.text('No activity yet.'), findsOneWidget);
    });

    testWidgets('renders the honest empty state for all-zero series', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const <HivorrMonthDatum>[
          HivorrMonthDatum(label: 'Jan', value: 0),
          HivorrMonthDatum(label: 'Feb', value: 0),
        ]),
      );
      expect(find.text('No activity yet.'), findsOneWidget);
      expect(find.text('Jan'), findsNothing);
    });

    testWidgets('renders in dark theme without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: HivorrMonthBars(
              items: <HivorrMonthDatum>[
                HivorrMonthDatum(label: 'Jan', value: 1),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Jan'), findsOneWidget);
    });
  });
}
