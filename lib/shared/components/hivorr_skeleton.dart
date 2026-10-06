import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Static first-paint placeholders (VISUAL-IDENTITY.md §21h).
///
/// Skeletons mirror the target layout (list rows, card grids, tables) so
/// content never flashes from blank space or a lone spinner. Blocks are
/// intentionally static — no shimmer animation — so they are correct under
/// reduced motion with no extra code path. Callers show these while the first
/// page loads, then cross-fade to real content.
class HivorrSkeletonBlock extends StatelessWidget {
  const HivorrSkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(
          borderRadius ?? context.appExtension.radiusSm,
        ),
      ),
    );
  }
}

/// Skeleton list rows: avatar dot + two text lines, repeated [rows] times.
/// Use inside the same padding the real list uses.
class HivorrSkeletonList extends StatelessWidget {
  const HivorrSkeletonList({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    // Genuine fixed dim (§4): mirrors the 40dp list-avatar tile.
    const double dot = 40;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < rows; i++) ...<Widget>[
          const Row(
            children: <Widget>[
              HivorrSkeletonBlock(width: dot, height: dot),
              SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    HivorrSkeletonBlock(height: 14),
                    SizedBox(height: HivorrSpacing.xs),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: HivorrSkeletonBlock(height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i < rows - 1) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Divider(
              height: 1,
              color: context.colorScheme.outline,
            ),
            const SizedBox(height: HivorrSpacing.md),
          ],
        ],
      ],
    );
  }
}
