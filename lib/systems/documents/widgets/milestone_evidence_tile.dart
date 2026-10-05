import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/contract_milestone.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/systems/documents/widgets/contract_status_badge.dart';
import 'package:hivorr/systems/finance/helpers/balance_formatter.dart';

/// Evidence tile for a single contract milestone (EP-03-10 §8 D10).
///
/// Shows the milestone title, amount, status badge, and evidence state
/// (thumbnail when [evidenceUrl] resolves, type placeholder otherwise) with
/// upload [progress] (`0..1`, `null` when idle), inline [error], and
/// retry/replace/delete affordances owned by the caller. Pure display —
/// upload orchestration lives in [ContractService]. Copies the
/// `listing_media_tile` pattern (progress + retry + confirm). Tokens only.
class MilestoneEvidenceTile extends StatelessWidget {
  const MilestoneEvidenceTile({
    super.key,
    required this.milestone,
    required this.currencyCode,
    this.evidenceUrl,
    this.progress,
    this.error,
    this.onRetry,
    this.onPick,
    this.onDelete,
    this.actionLabel = 'Attach evidence',
  });

  /// The milestone rendered by this tile.
  final ContractMilestone milestone;

  /// Currency code for the amount line.
  final String currencyCode;

  /// Resolved public URL for the evidence path, if any.
  final String? evidenceUrl;

  /// Upload progress fraction (`null` when idle).
  final double? progress;

  /// Inline upload/RPC error, when present.
  final String? error;

  /// Retries the failed upload.
  final VoidCallback? onRetry;

  /// Picks (and uploads) evidence bytes.
  final VoidCallback? onPick;

  /// Removes the evidence (caller confirms via `HivorrDialog`).
  final VoidCallback? onDelete;

  /// Label for the pick action.
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final double? progressValue = progress;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ext.radiusMd),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${milestone.milestoneNumber}. ${milestone.title}',
                      style: context.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      BalanceFormatter.formatBalance(
                        milestone.amount,
                        currencyCode,
                      ),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ContractMilestoneStatusBadge(status: milestone.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _EvidenceThumb(
                evidenceUrl: evidenceUrl,
                hasEvidence: milestone.evidencePath != null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (progressValue != null)
                      LinearProgressIndicator(
                        value: progressValue.clamp(0.0, 1.0),
                        color: colors.primary,
                        backgroundColor:
                            colors.surfaceContainerHighest,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(ext.radiusSm),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        error!,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                    if (progressValue == null && error == null)
                      Text(
                        milestone.evidencePath == null
                            ? 'No evidence attached yet.'
                            : 'Evidence attached.',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (onPick != null || onRetry != null || onDelete != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                if (onPick != null)
                  TextButton(
                    onPressed: onPick,
                    child: Text(actionLabel),
                  ),
                if (onRetry != null)
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                if (onDelete != null)
                  TextButton(onPressed: onDelete, child: const Text('Remove')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({required this.evidenceUrl, required this.hasEvidence});

  final String? evidenceUrl;
  final bool hasEvidence;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final String? url = evidenceUrl;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ext.radiusSm),
        border: Border.all(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              // 56dp thumb: 2x bitmap is plenty.
              cacheWidth: 112,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => Icon(
                    Icons.description_outlined,
                    color: colors.onSurfaceVariant,
                  ),
            )
          : Icon(
              hasEvidence
                  ? Icons.description_outlined
                  : Icons.upload_file_outlined,
              color: colors.onSurfaceVariant,
            ),
    );
  }
}
