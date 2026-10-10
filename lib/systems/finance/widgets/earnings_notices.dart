import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/sync/sync_status.dart';
import 'package:hivorr/core/sync/sync_status_provider.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/shared/components/hivorr_cta_band.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:provider/provider.dart';

/// `tier_0` withdrawal upsell for earnings screens (EP-03-16).
///
/// Reads are never gated — this band renders only when a [KycProvider] is
/// mounted and its tier is unverified, guiding toward withdrawals without
/// blocking earnings visibility. Absent in isolated harnesses. Uses only
/// [AppTheme] tokens via [HivorrCtaBand] (AGENT.md Rule 5).
class EarningsKycUpsell extends StatelessWidget {
  const EarningsKycUpsell({super.key});

  @override
  Widget build(BuildContext context) {
    KycTier tier = KycTier.tier1;
    try {
      tier = context.watch<KycProvider>().currentTier;
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (tier.isAtLeastVerified) return const SizedBox.shrink();
    return HivorrCtaBand(
      title: 'Verify your identity to withdraw',
      subtitle:
          'Reading your earnings is free. Withdrawals, payouts, and higher limits unlock at a verified tier.',
      actions: <Widget>[
        HivorrButton(
          label: 'Verify identity',
          onPressed: () => context.push(RoutePaths.kycUpgrade),
        ),
      ],
    );
  }
}

/// Offline notice for earnings screens (EP-03-16).
///
/// Renders only when a [SyncStatusProvider] is mounted and reports
/// [SyncStatus.offline]; the cached earnings window stays visible behind it
/// (read-only — nothing queues for replay). Absent in isolated harnesses.
/// Uses only [AppTheme] tokens (AGENT.md Rule 5).
class EarningsOfflineBanner extends StatelessWidget {
  const EarningsOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    SyncStatus status = SyncStatus.idle;
    try {
      status = context.watch<SyncStatusProvider>().status;
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (status != SyncStatus.offline) return const SizedBox.shrink();
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: HivorrSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ext.warningContainer,
        borderRadius: BorderRadius.circular(ext.radiusSm),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: ext.onWarningContainer,
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Text(
              'You are offline — showing your last synced earnings.',
              style: context.textTheme.labelMedium?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
