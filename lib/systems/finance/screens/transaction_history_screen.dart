import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/earnings_transaction.dart';
import 'package:hivorr/data/providers/transaction_history_provider.dart';
import 'package:hivorr/data/repositories/earnings_repository.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/components/hivorr_select_field.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/models/supported_currency.dart';
import 'package:hivorr/systems/finance/widgets/earnings_notices.dart';
import 'package:hivorr/systems/finance/widgets/earnings_transaction_tile.dart';
import 'package:provider/provider.dart';

/// Filterable ledger history over `financial_transactions` (EP-03-16).
///
/// Type chips (`All` / `Earned` / `Withdrawn` / `Locked` / `Frozen`), currency
/// selector, and keyset infinite scroll — rows render verbatim in server
/// order and drill into the attributed contract. Display-only: filtering and
/// pagination are server-executed via `service_transaction_history`.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key, this.contractId});

  /// Optional contract scoping (`?contractId=` deep-link).
  final String? contractId;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late final TransactionHistoryProvider _provider;
  late final ScrollController _scroll;
  bool _initialized = false;

  static const Map<String, String> _chipLabels = <String, String>{
    EarningsHistoryFilter.all: 'All',
    EarningsHistoryFilter.earned: 'Earned',
    EarningsHistoryFilter.withdrawn: 'Withdrawn',
    EarningsHistoryFilter.fundLocked: 'Locked',
    EarningsHistoryFilter.frozen: 'Frozen',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<TransactionHistoryProvider>();
    if (!_initialized) {
      _initialized = true;
      _scroll = ScrollController()..addListener(_onScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_provider.setCurrency(_provider.currency));
        if (widget.contractId != null) {
          unawaited(_provider.setContract(widget.contractId));
        } else {
          unawaited(_provider.load());
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double edge = _scroll.position.maxScrollExtent;
    if (edge <= 0) return;
    if (_scroll.offset >= edge - 240) {
      unawaited(_provider.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(
        title: Text(
          widget.contractId == null
              ? 'Transaction history'
              : 'Contract activity',
          style: context.textTheme.titleLarge,
        ),
      ),
      body: Consumer<TransactionHistoryProvider>(
        builder: (
          BuildContext context,
          TransactionHistoryProvider provider,
          _,
        ) {
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                const EarningsOfflineBanner(),
                const SizedBox(height: HivorrSpacing.md),
                Wrap(
                  spacing: HivorrSpacing.sm,
                  runSpacing: HivorrSpacing.sm,
                  children: <Widget>[
                    for (final String type in EarningsHistoryFilter.values)
                      HivorrChip(
                        label: _chipLabels[type] ?? type,
                        isSelected: provider.typeFilter == type,
                        onSelected: (_) =>
                            unawaited(provider.setType(type)),
                      ),
                  ],
                ),
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
                  },
                ),
                const SizedBox(height: HivorrSpacing.md),
                if (provider.contractId != null)
                  HivorrChip(
                    label: 'Contract …${provider.contractId!.length <= 4 ? provider.contractId! : provider.contractId!.substring(provider.contractId!.length - 4)}',
                    isSelected: true,
                    onDismissed: () =>
                        unawaited(provider.setContract(null)),
                  ),
                if (provider.contractId != null)
                const SizedBox(height: HivorrSpacing.md),
                _DateRangeRow(
                  from: provider.dateFrom,
                  to: provider.dateTo,
                  onPickFrom: (DateTime? picked) => unawaited(
                    provider.setDateRange(picked, provider.dateTo),
                  ),
                  onPickTo: (DateTime? picked) => unawaited(
                    provider.setDateRange(provider.dateFrom, picked),
                  ),
                  onClear: () => unawaited(
                    provider.setDateRange(null, null),
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
                _HistoryBody(
                  provider: provider,
                  onRetry: () => unawaited(provider.load()),
                  onClearFilters: () => provider.clearFilters(),
                  onViewContract: (String? contractId) {
                    if (contractId == null) return;
                    unawaited(
                      context.push(
                        RoutePaths.contractEarningsDetail(contractId),
                      ),
                    );
                  },
                ),
                if (provider.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: HivorrSpacing.md,
                    ),
                    child: HivorrLoadingState(
                      message: 'Loading more...',
                    ),
                  ),
                const SizedBox(height: HivorrSpacing.md),
                const EarningsKycUpsell(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Ledger body: loading / error / empty / rows (EP-03-16).
class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    required this.provider,
    required this.onRetry,
    required this.onClearFilters,
    required this.onViewContract,
  });

  final TransactionHistoryProvider provider;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final ValueChanged<String?> onViewContract;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const HivorrLoadingState(message: 'Loading history...');
    }
    if (provider.lastError != null && provider.items.isEmpty) {
      return HivorrErrorState(
        message: 'Failed to load history',
        detail: provider.lastError!.message,
        onRetry: onRetry,
      );
    }
    if (provider.items.isEmpty) {
      final bool filtered =
          provider.typeFilter != EarningsHistoryFilter.all ||
          provider.contractId != null ||
          provider.dateFrom != null ||
          provider.dateTo != null;
      return HivorrEmptyState(
        title: filtered ? 'No matches' : 'No activity yet',
        subtitle: filtered
            ? 'No earnings match this filter.'
            : 'Released payments and withdrawals will appear here.',
        actionButton: filtered
            ? HivorrButton(
                label: 'Clear filters',
                variant: HivorrButtonVariant.outline,
                onPressed: onClearFilters,
              )
            : null,
        compact: true,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const HivorrSectionHeader(title: 'Ledger'),
        for (final EarningsTransaction item in provider.items)
          EarningsTransactionTile(
            transaction: item,
            onTap: item.contractId == null
                ? null
                : () => onViewContract(item.contractId),
          ),
      ],
    );
  }
}

/// Date-window filter row driving the server `date_from`/`date_to` filters
/// (EP-03-16). Bounds open the platform date picker; the range applies
/// server-side on selection and clears without a reload loop. Uses only
/// [AppTheme] tokens via [HivorrChip] (AGENT.md Rule 5).
class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClear,
  });

  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onPickFrom;
  final ValueChanged<DateTime?> onPickTo;
  final VoidCallback onClear;

  Future<void> _pick(
    BuildContext context, {
    required bool isFrom,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? from : to) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null) return;
    if (isFrom) {
      onPickFrom(picked);
    } else {
      onPickTo(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool active = from != null || to != null;
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        HivorrChip(
          label: from == null
              ? 'From date'
              : 'From ${HivorrFormatters.date(from!)}',
          isSelected: from != null,
          onSelected: (_) => unawaited(_pick(context, isFrom: true)),
        ),
        HivorrChip(
          label: to == null ? 'To date' : 'To ${HivorrFormatters.date(to!)}',
          isSelected: to != null,
          onSelected: (_) => unawaited(_pick(context, isFrom: false)),
        ),
        if (active)
          HivorrChip(
            label: 'Clear dates',
            variant: HivorrChipVariant.surface,
            onSelected: (_) => onClear(),
          ),
      ],
    );
  }
}
