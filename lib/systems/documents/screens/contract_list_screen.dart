import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:provider/provider.dart';

/// Caller contracts list (EP-03-10 §8 D12 route `/contracts`).
///
/// Renders one [_ContractRow] per contract with a status filter chip row,
/// pull-to-refresh, keyset pagination, and branded loading/error/empty
/// states. Follows the `MyListingsScreen` lifecycle convention (one-shot
/// initial load, resume reload). Tap navigates to `contractDetail(id)`.
/// Tokens only (`AGENT.md` Rule 5).
class ContractListScreen extends StatefulWidget {
  const ContractListScreen({super.key});

  @override
  State<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends State<ContractListScreen>
    with WidgetsBindingObserver {
  late final ServiceContractProvider _provider;
  bool _initialized = false;
  String? _statusFilter;

  static const List<String?> _filters = <String?>[
    null,
    'offered',
    'active',
    'completed',
    'closed',
    'cancelled',
    'disputed',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<ServiceContractProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load());
    }
  }

  Future<void> _load() => _provider.loadMine(status: _statusFilter);

  void _applyFilter(String? status) {
    setState(() => _statusFilter = status);
    unawaited(_provider.loadMine(status: status));
  }

  String _filterLabel(String? status) {
    if (status == null) return 'All';
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Contracts')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: HivorrSpacing.sm,
                ),
                child: HivorrSectionHeader(
                  title: 'My contracts',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Wrap(
                spacing: HivorrSpacing.xs,
                runSpacing: HivorrSpacing.xs,
                children: <Widget>[
                  for (final String? filter in _filters)
                    HivorrChip(
                      label: _filterLabel(filter),
                      isSelected: _statusFilter == filter,
                      onSelected: (_) => _applyFilter(filter),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: HivorrSpacing.md)),
            SliverToBoxAdapter(
              child: Consumer<ServiceContractProvider>(
                builder:
                    (BuildContext context, ServiceContractProvider provider, _) {
                      switch (provider.loadState) {
                        case ServiceContractLoadState.idle:
                        case ServiceContractLoadState.loading:
                          if (provider.contracts.isEmpty) {
                            return const HivorrLoadingState(
                              message: 'Loading contracts…',
                            );
                          }
                          return _ContractList(
                            contracts: provider.contracts,
                            hasMore: provider.hasMore,
                            onLoadMore: provider.loadMore,
                          );
                        case ServiceContractLoadState.loaded:
                          if (provider.isEmpty) {
                            return const HivorrEmptyState(
                              title: 'No contracts yet',
                              subtitle:
                                  'Request a service from a listing to start your first contract.',
                            );
                          }
                          return _ContractList(
                            contracts: provider.contracts,
                            hasMore: provider.hasMore,
                            onLoadMore: provider.loadMore,
                          );
                        case ServiceContractLoadState.error:
                          final ApiException? error = provider.lastError;
                          return HivorrErrorState(
                            message: 'Could not load contracts',
                            detail:
                                error?.message ?? 'Something went wrong.',
                            onRetry: _load,
                          );
                      }
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContractList extends StatelessWidget {
  const _ContractList({
    required this.contracts,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<ServiceContract> contracts;
  final bool hasMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final ServiceContract contract in contracts)
          Padding(
            padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
            child: _ContractRow(contract: contract),
          ),
        if (hasMore)
          TextButton(onPressed: () => unawaited(onLoadMore()), child: const Text('Load more')),
      ],
    );
  }
}

class _ContractRow extends StatelessWidget {
  const _ContractRow({required this.contract});

  final ServiceContract contract;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      onTap: () => context.push(
        RoutePaths.contractDetail(contract.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  contract.listingTitle ?? 'Service contract',
                  style: context.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              ContractStatusBadge(status: contract.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            BalanceFormatter.formatBalance(
              contract.totalAmount,
              contract.currencyCode,
            ),
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
