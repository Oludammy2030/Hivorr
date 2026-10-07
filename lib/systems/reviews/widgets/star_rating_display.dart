import 'package:flutter/material.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';

/// Read-only star display for revealed ratings and aggregates (EP-03-12).
///
/// Renders [rating] (`0-5`) as 5 stars with fractional fill approximated by
/// full/half/empty icons, tinted `colorScheme.secondary`. Exposes
/// `Semantics(label: 'Rated X out of 5 …')`. Never computes averages — the
/// caller passes the server-derived value verbatim.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.starSize = 18,
    this.showValue = false,
  });

  /// Server-derived rating `0-5` (aggregate mean or single review rating).
  final double rating;

  /// Icon size per star.
  final double starSize;

  /// Whether to render the numeric value beside the stars.
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final List<Widget> stars = <Widget>[];
    for (int i = 1; i <= 5; i++) {
      final IconData icon;
      if (rating >= i - 0.25) {
        icon = Icons.star;
      } else if (rating >= i - 0.75) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(
        Icon(icon, size: starSize, color: colors.secondary),
      );
    }
    final String label = 'Rated ${rating.toStringAsFixed(1)} out of 5';
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...stars,
          if (showValue) ...<Widget>[
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
