import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';

/// Single listing media tile (EP-03-08).
///
/// Pure display: thumbnail (or type placeholder when [imageUrl] is null),
/// cover indicator, upload progress, error + retry, and delete affordance.
/// All styling resolves to [AppTheme] tokens (AGENT.md Rule 5).
class ListingMediaTile extends StatelessWidget {
  const ListingMediaTile({
    super.key,
    this.media,
    this.imageUrl,
    this.progress,
    this.errorMessage,
    this.onRetry,
    this.onDelete,
    this.fileName,
  });

  /// The persisted media row, if uploaded.
  final ListingMedia? media;

  /// Resolved public thumbnail URL, if available.
  final String? imageUrl;

  /// Upload progress `0..1` for in-flight items (`null` when settled).
  final double? progress;

  /// Upload error message for failed items.
  final String? errorMessage;

  /// Retry handler for failed items.
  final VoidCallback? onRetry;

  /// Delete handler.
  final VoidCallback? onDelete;

  /// Local file name for pending items (semantics + fallback label).
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final bool isCover = media?.isCover ?? false;
    return HivorrCard(
      padding: const EdgeInsets.all(HivorrSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: _buildPreview(context)),
          const SizedBox(height: HivorrSpacing.xs),
          Row(
            children: <Widget>[
              if (isCover)
                const HivorrBadge(
                  label: 'Cover',
                  variant: HivorrBadgeVariant.success,
                ),
              const Spacer(),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete photo',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (progress != null)
            LinearProgressIndicator(value: progress!.clamp(0.0, 1.0)),
          if (errorMessage != null && errorMessage!.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              errorMessage!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final String? url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          context.appExtension.radiusSm,
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final String label = fileName ?? media?.mimeType ?? 'Photo';
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(
          context.appExtension.radiusSm,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.image_outlined,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HivorrSpacing.xs,
              ),
              child: Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
