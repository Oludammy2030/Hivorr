import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:hivorr/systems/support/widgets/dispute_status_badge.dart';
import 'package:provider/provider.dart';

/// Dispute list screen (EP-02-17 §5.7).
///
/// `GET /support/disputes`. Renders one `_DisputeCard` per case with a status
/// filter chip row, a file-dispute FAB, pull-to-refresh, and branded
/// loading/error/empty states. Follows the `EscrowListScreen` lifecycle
/// convention (lifecycle-observed, one-shot initial load).
class DisputeListScreen extends StatefulWidget {
  const DisputeListScreen({super.key});

  @override
  State<DisputeListScreen> createState() => _DisputeListScreenState();
}

class _DisputeListScreenState extends State<DisputeListScreen>
    with WidgetsBindingObserver {
  late final DisputeProvider _provider;
  bool _initialized = false;
  String? _statusFilter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<DisputeProvider>();
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

  Future<void> _load() => _provider.loadList(status: _statusFilter);

  void _applyFilter(String? status) {
    setState(() => _statusFilter = status);
    unawaited(_provider.loadList(status: status));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Disputes', style: context.textTheme.titleLarge),
      ),
      body: Consumer<DisputeProvider>(
        builder: (BuildContext context, DisputeProvider provider, _) {
          if (provider.isLoading && !provider.isLoaded) {
            return const HivorrLoadingState(message: 'Loading disputes...');
          }

          if (provider.lastError != null && !provider.isLoaded) {
            return HivorrErrorState(
              message: 'Failed to load disputes',
              detail: provider.lastError!.message,
              onRetry: _load,
            );
          }

          if (provider.disputes.isEmpty) {
            return HivorrEmptyState(
              icon: const Icon(Icons.gavel_outlined),
              title: 'No disputes yet',
              subtitle:
                  'Raise one from an escrow’s dispute action to freeze the '
                  'funds while a resolution is reached.',
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                _FilterChips(
                  selected: _statusFilter,
                  onSelected: _applyFilter,
                ),
                const SizedBox(height: HivorrSpacing.md),
                for (final DisputeCase case_ in provider.disputes) ...[
                  _DisputeCard(
                    case_: case_,
                    onTap: () =>
                        context.push(RoutePaths.disputeDetail.replaceAll(
                          ':id',
                          case_.id,
                        )),
                  ),
                  const SizedBox(height: HivorrSpacing.md),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<(String?, String)> filters = <(String?, String)>[
      (null, 'All'),
      for (final DisputeStatus status in DisputeService.disputeStatusList)
        (status.code, status.label),
    ];
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: <Widget>[
        for (final (String? code, String label) in filters)
          HivorrChip(
            label: label,
            isSelected: selected == code,
            onSelected: (_) => onSelected(code),
            variant: HivorrChipVariant.surface,
          ),
      ],
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.case_, this.onTap});

  final DisputeCase case_;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final DisputeStatus? status = DisputeStatus.forCode(case_.status);
    final DisputeType? type = DisputeType.forCode(case_.disputeType);

    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  type?.label ?? case_.disputeType,
                  style: context.textTheme.titleMedium,
                ),
              ),
              if (status != null) DisputeStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Counterparty ${idRefSuffix(case_.counterpartyEntityId)}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                HivorrFormatters.date(case_.filedAt),
                style: context.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}