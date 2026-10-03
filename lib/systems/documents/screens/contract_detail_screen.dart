import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_screen_scaffold.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/documents/widgets/contract_milestone_adapter.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/documents/widgets/contract_timeline.dart';
import 'package:hivorr/systems/documents/widgets/contract_write_cta_panel.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/finance/widgets/escrow_dispute_banner.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';
import 'package:provider/provider.dart';

/// Contract detail screen (EP-03-10 §8 D8).
///
/// `GET /contracts/:id`. Header (`contract_status_badge` + total +
/// participant role + `escrow_id` chip) + `MilestoneListCard` via adapter
/// (verbatim server order) + per-row role actions + `contract_timeline` +
/// `ContractWriteCtaPanel` + `escrow_dispute_banner` when `disputed`.
/// Role gating derives from `auth.uid()` vs the authoritative row and is
/// affordance only — enforcement stays server-side (`AGENT.md` Rule 4).
/// `PLT004` renders identically for foreign/unknown ids (no oracle).
/// Tokens only (Rule 5).
class ContractDetailScreen extends StatefulWidget {
  const ContractDetailScreen({super.key, required this.contractId});

  /// The `service_contracts.id` from the route (`:id`) — authoritative.
  final String contractId;

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  bool _initialized = false;
  bool _busy = false;
  String? _busyMilestoneId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            context.read<ServiceContractProvider>().select(widget.contractId),
          );
        }
      });
    }
  }

  String get _viewerId =>
      context.read<AuthProvider>().currentSession?.entityId ?? '';

  Future<void> _run(
    Future<ServiceContract> Function() action, {
    String? milestoneId,
    required String successMessage,
  }) async {
    setState(() {
      _busy = true;
      _busyMilestoneId = milestoneId;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: successMessage,
          variant: HivorrSnackbarVariant.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMilestoneId = null;
        });
      }
    }
  }

  Future<void> _confirmCancel(ServiceContract contract) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => HivorrDialog(
        title: 'Cancel contract?',
        content: const Text(
          'The offer will be cancelled. This cannot be undone.',
        ),
        actions: <Widget>[
          HivorrButton(
            label: 'Keep contract',
            variant: HivorrButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          HivorrButton(
            label: 'Cancel contract',
            variant: HivorrButtonVariant.primary,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ServiceContractProvider provider = context
        .read<ServiceContractProvider>();
    await _run(
      () => provider.cancel(contract.id),
      successMessage: 'Contract cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return HivorrScreenScaffold(
      appBar: AppBar(title: const Text('Contract')),
      body: Consumer<ServiceContractProvider>(
        builder:
            (BuildContext context, ServiceContractProvider provider, _) {
              switch (provider.loadState) {
                case ServiceContractLoadState.idle:
                case ServiceContractLoadState.loading:
                  if (provider.selected == null) {
                    return const HivorrLoadingState(
                      message: 'Loading contract…',
                    );
                  }
                  return _DetailBody(
                    contract: provider.selected!,
                    viewerId: _viewerId,
                    busy: _busy,
                    busyMilestoneId: _busyMilestoneId,
                    onAccept: () => _run(
                      () => provider.accept(provider.selected!.id),
                      successMessage: 'Offer accepted.',
                    ),
                    onCancel: () =>
                        _confirmCancel(provider.selected!),
                    onComplete: (ContractMilestone m) => _run(
                      () => provider.completeMilestone(
                        contractId: provider.selected!.id,
                        milestoneId: m.id,
                      ),
                      milestoneId: m.id,
                      successMessage: 'Milestone completed.',
                    ),
                    onVerify: (ContractMilestone m) => _run(
                      () => provider.verifyMilestone(
                        contractId: provider.selected!.id,
                        milestoneId: m.id,
                      ),
                      milestoneId: m.id,
                      successMessage: 'Milestone verified.',
                    ),
                    onRevision: (ContractMilestone m) => _run(
                      () => provider.verifyMilestone(
                        contractId: provider.selected!.id,
                        milestoneId: m.id,
                        action: 'revision_requested',
                      ),
                      milestoneId: m.id,
                      successMessage: 'Revision requested.',
                    ),
                    onClose: () => _run(
                      () => provider.close(provider.selected!.id),
                      successMessage: 'Contract closed.',
                    ),
                    onFileDispute: () => context.push(
                      RoutePaths.disputesFile(provider.selected!.id),
                    ),
                  );
                case ServiceContractLoadState.loaded:
                  final ServiceContract? contract = provider.selected;
                  if (contract == null) {
                    return const HivorrEmptyState(
                      title: 'Contract not found',
                      subtitle:
                          'It may have been removed or you may not have access.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: provider.refresh,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: HivorrSpacing.md,
                      ),
                      children: <Widget>[
                        _DetailBody(
                          contract: contract,
                          viewerId: _viewerId,
                          busy: _busy,
                          busyMilestoneId: _busyMilestoneId,
                          onAccept: () => _run(
                            () => provider.accept(contract.id),
                            successMessage: 'Offer accepted.',
                          ),
                          onCancel: () => _confirmCancel(contract),
                          onComplete: (ContractMilestone m) => _run(
                            () => provider.completeMilestone(
                              contractId: contract.id,
                              milestoneId: m.id,
                            ),
                            milestoneId: m.id,
                            successMessage: 'Milestone completed.',
                          ),
                          onVerify: (ContractMilestone m) => _run(
                            () => provider.verifyMilestone(
                              contractId: contract.id,
                              milestoneId: m.id,
                            ),
                            milestoneId: m.id,
                            successMessage: 'Milestone verified.',
                          ),
                          onRevision: (ContractMilestone m) => _run(
                            () => provider.verifyMilestone(
                              contractId: contract.id,
                              milestoneId: m.id,
                              action: 'revision_requested',
                            ),
                            milestoneId: m.id,
                            successMessage: 'Revision requested.',
                          ),
                          onClose: () => _run(
                            () => provider.close(contract.id),
                            successMessage: 'Contract closed.',
                          ),
                          onFileDispute: () => context.push(
                            RoutePaths.disputesFile(contract.id),
                          ),
                        ),
                      ],
                    ),
                  );
                case ServiceContractLoadState.error:
                  final ApiException? error = provider.lastError;
                  if (error?.kind == ApiExceptionKind.notFound) {
                    return const HivorrEmptyState(
                      title: 'Contract not found',
                      subtitle:
                          'It may have been removed or you may not have access.',
                    );
                  }
                  return HivorrErrorState(
                    message: 'Could not load contract',
                    detail: error?.message,
                    onRetry: () => unawaited(
                      provider.select(widget.contractId),
                    ),
                  );
              }
            },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.contract,
    required this.viewerId,
    required this.busy,
    required this.busyMilestoneId,
    required this.onAccept,
    required this.onCancel,
    required this.onComplete,
    required this.onVerify,
    required this.onRevision,
    required this.onClose,
    required this.onFileDispute,
  });

  final ServiceContract contract;
  final String viewerId;
  final bool busy;
  final String? busyMilestoneId;
  final VoidCallback onAccept;
  final VoidCallback onCancel;
  final ValueChanged<ContractMilestone> onComplete;
  final ValueChanged<ContractMilestone> onVerify;
  final ValueChanged<ContractMilestone> onRevision;
  final VoidCallback onClose;
  final VoidCallback onFileDispute;

  bool get _isClient => viewerId == contract.clientEntityId;
  bool get _isProfessional => viewerId == contract.professionalEntityId;
  bool get _isParticipant => _isClient || _isProfessional;

  @override
  Widget build(BuildContext context) {
    final bool disputed = contract.isDisputed;
    final bool writeAvailable =
        _isParticipant && !disputed && !contract.isTerminal;
    final ContractMilestone? actionable = _firstActionable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      contract.listingTitle ?? 'Service contract',
                      style: context.textTheme.titleSmall,
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
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _isClient
                    ? 'You are the client'
                    : _isProfessional
                    ? 'You are the professional'
                    : 'You are not a participant',
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              if (contract.escrowId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Escrow ${contract.escrowId!.length > 8 ? contract.escrowId!.substring(contract.escrowId!.length - 8) : contract.escrowId!}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        if (disputed) ...[
          EscrowDisputeBanner(onViewDispute: onFileDispute),
          const SizedBox(height: HivorrSpacing.md),
        ],
        MilestoneListCard(
          milestones: ContractMilestoneAdapter.toCardMilestones(contract),
          totalAmount: contract.totalAmount,
          currencyCode: contract.currencyCode,
        ),
        const SizedBox(height: HivorrSpacing.sm),
        for (final ContractMilestone m in contract.milestones)
          _MilestoneActions(
            milestone: m,
            viewerId: viewerId,
            contract: contract,
            busy: busy && busyMilestoneId == m.id,
            onComplete: () => onComplete(m),
            onVerify: () => onVerify(m),
            onRevision: () => onRevision(m),
          ),
        const SizedBox(height: HivorrSpacing.md),
        ContractTimeline(events: contract.events),
        const SizedBox(height: HivorrSpacing.md),
        ContractWriteCtaPanel(
          writeAvailable: writeAvailable,
          isBusy: busy,
          onAccept: contract.canAccept(viewerId) ? onAccept : null,
          onCancel: _canCancel ? onCancel : null,
          onCompleteMilestone:
              actionable != null && contract.canComplete(viewerId)
              ? () => onComplete(actionable)
              : null,
          onVerifyMilestone:
              actionable != null &&
                  contract.canVerify(viewerId) &&
                  actionable.isCompleted
              ? () => onVerify(actionable)
              : null,
          onRequestRevision:
              actionable != null &&
                  contract.canVerify(viewerId) &&
                  actionable.isCompleted
              ? () => onRevision(actionable)
              : null,
          onClose: contract.canClose(viewerId) ? onClose : null,
          onFileDispute: _isParticipant && !disputed ? onFileDispute : null,
        ),
      ],
    );
  }

  bool get _canCancel =>
      contract.status == 'offered' &&
      (viewerId == contract.clientEntityId ||
          viewerId == contract.professionalEntityId);

  ContractMilestone? get _firstActionable {
    for (final ContractMilestone m in contract.milestones) {
      if (m.isPending || m.isCompleted) return m;
    }
    return null;
  }
}

class _MilestoneActions extends StatelessWidget {
  const _MilestoneActions({
    required this.milestone,
    required this.viewerId,
    required this.contract,
    required this.busy,
    required this.onComplete,
    required this.onVerify,
    required this.onRevision,
  });

  final ContractMilestone milestone;
  final String viewerId;
  final ServiceContract contract;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onVerify;
  final VoidCallback onRevision;

  @override
  Widget build(BuildContext context) {
    final bool isProfessional = viewerId == contract.professionalEntityId;
    final bool isClient = viewerId == contract.clientEntityId;
    final List<Widget> actions = <Widget>[];
    if (isProfessional && milestone.isPending && contract.isActive) {
      actions.add(
        TextButton(
          onPressed: busy ? null : onComplete,
          child: Text(busy ? 'Working…' : 'Mark complete'),
        ),
      );
    }
    if (isClient && milestone.isCompleted && contract.isActive) {
      actions.add(
        TextButton(
          onPressed: busy ? null : onVerify,
          child: Text(busy ? 'Working…' : 'Verify'),
        ),
      );
      actions.add(
        TextButton(
          onPressed: busy ? null : onRevision,
          child: const Text('Request revision'),
        ),
      );
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 8, children: actions),
    );
  }
}
