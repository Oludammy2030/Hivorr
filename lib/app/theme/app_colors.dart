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
///
/// Role accents (client/professional/both/admin) live in [RoleThemeExtension]
/// (see `app_theme.dart`) — accent-only on top of the single unified
/// [ColorScheme], per VISUAL-IDENTITY.md §3.
class AppColors {
  AppColors._();

  // ── Brand ───────────────────────────────────────────────
  static const Color brandPrimary = Color(
    0xFF2D3FE7,
  ); // Brand / Client signature
  static const Color brandSecondary = Color(
    0xFF8B5CF6,
  ); // Both / unified accent
  static const Color brandDeep = Color(
    0xFF1A2AD4,
  ); // Gradient start / Admin primary
  static const Color brandBright = Color(0xFF4F5FEF); // Gradient end only
  static const List<Color> brandGradient = <Color>[
    brandDeep,
    brandPrimary,
    brandBright,
  ];

  // ── Role accents (consumed by RoleThemeExtension) ──────
  static const Color clientPrimary = Color(0xFF2D3FE7);
  static const Color clientLight = Color(0xFFEEF0FD);
  static const Color professionalPrimary = Color(0xFF16A34A);
  static const Color professionalLight = Color(0xFFDCFCE7);
  static const Color bothPrimary = Color(0xFF8B5CF6);
  static const Color bothLight = Color(0xFFF3F0FF);
  static const Color adminPrimary = Color(0xFF1A2AD4);
  static const Color adminAccent = Color(0xFF8B5CF6);

  // ── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F1626);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // ── Semantic (consumed by AppThemeExtension) ───────────
  static const Color success = Color(0xFF16A34A);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF14532D);

  static const Color warning = Color(0xFFF97316);
  static const Color onWarning = Color(0xFF1F2937);
  static const Color warningContainer = Color(0xFFFFF7ED);
  static const Color onWarningContainer = Color(0xFF78350F);

  static const Color info = Color(0xFF0891B2);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFE0F2FE);
  static const Color onInfoContainer = Color(0xFF0C4A6E);

  // ── Light theme raw tokens ─────────────────────────────
  static const Color lightPrimary = Color(0xFF2D3FE7);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFEEF0FD);
  static const Color lightOnPrimaryContainer = Color(0xFF1A2AD4);
  static const Color lightSecondary = Color(0xFF8B5CF6);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFF3F0FF);
  static const Color lightOnSecondaryContainer = Color(0xFF5B21B6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF0F1626);
  static const Color lightSurfaceVariant = Color(0xFFE6EAF3);
  static const Color lightOnSurfaceVariant = Color(0xFF6B7280);
  static const Color lightOutline = Color(0xFFD8DFEA);
  static const Color lightBackground = Color(0xFFF0F2F8);
  static const Color lightOnBackground = Color(0xFF0F1626);
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFEF2F2);
  static const Color lightOnErrorContainer = Color(0xFF7F1D1D);

  // ── Dark theme raw tokens ──────────────────────────────
  static const Color darkPrimary = Color(0xFF8B9DFF);
  static const Color darkOnPrimary = Color(0xFF0F173D);
  static const Color darkPrimaryContainer = Color(0xFF1A2AD4);
  static const Color darkOnPrimaryContainer = Color(0xFFE0E4FF);
  static const Color darkSecondary = Color(0xFFB7A6FF);
  static const Color darkOnSecondary = Color(0xFF2A1650);
  static const Color darkSecondaryContainer = Color(0xFF4C2FB3);
  static const Color darkOnSecondaryContainer = Color(0xFFEDE9FE);
  static const Color darkSurface = Color(0xFF131A2E);
  static const Color darkOnSurface = Color(0xFFE8EBF3);
  static const Color darkSurfaceVariant = Color(0xFF232C47);
  static const Color darkOnSurfaceVariant = Color(0xFFA7B0C2);
  static const Color darkOutline = Color(0xFF334155);
  static const Color darkBackground = Color(0xFF0F1626);
  static const Color darkOnBackground = Color(0xFFE8EBF3);
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
