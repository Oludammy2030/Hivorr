import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Numbered how-it-works step (VISUAL-IDENTITY.md §§14, 17).
///
/// Primary-colored step number (`01`), section-heading title and supporting
/// body. Shared by the welcome teaser and the full How-it-works page so both
/// read as the same product.
class HivorrStepCard extends StatelessWidget {
  const HivorrStepCard({
    super.key,
    required this.step,
    required this.title,
    required this.body,
  });

  final int step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '0$step',
          style: context.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          title,
          style: context.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          body,
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
