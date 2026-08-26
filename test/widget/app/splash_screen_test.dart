import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/startup/splash_screen.dart';
import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';

void main() {
  testWidgets('SplashScreen renders the brand logo and loader', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LogoHorizontal), findsOneWidget);
    expect(find.byType(HivorrLoader), findsOneWidget);
  });
}
