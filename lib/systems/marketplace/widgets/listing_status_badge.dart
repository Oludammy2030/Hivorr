import 'package:flutter/material.dart';

import 'package:hivorr/shared/widgets/hivorr_badge.dart';

/// Thin [HivorrBadge] wrapper mapping a listing `status` to its semantic
/// variant (EP-03-08).
///
/// `published` → success, `paused` → warning, `reported`/`archived` → error,
/// `draft` → info. Unknown codes fall back to info (never throw in UI).
class ListingStatusBadge extends StatelessWidget {
  const ListingStatusBadge({super.key, required this.status});

  /// Listing lifecycle status (`draft|published|paused|archived|reported`).
  final String status;

  @override
  Widget build(BuildContext context) {
    final HivorrBadgeVariant variant = switch (status) {
      'published' => HivorrBadgeVariant.success,
      'paused' => HivorrBadgeVariant.warning,
      'archived' || 'reported' => HivorrBadgeVariant.error,
      _ => HivorrBadgeVariant.info,
    };
    return HivorrBadge(label: status, variant: variant);
  }
}
