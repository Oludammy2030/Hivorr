import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// Semantic color variants for [HivorrSnackbar].
enum HivorrSnackbarVariant {
  success,
  error,
  warning,
  info,
}

/// Factory for themed [SnackBar]s with semantic feedback colors sourced from
/// [AppThemeExtension] (AGENT.md Rule 5 — never hardcoded colors).
class HivorrSnackbar {
  const HivorrSnackbar._();

  /// Builds a [SnackBar] tinted by [variant] with the given [message].
  static SnackBar show(
    BuildContext context, {
    required String message,
    HivorrSnackbarVariant variant = HivorrSnackbarVariant.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final AppThemeExtension ext = context.appExtension;
    final Color background;
    final Color foreground;
    switch (variant) {
      case HivorrSnackbarVariant.success:
        background = ext.success;
        foreground = ext.onSuccess;
      case HivorrSnackbarVariant.error:
        background = context.colorScheme.error;
        foreground = context.colorScheme.onError;
      case HivorrSnackbarVariant.warning:
        background = ext.warning;
        foreground = ext.onWarning;
      case HivorrSnackbarVariant.info:
        background = ext.info;
        foreground = ext.onInfo;
    }
    return SnackBar(
      content: Text(
        message,
        style: context.textTheme.bodyMedium?.copyWith(color: foreground),
      ),
      backgroundColor: background,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    );
  }
}
