import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Limits grid showing Daily / Weekly / Monthly / Cashout chips (EP-02-12 §5.7).
///
/// Each value formatted via [HivorrFormatters] (`₦50,000`), rendered on an
/// [HivorrCard] with token elevation/radius. Uses [AppTheme] tokens only.
class KycLimitsCard extends StatelessWidget {
  const KycLimitsCard({
    super.key,
    required this.level,
  });

  /// The KYC level whose limits to display.
  final KycLevel level;

  @override
  Widget build(BuildContext context) {
    final KycLimits limits = level.limits;
    return HivorrCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Transaction limits',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.xs,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              _LimitChip(label: 'Daily', value: _ngn(limits.daily)),
              _LimitChip(label: 'Weekly', value: _ngn(limits.weekly)),
              _LimitChip(label: 'Monthly', value: _ngn(limits.monthly)),
              _LimitChip(label: 'Cashout', value: _ngn(limits.cashout)),
            ],
          ),
        ],
      ),
    );
  }

  static String _ngn(num value) => '₦${HivorrFormatters.number(value, decimals: 0)}';
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: HivorrSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ext.radiusSm),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
