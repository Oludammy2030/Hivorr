import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/entities/dispute_resolution.dart';
import 'package:hivorr/data/providers/admin_dispute_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/support/helpers/dispute_id_ref.dart';
import 'package:hivorr/systems/support/models/dispute_status.dart';
import 'package:hivorr/systems/support/widgets/dispute_contract_card.dart';
import 'package:hivorr/systems/support/widgets/dispute_status_badge.dart';
import 'package:hivorr/systems/support/widgets/evidence_attachment_card.dart';
import 'package:provider/provider.dart';

/// Admin dispute detail (R3 follow-up).
///
/// Read-only case review inside the Admin shell: header, joined engagement
/// summary, filed reason, ordered evidence, and the resolution outcome when
/// bound. No withdraw/resolve/edit affordances exist on this screen — case
/// disposition stays service-role SQL/manual. Access is fail-closed through
/// [AdminGate]; row authorization is server-side via `is_platform_admin()`.
class AdminDisputeDetailScreen extends StatefulWidget {
  const AdminDisputeDetailScreen({super.key, required this.caseId});

  /// The dispute case to load (`:caseId` path parameter).
  final String caseId;

  @override
  State<AdminDisputeDetailScreen> createState() =>
      _AdminDisputeDetailScreenState();
}

class _AdminDisputeDetailScreenState extends State<AdminDisputeDetailScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isAdmin) {
          unawaited(
            context.read<AdminDisputeProvider>().select(widget.caseId),
          );
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

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Dispute case', style: context.textTheme.titleLarge),
        ),
        body: const HivorrErrorState(
          message: 'Admin access required',
          detail: 'This case view is visible to platform admins only.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Dispute case', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Consumer<AdminDisputeProvider>(
          builder: (BuildContext context, AdminDisputeProvider provider, _) {
            if (provider.isLoading && provider.selected == null) {
              return const HivorrLoadingState(
                message: 'Loading dispute case…',
              );
            }
            if (provider.lastError != null && provider.selected == null) {
              return HivorrErrorState(
                message: 'Could not load dispute case',
                detail: provider.lastError!.message,
                onRetry: () => unawaited(provider.select(widget.caseId)),
              );
            }
            final selected = provider.selected;
            if (selected == null) {
              return const HivorrErrorState(
                message: 'Dispute case not found',
                detail: 'No case matches this reference.',
              );
            }
            final DisputeStatus? status = DisputeStatus.forCode(
              selected.status,
            );
            final DisputeType? type = DisputeType.forCode(
              selected.disputeType,
            );
            return RefreshIndicator(
              onRefresh: () async =>
                  provider.select(widget.caseId),
              child: ListView(
                padding: const EdgeInsets.all(HivorrSpacing.lg),
                children: <Widget>[
                  HivorrCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                type?.label ?? selected.disputeType,
                                style: context.textTheme.titleLarge,
                              ),
                            ),
                            if (status != null)
                              DisputeStatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: HivorrSpacing.sm),
                        Text(
                          'Case ${idRefSuffix(selected.id)} · '
                          'Filed ${HivorrFormatters.dateTime(selected.filedAt)}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: HivorrSpacing.xs),
                        Text(
                          'Filer ${idRefSuffix(selected.filerEntityId)} · '
                          'Counterparty ${idRefSuffix(selected.counterpartyEntityId)}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.contractSummary != null) ...[
                    const SizedBox(height: HivorrSpacing.md),
                    DisputeContractCard(
                      summary: provider.contractSummary!,
                    ),
                  ],
                  const SizedBox(height: HivorrSpacing.md),
                  HivorrCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Reason',
                          style: context.textTheme.titleSmall,
                        ),
                        const SizedBox(height: HivorrSpacing.sm),
                        Text(
                          selected.reason,
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HivorrSpacing.md),
                  Text(
                    'Evidence (${provider.evidence.length})',
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                  if (provider.evidence.isEmpty)
                    Text(
                      'No evidence was submitted for this case.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final evidence in provider.evidence) ...[
                      EvidenceAttachmentCard(evidence: evidence),
                      const SizedBox(height: HivorrSpacing.sm),
                    ],
                  if (provider.resolution != null) ...[
                    const SizedBox(height: HivorrSpacing.md),
                    _ResolutionCard(
                      resolution: provider.resolution!,
                    ),
                  ],
                  const SizedBox(height: HivorrSpacing.md),
                  const _ReadOnlyNote(),
                ],
              ),
            );
          },
        ),
      ),
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
          Text('Resolution', style: context.textTheme.titleSmall),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            ResolutionType.forCode(resolution.resolutionType)?.label ??
                resolution.resolutionType,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Decided ${HivorrFormatters.dateTime(resolution.resolvedAt)}',
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          if (resolution.payerRefundAmount > 0 ||
              resolution.payeeReleaseAmount > 0) ...[
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              'Refund to payer: ${HivorrFormatters.number(resolution.payerRefundAmount)}',
              style: context.textTheme.bodyMedium,
            ),
            Text(
              'Release to provider: '
              '${HivorrFormatters.number(resolution.payeeReleaseAmount)}',
              style: context.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            resolution.reasoning,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

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
          Icon(Icons.lock_outline, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Text(
              'Read-only admin view: case disposition is performed '
              'server-side. Evidence and resolutions are immutable.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
