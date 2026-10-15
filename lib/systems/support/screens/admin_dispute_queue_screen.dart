import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/providers/admin_dispute_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
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
import 'package:hivorr/systems/support/widgets/dispute_status_badge.dart';
import 'package:provider/provider.dart';

/// Admin dispute queue (R3 follow-up).
///
/// Read-only, filterable view over ALL dispute cases inside the Admin shell,
/// reusing the EP-02-11 review-gate hosting pattern: the route lives under
/// `/admin`, access is fail-closed through [AdminGate] over the existing
/// `AdminReviewProvider`, and row authorization is server-side via
/// `is_platform_admin()`. Resolution stays service-role SQL/manual — this
/// screen offers no resolve/withdraw affordances.
class AdminDisputeQueueScreen extends StatefulWidget {
  const AdminDisputeQueueScreen({super.key});

  @override
  State<AdminDisputeQueueScreen> createState() => _AdminDisputeQueueScreenState();
}

class _AdminDisputeQueueScreenState extends State<AdminDisputeQueueScreen> {
  static const List<String?> _filters = <String?>[
    null,
    'open',
    'under_review',
    'resolved',
    'withdrawn',
    'closed',
  ];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isAdmin) {
          unawaited(context.read<AdminDisputeProvider>().loadQueue());
        }
      });
    }
  }

  bool get _isAdmin {
    try {
      return AdminGate.isAdmin(context.read<AdminReviewProvider>());
    } on ProviderNotFoundException {
      return false;
    }
  }

  Future<void> _applyFilter(String? status) async {
    await context.read<AdminDisputeProvider>().loadQueue(status: status);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Disputes', style: context.textTheme.titleLarge),
        ),
        body: const HivorrErrorState(
          message: 'Admin access required',
          detail: 'This queue is visible to platform admins only.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Disputes', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Consumer<AdminDisputeProvider>(
          builder: (BuildContext context, AdminDisputeProvider provider, _) {
            if (provider.isLoading && provider.queue.isEmpty) {
              return const HivorrLoadingState(
                message: 'Loading disputes…',
              );
            }
            final ApiException? error = provider.lastError;
            if (error != null && provider.queue.isEmpty) {
              return HivorrErrorState(
                message: 'Could not load disputes',
                detail: error.message,
                onRetry: () => unawaited(
                  provider.loadQueue(status: provider.statusFilter),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: provider.refresh,
              child: ListView(
                padding: const EdgeInsets.all(HivorrSpacing.lg),
                children: <Widget>[
                  _FilterRow(
                    active: provider.statusFilter,
                    onSelected: _applyFilter,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  Text(
                    '${provider.totalCount} case${provider.totalCount == 1 ? '' : 's'}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: HivorrSpacing.md),
                  if (provider.queue.isEmpty)
                    const HivorrEmptyState(
                      title: 'No disputes match this filter',
                      subtitle:
                          'Filed service and escrow disputes appear here for review.',
                    )
                  else
                    for (final DisputeCase case_ in provider.queue) ...[
                      _QueueCard(
                        case_: case_,
                        onTap: () => context.push(
                          RoutePaths.adminDisputeDetail.replaceAll(
                            ':caseId',
                            case_.id,
                          ),
                        ),
                      ),
                      const SizedBox(height: HivorrSpacing.sm),
                    ],
                  if (provider.hasMore) ...[
                    const SizedBox(height: HivorrSpacing.md),
                    OutlinedButton(
                      onPressed: provider.isLoading
                          ? null
                          : () => unawaited(provider.loadMore()),
                      child: Text(
                        provider.isLoading ? 'Loading…' : 'Load more',
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.active, required this.onSelected});

  final String? active;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: <Widget>[
        for (final String? code
            in _AdminDisputeQueueScreenState._filters)
          HivorrChip(
            label: code == null ? 'All' : _labelFor(code),
            isSelected: active == code,
            onSelected: (_) => onSelected(code),
          ),
      ],
    );
  }

  static String _labelFor(String code) =>
      DisputeStatus.forCode(code)?.label ?? code;
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.case_, required this.onTap});

  final DisputeCase case_;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DisputeStatus? status = DisputeStatus.forCode(case_.status);
    final DisputeType? type = DisputeType.forCode(case_.disputeType);
    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  type?.label ?? case_.disputeType,
                  style: context.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status != null) DisputeStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Case ${idRefSuffix(case_.id)}'
            '${case_.hasContract ? ' · Contract ${idRefSuffix(case_.contractId!)}' : ''}'
            '${case_.hasEscrow ? ' · Escrow ${idRefSuffix(case_.escrowId)}' : ' · unfunded'}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Filed ${HivorrFormatters.dateTime(case_.filedAt)}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
