import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/trade_verification_status.dart';
import 'package:hivorr/data/entities/verification_status.dart';
import 'package:hivorr/data/providers/trade_verification_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/verification/gate/trade_verification_gate.dart';
import 'package:hivorr/systems/verification/widgets/trade_verification_timeline.dart';
import 'package:hivorr/systems/verification/widgets/trade_verified_badge.dart';
import 'package:provider/provider.dart';

/// Screen for per-profession trade-verification status tracking (EP-02-11
/// §5.6, §10).
///
/// Lists each bound profession with its [TradeVerificationTimeline] and a
/// [TradeVerifiedBadge] when approved. Shows a bid-lock panel when
/// [TradeVerificationGate.canBid] is `false` and a `HivorrErrorState` for
/// rejected proofs with a resubmit CTA. Owns the poll lifecycle via
/// [WidgetsBindingObserver].
class TradeVerificationStatusScreen extends StatefulWidget {
  const TradeVerificationStatusScreen({super.key});

  @override
  State<TradeVerificationStatusScreen> createState() =>
      _TradeVerificationStatusScreenState();
}

class _TradeVerificationStatusScreenState
    extends State<TradeVerificationStatusScreen> with WidgetsBindingObserver {
  late final TradeVerificationProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<TradeVerificationProvider>();
    _provider.startPolling();
    // Defer the initial refresh out of the build phase: refreshStatus()
    // synchronously notifies listeners, which is illegal mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_provider.refreshStatus());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _provider.pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_provider.refreshStatus());
      _provider.resumePolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trade verification', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(child: _content()),
    );
  }

  Widget _content() {
    final provider = context.watch<TradeVerificationProvider>();
    final status = provider.status;
    if (status == null) {
      return RefreshIndicator(
        onRefresh: provider.refreshStatus,
        child: ListView(children: <Widget>[const HivorrLoadingState()]),
      );
    }
    if (status.tradeVerifications.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.work_outline,
          color: context.colorScheme.primary,
        ),
        title: 'No bound professions',
        subtitle:
            'Add a profession to your profile to begin trade verification.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.refreshStatus,
      child: ListView(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        children: <Widget>[
          for (final TradeVerification entry in status.tradeVerifications)
            _ProfessionSection(
              key: ValueKey<String>(entry.professionId),
              entry: entry,
              canBid: TradeVerificationGate.canBid(status, entry.professionId),
              onUpload: () => context.push(RoutePaths.tradeProofUpload),
            ),
        ],
      ),
    );
  }
}

class _ProfessionSection extends StatelessWidget {
  const _ProfessionSection({
    super.key,
    required this.entry,
    required this.canBid,
    required this.onUpload,
  });

  final TradeVerification entry;
  final bool canBid;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final kind = entry.statusKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Profession',
          style: context.textTheme.bodySmall
              ?.copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
            side: BorderSide(color: context.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _shortId(entry.professionId),
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: HivorrSpacing.md),
                if (canBid)
                  TradeVerifiedBadge(
                    professionName: _shortId(entry.professionId),
                    subtitle: 'Bidding unlocked',
                  )
                else
                  _BidLockPanel(onUpload: onUpload),
                const SizedBox(height: HivorrSpacing.md),
                TradeVerificationTimeline(entry: entry),
                if (kind == TradeVerificationStatusKind.rejected) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.md),
                  HivorrErrorState(
                    message: 'This trade proof was not approved.',
                    detail: 'Please upload a new, clearer proof to continue.',
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  HivorrButton(
                    label: 'Resubmit',
                    isExpanded: true,
                    onPressed: onUpload,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: HivorrSpacing.lg),
      ],
    );
  }

  static String _shortId(String id) => id.length > 13
      ? 'Profession ${id.substring(0, 8)}'
      : 'Profession $id';
}

class _BidLockPanel extends StatelessWidget {
  const _BidLockPanel({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return HivorrCard(
      elevation: 0,
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_outline, color: colors.error),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Text(
              'Unverified — bidding is locked until your trade is approved.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onUpload, child: const Text('Verify')),
        ],
      ),
    );
  }
}
