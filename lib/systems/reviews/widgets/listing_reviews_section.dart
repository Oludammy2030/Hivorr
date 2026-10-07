import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/data/providers/service_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/reviews/widgets/rating_distribution_bar.dart';
import 'package:hivorr/systems/reviews/widgets/review_list_tile.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_display.dart';
import 'package:provider/provider.dart';

/// Read-only revealed-reviews section for `service_detail_screen` (EP-03-12).
///
/// Appended below `_RatingLine`, before the proof slot. Fed by
/// `service_review_get_for_listing` (revealed only) plus the aggregate
/// header. Makes at most one page fetch; header falls back to the listing
/// row cache (`avgRating`/`reviewCount`) while loading.
class ListingReviewsSection extends StatefulWidget {
  const ListingReviewsSection({
    super.key,
    required this.listingId,
    required this.professionalEntityId,
    required this.professionId,
    required this.cachedAvgRating,
    required this.cachedReviewCount,
  });

  /// The `service_listings.id` (authoritative).
  final String listingId;

  /// Listing owner (`entities.id`) keying the aggregate header.
  final String professionalEntityId;

  /// Listing profession (`professions.id`) keying the aggregate header.
  final String professionId;

  /// Cached header from the listing row (instant paint).
  final double cachedAvgRating;

  /// Cached count from the listing row (instant paint).
  final int cachedReviewCount;

  @override
  State<ListingReviewsSection> createState() => _ListingReviewsSectionState();
}

class _ListingReviewsSectionState extends State<ListingReviewsSection> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (widget.listingId.trim().isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          context.read<ServiceReviewProvider?>()?.loadForListing(
            listingId: widget.listingId.trim(),
            professionalEntityId: widget.professionalEntityId,
            professionId: widget.professionId,
          ),
        );
      } on Object {
        // Review layer not wired in this build — section degrades to cache.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ServiceReviewProvider? provider;
    try {
      provider = context.watch<ServiceReviewProvider?>();
    } on Object {
      provider = null;
    }
    if (provider == null) return const SizedBox.shrink();
    if (provider.isLoading && provider.listingReviews.isEmpty) {
      return const HivorrLoadingState(message: 'Loading reviews…');
    }
    final Object? error = provider.lastError;
    if (provider.listingReviews.isEmpty && error != null) {
      return const SizedBox.shrink();
    }
    final ReviewAggregate? aggregate = provider.listingAggregate;
    final double avg = aggregate?.avgRating ?? widget.cachedAvgRating;
    final int count = aggregate?.reviewCount ?? widget.cachedReviewCount;
    final Map<int, int> distribution =
        aggregate?.distribution ??
        const <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    if (count <= 0 && provider.listingReviews.isEmpty) {
      return HivorrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Reviews', style: context.textTheme.titleMedium),
            const SizedBox(height: HivorrSpacing.xs),
            const HivorrEmptyState(
              compact: true,
              title: 'No reviews yet',
              subtitle: 'Revealed reviews will appear here.',
            ),
          ],
        ),
      );
    }
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Reviews', style: context.textTheme.titleMedium),
          const SizedBox(height: HivorrSpacing.xs),
          Row(
            children: <Widget>[
              StarRatingDisplay(rating: avg, showValue: true),
              const SizedBox(width: 4),
              Text(
                count == 1 ? '(1 review)' : '($count reviews)',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          RatingDistributionBar(
            distribution: distribution,
            reviewCount: count,
          ),
          if (provider.listingReviews.isNotEmpty) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            for (final ServiceReview review in provider.listingReviews) ...<
              Widget
            >[
              ReviewListTile(review: review),
              const SizedBox(height: HivorrSpacing.xs),
            ],
          ],
          if (error != null && provider.listingReviews.isNotEmpty)
            HivorrErrorState(
              message: 'Could not refresh reviews',
              detail: null,
              onRetry: () => provider!.loadForListing(
                listingId: widget.listingId.trim(),
                professionalEntityId: widget.professionalEntityId,
                professionId: widget.professionId,
              ),
            ),
        ],
      ),
    );
  }
}
