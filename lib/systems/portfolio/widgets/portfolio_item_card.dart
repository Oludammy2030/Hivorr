import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/portfolio_item.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';

/// Single work-sample card for the public professional page (EP-02-19 §5.6,
/// DoD FV-16/FV-25).
///
/// Renders the media thumbnail from the public Storage URL (never bytes over
/// the profile path), a type chip, the title, and the description. When no
/// public URL is available the card shows a neutral type placeholder instead
/// of a broken image. Ordering is handled by [PortfolioGrid] (`sort_order`).
class PortfolioItemCard extends StatelessWidget {
  const PortfolioItemCard({
    super.key,
    required this.item,
    this.mediaUrl,
  });

  /// The portfolio work sample (whitelisted fields only).
  final PortfolioItem item;

  /// Resolved public media URL, or `null` to render the placeholder.
  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String? title = _nonEmpty(item.title);
    final String? description = _nonEmpty(item.description);
    final String? type = _nonEmpty(item.itemType);

    return HivorrCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _thumbnail(context, colors),
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (type != null) ...<Widget>[
                  HivorrChip(
                    label: type,
                    variant: HivorrChipVariant.surface,
                  ),
                  const SizedBox(height: HivorrSpacing.sm),
                ],
                if (title != null) ...<Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ],
                if (description != null) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.xs),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(BuildContext context, ColorScheme colors) {
    final ColorScheme scheme = colors;
    final Widget placeholder = AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          _placeholderIconFor(item.itemType),
          size: 40,
          color: scheme.outline,
        ),
      ),
    );
    final String? url = mediaUrl;
    if (url == null || url.isEmpty) {
      return placeholder;
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.appExtension.radiusMd),
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
            return placeholder;
          },
        ),
      ),
    );
  }

  static IconData _placeholderIconFor(String? type) => switch (type) {
        'link' => Icons.link,
        'document' => Icons.description_outlined,
        'video' => Icons.play_circle_outline,
        _ => Icons.image_outlined,
      };

  static String? _nonEmpty(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}