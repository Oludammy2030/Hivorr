import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/escrow.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/data/providers/escrow_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/services/dispute_service.dart';
import 'package:provider/provider.dart';

/// Dispute filing screen (EP-02-17 §5.7).
///
/// Escrow-first: filing is entered from a specific escrow and the escrow is
/// frozen the moment the case is filed (server-side disposition). Renders the
/// 5-type vocabulary, the 10–2000 char reason validator, an optional desired
/// outcome, and a priority picker defaulting to `medium` (CHECK `74-75`).
class DisputeFilingScreen extends StatefulWidget {
  const DisputeFilingScreen({super.key, required this.escrowId});

  /// The escrow to freeze via this dispute.
  final String escrowId;

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

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

  bool get _reasonValid => DisputeService.validateReason(_reasonController.text);

  bool get _canSubmit =>
      !_submitting &&
      !_succeeded &&
      _type != null &&
      _reasonValid;

  Future<void> _submit() async {
    final DisputeProvider provider = context.read<DisputeProvider>();
    setState(() {
      _submitting = true;
      _fieldError = null;
      _submitError = null;
    });
    try {
      final DisputeCase filed = await provider.file(
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
    // Mirror-client guard (FV-34): only a matching, already-disputed escrow
    // pre-disables filing. When the escrow status is unknown (still loading or
    // unreadable) we fail open to the server, which remains the authority.
    final Escrow? escrow = context.watch<EscrowProvider>().selected;
    final bool escrowDisputed =
        escrow?.id == widget.escrowId && escrow?.status == 'disputed';
    final bool canSubmit =
        _canSubmit && !escrowDisputed;

    return Scaffold(
      appBar: AppBar(
        title: Text('File dispute', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Filing freezes escrow ${idRefSuffix(widget.escrowId)} until '
                'the dispute is resolved.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (escrowDisputed) ...[
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
                          'An active dispute already exists for this escrow.',
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
      decoration: InputDecoration(
        labelText: 'Dispute type',
        border: const OutlineInputBorder(),
      ),
      items: <DropdownMenuItem<DisputeType>>[
        for (final DisputeType type in disputeTypes)
          DropdownMenuItem<DisputeType>(
            value: type,
            child: Text(type.label),
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
      decoration: const InputDecoration(labelText: 'Desired outcome (optional)'),
      items: <DropdownMenuItem<DesiredOutcome?>>[
        const DropdownMenuItem<DesiredOutcome?>(
          value: null,
          child: Text('Not specified'),
        ),
        for (final DesiredOutcome outcome in desiredOutcomes)
          DropdownMenuItem<DesiredOutcome?>(
            value: outcome,
            child: Text(outcome.label),
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
      decoration: const InputDecoration(labelText: 'Priority'),
      items: <DropdownMenuItem<DisputePriority?>>[
        for (final DisputePriority priority in disputePriorities)
          DropdownMenuItem<DisputePriority?>(
            value: priority,
            child: Text(priority.label),
          ),
      ],
      onChanged: (DisputePriority? priority) => onChanged(priority),
    );
  }
}