import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Histogram of revealed ratings from a server aggregate (EP-03-12).
///
/// Renders rows `5→1` with a `LinearProgressIndicator` share per row and the
/// raw count. Consumes `distribution {1..5}` verbatim — never recomputes it.
/// Exposes per-row `Semantics(label: 'N out of M are X stars')`.
class RatingDistributionBar extends StatelessWidget {
  const RatingDistributionBar({
    super.key,
    required this.distribution,
    required this.reviewCount,
  });

  /// Server-derived histogram `{1: count, …, 5: count}`.
  final Map<int, int> distribution;

  /// Total revealed count (denominator).
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rating distribution from $reviewCount reviews',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int stars = 5; stars >= 1; stars--)
            _DistributionRow(
              stars: stars,
              count: distribution[stars] ?? 0,
              total: reviewCount,
            ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.stars,
    required this.count,
    required this.total,
  });

  final int stars;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double share = total <= 0 ? 0 : count / total;
    return Semantics(
      label: '$count out of $total are $stars stars',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16,
              child: Text(
                '$stars',
                style: context.textTheme.labelMedium,
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.star,
              size: 14,
              color: context.colorScheme.secondary,
            ),
            const SizedBox(width: HivorrSpacing.xs),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor:
                      context.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.colorScheme.secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.xs),
            SizedBox(
              width: 32,
              child: Text(
                '$count',
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
