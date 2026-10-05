import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_spot_illustration.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('HivorrSpotIllustration', () {
    testWidgets('renders every variant without throwing', (tester) async {
      for (final HivorrSpotVariant variant in HivorrSpotVariant.values) {
        await tester.pumpWidget(
          _harness(HivorrSpotIllustration(variant: variant)),
        );
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('renders in dark theme without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: HivorrSpotIllustration(
              variant: HivorrSpotVariant.messages,
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('HivorrEmptyState illustration default', () {
    testWidgets('shows the spot illustration when no icon is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const HivorrEmptyState(title: 'Nothing here')),
      );
      expect(find.byType(HivorrSpotIllustration), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('explicit icon still wins over the illustration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const HivorrEmptyState(
            title: 'Nothing here',
            icon: Icon(Icons.search),
          ),
        ),
      );
      expect(find.byType(HivorrSpotIllustration), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
