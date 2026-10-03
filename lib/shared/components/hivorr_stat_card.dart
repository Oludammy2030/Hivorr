import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Compact metric card for dashboards and admin surfaces
/// (VISUAL-IDENTITY.md §§6a, 20a).
///
/// Icon tile + label + prominent value + optional delta line. [compact]
/// selects the 12dp-padding / 32dp-tile admin density; the standard variant
/// uses 16dp padding with a 40dp tile. Values render at `titleLarge` /
/// `headlineSmall` w700 — never w800.
class HivorrStatCard extends StatelessWidget {
  const HivorrStatCard({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
    this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  final VoidCallback? onTap;

  /// Admin density: 12dp padding, 32dp tile, 22sp value.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final double tile = compact ? 32 : 40;
    return HivorrCard(
      padding: compact ? const EdgeInsets.all(HivorrSpacing.smMd) : null,
      elevation: 1,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(
                compact ? ext.radiusSm : ext.radiusXs,
              ),
            ),
            child: Icon(
              icon,
              size: compact ? 16 : 20,
              color: iconForeground,
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style:
                      (compact
                              ? context.textTheme.titleLarge
                              : context.textTheme.headlineSmall)
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                ),
                if (sub != null && sub!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: subColor ?? colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive stat grid: [columns] of equal cards with a token [gap].
/// Column policy lives with the caller (VISUAL-IDENTITY.md §21a); this
/// widget owns only the width math.
class HivorrStatGrid extends StatelessWidget {
  const HivorrStatGrid({
    super.key,
    required this.columns,
    required this.maxWidth,
    required this.children,
    this.gap = HivorrSpacing.md,
  });

  final int columns;
  final double maxWidth;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final double cardWidth = (maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: <Widget>[
        for (final Widget card in children)
          SizedBox(width: cardWidth, child: card),
      ],
    );
  }
}
