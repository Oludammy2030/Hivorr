import 'package:flutter/material.dart';

/// Canonical color values for the Hivorr visual identity.
///
/// These MUST match `documents/Context/VISUAL-IDENTITY.md` (the project source
/// of truth). If a value here disagrees with that document, this file is wrong
/// and must be fixed — never the other way around.
///
/// Semantic colors (success/warning/info) are intentionally NOT part of
/// [ColorScheme] (which has no such slots); they live in [AppThemeExtension]
/// so widgets can read them via `Theme.of(context).extension<AppThemeExtension>()`.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────────
  static const Color brandPrimary = Color(0xFF0B6E99); // Cerulean (signature)
  static const Color brandSecondary = Color(0xFF10B981); // Emerald (accent)

  // ── Semantic (consumed by AppThemeExtension) ───────────
  static const Color success = Color(0xFF16A34A);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF14532D);

  static const Color warning = Color(0xFFF59E0B);
  static const Color onWarning = Color(0xFF1F2937);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF78350F);

  static const Color info = Color(0xFF0EA5E9);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFE0F2FE);
  static const Color onInfoContainer = Color(0xFF0C4A6E);

  // ── Light theme raw tokens ─────────────────────────────
  static const Color lightPrimary = Color(0xFF0B6E99);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD3E7F0);
  static const Color lightOnPrimaryContainer = Color(0xFF062E40);
  static const Color lightSecondary = Color(0xFF10B981);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFA7F3D0);
  static const Color lightOnSecondaryContainer = Color(0xFF053B29);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightSurfaceVariant = Color(0xFFE2E8F0);
  static const Color lightOnSurfaceVariant = Color(0xFF475569);
  static const Color lightOutline = Color(0xFFCBD5E1);
  static const Color lightBackground = Color(0xFFF7F9FB);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFEE2E2);
  static const Color lightOnErrorContainer = Color(0xFF7F1D1D);

  // ── Dark theme raw tokens ──────────────────────────────
  static const Color darkPrimary = Color(0xFF6CB8D6);
  static const Color darkOnPrimary = Color(0xFF06222E);
  static const Color darkPrimaryContainer = Color(0xFF0B4A66);
  static const Color darkOnPrimaryContainer = Color(0xFFCDE8F4);
  static const Color darkSecondary = Color(0xFF34D399);
  static const Color darkOnSecondary = Color(0xFF063322);
  static const Color darkSecondaryContainer = Color(0xFF065F46);
  static const Color darkOnSecondaryContainer = Color(0xFFA7F3D0);
  static const Color darkSurface = Color(0xFF0B1220);
  static const Color darkOnSurface = Color(0xFFE5E7EB);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkOutline = Color(0xFF334155);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkOnError = Color(0xFF7F1D1D);
  static const Color darkErrorContainer = Color(0xFF450A0A);
  static const Color darkOnErrorContainer = Color(0xFFFCA5A5);

  static ColorScheme get lightColorScheme => const ColorScheme(
    brightness: Brightness.light,
    primary: lightPrimary,
    onPrimary: lightOnPrimary,
    primaryContainer: lightPrimaryContainer,
    onPrimaryContainer: lightOnPrimaryContainer,
    secondary: lightSecondary,
    onSecondary: lightOnSecondary,
    secondaryContainer: lightSecondaryContainer,
    onSecondaryContainer: lightOnSecondaryContainer,
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceContainerHighest: lightSurfaceVariant,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
    error: lightError,
    onError: lightOnError,
    errorContainer: lightErrorContainer,
    onErrorContainer: lightOnErrorContainer,
  );

  static ColorScheme get darkColorScheme => const ColorScheme(
    brightness: Brightness.dark,
    primary: darkPrimary,
    onPrimary: darkOnPrimary,
    primaryContainer: darkPrimaryContainer,
    onPrimaryContainer: darkOnPrimaryContainer,
    secondary: darkSecondary,
    onSecondary: darkOnSecondary,
    secondaryContainer: darkSecondaryContainer,
    onSecondaryContainer: darkOnSecondaryContainer,
    surface: darkSurface,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceVariant,
    onSurfaceVariant: darkOnSurfaceVariant,
    outline: darkOutline,
    error: darkError,
    onError: darkOnError,
    errorContainer: darkErrorContainer,
    onErrorContainer: darkOnErrorContainer,
  );
}
