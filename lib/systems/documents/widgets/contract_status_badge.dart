import 'package:flutter/material.dart';

import 'package:hivorr/shared/widgets/hivorr_badge.dart';

/// Status badge for a service contract (EP-03-10 §8 D10).
///
/// Thin [HivorrBadge] wrapper mapping the `service_contracts` status
/// vocabulary to semantic variants. Pure display — enforcement stays
/// server-side (`AGENT.md` Rule 4). Every color/token resolves from the theme;
/// no hardcoded colors.
class ContractStatusBadge extends StatelessWidget {
  const ContractStatusBadge({super.key, required this.status});

  /// Contract status
  /// (`draft | offered | active | completed | disputed | closed | cancelled`).
  final String status;

  @override
  Widget build(BuildContext context) {
    return HivorrBadge(label: _label, variant: _variant);
  }

  String get _label {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'offered':
        return 'Offered';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'disputed':
        return 'Disputed';
      case 'closed':
        return 'Closed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  HivorrBadgeVariant get _variant {
    switch (status) {
      case 'active':
      case 'completed':
      case 'closed':
        return HivorrBadgeVariant.success;
      case 'disputed':
      case 'cancelled':
        return HivorrBadgeVariant.error;
      case 'offered':
        return HivorrBadgeVariant.info;
      default:
        return HivorrBadgeVariant.neutral;
    }
  }
}

/// Status badge for a contract milestone (EP-03-10 §8 D10).
///
/// Thin [HivorrBadge] wrapper mapping the `contract_milestones` status
/// vocabulary (`pending | completed | verified | released`) to semantic
/// variants. `verified` renders with the completed-adjacent success treatment
/// plus its own label (adapter contract with `MilestoneListCard`).
class ContractMilestoneStatusBadge extends StatelessWidget {
  const ContractMilestoneStatusBadge({super.key, required this.status});

  /// Milestone status.
  final String status;

  @override
  Widget build(BuildContext context) {
    return HivorrBadge(label: _label, variant: _variant);
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'verified':
        return 'Verified';
      case 'released':
        return 'Released';
      default:
        return status;
    }
  }

  HivorrBadgeVariant get _variant {
    switch (status) {
      case 'verified':
      case 'released':
      case 'completed':
        return HivorrBadgeVariant.success;
      case 'pending':
        return HivorrBadgeVariant.info;
      default:
        return HivorrBadgeVariant.neutral;
    }
  }
}
