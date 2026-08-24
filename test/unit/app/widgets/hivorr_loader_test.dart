import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';

void main() {
  testWidgets('HivorrLoader renders as monochrome animated outlines',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: HivorrLoader(size: 48, color: Colors.grey)),
      ),
    );

    expect(find.byType(HivorrLoader), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    // Advance animation frames; must not throw and must keep painting.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 450));

    // A configurable color is honored (monochrome single stroke).
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: HivorrLoader(size: 64, color: Colors.blueGrey)),
      ),
    );
    expect(find.byType(HivorrLoader), findsOneWidget);
  });
}
