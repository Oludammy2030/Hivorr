import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';

import '../../support/harnesses/responsive_harness.dart';
import '../../support/harnesses/widget_harness.dart';

void main() {
  group('MobileCompact contract', () {
    test('compact boundary mirrors the 600dp breakpoint', () {
      expect(MobileCompact.compactStart, Breakpoints.tabletStart);
      expect(MobileCompact.isCompactWidth(599), isTrue);
      expect(MobileCompact.isCompactWidth(600), isFalse);
    });

    test('scroll padding is compact on phones, reference otherwise', () {
      expect(
        MobileCompact.scrollPaddingFor(320),
        MobileCompact.scrollPadding,
      );
      expect(
        MobileCompact.scrollPaddingFor(599),
        MobileCompact.scrollPadding,
      );
      expect(
        MobileCompact.scrollPaddingFor(600),
        MobileCompact.desktopScrollPadding,
      );
      expect(
        MobileCompact.scrollPaddingForBreakpoint(Breakpoint.mobile),
        MobileCompact.scrollPadding,
      );
      expect(
        MobileCompact.scrollPaddingForBreakpoint(Breakpoint.tablet),
        MobileCompact.desktopScrollPadding,
      );
    });

    test('section rhythm stays compact but not crowded', () {
      expect(MobileCompact.sectionGapFor(390), HivorrSpacing.md);
      expect(MobileCompact.sectionGapFor(1024), HivorrSpacing.lg);
      expect(MobileCompact.minorGapFor(390), HivorrSpacing.sm);
      expect(MobileCompact.minorGapFor(1024), HivorrSpacing.md);
    });

    test('two-column grids collapse at 320px', () {
      expect(MobileCompact.fitsTwoColumns(360), isTrue);
      expect(MobileCompact.fitsTwoColumns(320), isFalse);
      expect(MobileCompact.twoColumnWidth(360), 176);
    });

    test('bubble ceiling never overflows 320px', () {
      expect(MobileCompact.bubbleMaxWidth(320), 240);
      expect(MobileCompact.bubbleMaxWidth(390), 292.5);
    });
  });

  group('MobileSafeBody', () {
    testWidgets('opens the bottom for the shell bottom bar', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, const MobileSafeBody(child: Text('body')));
      final SafeArea safe = tester.widget<SafeArea>(find.byType(SafeArea));
      expect(safe.top, isTrue);
      expect(safe.bottom, isFalse);
    });
  });

  group('ResponsiveScrollPadding', () {
    testWidgets('uses compact padding on phones', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ResponsiveScrollPadding(child: Text('content')),
        width: 390,
      );
      final SingleChildScrollView scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.padding, MobileCompact.scrollPadding);
    });

    testWidgets('keeps reference padding on desktop', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ResponsiveScrollPadding(child: Text('content')),
        width: 1024,
      );
      final SingleChildScrollView scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.padding, MobileCompact.desktopScrollPadding);
    });

    testWidgets('no overflow across the mobile width matrix', (
      WidgetTester tester,
    ) async {
      await expectNoOverflowAtMobileWidths(
        tester,
        () => const ResponsiveScrollPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'A very long title that must wrap instead of clipping '
                'on narrow phones at 320 logical pixels wide',
              ),
              Text('Body copy wraps the same way.'),
            ],
          ),
        ),
      );
    });

    testWidgets('respects home-indicator insets', (
      WidgetTester tester,
    ) async {
      await expectSafeAreaRespected(
        tester,
        () => const ResponsiveScrollPadding(child: Text('content')),
      );
    });
  });
}
