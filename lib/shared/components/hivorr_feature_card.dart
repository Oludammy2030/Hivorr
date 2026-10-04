import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Tinted-icon feature card for grids and trust strips
/// (VISUAL-IDENTITY.md §§14–15, 18).
///
/// Flat surface card (static containment → border, no shadow) with an icon
/// tile, a card-heading title and supporting body. Tint via [iconBackground]
/// / [iconColor] — e.g. the role containers from `context.roleTheme` — so
/// activity grids can carry Client/Professional accents without new
/// hues. Tappable when [onTap] is provided.
class HivorrFeatureCard extends StatelessWidget {
  const HivorrFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.iconBackground,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? iconBackground;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(HivorrSpacing.sm),
            decoration: BoxDecoration(
              color: iconBackground ?? colors.primaryContainer,
              borderRadius: BorderRadius.circular(ext.radiusSm),
            ),
            child: Icon(
              icon,
              color: iconColor ?? colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            body,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
