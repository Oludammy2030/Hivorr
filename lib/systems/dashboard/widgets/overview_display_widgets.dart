import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Shared overview display primitives (hire + offer mirrors merged).
///
/// Extracted verbatim from `dashboard_overview_screen.dart` (`_HeroStat` ≡
/// `_ProHeroStat`, `_SoftChip` ≡ `_ProSoftChip`): glass stat tile and soft
/// status chip used on both dashboard heroes. White-on-brand fills are the
/// sanctioned §2 exception (verified contrast on hero gradients).

/// Glass stat tile for hero gradients: value + label, centered.
class OverviewHeroStat extends StatelessWidget {
  const OverviewHeroStat({
    super.key,
    required this.value,
    required this.label,
    this.width = 132,
    this.compact = false,
  });

  final String value;
  final String label;

  /// Fixed tile width where the hero lays stats out in a row; `null` lets
  /// the tile size to content (e.g. wrapped grids).
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // White-on-brand exception (§2): hero gradients only.
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? HivorrSpacing.smMd : HivorrSpacing.md,
        vertical: compact ? HivorrSpacing.sm : HivorrSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(
          context.appExtension.radiusXs,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleMedium
                    : context.textTheme.titleLarge)
                ?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Soft tinted status chip: tinted background + bold small label.
class OverviewSoftChip extends StatelessWidget {
  const OverviewSoftChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
