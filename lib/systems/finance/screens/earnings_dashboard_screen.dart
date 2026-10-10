import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/earnings_summary.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/components/hivorr_select_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/analytics/services/service_analytics_service.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/widgets/earnings_notices.dart';
import 'package:hivorr/systems/finance/widgets/earnings_summary_header.dart';
import 'package:hivorr/systems/finance/widgets/earnings_transaction_tile.dart';
import 'package:hivorr/systems/finance/widgets/finance_history_badge.dart';
import 'package:hivorr/systems/finance/widgets/monthly_earnings_section.dart';
import 'package:hivorr/systems/support/widgets/escrow_frozen_banner.dart';
import 'package:provider/provider.dart';

/// Live earnings dashboard (EP-03-16).
///
/// Server-verified summary header, frozen-escrow notice, monthly chart, and
/// recent ledger preview — every figure rendered verbatim from
/// [EarningsProvider] / [TransactionHistoryProvider] (AGENT.md Rule 4).
/// Replaces the mock `EarningsScreen` seams; the dashboard shell keeps its
/// reference chrome and consumes the same providers. Pauses/resumes polling
/// with the app lifecycle via [WidgetsBindingObserver].
class EarningsDashboardScreen extends StatefulWidget {
  const EarningsDashboardScreen({super.key});

  @override
  State<EarningsDashboardScreen> createState() =>
      _EarningsDashboardScreenState();
}

class _EarningsDashboardScreenState extends State<EarningsDashboardScreen>
    with WidgetsBindingObserver {
  late final EarningsProvider _provider;
  late final TransactionHistoryProvider _history;
  bool _initialized = false;

  static const ServiceAnalyticsService _analytics = ServiceAnalyticsService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<EarningsProvider>();
    _history = context.read<TransactionHistoryProvider>();
    if (!_initialized) {
      _initialized = true;
      _provider.startPolling();
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_provider.load());
        unawaited(_history.load());
      });
    }
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

  Future<void> _refresh() async {
    await _provider.refresh();
    if (mounted) await _history.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text('Earnings', style: context.textTheme.titleLarge),
      ),
      body: Consumer<EarningsProvider>(
        builder: (BuildContext context, EarningsProvider provider, _) {
          if (provider.isLoading && !provider.isLoaded) {
            return const HivorrLoadingState(
              message: 'Loading earnings...',
            );
          }
          if (provider.lastError != null && !provider.isLoaded) {
            return HivorrErrorState(
              message: 'Failed to load earnings',
              detail: provider.lastError!.message,
              onRetry: () => unawaited(provider.load()),
            );
          }
          final EarningsSummary? summary = provider.summary;
          if (summary == null) {
            return HivorrEmptyState(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              title: 'No earnings yet',
              subtitle:
                  'Publish a listing to get hired — released milestone payments will appear here.',
              actionButton: HivorrButton(
                label: 'Browse services',
                onPressed: () =>
                    context.go(RoutePaths.serviceDiscovery),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                const EarningsOfflineBanner(),
                const SizedBox(height: HivorrSpacing.md),
                EarningsSummaryHeader(summary: summary),
                const SizedBox(height: HivorrSpacing.md),
                HivorrSelectField<String>(
                  label: 'Currency',
                  options: <SelectOption<String>>[
                    for (final SupportedCurrency c
                        in SupportedCurrency.values)
                      SelectOption<String>(
                        value: c.code,
                        label: '${c.symbol} ${c.name} (${c.code})',
                      ),
                  ],
                  selected: provider.currency,
                  onSelected: (String? code) {
                    if (code == null) return;
                    unawaited(provider.setCurrency(code));
                    unawaited(_history.setCurrency(code));
                  },
                ),
                if (summary.hasFrozen) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.md),
                  EscrowFrozenBanner(
                    onViewDispute: () =>
                        context.push(RoutePaths.disputes),
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
                MonthlyEarningsSection(
                  analytics: _analytics,
                  chartData: _analytics.monthBucketsToChartData(
                    summary.monthly,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.lg),
                const HivorrSectionHeader(title: 'Recent activity'),
                _RecentHistory(
                  history: _history,
                  onViewContract: (String? contractId) {
                    if (contractId == null) return;
                    unawaited(
                      context.push(
                        RoutePaths.contractEarningsDetail(contractId),
                      ),
                    );
                  },
                ),
                const SizedBox(height: HivorrSpacing.md),
                HivorrButton(
                  label: 'View full history',
                  variant: HivorrButtonVariant.outline,
                  onPressed: () =>
                      context.push(RoutePaths.earningsHistory),
                ),
                const SizedBox(height: HivorrSpacing.lg),
                FinanceHistoryBadge(
                  ledgerCount: _history.items.length,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                const EarningsKycUpsell(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Recent-ledger preview bound to the shared history provider (EP-03-16).
class _RecentHistory extends StatelessWidget {
  const _RecentHistory({required this.history, required this.onViewContract});

  final TransactionHistoryProvider history;
  final ValueChanged<String?> onViewContract;

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionHistoryProvider>(
      builder: (
        BuildContext context,
        TransactionHistoryProvider provider,
        _,
      ) {
        if (provider.isLoading && provider.items.isEmpty) {
          return const HivorrLoadingState(message: 'Loading activity...');
        }
        if (provider.lastError != null && provider.items.isEmpty) {
          return HivorrErrorState(
            message: 'Failed to load activity',
            detail: provider.lastError!.message,
            onRetry: () => unawaited(provider.load()),
          );
        }
        if (provider.items.isEmpty) {
          return const HivorrEmptyState(
            title: 'No activity yet',
            subtitle: 'Released payments and withdrawals will appear here.',
            compact: true,
          );
        }
        final int previewCount = provider.items.length > 5
            ? 5
            : provider.items.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < previewCount; i++)
              EarningsTransactionTile(
                transaction: provider.items[i],
                onTap: provider.items[i].contractId == null
                    ? null
                    : () => onViewContract(provider.items[i].contractId),
              ),
          ],
        );
      },
    );
  }
}
