import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';

/// Narrow left-side navigation for the Super Admin shell.
///
/// Per §13: narrow enough to preserve the workspace; responsive.
/// Per §2: initial items Dashboard, Verification & Approvals, Users (with
/// nested submenu), plus future sections as disabled/coming-soon.
///
/// The Users submenu is the same Hivorr population filtered by `capability`:
///   All Users     → /admin/users (no capability param)
///   Professionals → /admin/users/professionals (capability=professional)
///   Clients       → /admin/users/clients (capability=client)
class SuperAdminSidebar extends StatefulWidget {
  const SuperAdminSidebar({
    super.key,
    required this.location,
    this.onNavigate,
  });

  final String location;
  final VoidCallback? onNavigate;

  @override
  State<SuperAdminSidebar> createState() => _SuperAdminSidebarState();
}

class _SuperAdminSidebarState extends State<SuperAdminSidebar> {
  bool _usersExpanded = false;

  @override
  void didUpdateWidget(SuperAdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _syncExpanded(widget.location);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncExpanded(widget.location);
  }

  void _syncExpanded(String loc) {
    if (loc.startsWith('/admin/users')) {
      _usersExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final TextTheme text = context.textTheme;

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
            child: Text(
              'HIVORR\nSUPER ADMIN',
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: colors.primary,
                height: 1.2,
              ),
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.sm),
              children: <Widget>[
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: widget.location == RoutePaths.adminDashboard ||
                      widget.location == '/admin' ||
                      widget.location == '/admin/',
                  onTap: () => _go(context, RoutePaths.adminDashboard),
                ),
                _NavItem(
                  icon: Icons.verified_user_outlined,
                  activeIcon: Icons.verified_user,
                  label: 'Verification &\nApprovals',
                  selected: widget.location.startsWith('/admin/review-queue') ||
                      widget.location == RoutePaths.adminVerificationApprovals,
                  onTap: () =>
                      _go(context, RoutePaths.adminVerificationApprovals),
                ),
                _UsersParent(
                  expanded: _usersExpanded,
                  location: widget.location,
                  onToggle: () =>
                      setState(() => _usersExpanded = !_usersExpanded),
                  onNavigate: (String path) => _go(context, path),
                ),
                _NavItem(
                  icon: Icons.work_outline,
                  activeIcon: Icons.work,
                  label: 'Jobs & Projects',
                  enabled: false,
                  badge: 'Soon',
                  selected: widget.location.startsWith('/admin/jobs'),
                  onTap: () {},
                ),
                _NavItem(
                  icon: Icons.flag_outlined,
                  activeIcon: Icons.flag,
                  label: 'Reports / Moderation',
                  enabled: false,
                  badge: 'Soon',
                  selected: widget.location.startsWith('/admin/reports'),
                  onTap: () {},
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: HivorrSpacing.md,
                    vertical: HivorrSpacing.xs,
                  ),
                  child: Divider(height: 1, color: colors.outlineVariant),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  enabled: false,
                  badge: 'Soon',
                  selected: widget.location.startsWith('/admin/settings'),
                  onTap: () {},
                ),
              ],
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
                    Icon(Icons.arrow_back,
                        size: 16, color: colors.onSurfaceVariant),
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

  void _go(BuildContext context, String path) {
    widget.onNavigate?.call();
    if (widget.location != path) {
      context.go(path);
    } else {
      // already there — still close drawer on mobile
      if (widget.onNavigate != null) {
        // drawer already handled
      }
    }
  }
}

class _UsersParent extends StatelessWidget {
  const _UsersParent({
    required this.expanded,
    required this.location,
    required this.onToggle,
    required this.onNavigate,
  });

  final bool expanded;
  final String location;
  final VoidCallback onToggle;
  final ValueChanged<String> onNavigate;

  bool get _isUsersSection => location.startsWith('/admin/users');

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final TextTheme text = context.textTheme;
    final bool parentActive = _isUsersSection;

    return Column(
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Container(
            color: parentActive
                ? colors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.lg,
              vertical: 12,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  parentActive ? Icons.group : Icons.group_outlined,
                  size: 20,
                  color:
                      parentActive ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: HivorrSpacing.md),
                Expanded(
                  child: Text(
                    'Users',
                    style: text.labelMedium?.copyWith(
                      fontWeight:
                          parentActive ? FontWeight.w700 : FontWeight.w500,
                      color: parentActive
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...<Widget>[
          _SubItem(
            label: 'All Users',
            selected: location == RoutePaths.adminManageUsers ||
                location == '/admin/users',
            onTap: () => onNavigate(RoutePaths.adminManageUsers),
          ),
          _SubItem(
            label: 'Professionals',
            selected: location == RoutePaths.adminUsersProfessionals,
            onTap: () => onNavigate(RoutePaths.adminUsersProfessionals),
          ),
          _SubItem(
            label: 'Clients',
            selected: location == RoutePaths.adminUsersClients,
            onTap: () => onNavigate(RoutePaths.adminUsersClients),
          ),
        ],
      ],
    );
  }
}

class _SubItem extends StatelessWidget {
  const _SubItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            selected ? colors.primary.withValues(alpha: 0.10) : Colors.transparent,
        padding: const EdgeInsets.only(
          left: 56,
          right: HivorrSpacing.lg,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Widget content = InkWell(
      onTap: enabled ? onTap : null,
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
              selected ? activeIcon : icon,
              size: 20,
              color: enabled
                  ? (selected ? colors.primary : colors.onSurfaceVariant)
                  : colors.outline,
            ),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: enabled
                      ? (selected ? colors.primary : colors.onSurface)
                      : colors.outline,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: context.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!enabled) {
      return Opacity(opacity: 0.6, child: content);
    }
    return content;
  }
}
