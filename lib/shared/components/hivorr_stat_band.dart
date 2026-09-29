import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Statistics band for light content sections (VISUAL-IDENTITY.md §§15, 18).
///
/// A flat surface card holding a responsive [Wrap] of [HivorrStatItem]s.
/// For white-on-gradient hero statistics, use `HivorrHeroStat` in
/// [HivorrHeroPanel] instead.
class HivorrStatBand extends StatelessWidget {
  const HivorrStatBand({super.key, required this.items});

  final List<HivorrStatItem> items;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Wrap(
        spacing: HivorrSpacing.xl,
        runSpacing: HivorrSpacing.md,
        children: items,
      ),
    );
  }
}

/// Single value + label statistic for [HivorrStatBand].
class HivorrStatItem extends StatelessWidget {
  const HivorrStatItem({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(HivorrSpacing.sm),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(ext.radiusSm),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: HivorrSpacing.sm),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: context.textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
