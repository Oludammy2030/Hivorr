import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/escrow_milestone.dart';
import 'package:hivorr/data/entities/escrow_transaction.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/models/escrow_status.dart';
import 'package:hivorr/systems/finance/widgets/escrow_card.dart';
import 'package:hivorr/systems/finance/widgets/escrow_dispute_banner.dart';
import 'package:hivorr/systems/finance/widgets/escrow_status_badge.dart';
import 'package:hivorr/systems/finance/widgets/escrow_write_cta_panel.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';
import 'package:provider/provider.dart';

/// Escrow detail screen (EP-02-14 §5.6).
///
/// `GET /finance/escrow/:id`. Renders the header badge + amount + `***ref`,
/// the dispute banner when frozen, the [MilestoneListCard] progress, the
/// [EscrowWriteCtaPanel] action surface (guidance while the write seam is off,
/// provider actions when on — disputed escrows always disabled), and a
/// read-only ledger summary.
class EscrowDetailScreen extends StatefulWidget {
  const EscrowDetailScreen({
    super.key,
    required this.escrowId,
    this.onViewDispute,
  });

  /// The escrow to load (`:id` path parameter).
  final String escrowId;

  /// Routes to the EP-02-05 dispute screen. May be `null` to hide the link.
  final VoidCallback? onViewDispute;

  @override
  State<EscrowDetailScreen> createState() => _EscrowDetailScreenState();
}

class _EscrowDetailScreenState extends State<EscrowDetailScreen>
    with WidgetsBindingObserver {
  late final EscrowProvider _provider;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<EscrowProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_provider.select(widget.escrowId));
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
      unawaited(_provider.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Escrow', style: context.textTheme.titleLarge),
      ),
      body: Consumer<EscrowProvider>(
        builder: (BuildContext context, EscrowProvider provider, _) {
          if (provider.isLoading && !provider.isLoaded) {
            return const HivorrLoadingState(message: 'Loading escrow...');
          }

          if (provider.lastError != null && !provider.isLoaded) {
            return HivorrErrorState(
              message: 'Failed to load escrow',
              detail: provider.lastError!.message,
              onRetry: () => provider.select(widget.escrowId),
            );
          }

          final Escrow? escrow = provider.selected;
          if (escrow == null) {
            return HivorrErrorState(
              message: 'Escrow not found',
              detail: 'No escrow matches this reference.',
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                if (escrow.isDisputed) ...<Widget>[
                  EscrowDisputeBanner(onViewDispute: widget.onViewDispute),
                  const SizedBox(height: HivorrSpacing.lg),
                ],
                _HeaderCard(escrow: escrow),
                const SizedBox(height: HivorrSpacing.lg),
                MilestoneListCard(
                  milestones: provider.milestones,
                  totalAmount: escrow.totalAmount,
                  currencyCode: escrow.currencyCode,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                _TransactionSummary(
                  transactions:
                      provider.transactionsByEscrowId[escrow.id] ??
                      const <EscrowTransaction>[],
                  currencyCode: escrow.currencyCode,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                EscrowWriteCtaPanel(
                  writeAvailable: provider.writeAvailable,
                  isDisputed: escrow.isDisputed,
                  isBusy: provider.isLoading,
                  onCompleteMilestone: _completeAction(provider),
                  onReleaseMilestone: _releaseAction(provider),
                  onReleaseFinal: () => provider.releaseFinal(),
                  onRefund: () => provider.refundEscrow(reason: 'Requested via support'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Bound `completeMilestone` for the first actionable milestone.
  VoidCallback? _completeAction(EscrowProvider provider) {
    final EscrowMilestone? target = _firstActionable(provider.milestones);
    if (target == null) return null;
    return () => provider.completeMilestone(milestoneId: target.id);
  }

  /// Bound `releaseMilestone` for the first completed milestone.
  VoidCallback? _releaseAction(EscrowProvider provider) {
    for (final EscrowMilestone milestone in provider.milestones) {
      if (milestone.isCompleted) {
        return () => provider.releaseMilestone(milestoneId: milestone.id);
      }
    }
    return null;
  }

  /// First pending-or-completed milestone by sort order (the "next" action).
  static EscrowMilestone? _firstActionable(List<EscrowMilestone> milestones) {
    if (milestones.isEmpty) return null;
    return milestones
        .where((EscrowMilestone m) => m.isPending || m.isCompleted)
        .toList()
        .reduce(
          (EscrowMilestone a, EscrowMilestone b) =>
              a.sortOrder <= b.sortOrder ? a : b,
        );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.escrow});

  final Escrow escrow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final EscrowStatus? status = EscrowStatus.forCode(escrow.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  BalanceFormatter.formatBalance(
                    escrow.totalAmount,
                    escrow.currencyCode,
                  ),
                  style: context.textTheme.titleLarge,
                ),
              ),
              if (status != null) EscrowStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ref ${EscrowCard.truncateReference(escrow.externalReference)}',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                'Held: ${BalanceFormatter.formatBalance(escrow.heldAmount, escrow.currencyCode)}',
                style: context.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: HivorrSpacing.md),
              Text(
                'Released: ${BalanceFormatter.formatBalance(escrow.releasedAmount, escrow.currencyCode)}',
                style: context.textTheme.labelMedium?.copyWith(
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

class _TransactionSummary extends StatelessWidget {
  const _TransactionSummary({
    required this.transactions,
    required this.currencyCode,
  });

  final List<EscrowTransaction> transactions;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Ledger', style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            Text(
              'Ledger entries appear once funds move within this escrow.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            for (final EscrowTransaction transaction in transactions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Icon(
                      transaction.isInbound
                          ? Icons.north_east
                          : Icons.south_east,
                      size: 16,
                      color: transaction.isInbound
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transaction.type,
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      BalanceFormatter.formatBalance(
                        transaction.amount,
                        currencyCode,
                      ),
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}