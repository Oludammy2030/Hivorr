import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/quick_actions.dart';
import 'package:provider/provider.dart';

/// Client payments hub (EP-04-03).
///
/// Composes the client's hires (each linked to a funded/fundable escrow
/// contract) with entry points into the existing finance surfaces
/// (`/finance`, `/finance/escrow`, `/finance/convert`). Money movement stays
/// owned by the finance providers — this screen routes and summarizes.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<HireProvider>().loadList(role: 'client');

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Payments', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const HivorrSectionHeader(title: 'Money movement'),
                DashboardQuickActions(
                  actions: <DashboardQuickAction>[
                    DashboardQuickAction(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => context.go(RoutePaths.finance),
                    ),
                    DashboardQuickAction(
                      label: 'Escrow',
                      icon: Icons.lock_outline,
                      onTap: () => context.go(RoutePaths.escrow),
                    ),
                    DashboardQuickAction(
                      label: 'Convert',
                      icon: Icons.currency_exchange_outlined,
                      onTap: () => context.go(RoutePaths.convert),
                    ),
                    DashboardQuickAction(
                      label: 'Disputes',
                      icon: Icons.flag_outlined,
                      onTap: () => context.go(RoutePaths.disputes),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.xl),
                const HivorrSectionHeader(title: 'Hires to fund'),
                if (hires.isLoading && hires.hires.isEmpty)
                  const HivorrLoadingState()
                else if (hires.lastError != null && hires.hires.isEmpty)
                  HivorrErrorState(
                    message: 'Could not load hires',
                    detail: hires.lastError!.message,
                    onRetry: () => unawaited(_load()),
                  )
                else if (hires.hires.isEmpty)
                  HivorrEmptyState(
                    title: 'No payments yet',
                    subtitle:
                        'Funded escrows for your hires will appear here. Hire a professional to get started.',
                    actionButton: HivorrButton(
                      label: 'My Jobs',
                      onPressed: () => context.go(RoutePaths.dashboardJobs),
                    ),
                  )
                else
                  ...hires.hires.map(
                    (Hire hire) => Padding(
                      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
                      child: HireCard(
                        hire: hire,
                        onTap: () =>
                            context.go(RoutePaths.dashboardHireDetail(hire.id)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Professional earnings hub (EP-04-03).
///
/// Composes the professional's work (hires won) with entry points into the
/// existing finance surfaces. Payouts and balances stay owned by the finance
/// providers.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() =>
      context.read<HireProvider>().loadList(role: 'professional');

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final int active = hires.hires.where((Hire h) => h.isActive).length;
    final int completed = hires.hires
        .where((Hire h) => h.liveStatus == 'completed')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Earnings', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HivorrCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _Stat(label: 'Active work', value: '$active'),
                      ),
                      Expanded(
                        child: _Stat(label: 'Completed', value: '$completed'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
                DashboardQuickActions(
                  actions: <DashboardQuickAction>[
                    DashboardQuickAction(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => context.go(RoutePaths.finance),
                    ),
                    DashboardQuickAction(
                      label: 'Escrow',
                      icon: Icons.lock_outline,
                      onTap: () => context.go(RoutePaths.escrow),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.xl),
                const HivorrSectionHeader(title: 'Work history'),
                if (hires.isLoading && hires.hires.isEmpty)
                  const HivorrLoadingState()
                else if (hires.lastError != null && hires.hires.isEmpty)
                  HivorrErrorState(
                    message: 'Could not load work',
                    detail: hires.lastError!.message,
                    onRetry: () => unawaited(_load()),
                  )
                else if (hires.hires.isEmpty)
                  HivorrEmptyState(
                    title: 'No earnings yet',
                    subtitle:
                        'Win work through applications — completed hires and their payouts land here.',
                    actionButton: HivorrButton(
                      label: 'Find Jobs',
                      onPressed: () =>
                          context.go(RoutePaths.dashboardOpportunities),
                    ),
                  )
                else
                  ...hires.hires.map(
                    (Hire hire) => Padding(
                      padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
                      child: HireCard(
                        hire: hire,
                        onTap: () =>
                            context.go(RoutePaths.dashboardHireDetail(hire.id)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          value,
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
