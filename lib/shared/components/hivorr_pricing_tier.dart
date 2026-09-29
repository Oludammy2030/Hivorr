import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Pricing tier card (VISUAL-IDENTITY.md §§15, 18).
///
/// Name, price headline + caption, check-marked feature list and a CTA.
/// The [highlighted] tier raises (Level-1 shadow) with a primary border and a
/// `primaryContainer` tint; others stay flat. Copy must stay honest — no
/// invented fee figures.
class HivorrPricingTier extends StatelessWidget {
  const HivorrPricingTier({
    super.key,
    required this.name,
    required this.price,
    required this.caption,
    required this.features,
    required this.ctaLabel,
    this.onCta,
    this.highlighted = false,
  });

  final String name;
  final String price;
  final String caption;
  final List<String> features;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return HivorrCard(
      elevation: highlighted ? 1 : 0,
      child: Container(
        decoration: highlighted
            ? BoxDecoration(
                border: Border.all(color: colors.primary, width: 1.5),
                borderRadius: BorderRadius.circular(ext.radiusMd),
                color: colors.primaryContainer.withValues(alpha: 0.35),
              )
            : null,
        padding: const EdgeInsets.all(HivorrSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              name,
              style: context.textTheme.labelLarge?.copyWith(
                color: colors.primary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              price,
              style: context.textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              caption,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            for (final String feature in features) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: HivorrSpacing.sm),
                  Expanded(
                    child: Text(
                      feature,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.xs),
            ],
            const SizedBox(height: HivorrSpacing.md),
            HivorrButton(
              label: ctaLabel,
              variant: highlighted
                  ? HivorrButtonVariant.primary
                  : HivorrButtonVariant.outline,
              isExpanded: true,
              onPressed: onCta,
            ),
          ],
        ),
      ),
    );
  }
}
