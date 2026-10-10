import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/documents/widgets/contract_milestone_adapter.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/finance/widgets/earnings_transaction_tile.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';
import 'package:hivorr/systems/support/widgets/escrow_frozen_banner.dart';
import 'package:provider/provider.dart';

/// Per-contract earnings drill-down (EP-03-16).
///
/// Contract header ([ContractStatusBadge]), milestone rows ([MilestoneListCard]
/// via [ContractMilestoneAdapter]), and the contract-scoped ledger from
/// [TransactionHistoryProvider]. Actions deep-link only — `View contract`
/// ([RoutePaths.contractDetail]), `View escrow`
/// ([RoutePaths.escrowDetailFor]), `Get help`
/// ([RoutePaths.disputesFile]) — per the EP-03-10 boundary this screen files
/// nothing and releases nothing.
class ContractEarningsDetailScreen extends StatefulWidget {
  const ContractEarningsDetailScreen({super.key, required this.contractId});

  /// Authoritative `service_contracts.id`.
  final String contractId;

  @override
  State<ContractEarningsDetailScreen> createState() =>
      _ContractEarningsDetailScreenState();
}

class _ContractEarningsDetailScreenState
    extends State<ContractEarningsDetailScreen> {
  ServiceContractProvider? _contracts;
  late final TransactionHistoryProvider _history;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _contracts = context.read<ServiceContractProvider>();
    } on Object {
      _contracts = null;
    }
    _history = context.read<TransactionHistoryProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_contracts?.select(widget.contractId));
        unawaited(_history.setContract(widget.contractId));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServiceContractProvider? contracts = _contracts;
    if (contracts == null) {
      return HivorrScreenScaffold(
        appBar: AppBar(
          title: Text('Contract earnings', style: context.textTheme.titleLarge),
        ),
        body: const HivorrErrorState(
          message: 'Contract unavailable',
          detail: 'Open this screen from the contracts list.',
        ),
      );
    }
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text('Contract earnings', style: context.textTheme.titleLarge),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await contracts.select(widget.contractId);
          if (context.mounted) await _history.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          children: <Widget>[
            Consumer<ServiceContractProvider>(
              builder: (
                BuildContext context,
                ServiceContractProvider provider,
                _,
              ) {
                if (provider.isLoading && provider.selected == null) {
                  return const HivorrLoadingState(
                    message: 'Loading contract...',
                  );
                }
                if (provider.lastError != null &&
                    provider.selected == null) {
                  return HivorrErrorState(
                    message: 'Failed to load contract',
                    detail: provider.lastError!.message,
                    onRetry: () => unawaited(provider.select(widget.contractId)),
                  );
                }
                final ServiceContract? contract = provider.selected;
                if (contract == null) {
                  return const HivorrEmptyState(
                    title: 'Contract not found',
                    subtitle: 'It may have been closed or removed.',
                    compact: true,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        ContractStatusBadge(status: contract.status),
                        const Spacer(),
                        Text(
                          '…${widget.contractId.length <= 4 ? widget.contractId : widget.contractId.substring(widget.contractId.length - 4)}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (contract.isDisputed) ...<Widget>[
                      const SizedBox(height: HivorrSpacing.md),
                      EscrowFrozenBanner(
                        onViewDispute: contract.escrowId == null
                            ? null
                            : () => context.push(
                                RoutePaths.disputesFile(contract.escrowId!),
                              ),
                      ),
                    ],
                    const SizedBox(height: HivorrSpacing.lg),
                    const HivorrSectionHeader(title: 'Milestones'),
                    MilestoneListCard(
                      milestones: ContractMilestoneAdapter.toCardMilestones(
                        contract,
                      ),
                      totalAmount: contract.totalAmount,
                      currencyCode: contract.currencyCode,
                    ),
                    const SizedBox(height: HivorrSpacing.md),
                    Wrap(
                      spacing: HivorrSpacing.sm,
                      runSpacing: HivorrSpacing.sm,
                      children: <Widget>[
                        HivorrButton(
                          label: 'View contract',
                          variant: HivorrButtonVariant.outline,
                          onPressed: () => context.push(
                            RoutePaths.contractDetail(widget.contractId),
                          ),
                        ),
                        if (contract.escrowId != null)
                          HivorrButton(
                            label: 'View escrow',
                            variant: HivorrButtonVariant.outline,
                            onPressed: () => context.push(
                              RoutePaths.escrowDetailFor(contract.escrowId!),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: HivorrSpacing.lg),
            const HivorrSectionHeader(title: 'Ledger'),
            Consumer<TransactionHistoryProvider>(
              builder: (
                BuildContext context,
                TransactionHistoryProvider provider,
                _,
              ) {
                if (provider.isLoading && provider.items.isEmpty) {
                  return const HivorrLoadingState(
                    message: 'Loading ledger...',
                  );
                }
                if (provider.lastError != null && provider.items.isEmpty) {
                  return HivorrErrorState(
                    message: 'Failed to load ledger',
                    detail: provider.lastError!.message,
                    onRetry: () => unawaited(provider.load()),
                  );
                }
                if (provider.items.isEmpty) {
                  return const HivorrEmptyState(
                    title: 'No ledger rows yet',
                    subtitle:
                        'Fund movements for this contract will appear here.',
                    compact: true,
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final item in provider.items)
                      EarningsTransactionTile(transaction: item),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
