/// Spacing scale derived from the design token base (8dp) in
/// [AppThemeExtension.spacing].
///
/// Use these constants instead of magic numbers so every screen shares a
/// consistent rhythm. All values are compile-time constants.
class HivorrSpacing {
  const HivorrSpacing._();

  /// 4.0 — tight gaps (icon-to-text).
  static const double xs = 4.0;

  /// 8.0 — standard element gaps.
  static const double sm = 8.0;

  /// 16.0 — section padding, card padding.
  static const double md = 16.0;

  /// 24.0 — screen horizontal padding.
  static const double lg = 24.0;

  /// 32.0 — major section separation.
  static const double xl = 32.0;

  /// 48.0 — page-level vertical spacing.
  static const double xxl = 48.0;
}
