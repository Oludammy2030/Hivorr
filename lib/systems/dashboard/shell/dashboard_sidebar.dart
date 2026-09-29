import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';

/// Capability-filtered left navigation for the dashboard shell (EP-04-03).
///
/// Renders the single combined navigation grouped by section headers
/// (My Work / My Hiring / Shared). Hire sees hiring + shared, offer sees
/// work + shared, both sees everything. Mirrors the `SuperAdminSidebar`
/// visual language (narrow rail preserving the workspace).
class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.location,
    required this.capability,
    this.onNavigate,
  });

  final String location;
  final DashboardCapability capability;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final TextTheme text = context.textTheme;
    final bool hire = capability.showsHiring;
    final bool offer = capability.showsWork;
    final List<DashboardNavItem> visible = dashboardNavItems
        .where(
          (DashboardNavItem item) => item.visibleFor(hire: hire, offer: offer),
        )
        .toList(growable: false);

    DashboardNavSection? lastSection;
    final List<Widget> children = <Widget>[];
    for (final DashboardNavItem item in visible) {
      if (item.section != lastSection) {
        lastSection = item.section;
        // The leading Overview sits above the first header without one.
        if (children.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HivorrSpacing.lg,
                HivorrSpacing.md,
                HivorrSpacing.lg,
                HivorrSpacing.xs,
              ),
              child: Text(
                item.section.label.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
      }
      children.add(
        _NavItem(
          item: item,
          selected: _isSelected(item.location),
          onTap: () => _go(context, item.location),
        ),
      );
    }

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HivorrSpacing.lg,
              HivorrSpacing.xl,
              HivorrSpacing.lg,
              HivorrSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'HIVORR',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: colors.primary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  capability.label.toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
              children: children,
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: InkWell(
              onTap: () => context.go(RoutePaths.home),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: HivorrSpacing.xs,
                  horizontal: HivorrSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.arrow_back,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: HivorrSpacing.sm),
                    Text(
                      'Back to app',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSelected(String itemLocation) {
    final String base = itemLocation.split('?').first;
    if (base == '/dashboard') return location == '/dashboard';
    return location == base || location.startsWith('$base/');
  }

  void _go(BuildContext context, String path) {
    onNavigate?.call();
    final String base = path.split('?').first;
    final String currentBase = location.split('?').first;
    if (currentBase != base ||
        Uri.parse(path).query != Uri.parse(location).query) {
      context.go(path);
    }
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
      child: Container(
        color: selected
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.lg,
          vertical: 12,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? item.activeIcon : item.icon,
              size: 20,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
