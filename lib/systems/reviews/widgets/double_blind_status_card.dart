import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_display.dart';

/// Blind-review lifecycle states rendered verbatim from [MyReviewStatus].
///
/// - [DoubleBlindState.awaitingYours]: viewer has not submitted — CTA to
///   submit (`HivorrBadge info`).
/// - [DoubleBlindState.awaitingCounterparty]: viewer submitted, reveal pending
///   — neutral waiting copy, no rating shown, no countdown leaking the exact
///   deadline (timing-oracle mitigation per Phase Plan §8).
/// - [DoubleBlindState.revealed]: `revealed_reviews[]` non-empty — both rows
///   with stars + comments (`HivorrBadge success`).
///
/// Pure display — never evaluates `both_submitted` itself.
enum DoubleBlindState { awaitingYours, awaitingCounterparty, revealed }

/// Status card for the double-blind review lifecycle (EP-03-12).
class DoubleBlindStatusCard extends StatelessWidget {
  const DoubleBlindStatusCard({
    super.key,
    required this.status,
    this.onWriteReview,
    this.onViewReviews,
    this.compact = false,
  });

  /// Viewer-scoped status from `service_review_get_mine`.
  final MyReviewStatus status;

  /// Invoked when the viewer taps the submit CTA (`awaiting_yours` only).
  final VoidCallback? onWriteReview;

  /// Invoked when the viewer taps the view CTA (`revealed` only).
  final VoidCallback? onViewReviews;

  /// Compact rendering for embedded (contract-detail) contexts.
  final bool compact;

  /// Derives the display state from [status] (verbatim server fields only).
  static DoubleBlindState stateFor(MyReviewStatus status) {
    if (status.revealedReviews.isNotEmpty) {
      return DoubleBlindState.revealed;
    }
    if (status.youHaveSubmitted) {
      return DoubleBlindState.awaitingCounterparty;
    }
    return DoubleBlindState.awaitingYours;
  }

  @override
  Widget build(BuildContext context) {
    final DoubleBlindState state = stateFor(status);
    switch (state) {
      case DoubleBlindState.awaitingYours:
        return _AwaitingYoursCard(
          onWriteReview: onWriteReview,
          compact: compact,
        );
      case DoubleBlindState.awaitingCounterparty:
        return const _AwaitingCounterpartyCard();
      case DoubleBlindState.revealed:
        return _RevealedCard(
          status: status,
          onViewReviews: onViewReviews,
          compact: compact,
        );
    }
  }
}

class _AwaitingYoursCard extends StatelessWidget {
  const _AwaitingYoursCard({this.onWriteReview, required this.compact});

  final VoidCallback? onWriteReview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const HivorrBadge(
                label: 'Awaiting your review',
                variant: HivorrBadgeVariant.info,
              ),
            ],
          ),
          SizedBox(
            height: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
          ),
          Text(
            'Share your experience',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            'Your review stays hidden until both parties submit or the 14-day window ends.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onWriteReview != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.sm),
            HivorrButton(
              label: 'Write a review',
              variant: HivorrButtonVariant.primary,
              isExpanded: true,
              onPressed: onWriteReview,
            ),
          ],
        ],
      ),
    );
  }
}

class _AwaitingCounterpartyCard extends StatelessWidget {
  const _AwaitingCounterpartyCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Waiting for the other party',
      child: HivorrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: const <Widget>[
                HivorrBadge(
                  label: 'Submitted',
                  variant: HivorrBadgeVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              'Waiting for the other party',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              'Your review stays hidden until both submit or the 14-day window ends.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  const _RevealedCard({
    required this.status,
    this.onViewReviews,
    required this.compact,
  });

  final MyReviewStatus status;
  final VoidCallback? onViewReviews;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<ServiceReview> revealed = status.revealedReviews;
    final List<Widget> rows = <Widget>[];
    for (final ServiceReview review in revealed) {
      rows.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            StarRatingDisplay(rating: review.rating.toDouble()),
            if (review.hasComment) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                review.comment!.trim(),
                style: context.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      );
    }
    final int displayCount = compact && rows.length > 2 ? 2 : rows.length;
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: const <Widget>[
              HivorrBadge(
                label: 'Revealed',
                variant: HivorrBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          for (int i = 0; i < displayCount; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: HivorrSpacing.sm),
            rows[i],
          ],
          if (onViewReviews != null && (!compact || rows.length > 2))
            ...<Widget>[
              const SizedBox(height: HivorrSpacing.sm),
              HivorrButton(
                label: 'View reviews',
                variant: HivorrButtonVariant.outline,
                isExpanded: true,
                onPressed: onViewReviews,
              ),
            ],
        ],
      ),
    );
  }
}
