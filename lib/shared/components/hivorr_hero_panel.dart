import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Gradient hero panel for landing and major public pages
/// (VISUAL-IDENTITY.md §§16–18).
///
/// Brand gradient background (`#1A2AD4 → #2D3FE7 → #4F5FEF`) with white
/// content: optional eyebrow, a display headline, supporting copy, up to two
/// actions, and an optional statistics row. The primary action renders as a
/// white fill with brand text (contrast-safe on the gradient); the secondary
/// renders as a white outlined button.
class HivorrHeroPanel extends StatelessWidget {
  const HivorrHeroPanel({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.statistics = const <HivorrHeroStat>[],
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final List<HivorrHeroStat> statistics;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final ColorScheme colors = context.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.roleTheme.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      padding: const EdgeInsets.all(HivorrSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (eyebrow != null) ...<Widget>[
            Text(
              eyebrow!,
              style: context.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: HivorrSpacing.sm),
          ],
          Text(
            title,
            // White-on-gradient is a deliberate §16 exception: the gradient
            // is identical in both themes, so literal white is correct here.
            style: context.textTheme.displaySmall?.copyWith(
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.md),
            Text(
              subtitle!,
              style: context.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
          if (primaryLabel != null || secondaryLabel != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.lg),
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (primaryLabel != null)
                  ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: colors.primary,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: HivorrSpacing.lg,
                        vertical: HivorrSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.radiusSm),
                      ),
                    ),
                    child: Text(primaryLabel!),
                  ),
                if (secondaryLabel != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: HivorrSpacing.lg,
                        vertical: HivorrSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.radiusSm),
                      ),
                    ),
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
          if (statistics.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.lg),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: HivorrSpacing.md),
            Wrap(
              spacing: HivorrSpacing.xl,
              runSpacing: HivorrSpacing.md,
              children: statistics,
            ),
          ],
        ],
      ),
    );
  }
}

/// Single white-on-gradient statistic for [HivorrHeroPanel].
class HivorrHeroStat extends StatelessWidget {
  const HivorrHeroStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
