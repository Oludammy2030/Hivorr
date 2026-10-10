import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';

/// Mobile `More` overflow sheet for the dashboard bottom navigation (<600dp).
///
/// Lists every focus-visible destination that is not already a primary bottom
/// tab, in canonical nav order. Tapping a row navigates via `go_router` and
/// closes the sheet.
class DashboardMoreSheet extends StatelessWidget {
  const DashboardMoreSheet({
    super.key,
    required this.location,
    required this.hire,
    required this.offer,
  });

  final String location;
  final bool hire;
  final bool offer;

  static Future<void> show(
    BuildContext context, {
    required String location,
    required bool hire,
    required bool offer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) =>
          DashboardMoreSheet(location: location, hire: hire, offer: offer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DashboardNavItem> overflow = mobileOverflowNavItems(
      hire: hire,
      offer: offer,
    );
    // Professional-only focus carries the green identity into the selected
    // states below; hire and fail-open focuses keep the brand-blue default.
    final bool isProfessional = offer && !hire;

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
                        fontWeight: FontWeight.w700,
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
              for (final DashboardNavItem item in overflow)
                _MoreRow(
                  item: item,
                  selected: _isSelected(location, item.location),
                  isProfessional: isProfessional,
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
              _MoreRow(
                item: const DashboardNavItem(
                  label: 'Explore more ways to use Hivorr',
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  location: RoutePaths.activities,
                  section: DashboardNavSection.shared,
                ),
                selected: _isSelected(location, RoutePaths.activities),
                isProfessional: isProfessional,
                onTap: () {
                  Navigator.of(context).pop();
                  if (location != RoutePaths.activities) {
                    context.go(RoutePaths.activities);
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
    required this.isProfessional,
    required this.onTap,
  });

  final DashboardNavItem item;
  final bool selected;

  /// Professional-only focus renders selected states in green; every other
  /// focus keeps the brand-blue default (client unaffected).
  final bool isProfessional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color accent = isProfessional
        ? context.roleTheme.professionalPrimary
        : colors.primary;
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
              ? accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: selected ? accent : colors.onSurfaceVariant,
            ),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : colors.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected) Icon(Icons.check, size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}
