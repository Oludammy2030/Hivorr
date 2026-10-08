import 'package:flutter/material.dart';

import 'package:hivorr/shared/widgets/hivorr_badge.dart';

/// Status badge for an appointment (EP-03-14 §8 D10).
///
/// Thin [HivorrBadge] wrapper mapping the `appointments` status vocabulary to
/// semantic variants. Pure display — enforcement stays server-side
/// (`AGENT.md` Rule 4). Every color/token resolves from the theme;
/// no hardcoded colors.
class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge({super.key, required this.status});

  /// Appointment status
  /// (`pending | confirmed | completed | cancelled | rescheduled`).
  final String status;

  @override
  Widget build(BuildContext context) {
    return HivorrBadge(label: _label, variant: _variant);
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rescheduled':
        return 'Rescheduled';
      default:
        return status;
    }
  }

  HivorrBadgeVariant get _variant {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return HivorrBadgeVariant.success;
      case 'cancelled':
        return HivorrBadgeVariant.error;
      case 'rescheduled':
        return HivorrBadgeVariant.warning;
      case 'pending':
        return HivorrBadgeVariant.info;
      default:
        return HivorrBadgeVariant.neutral;
    }
  }
}
