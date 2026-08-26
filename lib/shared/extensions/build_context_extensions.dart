import 'package:flutter/material.dart';

import 'package:hivorr/app/theme/app_theme.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';

export 'package:hivorr/app/theme/app_theme.dart';

/// Convenience accessors on [BuildContext] for theme tokens and sizing.
///
/// These mirror the existing `Theme.of(context)` lookups but keep call sites
/// terse and consistent. Every accessor resolves to the canonical
/// [AppTheme] tokens (AGENT.md Rule 5) — never hardcoded values.
extension BuildContextExtensions on BuildContext {
  /// Color tokens from the active [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Typography tokens from the active [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Semantic color/spacing tokens from [AppThemeExtension].
  AppThemeExtension get appExtension =>
      Theme.of(this).extension<AppThemeExtension>()!;

  /// Media query data for the current context.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Width of the current media (in dp).
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Height of the current media (in dp).
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Whether the active theme is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// The responsive [Breakpoint] for the current width.
  Breakpoint get breakpoint => Breakpoints.current(this);
}
