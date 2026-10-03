import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';

/// Public media carousel for the service detail screen (EP-03-09).
///
/// Pure display over server-ordered [media] (`sort_order ASC, created_at ASC`
/// verbatim — never re-sorted). Thumbnails resolve through [imageUrlFor]
/// (typically `ServiceListingService.mediaPublicUrl`); a `null` URL renders a
/// type placeholder instead of a broken image. The first item carries the
/// cover badge (`sort_order 0`). Empty media renders a compact
/// [HivorrEmptyState]. All styling resolves to [AppTheme] tokens
/// (AGENT.md Rule 5).
class ServiceMediaCarousel extends StatefulWidget {
  const ServiceMediaCarousel({
    super.key,
    required this.media,
    this.imageUrlFor,
  });

  /// Media rows in server order (verbatim from `service_listing_get`).
  final List<ListingMedia> media;

  /// Resolves a displayable thumbnail URL for a storage path (`null` when
  /// unavailable — the tile falls back to a placeholder).
  final String? Function(String storagePath)? imageUrlFor;

  @override
  State<ServiceMediaCarousel> createState() => _ServiceMediaCarouselState();
}

class _ServiceMediaCarouselState extends State<ServiceMediaCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ListingMedia> media = widget.media;
    if (media.isEmpty) {
      return const HivorrCard(
        child: HivorrEmptyState(
          compact: true,
          title: 'No photos yet',
          subtitle: 'This professional has not added service photos.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: PageView.builder(
            controller: _controller,
            itemCount: media.length,
            onPageChanged: (int index) => setState(() => _page = index),
            itemBuilder: (BuildContext context, int index) {
              final ListingMedia item = media[index];
              final String? url = widget.imageUrlFor?.call(item.storagePath);
              return _MediaPage(
                media: item,
                imageUrl: url,
                isCover: index == 0,
                position: '${index + 1} of ${media.length}',
              );
            },
          ),
        ),
        if (media.length > 1) ...<Widget>[
          const SizedBox(height: HivorrSpacing.xs),
          _Dots(count: media.length, active: _page),
        ],
      ],
    );
  }
}

class _MediaPage extends StatelessWidget {
  const _MediaPage({
    required this.media,
    required this.imageUrl,
    required this.isCover,
    required this.position,
  });

  final ListingMedia media;
  final String? imageUrl;
  final bool isCover;
  final String position;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    return HivorrCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.appExtension.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (url != null && url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _MediaPlaceholder(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _MediaPlaceholder(),
              )
            else
              const _MediaPlaceholder(),
            Positioned(
              top: HivorrSpacing.sm,
              left: HivorrSpacing.sm,
              child: Row(
                children: <Widget>[
                  if (isCover)
                    const HivorrBadge(
                      label: 'Cover',
                      variant: HivorrBadgeVariant.success,
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: HivorrSpacing.sm,
              right: HivorrSpacing.sm,
              child: HivorrBadge(
                label: position,
                variant: HivorrBadgeVariant.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Photo ${active + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Container(
              width: i == active ? 20 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == active
                    ? context.colorScheme.primary
                    : context.colorScheme.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ],
      ),
    );
  }
}
