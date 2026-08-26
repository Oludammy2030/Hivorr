import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Themed list row with leading, title, optional subtitle, trailing, and an
/// optional tap handler. Minimum touch target height is 48dp.
class HivorrListTile extends StatelessWidget {
  const HivorrListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: HivorrSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: context.textTheme.titleSmall),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: context.textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: HivorrSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return row;
    }
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.primary.withValues(alpha: 0.12),
        child: row,
      ),
    );
  }
}
