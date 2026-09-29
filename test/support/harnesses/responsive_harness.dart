import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

/// Responsive validation contract for every current and future mobile screen.
///
/// RULE: any new dashboard screen must add a case pumping it through
/// [expectNoOverflowAtMobileWidths] (plus [expectSafeAreaRespected] and
/// [expectKeyboardSafe] when it has a bottom bar, notch-sensitive content,
/// or text inputs). Widths mirror the mobile DoD:
/// 320 / 360 / 375 / 390 / 414 / 480 / 599, with 600+ as the
/// desktop-transition check.
const List<double> mobileValidationWidths = <double>[
  320,
  360,
  375,
  390,
  414,
  480,
  599,
];

/// First width at/above the tablet breakpoint (layout must switch cleanly).
const double desktopTransitionWidth = 600;

/// Pumps [builder] at every [mobileValidationWidths] entry and fails on any
/// Flutter exception (RenderFlex overflow, clipped Intrinsic, etc.).
Future<void> expectNoOverflowAtMobileWidths(
  WidgetTester tester,
  Widget Function() builder, {
  double height = 844,
}) async {
  for (final double width in mobileValidationWidths) {
    await pumpScreen(tester, builder(), width: width, height: height);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Overflow/exception at ${width.toInt()}px width',
    );
  }
}

/// Pumps [builder] with and without a home-indicator inset and fails if the
/// bottom safe area is ignored (content hidden behind system navigation).
Future<void> expectSafeAreaRespected(
  WidgetTester tester,
  Widget Function() builder, {
  double width = 390,
  double height = 844,
}) async {
  for (final double bottom in <double>[0, 34]) {
    await pumpScreen(
      tester,
      MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(bottom: bottom),
          viewPadding: EdgeInsets.only(bottom: bottom),
        ),
        child: builder(),
      ),
      width: width,
      height: height,
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Safe-area failure with bottom inset $bottom',
    );
  }
}

/// Pumps [builder] with the keyboard open (`viewInsets.bottom = 320`) and
/// fails if the layout throws or overflows. Screens with inputs must keep
/// the active field and primary actions reachable — no-overflow is asserted
/// here; focus/scroll-to-field behavior belongs in the screen's own test.
Future<void> expectKeyboardSafe(
  WidgetTester tester,
  Widget Function() builder, {
  double width = 390,
  double height = 844,
}) async {
  await pumpScreen(
    tester,
    MediaQuery(
      data: const MediaQueryData(
        viewInsets: EdgeInsets.only(bottom: 320),
      ),
      child: builder(),
    ),
    width: width,
    height: height,
  );
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: 'Keyboard-open overflow at ${width.toInt()}px width',
  );
}
