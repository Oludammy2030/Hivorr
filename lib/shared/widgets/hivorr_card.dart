import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Surface card built from [AppTheme] tokens (AGENT.md Rule 5).
///
/// Uses [ColorScheme.surface] for its fill, an [ColorScheme.outline] hairline
/// border when flat (`elevation == 0`), and a token-based shadow when raised.
/// When [onTap] is provided the card becomes tappable with a primary splash.
class HivorrCard extends StatelessWidget {
  const HivorrCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation = 0,
    this.onTap,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final VoidCallback? onTap;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final double radius = borderRadius ?? ext.radiusMd;

    final Widget body = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: elevation == 0 ? Border.all(color: colors.outline) : null,
        boxShadow: elevation > 0
            ? <BoxShadow>[
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.12),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation / 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(HivorrSpacing.md),
        child: child,
      ),
    );

    if (onTap == null) {
      return body;
    }
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: colors.primary.withValues(alpha: 0.12),
        child: body,
      ),
    );
  }
}
