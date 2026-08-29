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

/// Pumps [child] at a fixed viewport [width] x [height], wrapping via
/// [pumpApp]. The viewport is restored in a `tearDown` even if the test body
/// throws (EP-01-19 DoD).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double height = 844,
  List<SingleChildWidget>? providers,
  bool dark = false,
}) async {
  final Size previous = tester.view.physicalSize;
  tester.view.physicalSize = Size(width, height);
  addTearDown(() => tester.view.physicalSize = previous);
  await pumpApp(tester, child, providers: providers, dark: dark);
}
