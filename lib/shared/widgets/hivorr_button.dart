import 'package:flutter/material.dart';

import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Visual style of a [HivorrButton].
enum HivorrButtonVariant {
  primary,
  secondary,
  outline,
  text,
}

/// Size tier of a [HivorrButton].
enum HivorrButtonSize {
  small,
  medium,
  large,
}

/// Brand-themed button built entirely from [AppTheme] tokens (AGENT.md Rule 5).
///
/// Supports four variants, a loading state (branded [HivorrLoader]), a disabled
/// state, an optional leading icon, and three size tiers. The minimum touch
/// target is 48×48dp.
class HivorrButton extends StatelessWidget {
  const HivorrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HivorrButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isExpanded = false,
    this.size = HivorrButtonSize.medium,
  });

  /// Button text.
  final String label;

  /// Tap handler. `null` renders the button disabled.
  final VoidCallback? onPressed;

  /// Visual variant.
  final HivorrButtonVariant variant;

  /// When `true`, replaces the label with a small [HivorrLoader].
  final bool isLoading;

  /// Optional leading icon.
  final Widget? icon;

  /// When `true`, stretches to the full available width.
  final bool isExpanded;

  /// Size tier.
  final HivorrButtonSize size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;

    final bool enabled = onPressed != null && !isLoading;

    final double vertical;
    final double horizontal;
    switch (size) {
      case HivorrButtonSize.small:
        vertical = 8;
        horizontal = 16;
      case HivorrButtonSize.medium:
        vertical = 12;
        horizontal = 20;
      case HivorrButtonSize.large:
        vertical = 16;
        horizontal = 24;
    }

    final Color loaderColor;
    switch (variant) {
      case HivorrButtonVariant.primary:
        loaderColor = colors.onPrimary;
      case HivorrButtonVariant.secondary:
        loaderColor = colors.onSecondary;
      case HivorrButtonVariant.outline:
      case HivorrButtonVariant.text:
        loaderColor = colors.primary;
    }

    final Widget child = isLoading
        ? HivorrLoader(size: 20, color: loaderColor)
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  icon!,
                  const SizedBox(width: HivorrSpacing.xs),
                  Text(label, style: context.textTheme.labelLarge),
                ],
              )
            : Text(label, style: context.textTheme.labelLarge));

    final ButtonStyle style;
    switch (variant) {
      case HivorrButtonVariant.primary:
        style = ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceContainerHighest,
          disabledForegroundColor:
              colors.onSurfaceVariant.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(
            vertical: vertical,
            horizontal: horizontal,
          ),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
          elevation: 0,
        );
        return _wrap(enabled, child, style, context);
      case HivorrButtonVariant.secondary:
        style = ElevatedButton.styleFrom(
          backgroundColor: colors.secondary,
          foregroundColor: colors.onSecondary,
          disabledBackgroundColor: colors.surfaceContainerHighest,
          disabledForegroundColor:
              colors.onSurfaceVariant.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(
            vertical: vertical,
            horizontal: horizontal,
          ),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
          elevation: 0,
        );
        return _wrap(enabled, child, style, context);
      case HivorrButtonVariant.outline:
        style = OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          disabledForegroundColor:
              colors.onSurfaceVariant.withValues(alpha: 0.5),
          disabledBackgroundColor: colors.surfaceContainerHighest,
          side: BorderSide(color: colors.primary),
          padding: EdgeInsets.symmetric(
            vertical: vertical,
            horizontal: horizontal,
          ),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
        );
        return _wrap(enabled, child, style, context);
      case HivorrButtonVariant.text:
        style = TextButton.styleFrom(
          foregroundColor: colors.primary,
          disabledForegroundColor:
              colors.onSurfaceVariant.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(
            vertical: vertical,
            horizontal: horizontal,
          ),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ext.radiusSm),
          ),
        );
        return _wrap(enabled, child, style, context);
    }
  }

  Widget _wrap(
    bool enabled,
    Widget child,
    ButtonStyle style,
    BuildContext context,
  ) {
    final Widget button;
    if (variant == HivorrButtonVariant.text) {
      button = TextButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: child,
      );
    } else if (variant == HivorrButtonVariant.outline) {
      button = OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: child,
      );
    } else {
      button = ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: child,
      );
    }
    return Semantics(
      label: label,
      enabled: enabled,
      button: true,
      child: isExpanded
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
