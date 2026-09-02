import 'package:flutter/material.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:intl/intl.dart';

/// Displays the assigned KYC tier plus its numeric limits (EP-02-10 §5.6).
///
/// Backed by [KycLevel] and rendered entirely from [AppTheme] tokens — tier
/// label via `SurfaceTint`/`onSurfaceVariant`, limits as outline chips. No
/// hardcoded colors or font families.
class KycLevelCard extends StatelessWidget {
  const KycLevelCard({
    super.key,
    required this.level,
  });

  /// The assigned KYC level to render.
  final KycLevel level;

  static final NumberFormat _currency = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;

    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.workspace_premium_outlined,
                  size: 20, color: colors.primary),
              const SizedBox(width: HivorrSpacing.xs),
              Expanded(
                child: Text(
                  level.tierCode == 'tier_0'
                      ? 'Not verified'
                      : _tierTitle(level.tierCode),
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.xs,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              _Limit(label: 'Daily', value: _currency.format(level.limits.daily)),
              _Limit(
                label: 'Weekly',
                value: _currency.format(level.limits.weekly),
              ),
              _Limit(
                label: 'Monthly',
                value: _currency.format(level.limits.monthly),
              ),
              _Limit(
                label: 'Cashout',
                value: _currency.format(level.limits.cashout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _tierTitle(String tierCode) => switch (tierCode) {
        'tier_1' => 'Identity Verified',
        'tier_2' => 'Trade Verified',
        'tier_3' => 'Fully Verified',
        _ => 'Verified — $tierCode',
      };
}

class _Limit extends StatelessWidget {
  const _Limit({required this.label, required this.value});

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
