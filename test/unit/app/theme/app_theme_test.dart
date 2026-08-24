import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivorr/app/theme/app_colors.dart';
import 'package:hivorr/app/theme/app_text_theme.dart';
import 'package:hivorr/app/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('brand primary matches VISUAL-IDENTITY.md (#0B6E99)', () {
      expect(AppColors.brandPrimary, const Color(0xFF0B6E99));
    });

    test('brand secondary matches VISUAL-IDENTITY.md (#10B981)', () {
      expect(AppColors.brandSecondary, const Color(0xFF10B981));
    });

    test('light color scheme primary equals brand primary', () {
      expect(AppColors.lightColorScheme.primary, AppColors.brandPrimary);
    });

    test('dark color scheme primary is the darkened cerulean', () {
      expect(AppColors.darkColorScheme.primary, const Color(0xFF6CB8D6));
    });
  });

  group('AppTextTheme', () {
    test('fontFamily is Inter (bundled offline)', () {
      expect(AppTextTheme.fontFamily, 'Inter');
    });

    test('bodyMedium uses Inter and regular weight', () {
      final style = AppTextTheme.textTheme.bodyMedium;
      expect(style?.fontFamily, 'Inter');
      expect(style?.fontWeight, FontWeight.w400);
    });

    test('headline styles use semi-bold weight', () {
      expect(AppTextTheme.textTheme.headlineMedium?.fontWeight, FontWeight.w600);
    });
  });

  group('AppTheme', () {
    test('light theme builds and primary equals #0B6E99', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, const Color(0xFF0B6E99));
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme builds and primary equals darkened cerulean', () {
      final theme = AppTheme.darkTheme;
      expect(theme.colorScheme.primary, const Color(0xFF6CB8D6));
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffold background equals documented background token', () {
      expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    test('text theme fontFamily is Inter', () {
      expect(AppTheme.lightTheme.textTheme.bodyMedium!.fontFamily, 'Inter');
    });

    test('AppThemeExtension exposes semantic colors', () {
      final ext = AppTheme.lightTheme.extension<AppThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.success, const Color(0xFF16A34A));
      expect(ext.warning, const Color(0xFFF59E0B));
      expect(ext.info, const Color(0xFF0EA5E9));
    });

    test('dark AppThemeExtension exposes darkened semantic colors', () {
      final ext = AppTheme.darkTheme.extension<AppThemeExtension>();
      expect(ext, isNotNull);
      expect(ext!.success, const Color(0xFF22C55E));
    });
  });
}
