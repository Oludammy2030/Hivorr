import 'package:flutter/material.dart';

/// Responsive layout breakpoints for the Hivorr design system.
///
/// Mirrors the material `NavigationRail` / side-rail pattern: a single-column
/// phone layout below 600dp, a side-rail tablet layout from 600dp, and a
/// fixed sidebar from 1024dp.
enum Breakpoint {
  /// Phone layout (< 600dp).
  mobile,

  /// Tablet layout (600–1023dp).
  tablet,

  /// Desktop layout (≥ 1024dp).
  desktop,
}

/// Helpers for resolving the active [Breakpoint] from a width.
class Breakpoints {
  const Breakpoints._();

  /// Width (dp) at or above which the tablet layout applies.
  static const double tabletStart = 600;

  /// Width (dp) at or above which the desktop layout applies.
  static const double desktopStart = 1024;

  /// Resolves the [Breakpoint] for a given [width] in dp.
  static Breakpoint fromWidth(double width) {
    if (width < tabletStart) {
      return Breakpoint.mobile;
    }
    if (width < desktopStart) {
      return Breakpoint.tablet;
    }
    return Breakpoint.desktop;
  }

  /// Resolves the [Breakpoint] for the current [BuildContext] width.
  static Breakpoint current(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}
