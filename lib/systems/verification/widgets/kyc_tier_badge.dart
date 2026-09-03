import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';

/// Tier header badge showing the KYC tier label + lifecycle status chip
/// (EP-02-12 §5.7).
///
/// Status coloring: `pending` → amber `warningContainer`, `active` → green
/// `successContainer`, `expired`/`unassigned` → grey `outline`. Uses [AppTheme]
/// tokens only — never `Colors.*` or inline hex.
class KycTierBadge extends StatelessWidget {
  const KycTierBadge({
    super.key,
    required this.level,
  });

  /// The KYC level (tier + status) to render.
  final KycLevel level;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final KycTier tier = KycTier.fromCode(level.tierCode);

    final (Color surface, Color foreground, String label) =
        _statusTone(colors, ext, level.status);

    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            tier.isVerified ? Icons.verified_outlined : Icons.lock_outline,
            size: 28,
            color: tier.isVerified ? ext.success : colors.onSurfaceVariant,
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tier.displayLabel,
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  level.tierCode,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(ext.radiusSm),
            ),
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _statusTone(
    ColorScheme colors,
    AppThemeExtension ext,
    String status,
  ) {
    switch (status) {
      case 'active':
        return (ext.successContainer, ext.onSuccessContainer, 'Active');
      case 'pending':
        return (ext.warningContainer, ext.onWarningContainer, 'Pending');
      default:
        return (colors.surfaceContainerHighest, colors.onSurfaceVariant, 'Expired');
    }
  }
}
