import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/listing_media.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/marketplace/widgets/listing_status_badge.dart';

/// Owner listing row card (EP-03-08).
///
/// Pure display: title, status + verification badges, price line,
/// profession name, and cover indicator. Tappable when [onTap] is provided.
/// All colors/typography resolve to [AppTheme] tokens (AGENT.md Rule 5).
class ServiceListingCard extends StatelessWidget {
  const ServiceListingCard({
    super.key,
    required this.listing,
    this.coverUrl,
    this.onTap,
    this.onPublish,
    this.onUnpublish,
    this.onEdit,
    this.onMedia,
    this.isBusy = false,
  });

  /// The owner listing to render.
  final MyServiceListing listing;

  /// Resolved public URL for the cover media, if any.
  final String? coverUrl;

  /// Tap handler (opens edit/detail).
  final VoidCallback? onTap;

  /// Publish action (offered when `canPublish`).
  final VoidCallback? onPublish;

  /// Unpublish action (offered when `canUnpublish`).
  final VoidCallback? onUnpublish;

  /// Edit action.
  final VoidCallback? onEdit;

  /// Media action.
  final VoidCallback? onMedia;

  /// Whether an action is in flight (disables menu items).
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  listing.title,
                  style: context.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              ListingStatusBadge(status: listing.status),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Wrap(
            spacing: HivorrSpacing.xs,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              if (listing.professionName != null &&
                  listing.professionName!.isNotEmpty)
                HivorrBadge(
                  label: listing.professionName!,
                  variant: HivorrBadgeVariant.info,
                ),
              if (listing.isTradeVerifiedCache)
                const HivorrBadge(
                  label: 'Trade verified',
                  variant: HivorrBadgeVariant.success,
                ),
              if (coverUrl != null)
                const HivorrBadge(
                  label: 'Has photos',
                  variant: HivorrBadgeVariant.info,
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            _priceLine(listing),
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.primary,
            ),
          ),
          if (onPublish != null ||
              onUnpublish != null ||
              onEdit != null ||
              onMedia != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            Wrap(
              spacing: HivorrSpacing.xs,
              children: <Widget>[
                if (onEdit != null)
                  TextButton(
                    onPressed: isBusy ? null : onEdit,
                    child: const Text('Edit'),
                  ),
                if (onMedia != null)
                  TextButton(
                    onPressed: isBusy ? null : onMedia,
                    child: const Text('Photos'),
                  ),
                if (onPublish != null && listing.canPublish)
                  TextButton(
                    onPressed: isBusy ? null : onPublish,
                    child: const Text('Publish'),
                  ),
                if (onUnpublish != null && listing.canUnpublish)
                  TextButton(
                    onPressed: isBusy ? null : onUnpublish,
                    child: const Text('Pause'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _priceLine(MyServiceListing listing) {
    final String currency = listing.currencyCode;
    if (listing.pricingType == 'custom') return '$currency Custom quote';
    final double? min = listing.priceMin;
    final double? max = listing.priceMax;
    if (min == null) return '$currency —';
    final String minStr = HivorrFormatters.number(min, decimals: 0);
    if (max == null) return '$currency $minStr';
    return '$currency $minStr – ${HivorrFormatters.number(max, decimals: 0)}';
  }
}
