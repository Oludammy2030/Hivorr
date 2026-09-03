import 'package:flutter/material.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Upgrade CTA listing eligible higher tiers and a "Start verification" button
/// (EP-02-12 §5.7).
///
/// Used on the KYC status screen when [eligibleTiers] is non-empty. The action
/// navigates to the upgrade flow; no upload logic lives here (it is a router).
class KycUpgradeCard extends StatelessWidget {
  const KycUpgradeCard({
    super.key,
    required this.eligibleTiers,
    required this.onStartVerification,
  });

  /// The list of tiers reachable from the current tier.
  final List<KycTier> eligibleTiers;

  /// Called when the user taps the upgrade CTA.
  final VoidCallback onStartVerification;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.trending_up, size: 20, color: colors.primary),
              const SizedBox(width: HivorrSpacing.xs),
              Expanded(
                child: Text(
                  'Unlock higher limits',
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Complete verification to unlock:',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.xs,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              for (final KycTier tier in eligibleTiers)
                _TierPill(tier: tier),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStartVerification,
              child: const Text('Start verification'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.tier});

  final KycTier tier;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      child: Text(
        tier.displayLabel,
        style: context.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
