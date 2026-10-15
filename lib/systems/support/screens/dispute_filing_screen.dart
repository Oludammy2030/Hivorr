import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/entities/service_contract.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/data/providers/service_contract_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/hivorr_content_pane.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';

/// Dispute filing screen (EP-02-17 §5.7, extended EP-03-17).
///
/// Two entry modes share one form (type + 10–2000 reason + optional outcome +
/// priority defaulting to `medium`):
///
/// * Escrow mode (`escrowId`): filing is entered from a specific escrow and the
///   escrow is frozen the moment the case is filed (server-side disposition).
/// * Contract mode (`contractId`, EP-03-17): filing is entered from a service
///   engagement. The server resolves the escrow from
///   `service_contracts.escrow_id`, so unfunded contracts remain disputable;
///   the contract (and the escrow hold when funded) freezes on file.
///
/// At least one of [escrowId] / [contractId] must be non-empty. Contract mode
/// takes precedence when both are supplied.
class DisputeFilingScreen extends StatefulWidget {
  const DisputeFilingScreen({super.key, this.escrowId = '', this.contractId});

  /// The escrow to freeze via this dispute (escrow mode).
  final String escrowId;

  /// The service contract to dispute (contract mode, EP-03-17).
  final String? contractId;

  @override
  State<DisputeFilingScreen> createState() => _DisputeFilingScreenState();
}

class _DisputeFilingScreenState extends State<DisputeFilingScreen> {
  DisputeType? _type;
  DesiredOutcome? _outcome;
  DisputePriority? _priority;
  final TextEditingController _reasonController = TextEditingController();
  String? _fieldError;
  String? _submitError;
  bool _submitting = false;
  bool _succeeded = false;
  bool _escrowLoadKicked = false;
  bool _contractLoadKicked = false;

  /// Whether this instance files against a service contract (EP-03-17).
  bool get _isContractMode =>
      widget.contractId != null && widget.contractId!.isNotEmpty;

  /// The effective filing anchor for header copy (contract id or escrow id).
  String get _anchorId =>
      _isContractMode ? widget.contractId! : widget.escrowId;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isContractMode) {
      // Best-effort mirror-client guard: load the linked contract so filing
      // against an already-`disputed` contract pre-disables (server PLT005 via
      // the one-open-per-contract index). UX layer only — the server remains
      // the authority.
      if (!_contractLoadKicked) {
        _contractLoadKicked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            unawaited(
              context
                  .read<ServiceContractProvider>()
                  .select(widget.contractId!),
            );
          } on ProviderNotFoundException {
            // Contract provider absent (e.g. widget test harness) — fail open
            // to the server, which remains the authority for the conflict.
          }
        });
      }
      return;
    }
    // Best-effort mirror-client guard (FV-34): load the linked escrow so we can
    // pre-disable filing against an escrow that already shows `disputed`
    // (server PLT005 via the one-open-per-escrow index). This is a UX layer —
    // the server remains the authority for the conflict.
    if (!_escrowLoadKicked) {
      _escrowLoadKicked = true;
      // Post-frame so the provider's synchronous `notifyListeners()` never runs
      // during the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(context.read<EscrowProvider>().select(widget.escrowId));
        }
      });
    }
  }

  bool get _reasonValid =>
      DisputeService.validateReason(_reasonController.text);

  bool get _canSubmit =>
      !_submitting && !_succeeded && _type != null && _reasonValid;

  Future<void> _submit() async {
    final DisputeProvider provider = context.read<DisputeProvider>();
    setState(() {
      _submitting = true;
      _fieldError = null;
      _submitError = null;
    });
    try {
      final DisputeCase filed = _isContractMode
          ? await provider.fileForContract(
              contractId: widget.contractId!,
              disputeType: _type!.code,
              reason: _reasonController.text.trim(),
              desiredOutcome: _outcome?.code,
              priority: _priority?.code ?? 'medium',
            )
          : await provider.file(
              escrowId: widget.escrowId,
              disputeType: _type!.code,
              reason: _reasonController.text.trim(),
              desiredOutcome: _outcome?.code,
              priority: _priority?.code ?? 'medium',
            );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _succeeded = true;
      });
      context.pushReplacement(
        RoutePaths.disputeDetail.replaceAll(':id', filed.id),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool alreadyDisputed;
    final ServiceContract? contract = _isContractMode
        ? _watchedContract()
        : null;
    if (_isContractMode) {
      // Mirror-client guard: only a matching, already-disputed contract
      // pre-disables filing. Unknown/loading state fails open to the server.
      alreadyDisputed =
          contract?.id == widget.contractId && contract!.isDisputed;
    } else {
      // Mirror-client guard (FV-34): only a matching, already-disputed escrow
      // pre-disables filing. When the escrow status is unknown (still loading or
      // unreadable) we fail open to the server, which remains the authority.
      final Escrow? escrow = context.watch<EscrowProvider>().selected;
      alreadyDisputed =
          escrow?.id == widget.escrowId && escrow?.status == 'disputed';
    }
    final bool canSubmit = _canSubmit && !alreadyDisputed;

    return Scaffold(
      appBar: AppBar(
        title: Text('File dispute', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: HivorrContentPane(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_isContractMode && contract != null) ...[
                  _ContractHeaderCard(contract: contract),
                  const SizedBox(height: HivorrSpacing.md),
                ],
                Text(
                  _isContractMode
                      ? 'Filing freezes contract ${idRefSuffix(_anchorId)} until '
                            'the dispute is resolved.'
                      : 'Filing freezes escrow ${idRefSuffix(widget.escrowId)} until '
                            'the dispute is resolved.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (alreadyDisputed) ...[
                  const SizedBox(height: HivorrSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(HivorrSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(
                        context.appExtension.radiusSm,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.gavel_outlined,
                          size: 18,
                          color: colors.onErrorContainer,
                        ),
                        const SizedBox(width: HivorrSpacing.sm),
                        Expanded(
                          child: Text(
                            _isContractMode
                                ? 'An active dispute already exists for this contract.'
                                : 'An active dispute already exists for this escrow.',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: colors.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
                _TypeField(
                  selected: _type,
                  error: _fieldError,
                  onChanged: (DisputeType? type) {
                    setState(() {
                      _type = type;
                      _fieldError = null;
                      _submitError = null;
                    });
                  },
                ),
                const SizedBox(height: HivorrSpacing.md),
                TextField(
                  controller: _reasonController,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 2000,
                  onChanged: (_) => setState(() => _submitError = null),
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    hintText:
                        'Explain what happened and why the funds should be held…',
                    helperText:
                        'At least 10 characters so the reviewer has context.',
                    errorText: _fieldError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: HivorrSpacing.sm),
                _OutcomeField(
                  selected: _outcome,
                  onChanged: (DesiredOutcome? outcome) {
                    setState(() {
                      _outcome = outcome;
                      _submitError = null;
                    });
                  },
                ),
                const SizedBox(height: HivorrSpacing.md),
                _PriorityField(
                  selected: _priority,
                  onChanged: (DisputePriority? priority) {
                    setState(() {
                      _priority = priority;
                      _submitError = null;
                    });
                  },
                ),
                const SizedBox(height: HivorrSpacing.lg),
                HivorrButton(
                  label: 'File dispute',
                  isExpanded: true,
                  isLoading: _submitting,
                  onPressed: canSubmit ? () => unawaited(_submit()) : null,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: HivorrSpacing.md),
                  Text(
                    _submitError!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Watches the contract provider when available; `null` when the provider
  /// is absent (widget test harness) or holds another contract.
  ServiceContract? _watchedContract() {
    try {
      final ServiceContract? selected =
          context.watch<ServiceContractProvider>().selected;
      if (selected?.id == widget.contractId) return selected;
      return null;
    } on ProviderNotFoundException {
      return null;
    }
  }
}

/// Contract context header for contract-mode filing (EP-03-17).
///
/// Read-only summary (title, total, status, escrow linkage) so the filer can
/// confirm the engagement before the server freezes it. Tokens only.
class _ContractHeaderCard extends StatelessWidget {
  const _ContractHeaderCard({required this.contract});

  final ServiceContract contract;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.appExtension.radiusSm),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              ContractStatusBadge(status: contract.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            BalanceFormatter.formatBalance(
              contract.totalAmount,
              contract.currencyCode,
            ),
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            contract.escrowId != null
                ? 'Escrow ${idRefSuffix(contract.escrowId!)}'
                : 'Funding pending — the contract freezes without an escrow hold.',
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeField extends StatelessWidget {
  const _TypeField({
    required this.selected,
    required this.onChanged,
    this.error,
  });

  final DisputeType? selected;
  final ValueChanged<DisputeType?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DisputeType>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Dispute type',
        border: OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<DisputeType>>[
        for (final DisputeType type in disputeTypes)
          DropdownMenuItem<DisputeType>(
            value: type,
            child: Text(type.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (DisputeType? type) => onChanged(type),
    );
  }
}

class _OutcomeField extends StatelessWidget {
  const _OutcomeField({required this.selected, required this.onChanged});

  final DesiredOutcome? selected;
  final ValueChanged<DesiredOutcome?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DesiredOutcome?>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Desired outcome (optional)',
      ),
      items: <DropdownMenuItem<DesiredOutcome?>>[
        const DropdownMenuItem<DesiredOutcome?>(
          value: null,
          child: Text('Not specified', overflow: TextOverflow.ellipsis),
        ),
        for (final DesiredOutcome outcome in desiredOutcomes)
          DropdownMenuItem<DesiredOutcome?>(
            value: outcome,
            child: Text(outcome.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (DesiredOutcome? outcome) => onChanged(outcome),
    );
  }
}

class _PriorityField extends StatelessWidget {
  const _PriorityField({required this.selected, required this.onChanged});

  final DisputePriority? selected;
  final ValueChanged<DisputePriority?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DisputePriority?>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Priority'),
      items: <DropdownMenuItem<DisputePriority?>>[
        for (final DisputePriority priority in disputePriorities)
          DropdownMenuItem<DisputePriority?>(
            value: priority,
            child: Text(priority.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (DisputePriority? priority) => onChanged(priority),
    );
  }
}
