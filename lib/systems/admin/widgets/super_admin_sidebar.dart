import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/widgets/logo_variants.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:provider/provider.dart';

/// Narrow left-side navigation for the Super Admin shell.
///
/// Visual source of truth: Super Admin Dashboard reference screenshots —
/// white sidebar, official [LogoHorizontal] lockup, `Admin Dashboard`
/// section label, pill-style selected item, grey unselected items, and a
/// bottom Super Admin identity row with live profile data (never hardcoded).
///
/// Functional source of truth: existing Hivorr architecture. Keeps the
/// Users submenu (All / Professionals / Clients filtered by `capability`),
/// Verification & Approvals, Jobs, plus Payments / Settings as disabled
/// coming-soon placeholders. No duplicate services or routes.
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

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Official Hivorr lockup, top-left as in the reference.
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HivorrSpacing.lg,
              HivorrSpacing.lg,
              HivorrSpacing.lg,
              HivorrSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LogoHorizontal(height: 32),
            ),
          ),
          // Section label: purple dot + "Admin Dashboard".
          Container(
            color: colors.secondaryContainer.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.lg,
              vertical: 10,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.roleTheme.adminPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Text(
                  'Admin Dashboard',
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.roleTheme.adminPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: HivorrSpacing.sm,
                horizontal: 12,
              ),
              children: <Widget>[
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Overview',
                  selected: widget.location == RoutePaths.adminDashboard ||
                      widget.location == '/admin' ||
                      widget.location == '/admin/',
                  onTap: () => _go(context, RoutePaths.adminDashboard),
                ),
                const SizedBox(height: 2),
                _UsersParent(
                  expanded: _usersExpanded,
                  location: widget.location,
                  onToggle: () =>
                      setState(() => _usersExpanded = !_usersExpanded),
                  onNavigate: (String path) => _go(context, path),
                ),
                const SizedBox(height: 2),
                _NavItem(
                  icon: Icons.work_outline,
                  activeIcon: Icons.work,
                  label: 'Jobs',
                  selected: widget.location.startsWith('/admin/jobs'),
                  onTap: () => _go(context, RoutePaths.adminJobs),
                ),
                const SizedBox(height: 2),
                _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet,
                  label: 'Payments',
                  selected: widget.location.startsWith('/admin/payments'),
                  onTap: () => _go(context, RoutePaths.adminPayments),
                ),
                const SizedBox(height: 2),
                _NavItem(
                  icon: Icons.verified_user_outlined,
                  activeIcon: Icons.verified_user,
                  label: 'Verification &\nApprovals',
                  selected: widget.location.startsWith('/admin/review-queue') ||
                      widget.location.startsWith('/admin/verifications'),
                  onTap: () =>
                      _go(context, RoutePaths.adminVerificationApprovals),
                ),
                const SizedBox(height: 2),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  selected: widget.location.startsWith('/admin/settings'),
                  onTap: () => _go(context, RoutePaths.adminSettings),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          _AdminIdentityRow(onNavigate: widget.onNavigate),
        ],
      ),
    );
  }

  void _go(BuildContext context, String path) {
    widget.onNavigate?.call();
    if (widget.location != path) {
      context.go(path);
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
    final bool parentActive = _isUsersSection;
    final Color admin = context.roleTheme.adminPrimary;

    return Column(
      children: <Widget>[
        Material(
          color: parentActive
              ? colors.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: parentActive
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outline),
                    )
                  : null,
              padding: const EdgeInsets.symmetric(
                horizontal: HivorrSpacing.md,
                vertical: 12,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    parentActive ? Icons.people : Icons.people_outlined,
                    size: 20,
                    color: parentActive ? admin : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: HivorrSpacing.md),
                  Expanded(
                    child: Text(
                      'Users',
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight:
                            parentActive ? FontWeight.w700 : FontWeight.w500,
                        color:
                            parentActive ? admin : colors.onSurfaceVariant,
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
        ),
        if (expanded) ...<Widget>[
          const SizedBox(height: 2),
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
    final Color admin = context.roleTheme.adminPrimary;
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Material(
        color:
            selected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.md,
              vertical: 10,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? admin : colors.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Text(
                  label,
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? admin : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color admin = context.roleTheme.adminPrimary;
    final Color fg =
        selected ? admin : colors.onSurfaceVariant;

    return Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outline),
                )
              : null,
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: 12,
          ),
          child: Row(
            children: <Widget>[
              Icon(selected ? activeIcon : icon, size: 20, color: fg),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom identity row: live Super Admin profile + sign-out.
///
/// Name/initials resolve from [AuthProvider.currentSession] (full name,
/// display name, then email prefix). Never hardcoded — falls back to
/// "Super Admin" / "SA" only when no session is available (e.g. tests).
class _AdminIdentityRow extends StatelessWidget {
  const _AdminIdentityRow({this.onNavigate});

  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final _AdminIdentity identity = _resolveIdentity(context);

    return Padding(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Row(
        children: <Widget>[
          HivorrAvatar(
            name: identity.name,
            size: 36,
            backgroundColor: colors.secondaryContainer,
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  identity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Admin',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: Icon(
              Icons.logout_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    onNavigate?.call();
    try {
      await context.read<AuthProvider>().signOut();
    } catch (_) {
      if (context.mounted) context.go(RoutePaths.home);
    }
  }

  _AdminIdentity _resolveIdentity(BuildContext context) {
    try {
      final AuthProvider auth = context.watch<AuthProvider>();
      final session = auth.currentSession;
      final String? full = session?.fullName;
      if (full != null && full.trim().isNotEmpty) {
        final String name = full.trim();
        return _AdminIdentity(
          name: name,
          // Keep the generic Super Admin label only when nothing usable
          // exists; a real full name always wins.
          displayName: name,
        );
      }
      final String? display = session?.displayName?.trim();
      if (display != null && display.isNotEmpty) {
        return _AdminIdentity(name: display, displayName: display);
      }
      final String? email = session?.email;
      if (email != null && email.isNotEmpty) {
        final String pretty = _prettifyEmailPrefix(email);
        return _AdminIdentity(name: pretty, displayName: pretty);
      }
    } catch (_) {
      // Provider absent (isolated widget test) — fall through.
    }
    return const _AdminIdentity(name: 'Super Admin', displayName: 'Super Admin');
  }

  String _prettifyEmailPrefix(String email) {
    final String local = email.split('@').first.trim();
    if (local.isEmpty) return 'Super Admin';
    final List<String> words = local
        .split(RegExp(r'[._\-]+'))
        .where((String part) => part.isNotEmpty)
        .map((String part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase())
        .toList(growable: false);
    if (words.isEmpty) return 'Super Admin';
    return words.join(' ');
  }
}

class _AdminIdentity {
  const _AdminIdentity({required this.name, required this.displayName});

  final String name;
  final String displayName;
}
