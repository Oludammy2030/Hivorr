import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:provider/provider.dart';

/// KYC upgrade flow screen (EP-02-12 §5.7).
///
/// Lists the tiers reachable from the current assignment (from
/// [KycProvider]), their requirements, and a "Start verification" CTA that
/// reuses the existing identity-document upload path — it is a router, not a
/// duplicate upload.
class KycUpgradeScreen extends StatefulWidget {
  const KycUpgradeScreen({super.key});

  @override
  State<KycUpgradeScreen> createState() => _KycUpgradeScreenState();
}

class _KycUpgradeScreenState extends State<KycUpgradeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final KycProvider provider = context.read<KycProvider>();
      if (provider.kycLevel == null) {
        unawaited(provider.load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final KycProvider provider = context.watch<KycProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrade verification', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(child: _body(context, provider)),
    );
  }

  Widget _body(BuildContext context, KycProvider provider) {
    final KycLevel? level = provider.kycLevel;
    if (level == null) {
      if (provider.loadState == KycLoadState.error) {
        return HivorrErrorState(
          message: provider.lastError?.message ?? 'Unable to load KYC status.',
          onRetry: provider.load,
        );
      }
      return const HivorrLoadingState(message: 'Loading upgrade options…');
    }

    final List<KycTier> eligible = provider.nextEligibleTier == null
        ? const <KycTier>[]
        : <KycTier>[provider.nextEligibleTier!];

    return ListView(
      padding: const EdgeInsets.all(HivorrSpacing.lg),
      children: <Widget>[
        Text(
          'Eligible upgrades',
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: HivorrSpacing.sm),
        if (eligible.isEmpty)
          const _NoUpgradeNote()
        else ...<Widget>[
          for (final KycTier tier in eligible) ...<Widget>[
            _UpgradeTile(tier: tier),
            const SizedBox(height: HivorrSpacing.sm),
          ],
          const SizedBox(height: HivorrSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(RoutePaths.verificationIdentity),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Start verification'),
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            'Submitting identity proof may unlock a higher tier. '
            'Your document is verified by a reviewer.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({required this.tier});

  final KycTier tier;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      elevation: 1,
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_open_outlined, size: 20, color: colors.primary),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(tier.displayLabel, style: context.textTheme.titleSmall),
                Text(
                  tier.code,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoUpgradeNote extends StatelessWidget {
  const _NoUpgradeNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'You are already at the highest available tier.',
      style: context.textTheme.bodyMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
