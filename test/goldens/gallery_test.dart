import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/gallery/gallery.dart';

void main() {
  for (final bool dark in <bool>[false, true]) {
    testWidgets('gallery ${dark ? 'dark' : 'light'}', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: const Gallery(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(Gallery),
        matchesGoldenFile('gallery_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }
}
