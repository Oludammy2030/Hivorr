import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Pumps [child] inside a [MaterialApp] using the Hivorr theme tokens so the
/// design-system widgets resolve their [AppThemeExtension] / [ColorScheme].
Future<void> pumpTheme(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps [child] inside a themed [MaterialApp], optionally injecting
/// [Provider]s via [providers].
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<SingleChildWidget>? providers,
  bool dark = false,
}) async {
  final Widget app = MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  );
  if (providers == null || providers.isEmpty) {
    await tester.pumpWidget(app);
  } else {
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: app),
    );
  }
}

/// Pumps [child] at a fixed logical viewport [width] x [height], normalizing
/// [devicePixelRatio] to 1 so the physical size maps 1:1 to logical pixels
/// (matching `design_system_integration_test` / `escrow_detail_screen_test`).
/// The viewport is restored in a `tearDown` even if the test body throws
/// (EP-01-19 DoD).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double height = 844,
  List<SingleChildWidget>? providers,
  bool dark = false,
}) async {
  final Size previousPhysical = tester.view.physicalSize;
  final double previousDpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = previousPhysical;
    tester.view.devicePixelRatio = previousDpr;
  });
  await pumpApp(tester, child, providers: providers, dark: dark);
}
