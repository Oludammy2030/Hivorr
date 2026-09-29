import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_colors.dart';
import 'package:hivorr/app/theme/app_text_theme.dart';
import 'package:hivorr/app/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('brand primary matches VISUAL-IDENTITY.md (#2D3FE7)', () {
      expect(AppColors.brandPrimary, const Color(0xFF2D3FE7));
    });

    test('brand secondary matches VISUAL-IDENTITY.md (#8B5CF6)', () {
      expect(AppColors.brandSecondary, const Color(0xFF8B5CF6));
    });

    test('brand gradient matches VISUAL-IDENTITY.md', () {
      expect(AppColors.brandGradient, const <Color>[
        Color(0xFF1A2AD4),
        Color(0xFF2D3FE7),
        Color(0xFF4F5FEF),
      ]);
    });

    test('role accents match VISUAL-IDENTITY.md §3', () {
      expect(AppColors.clientPrimary, const Color(0xFF2D3FE7));
      expect(AppColors.clientLight, const Color(0xFFEEF0FD));
      expect(AppColors.professionalPrimary, const Color(0xFF16A34A));
      expect(AppColors.professionalLight, const Color(0xFFDCFCE7));
      expect(AppColors.bothPrimary, const Color(0xFF8B5CF6));
      expect(AppColors.bothLight, const Color(0xFFF3F0FF));
      expect(AppColors.adminPrimary, const Color(0xFF1A2AD4));
      expect(AppColors.adminAccent, const Color(0xFF8B5CF6));
    });

    test('light color scheme primary equals brand primary', () {
      expect(AppColors.lightColorScheme.primary, AppColors.brandPrimary);
    });

    test('light background matches VISUAL-IDENTITY.md (#F0F2F8)', () {
      expect(AppColors.lightBackground, const Color(0xFFF0F2F8));
      expect(AppColors.lightColorScheme.surface, const Color(0xFFFFFFFF));
    });

    test('dark color scheme primary is the lightened brand', () {
      expect(AppColors.darkColorScheme.primary, const Color(0xFF8B9DFF));
    });
  });

  group('AppTextTheme', () {
    test('fontFamily is Plus Jakarta Sans (bundled offline)', () {
      expect(AppTextTheme.fontFamily, 'Plus Jakarta Sans');
    });

    test('bodyMedium uses Plus Jakarta Sans and regular weight', () {
      final style = AppTextTheme.textTheme.bodyMedium;
      expect(style?.fontFamily, 'Plus Jakarta Sans');
      expect(style?.fontWeight, FontWeight.w400);
    });

    test('headline styles use semi-bold weight', () {
      expect(
        AppTextTheme.textTheme.headlineMedium?.fontWeight,
        FontWeight.w600,
      );
    });
  });

  group('AppTheme', () {
    test('light theme builds and primary equals #2D3FE7', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, const Color(0xFF2D3FE7));
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme builds and primary equals lightened brand', () {
      final theme = AppTheme.darkTheme;
      expect(theme.colorScheme.primary, const Color(0xFF8B9DFF));
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffold background equals documented background token', () {
      expect(
        AppTheme.lightTheme.scaffoldBackgroundColor,
        AppColors.lightBackground,
      );
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        AppColors.darkBackground,
      );
    });

    test('text theme fontFamily is Plus Jakarta Sans', () {
      expect(
        AppTheme.lightTheme.textTheme.bodyMedium!.fontFamily,
        'Plus Jakarta Sans',
      );
    });

    test('AppThemeExtension exposes semantic colors', () {
      final ext = AppTheme.lightTheme.extension<AppThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.success, const Color(0xFF16A34A));
      expect(ext.warning, const Color(0xFFF97316));
      expect(ext.info, const Color(0xFF0891B2));
      expect(ext.radiusSm, 8);
      expect(ext.radiusMd, 16);
      expect(ext.radiusLg, 24);
      expect(ext.spacing, 8);
    });

    test('dark AppThemeExtension exposes darkened semantic colors', () {
      final ext = AppTheme.darkTheme.extension<AppThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.success, const Color(0xFF22C55E));
    });

    test('RoleThemeExtension exposes role accents (accent-only)', () {
      final light = AppTheme.lightTheme.extension<RoleThemeExtension>();
      expect(light, isNotNull);
      expect(light!.clientPrimary, const Color(0xFF2D3FE7));
      expect(light.clientContainer, const Color(0xFFEEF0FD));
      expect(light.professionalPrimary, const Color(0xFF16A34A));
      expect(light.professionalContainer, const Color(0xFFDCFCE7));
      expect(light.bothPrimary, const Color(0xFF8B5CF6));
      expect(light.bothContainer, const Color(0xFFF3F0FF));
      expect(light.adminPrimary, const Color(0xFF1A2AD4));
      expect(light.adminAccent, const Color(0xFF8B5CF6));

      final dark = AppTheme.darkTheme.extension<RoleThemeExtension>();
      expect(dark, isNotNull);
      expect(dark!.clientPrimary, const Color(0xFF8B9DFF));
      expect(dark.professionalPrimary, const Color(0xFF4ADE80));
      expect(dark.bothPrimary, const Color(0xFFB7A6FF));
    });

    test('HivorrMotion tokens match VISUAL-IDENTITY.md §23', () {
      expect(HivorrMotion.short, const Duration(milliseconds: 150));
      expect(HivorrMotion.medium, const Duration(milliseconds: 250));
      expect(HivorrMotion.long, const Duration(milliseconds: 300));
    });
  });
}
