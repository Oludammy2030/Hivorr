import 'package:flutter/material.dart';

import 'package:hivorr/shared/widgets/hivorr_badge.dart';

/// Status badge for a business identity (identity audit Phase 2a).
///
/// Thin [HivorrBadge] wrapper over the `pending | approved | rejected`
/// vocabulary: pending → warning, approved → success, rejected → error.
class BusinessStatusBadge extends StatelessWidget {
  const BusinessStatusBadge({super.key, required this.status});

  /// The business `verification_status`.
  final String status;

  @override
  Widget build(BuildContext context) {
    return HivorrBadge(label: _label, variant: _variant);
  }

  String get _label {
    switch (status) {
      case 'approved':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  HivorrBadgeVariant get _variant {
    switch (status) {
      case 'approved':
        return HivorrBadgeVariant.success;
      case 'rejected':
        return HivorrBadgeVariant.error;
      default:
        return HivorrBadgeVariant.warning;
    }
  }
}
