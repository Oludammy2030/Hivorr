import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

/// Project design tokens that have no slot in [ColorScheme]: semantic colors
/// plus spacing/radii primitives. Access via
/// `Theme.of(context).extension<AppThemeExtension>()`.
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

  /// Shared shape/spacing primitives (see VISUAL-IDENTITY.md §3).
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
    radiusMd: 12,
    radiusLg: 20,
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
    radiusMd: 12,
    radiusLg: 20,
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
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
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
    extensions: const <ThemeExtension<dynamic>>[AppThemeExtension.light],
  );

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    colorScheme: AppColors.darkColorScheme,
    textTheme: AppTextTheme.textTheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
    extensions: const <ThemeExtension<dynamic>>[AppThemeExtension.dark],
  );
}
