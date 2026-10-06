import 'package:flutter/material.dart';

import 'package:hivorr/data/entities/service_review.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/systems/reviews/widgets/star_rating_display.dart';

/// Revealed review row (EP-03-12).
///
/// Renders a single `is_revealed=true` [ServiceReview]: stars + optional
/// comment + `revealed_at`. This widget must only ever receive revealed rows
/// (callers pass `revealed_reviews[]` / `get_for_listing` pages); it asserts
/// nothing about blindness itself — the server filters disclosure.
class ReviewListTile extends StatelessWidget {
  const ReviewListTile({super.key, required this.review});

  /// A revealed review row.
  final ServiceReview review;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StarRatingDisplay(rating: review.rating.toDouble()),
          if (review.hasComment) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              review.comment!.trim(),
              style: context.textTheme.bodyMedium,
            ),
          ],
          if (review.revealedAt != null) ...<Widget>[
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              'Revealed ${HivorrFormatters.date(review.revealedAt!)}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
