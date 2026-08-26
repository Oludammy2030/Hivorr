import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/app/theme/app_theme.dart';

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
