import 'package:flutter/material.dart';

import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';

/// A prominent quick-action button for dashboard overviews (EP-04-03).
///
/// Role-specific actions rendered as outlined buttons with leading icons —
/// prominent without overwhelming the overview.
class DashboardQuickAction extends StatelessWidget {
  const DashboardQuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return HivorrButton(
      label: label,
      icon: Icon(icon),
      variant: primary
          ? HivorrButtonVariant.primary
          : HivorrButtonVariant.outline,
      onPressed: onTap,
    );
  }
}

/// Wraps quick actions with consistent spacing (EP-04-03).
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.actions});

  final List<DashboardQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: HivorrSpacing.sm,
      runSpacing: HivorrSpacing.sm,
      children: actions,
    );
  }
}
