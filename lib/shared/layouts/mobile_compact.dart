import 'package:flutter/material.dart';

import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';

/// Responsive contract for every dashboard/mobile screen (<600dp).
///
/// RULE FOR FUTURE SCREENS — follow this instead of inventing ad-hoc
/// padding/gaps, otherwise the 320–599px validation will fail:
///
/// 1. Wrap the screen body in [MobileSafeBody] (top safe, bottom open — the
///    dashboard shell's bottom navigation owns the bottom inset).
/// 2. Use [MobileCompact.scrollPaddingFor] (or [ResponsiveScrollPadding])
///    for scroll roots: 16dp sides on phones, 24dp on tablet/desktop, with
///    32dp bottom clearance so the last card clears the bottom bar.
/// 3. Use [MobileCompact.sectionGapFor] for vertical rhythm: 24dp on phones,
///    32dp otherwise. Never leave `xl` gaps stacked on a phone.
/// 4. Never use fixed chip/card widths (e.g. 132dp). Use
///    [MobileCompact.twoColumnWidth] (>=360dp) with a single-column fallback
///    at 320dp, and clamp chat bubbles with [MobileCompact.bubbleMaxWidth].
/// 5. Wrap chat/message composers in `SafeArea(top: false, bottom: true)`
///    and rely on the Scaffold resize for the keyboard (no manual
///    `viewInsets` padding — that double-offsets above the keyboard).
/// 6. Validate with `expectNoOverflowAtMobileWidths` from
///    `test/support/harnesses/responsive_harness.dart` at
///    320/360/375/390/414/480/599/600+.
class MobileCompact {
  const MobileCompact._();

  /// Width below which the compact phone layout applies. Mirrors
  /// [Breakpoints.tabletStart] so there is exactly one breakpoint.
  static const double compactStart = Breakpoints.tabletStart;

  /// Narrowest phone we validate (two-column grids collapse below 360dp).
  static const double twoColumnStart = 360;

  /// Phone scroll padding: 16dp sides, 32dp bottom clearance for the bar.
  static const EdgeInsets scrollPadding = EdgeInsets.fromLTRB(
    HivorrSpacing.md,
    HivorrSpacing.md,
    HivorrSpacing.md,
    HivorrSpacing.xl,
  );

  /// Tablet/desktop scroll padding (unchanged reference spacing).
  static const EdgeInsets desktopScrollPadding = EdgeInsets.all(
    HivorrSpacing.lg,
  );

  static bool isCompactWidth(double maxWidth) => maxWidth < compactStart;

  static EdgeInsets scrollPaddingFor(double maxWidth) =>
      isCompactWidth(maxWidth) ? scrollPadding : desktopScrollPadding;

  static EdgeInsets scrollPaddingForBreakpoint(Breakpoint bp) =>
      bp == Breakpoint.mobile ? scrollPadding : desktopScrollPadding;

  /// Major section rhythm: 24dp on phones, 32dp otherwise.
  static double sectionGapFor(double maxWidth) =>
      isCompactWidth(maxWidth) ? HivorrSpacing.lg : HivorrSpacing.xl;

  /// Minor section rhythm: 8dp on phones, 16dp otherwise.
  static double minorGapFor(double maxWidth) =>
      isCompactWidth(maxWidth) ? HivorrSpacing.sm : HivorrSpacing.md;

  /// Two-column card width with [spacing] between columns.
  static double twoColumnWidth(double maxWidth, {double spacing = HivorrSpacing.sm}) =>
      (maxWidth - spacing) / 2;

  /// Whether [maxWidth] fits two columns without squeezing (<360dp → one).
  static bool fitsTwoColumns(double maxWidth) =>
      maxWidth >= twoColumnStart;

  /// Chat bubble ceiling: 75% of the screen clamped so list padding (16dp
  /// each side) plus bubble padding never overflow at 320px.
  static double bubbleMaxWidth(double screenWidth) =>
      (screenWidth * 0.75).clamp(0, screenWidth - 64).toDouble();
}

/// Screen body wrapper enforcing the bottom-navigation safe-area contract.
///
/// Top/left/right follow the device; bottom stays open because the dashboard
/// shell's bottom navigation already consumes the bottom inset. Using a plain
/// `SafeArea` (bottom: true) here double-pads above the bar and wastes ~34dp
/// on notched phones.
class MobileSafeBody extends StatelessWidget {
  const MobileSafeBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: child,
    );
  }
}

/// Scroll root that picks phone/desktop padding from its own width.
///
/// Use for new screens instead of a hardcoded `EdgeInsets.all(24)`: phones
/// get [MobileCompact.scrollPadding], wider layouts keep the reference 24dp.
class ResponsiveScrollPadding extends StatelessWidget {
  const ResponsiveScrollPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: MobileCompact.scrollPaddingFor(c.maxWidth),
          child: child,
        );
      },
    );
  }
}
