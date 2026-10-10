import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/earnings_provider.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
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
import 'package:hivorr/systems/finance/services/contract_escrow_orchestrator.dart';
import 'package:hivorr/systems/finance/services/contract_escrow_state.dart';
import 'package:hivorr/systems/finance/widgets/escrow_dispute_banner.dart';
import 'package:hivorr/systems/finance/widgets/milestone_list_card.dart';
import 'package:hivorr/systems/reviews/widgets/contract_review_section.dart';
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

  /// The EP-03-11 release orchestrator when the bootstrap wired it, else
  /// `null` (the screen degrades to verify-only actions with guidance).
  ContractEscrowOrchestrator? get _orchestrator {
    try {
      return context.read<ContractEscrowOrchestrator>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  EscrowProvider? get _escrowProvider {
    try {
      return context.read<EscrowProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// The EP-03-16 earnings provider when the bootstrap wired it, else `null`
  /// (release still settles server-side; only the earnings refresh +
  /// notification hook is skipped).
  EarningsProvider? get _earningsProvider {
    try {
      return context.read<EarningsProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

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

  Future<void> _runRelease(
    ServiceContract contract,
    ContractMilestone milestone,
  ) async {
    final ContractEscrowOrchestrator? orchestrator = _orchestrator;
    if (orchestrator == null) return;
    setState(() {
      _busy = true;
      _busyMilestoneId = milestone.id;
    });
    try {
      final ContractEscrowReleaseState state =
          await orchestrator.verifyAndReleaseMilestone(
            contractId: contract.id,
            milestoneId: milestone.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message:
              state.message ??
              (state.ok ? 'Milestone released.' : 'Release unavailable.'),
          variant: state.ok
              ? HivorrSnackbarVariant.success
              : HivorrSnackbarVariant.error,
        ),
      );
      if (state.ok) {
        await context.read<ServiceContractProvider>().select(contract.id);
        await _escrowProvider?.notifyContractMilestoneEvent(
          eventType: 'milestone_released',
          contractId: contract.id,
          milestoneId: milestone.id,
          escrowId: state.escrowId,
        );
        // EP-03-16: refresh the earnings windows and surface the one-shot
        // `Payment received` notification on the same verified release.
        await _earningsProvider?.notifyEarningsReleased(
          contractId: contract.id,
          milestoneId: milestone.id,
        );
      } else if (state.blockReason ==
          ContractEscrowBlockReason.disputed) {
        await _escrowProvider?.notifyContractMilestoneEvent(
          eventType: 'release_blocked_disputed',
          contractId: contract.id,
          milestoneId: milestone.id,
          escrowId: state.escrowId,
        );
      }
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
                    onVerifyAndRelease: _orchestrator == null
                        ? null
                        : (ContractMilestone m) => _runRelease(
                            provider.selected!,
                            m,
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
                          onVerifyAndRelease: _orchestrator == null
                              ? null
                              : (ContractMilestone m) =>
                                  _runRelease(contract, m),
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
    this.onVerifyAndRelease,
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

  /// Combined verify-then-release action (EP-03-11 orchestrator). `null`
  /// when the orchestrator is absent or the row is not release-eligible —
  /// the panel then renders verify-only actions plus guidance.
  final ValueChanged<ContractMilestone>? onVerifyAndRelease;

  bool get _isClient => viewerId == contract.clientEntityId;
  bool get _isProfessional => viewerId == contract.professionalEntityId;
  bool get _isParticipant => _isClient || _isProfessional;

  /// Whether the combined Verify & release action applies to [m]:
  /// client viewer, linked escrow, actionable milestone awaiting acceptance.
  bool _canVerifyAndRelease(ContractMilestone m) =>
      onVerifyAndRelease != null &&
      _isClient &&
      contract.escrowId != null &&
      m.escrowMilestoneId != null &&
      (m.isCompleted || m.isVerified);

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
                _EscrowLinkRow(escrowId: contract.escrowId!),
              ] else if (contract.isActive || contract.isCompleted) ...[
                const SizedBox(height: 4),
                Text(
                  'Funding pending',
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
        ContractReviewSection(contract: contract, viewerId: viewerId),
        const SizedBox(height: HivorrSpacing.md),
        _SchedulingEntry(
          contract: contract,
          viewerId: viewerId,
        ),
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
          onVerifyAndRelease:
              actionable != null && _canVerifyAndRelease(actionable)
              ? () => onVerifyAndRelease!(actionable)
              : null,
          onViewEscrow: contract.escrowId != null
              ? () => context.push(
                    RoutePaths.escrowDetailFor(contract.escrowId!),
                  )
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

/// Scheduling entry section for a contract detail (EP-03-14 §8 D13).
///
/// CTA-only wiring: `Book appointment` navigates to the booking flow for
/// either participant while the contract is `active`; `Manage availability`
/// navigates to the template editor for the professional. Non-active,
/// disputed, and stranger states render guidance cards — gating is affordance
/// only and enforcement stays server-side (`PLT004`/`PLT005`).
class _SchedulingEntry extends StatelessWidget {
  const _SchedulingEntry({required this.contract, required this.viewerId});

  final ServiceContract contract;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final bool isParticipant =
        viewerId == contract.clientEntityId ||
        viewerId == contract.professionalEntityId;
    if (!isParticipant) {
      return const HivorrCard(
        child: Text(
          'Scheduling is available to contract participants. '
          'You are not a participant on this contract.',
        ),
      );
    }
    if (!contract.isActive) {
      return HivorrCard(
        child: Text(
          'Appointments open once the contract is active. '
          'Current status: ${contract.status}.',
        ),
      );
    }
    final bool isProfessional =
        viewerId == contract.professionalEntityId;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Schedule', style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          HivorrButton(
            label: 'Book appointment',
            onPressed: () => context.push(
              RoutePaths.appointmentBook(contract.id),
            ),
            variant: HivorrButtonVariant.primary,
            isExpanded: true,
          ),
          const SizedBox(height: 8),
          HivorrButton(
            label: 'View appointments',
            onPressed: () => context.push(
              RoutePaths.appointmentList(contract.id),
            ),
            variant: HivorrButtonVariant.secondary,
            isExpanded: true,
          ),
          if (isProfessional) ...[
            const SizedBox(height: 8),
            HivorrButton(
              label: 'Manage availability',
              onPressed: () => context.push(RoutePaths.availability),
              variant: HivorrButtonVariant.outline,
              isExpanded: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _EscrowLinkRow extends StatelessWidget {
  const _EscrowLinkRow({required this.escrowId});

  final String escrowId;

  @override
  Widget build(BuildContext context) {
    final String suffix = escrowId.length > 8
        ? escrowId.substring(escrowId.length - 8)
        : escrowId;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Escrow $suffix',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: () =>
              context.push(RoutePaths.escrowDetailFor(escrowId)),
          child: const Text('View escrow'),
        ),
      ],
    );
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
    final String? countdown =
        ContractMilestoneAdapter.reviewCountdownLabel(milestone);
    // Release-amount caption from the server milestone row (no escrow fetch,
    // no client math): the held→available delta for this milestone on release.
    // The live escrow balances render on the escrow detail screen.
    final bool showReleaseAmount =
        contract.escrowId != null &&
        (milestone.isCompleted ||
            milestone.isVerified ||
            milestone.isReleased);
    final List<Widget> actions = <Widget>[];
    if (showReleaseAmount) {
      actions.add(
        Text(
          'Releases ${BalanceFormatter.formatBalance(milestone.amount, contract.currencyCode)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (countdown != null) {
      actions.add(
        Text(
          countdown,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
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
