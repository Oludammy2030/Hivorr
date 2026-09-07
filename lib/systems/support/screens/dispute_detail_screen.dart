import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/dispute_case.dart';
import 'package:hivorr/data/entities/dispute_evidence.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/providers/dispute_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/widgets/dispute_status_badge.dart';
import 'package:hivorr/systems/support/widgets/evidence_attachment_card.dart';
import 'package:provider/provider.dart';

/// Dispute case detail screen (EP-02-17 §5.7).
///
/// `GET /support/disputes/:id`. Renders the case header (badge + type +
/// priority + `***last4` refs), the filed reason, ordered evidence with
/// attachment preview hooks, the resolution outcome when bound, and the
/// withdraw action — visible only while the case is `open` (EP-02-17 §11;
/// buttons hidden, never disabled-without-explanation).
class DisputeDetailScreen extends StatefulWidget {
  const DisputeDetailScreen({
    super.key,
    required this.caseId,
    this.onViewEscrow,
    this.onPreviewFile,
  });

  /// The dispute case to load (`:id` path parameter).
  final String caseId;

  /// Routes to the frozen escrow’s finance detail. May be `null` to hide it.
  final VoidCallback? onViewEscrow;

  /// Hooks the caller’s signed-URL preview for attachment evidence.
  final VoidCallback? onPreviewFile;

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen>
    with WidgetsBindingObserver {
  late final DisputeProvider _provider;
  bool _initialized = false;
  bool _withdrawing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<DisputeProvider>();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_provider.select(widget.caseId));
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

  Future<void> _confirmWithdraw() async {
    final DisputeCase case_ = _provider.selected!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Withdraw dispute?'),
        content: const Text(
          'Withdrawing unfreezes the escrow and releases it back to the '
          'original state. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _withdrawing = true);
    try {
      await _provider.withdraw(case_.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Dispute withdrawn')));
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dispute', style: context.textTheme.titleLarge),
      ),
      body: Consumer<DisputeProvider>(
        builder: (BuildContext context, DisputeProvider provider, _) {
          if (provider.isLoading && !provider.isLoaded) {
            return const HivorrLoadingState(message: 'Loading dispute...');
          }

          if (provider.lastError != null && !provider.isLoaded) {
            return HivorrErrorState(
              message: 'Failed to load dispute',
              detail: provider.lastError!.message,
              onRetry: () => provider.select(widget.caseId),
            );
          }

          final DisputeCase? case_ = provider.selected;
          if (case_ == null) {
            return HivorrErrorState(
              message: 'Dispute not found',
              detail: 'No dispute case matches this reference.',
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(HivorrSpacing.lg),
              children: <Widget>[
                _HeaderCard(
                  case_: case_,
                  onViewEscrow: widget.onViewEscrow,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                _ReasonCard(reason: case_.reason),
                const SizedBox(height: HivorrSpacing.lg),
                _EvidenceSection(
                  evidence: provider.evidence,
                  canSubmit: case_.acceptsEvidence,
                  onAddEvidence: () => context.push(
                    RoutePaths.disputesEvidenceNew.replaceAll(
                      ':caseId',
                      case_.id,
                    ),
                  ),
                  onPreview: widget.onPreviewFile,
                ),
                if (provider.resolution != null) ...[
                  const SizedBox(height: HivorrSpacing.lg),
                  _ResolutionCard(resolution: provider.resolution!),
                ],
                if (case_.isOpen) ...[
                  const SizedBox(height: HivorrSpacing.lg),
                  HivorrButton(
                    label: 'Withdraw dispute',
                    variant: HivorrButtonVariant.outline,
                    isExpanded: true,
                    isLoading: _withdrawing,
                    onPressed: () {
                      if (!_withdrawing) unawaited(_confirmWithdraw());
                    },
                  ),
                ],
                const SizedBox(height: HivorrSpacing.lg),
                const _ImmutabilityNote(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.case_, this.onViewEscrow});

  final DisputeCase case_;
  final VoidCallback? onViewEscrow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final DisputeStatus? status = DisputeStatus.forCode(case_.status);
    final DisputeType? type = DisputeType.forCode(case_.disputeType);
    final DisputePriority? priority = priorityFor(case_.priority);

    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  type?.label ?? case_.disputeType,
                  style: context.textTheme.titleLarge,
                ),
              ),
              if (status != null) DisputeStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              Text(
                'Case ${idRefSuffix(case_.id)}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: HivorrSpacing.md),
              Text(
                'Filed ${HivorrFormatters.dateTime(case_.filedAt)}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (priority != null)
                _MetaChip(
                  icon: Icons.flag_outlined,
                  label: 'Priority: ${priority.label}',
                ),
              if (case_.desiredOutcome != null)
                _MetaChip(
                  icon: Icons.track_changes_outlined,
                  label: 'Outcome: ${outcomeLabel(case_.desiredOutcome!)}',
                ),
            ],
          ),
          if (onViewEscrow != null) ...[
            const SizedBox(height: HivorrSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onViewEscrow,
                borderRadius: BorderRadius.circular(
                  context.appExtension.radiusSm,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'View escrow ${idRefSuffix(case_.escrowId)}',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.appExtension.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: HivorrSpacing.xs),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Reason', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            reason,
            style: context.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.evidence,
    required this.canSubmit,
    required this.onAddEvidence,
    this.onPreview,
  });

  final List<DisputeEvidence> evidence;
  final bool canSubmit;
  final VoidCallback onAddEvidence;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Evidence (${evidence.length})', style: context.textTheme.titleSmall),
            if (canSubmit)
              HivorrButton(
                label: 'Add evidence',
                variant: HivorrButtonVariant.outline,
                onPressed: onAddEvidence,
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.md),
        if (evidence.isEmpty)
          Text(
            canSubmit
                ? 'No evidence yet — add documents, photos, or a written '
                    'description to support your case.'
                : 'No evidence was submitted for this case.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          )
        else
          for (final DisputeEvidence evidence_ in evidence) ...[
            EvidenceAttachmentCard(
              evidence: evidence_,
              onPreview: evidence_.hasAttachment ? onPreview : null,
            ),
            const SizedBox(height: HivorrSpacing.md),
          ],
      ],
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({required this.resolution});

  final DisputeResolution resolution;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.verified_outlined, size: 18, color: colors.primary),
              const SizedBox(width: HivorrSpacing.sm),
              Text('Resolution', style: context.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            resolutionLabel(resolution.resolutionType),
            style: context.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Decided ${HivorrFormatters.dateTime(resolution.resolvedAt)}',
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (resolution.payerRefundAmount > 0 || resolution.payeeReleaseAmount > 0)
            ...[
              const SizedBox(height: HivorrSpacing.md),
              Text(
                'Refund to payer: ${HivorrFormatters.number(resolution.payerRefundAmount)}',
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                'Release to provider: '
                '${HivorrFormatters.number(resolution.payeeReleaseAmount)}',
                style: context.textTheme.bodyMedium,
              ),
            ],
          const SizedBox(height: HivorrSpacing.md),
          Text(
            resolution.reasoning,
            style: context.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

DisputePriority? priorityFor(String code) {
  for (final DisputePriority priority in disputePriorities) {
    if (priority.code == code) return priority;
  }
  return null;
}

String outcomeLabel(String code) {
  for (final DesiredOutcome outcome in desiredOutcomes) {
    if (outcome.code == code) return outcome.label;
  }
  return code;
}

String resolutionLabel(String code) {
  return ResolutionType.forCode(code)?.label ?? code;
}

class _ImmutabilityNote extends StatelessWidget {
  const _ImmutabilityNote();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.appExtension.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Text(
              'Dispute records are permanent: evidence and resolutions '
              'cannot be edited or deleted. Every action is logged on a '
              'server-side audit trail.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}