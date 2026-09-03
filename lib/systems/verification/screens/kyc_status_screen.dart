import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/kyc_level.dart';
import 'package:hivorr/data/providers/kyc_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/verification/models/kyc_tier.dart';
import 'package:hivorr/systems/verification/widgets/kyc_limits_card.dart';
import 'package:hivorr/systems/verification/widgets/kyc_tier_badge.dart';
import 'package:hivorr/systems/verification/widgets/kyc_upgrade_card.dart';
import 'package:provider/provider.dart';

/// Screen summarising the KYC status and tier limits (EP-02-12 §5.7).
///
/// Consumes [KycProvider], kicks off a `load()` on init and polls every 15s
/// while the assignment is `pending`. Renders the [KycTierBadge],
/// [KycLimitsCard] and a [KycUpgradeCard] CTA when higher tiers are reachable.
/// All theming via [AppTheme] tokens.
class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen>
    with WidgetsBindingObserver {
  late final KycProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<KycProvider>();
    _provider.startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_provider.load());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.resumePolling();
    } else {
      _provider.pausePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final KycProvider provider = context.watch<KycProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('KYC Verification', style: context.textTheme.titleLarge),
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
      return const HivorrLoadingState(message: 'Loading KYC status…');
    }

    final List<KycTier> eligible = provider.nextEligibleTier == null
        ? const <KycTier>[]
        : <KycTier>[provider.nextEligibleTier!];

    return RefreshIndicator(
      onRefresh: provider.refreshStatus,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        children: <Widget>[
          KycTierBadge(level: level),
          const SizedBox(height: HivorrSpacing.lg),
          KycLimitsCard(level: level),
          const SizedBox(height: HivorrSpacing.lg),
          if (eligible.isNotEmpty) ...<Widget>[
            KycUpgradeCard(
              eligibleTiers: eligible,
              onStartVerification: () =>
                  context.push(RoutePaths.kycUpgrade),
            ),
          ] else if (provider.currentTier == KycTier.tier3) ...<Widget>[
            HivorrEmptyState(
              icon: const Icon(Icons.verified),
              title: 'Fully verified',
              subtitle:
                  'You have the maximum limits available on Hivorr.',
            ),
          ],
        ],
      ),
    );
  }
}
