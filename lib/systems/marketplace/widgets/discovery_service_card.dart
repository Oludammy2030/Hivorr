import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/service_listing.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/marketplace/widgets/favorite_toggle_button.dart';

/// Public discovery result card (EP-03-09).
///
/// Pure display over a ranked [ServiceListing]: title, profession + trust
/// badges, price line, and rating summary. Renders the RPC row verbatim —
/// never reorders or recomputes (AGENT.md:7 Deterministic Core Supremacy).
/// Tappable when [onTap] is provided. All styling resolves to [AppTheme]
/// tokens (AGENT.md Rule 5).
///
/// Contrast with the owner-oriented [ServiceListingCard], which exposes
/// Edit/Publish actions: this card exposes discovery actions only
/// (open detail + favorite).
class DiscoveryServiceCard extends StatelessWidget {
  const DiscoveryServiceCard({
    super.key,
    required this.listing,
    this.onTap,
    this.showFavorite = true,
    this.initiallyFavorited = false,
  });

  /// The ranked listing to render (RPC order position is owned by the list).
  final ServiceListing listing;

  /// Tap handler (opens the public detail).
  final VoidCallback? onTap;

  /// Whether to show the favorite heart (hidden for anonymous preview rows).
  final bool showFavorite;

  /// Initial favorite state for the heart (detail preview read-through).
  final bool initiallyFavorited;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  listing.title,
                  style: context.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showFavorite) ...<Widget>[
                const SizedBox(width: HivorrSpacing.xs),
                FavoriteToggleButton(
                  listingId: listing.id,
                  initialFavorited: initiallyFavorited,
                ),
              ],
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Wrap(
            spacing: HivorrSpacing.xs,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              if ((listing.professionName ?? '').isNotEmpty)
                HivorrBadge(
                  label: listing.professionName!,
                  variant: HivorrBadgeVariant.info,
                ),
              if (listing.isTradeVerifiedCache)
                const HivorrBadge(
                  label: 'Trade verified',
                  variant: HivorrBadgeVariant.success,
                ),
              HivorrBadge(
                label: _pricingLabel(listing.pricingType),
                variant: HivorrBadgeVariant.neutral,
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            priceLine(listing),
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          _RatingRow(listing: listing),
        ],
      ),
    );
  }

  /// Display price line for a ranked listing (display-only formatting).
  static String priceLine(ServiceListing listing) {
    final String currency = listing.currencyCode;
    if (listing.pricingType == 'custom') return '$currency Custom quote';
    final double? min = listing.priceMin;
    if (min == null) return '$currency —';
    final String minStr = HivorrFormatters.number(min, decimals: 0);
    final double? max = listing.priceMax;
    if (max == null) return '$currency $minStr';
    return '$currency $minStr – ${HivorrFormatters.number(max, decimals: 0)}';
  }

  static String _pricingLabel(String pricingType) {
    switch (pricingType) {
      case 'fixed':
        return 'Fixed price';
      case 'hourly':
        return 'Hourly';
      case 'per_milestone':
        return 'Per milestone';
      default:
        return 'Custom quote';
    }
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.listing});

  final ServiceListing listing;

  @override
  Widget build(BuildContext context) {
    final String rating = listing.avgRating.toStringAsFixed(1);
    final String count = listing.reviewCount == 1
        ? '1 review'
        : '${listing.reviewCount} reviews';
    return Semantics(
      label: 'Rated $rating out of 5 from $count',
      child: Row(
        children: <Widget>[
          Icon(Icons.star, size: 16, color: context.colorScheme.secondary),
          const SizedBox(width: 4),
          Text(
            rating,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '($count)',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
