import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

/// Project design tokens that have no slot in [ColorScheme]: semantic colors
/// plus spacing/radii primitives. Access via
/// `Theme.of(context).extension<AppThemeExtension>()`.
///
/// Source of truth: `documents/Context/VISUAL-IDENTITY.md` §§4–10.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.spacing,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Shared shape/spacing primitives (see VISUAL-IDENTITY.md §7–§8).
  /// radiusSm 8 (buttons/fields/badges), radiusMd 16 (cards/dialogs),
  /// radiusLg 24 (bottom-sheet top corners).
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double spacing;

  static const AppThemeExtension light = AppThemeExtension(
    success: AppColors.success,
    onSuccess: AppColors.onSuccess,
    successContainer: AppColors.successContainer,
    onSuccessContainer: AppColors.onSuccessContainer,
    warning: AppColors.warning,
    onWarning: AppColors.onWarning,
    warningContainer: AppColors.warningContainer,
    onWarningContainer: AppColors.onWarningContainer,
    info: AppColors.info,
    onInfo: AppColors.onInfo,
    infoContainer: AppColors.infoContainer,
    onInfoContainer: AppColors.onInfoContainer,
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    spacing: 8,
  );

  static const AppThemeExtension dark = AppThemeExtension(
    success: Color(0xFF22C55E),
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF14532D),
    onSuccessContainer: Color(0xFFBBF7D0),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF3A2A06),
    warningContainer: Color(0xFF5C3B00),
    onWarningContainer: Color(0xFFFDE68A),
    info: Color(0xFF38BDF8),
    onInfo: Color(0xFF062A3A),
    infoContainer: Color(0xFF0C4A6E),
    onInfoContainer: Color(0xFFBAE6FD),
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    spacing: 8,
  );

  @override
  AppThemeExtension copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? spacing,
  }) {
    return AppThemeExtension(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      spacing: spacing ?? this.spacing,
    );
  }

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }
    return AppThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      radiusSm: radiusSm,
      radiusMd: radiusMd,
      radiusLg: radiusLg,
      spacing: spacing,
    );
  }
}

/// Role-based accent colors (accent-only, NOT separate themes).
///
/// Hivorr is one unified ecosystem; operating contexts tint navigation,
/// primary actions and dashboard accents via this extension.
/// Source of truth: `documents/Context/VISUAL-IDENTITY.md` §3.
/// Access via `Theme.of(context).extension<RoleThemeExtension>()!`
/// or `context.roleTheme` (see `shared/extensions/build_context_extensions.dart`).
class RoleThemeExtension extends ThemeExtension<RoleThemeExtension> {
  const RoleThemeExtension({
    required this.clientPrimary,
    required this.clientContainer,
    required this.professionalPrimary,
    required this.professionalContainer,
    required this.bothPrimary,
    required this.bothContainer,
    required this.adminPrimary,
    required this.adminAccent,
  });

  final Color clientPrimary;
  final Color clientContainer;
  final Color professionalPrimary;
  final Color professionalContainer;
  final Color bothPrimary;
  final Color bothContainer;
  final Color adminPrimary;
  final Color adminAccent;

  /// Constrained brand gradient (#1A2AD4 → #2D3FE7 → #4F5FEF).
  /// Use only for hero accents / Both-admin identity / primary CTA fills.
  List<Color> get brandGradient => AppColors.brandGradient;

  static const RoleThemeExtension light = RoleThemeExtension(
    clientPrimary: AppColors.clientPrimary,
    clientContainer: AppColors.clientLight,
    professionalPrimary: AppColors.professionalPrimary,
    professionalContainer: AppColors.professionalLight,
    bothPrimary: AppColors.bothPrimary,
    bothContainer: AppColors.bothLight,
    adminPrimary: AppColors.adminPrimary,
    adminAccent: AppColors.adminAccent,
  );

  static const RoleThemeExtension dark = RoleThemeExtension(
    clientPrimary: Color(0xFF8B9DFF),
    clientContainer: Color(0xFF1A2AD4),
    professionalPrimary: Color(0xFF4ADE80),
    professionalContainer: Color(0xFF14532D),
    bothPrimary: Color(0xFFB7A6FF),
    bothContainer: Color(0xFF4C2FB3),
    adminPrimary: Color(0xFF8B9DFF),
    adminAccent: Color(0xFFB7A6FF),
  );

  @override
  RoleThemeExtension copyWith({
    Color? clientPrimary,
    Color? clientContainer,
    Color? professionalPrimary,
    Color? professionalContainer,
    Color? bothPrimary,
    Color? bothContainer,
    Color? adminPrimary,
    Color? adminAccent,
  }) {
    return RoleThemeExtension(
      clientPrimary: clientPrimary ?? this.clientPrimary,
      clientContainer: clientContainer ?? this.clientContainer,
      professionalPrimary: professionalPrimary ?? this.professionalPrimary,
      professionalContainer:
          professionalContainer ?? this.professionalContainer,
      bothPrimary: bothPrimary ?? this.bothPrimary,
      bothContainer: bothContainer ?? this.bothContainer,
      adminPrimary: adminPrimary ?? this.adminPrimary,
      adminAccent: adminAccent ?? this.adminAccent,
    );
  }

  @override
  RoleThemeExtension lerp(RoleThemeExtension? other, double t) {
    if (other is! RoleThemeExtension) {
      return this;
    }
    return RoleThemeExtension(
      clientPrimary: Color.lerp(clientPrimary, other.clientPrimary, t)!,
      clientContainer: Color.lerp(clientContainer, other.clientContainer, t)!,
      professionalPrimary: Color.lerp(
        professionalPrimary,
        other.professionalPrimary,
        t,
      )!,
      professionalContainer: Color.lerp(
        professionalContainer,
        other.professionalContainer,
        t,
      )!,
      bothPrimary: Color.lerp(bothPrimary, other.bothPrimary, t)!,
      bothContainer: Color.lerp(bothContainer, other.bothContainer, t)!,
      adminPrimary: Color.lerp(adminPrimary, other.adminPrimary, t)!,
      adminAccent: Color.lerp(adminAccent, other.adminAccent, t)!,
    );
  }
}

/// Token motion durations & curves (VISUAL-IDENTITY.md §23).
/// Animate only to communicate; prefer fade + slide.
class HivorrMotion {
  const HivorrMotion._();

  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration long = Duration(milliseconds: 300);
  static const Duration snackbar = Duration(seconds: 4);
  static const Duration loader = Duration(milliseconds: 1800);

  static const Curve standard = Curves.easeOut;
  static const Curve emphasized = Curves.easeInOut;
}

/// Token elevation scale (VISUAL-IDENTITY.md §9).
/// Level 0 = flat (border, no shadow). Levels 1–3 = soft shadows.
class HivorrElevation {
  const HivorrElevation._();

  static const double level0 = 0;
  static const double level1Blur = 12;
  static const double level2Blur = 24;
  static const double level3Blur = 32;

  /// Soft raised-card shadow: 0 2px 12px rgba(15,22,38,0.07).
  static List<BoxShadow> raised(Color shadowColor) => <BoxShadow>[
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.07),
      blurRadius: level1Blur,
      offset: const Offset(0, 2),
    ),
  ];

  /// Soft overlay shadow for dialogs/sheets.
  static List<BoxShadow> overlay(Color shadowColor) => <BoxShadow>[
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.12),
      blurRadius: level2Blur,
      offset: const Offset(0, 8),
    ),
  ];

  /// Floating shadow for snackbars/FABs.
  static List<BoxShadow> floating(Color shadowColor) => <BoxShadow>[
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.16),
      blurRadius: level3Blur,
      offset: const Offset(0, 12),
    ),
  ];
}

/// Hivorr application themes (light + dark), built from the canonical tokens.
///
/// Every UI surface MUST use these via `ThemeData` — never hardcode colors or
/// fonts. Source of truth: `documents/Context/VISUAL-IDENTITY.md`.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: AppColors.lightColorScheme,
    textTheme: AppTextTheme.textTheme,
    scaffoldBackgroundColor: AppColors.lightBackground,
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeExtension.light,
      RoleThemeExtension.light,
    ],
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: AppColors.darkColorScheme,
    textTheme: AppTextTheme.textTheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
    extensions: const <ThemeExtension<dynamic>>[
      AppThemeExtension.dark,
      RoleThemeExtension.dark,
    ],
  );
}
