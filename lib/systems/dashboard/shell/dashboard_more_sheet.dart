import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_mode_toggle.dart';

/// Mobile `More` overflow sheet for the dashboard bottom navigation (<600dp).
///
/// Lists every capability/mode-visible destination that is not already a
/// primary bottom tab, in canonical nav order. Tapping a row navigates via
/// `go_router` and closes the sheet. Shows the Professional | Client toggle
/// on top for `both` users so the sheet always reflects the active mode.
class DashboardMoreSheet extends StatelessWidget {
  const DashboardMoreSheet({
    super.key,
    required this.location,
    required this.capability,
    this.viewMode,
  });

  final String location;
  final DashboardCapability capability;
  final DashboardViewMode? viewMode;

  static Future<void> show(
    BuildContext context, {
    required String location,
    required DashboardCapability capability,
    DashboardViewMode? viewMode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => DashboardMoreSheet(
        location: location,
        capability: capability,
        viewMode: viewMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hire;
    final bool offer;
    if (capability != DashboardCapability.both || viewMode == null) {
      hire = capability.showsHiring;
      offer = capability.showsWork;
    } else {
      hire = viewMode == DashboardViewMode.client;
      offer = viewMode == DashboardViewMode.professional;
    }
    final List<DashboardNavItem> overflow = mobileOverflowNavItems(
      hire: hire,
      offer: offer,
    );
    final bool showModeToggle =
        capability == DashboardCapability.both && viewMode != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            HivorrSpacing.md,
            0,
            HivorrSpacing.md,
            HivorrSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'More',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (showModeToggle) ...<Widget>[
                const DashboardModeToggle(),
                const SizedBox(height: HivorrSpacing.md),
              ],
              for (final DashboardNavItem item in overflow)
                _MoreRow(
                  item: item,
                  selected: _isSelected(location, item.location),
                  onTap: () {
                    Navigator.of(context).pop();
                    final String base = item.location.split('?').first;
                    final String currentBase = location.split('?').first;
                    if (currentBase != base ||
                        Uri.parse(item.location).query !=
                            Uri.parse(location).query) {
                      context.go(item.location);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSelected(String current, String itemLocation) {
    final String base = itemLocation.split('?').first;
    if (base == '/dashboard') return current == '/dashboard';
    return current == base || current.startsWith('$base/');
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final DashboardNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.md,
          vertical: HivorrSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 20, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
