import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_mode_toggle.dart';
import 'package:provider/provider.dart';

/// Capability-filtered left navigation for the dashboard shell (EP-04-03).
///
/// Professional (offer) mode renders the Professional Dashboard reference
/// (green identity, `Dashboard / Find Work / My Jobs / Messages / Earnings /
/// Profile` primaries + a `More` overflow for the remaining capability
/// items so nothing is removed). Hire / Both modes keep the established
/// grouped navigation (My Work / My Hiring / Shared).
class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.location,
    required this.capability,
    this.viewMode,
    this.onNavigate,
  });

  final String location;
  final DashboardCapability capability;

  /// Current operating mode for `both` users. Null preserves the combined
  /// navigation (used by legacy callers/tests); the shell always supplies it.
  final DashboardViewMode? viewMode;
  final VoidCallback? onNavigate;

  bool get _isProfessional {
    if (capability == DashboardCapability.offer) return true;
    if (capability == DashboardCapability.both &&
        viewMode == DashboardViewMode.professional) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isProfessional) {
      return _ProfessionalSidebar(
        location: location,
        capability: capability,
        onNavigate: onNavigate,
      );
    }

    final ColorScheme colors = context.colorScheme;
    final TextTheme text = context.textTheme;
    final bool hire;
    final bool offer;
    if (capability != DashboardCapability.both || viewMode == null) {
      hire = capability.showsHiring;
      offer = capability.showsWork;
    } else {
      hire = viewMode == DashboardViewMode.client;
      offer = viewMode == DashboardViewMode.professional;
    }
    final bool showModeToggle =
        capability == DashboardCapability.both && viewMode != null;
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
                if (showModeToggle) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.sm),
                  const DashboardModeToggle(),
                ],
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

/// Professional Dashboard reference sidebar (green visual identity).
///
/// Primary structure matches the reference exactly: Hivorr logo, green
/// `Professional Dashboard` banner, then `Dashboard / Find Work / My Jobs /
/// Messages / Earnings / Profile`. Remaining capability-visible destinations
/// (e.g. `My Applications`, `Notifications`, `Settings`) render under a
/// `MORE` header so existing functionality is preserved, not removed.
/// The footer user card derives name + initials from the stored backend
/// profile (AuthSession first/last names from `user_metadata` /
/// `entity_profiles`) — never hardcoded.
class _ProfessionalSidebar extends StatelessWidget {
  const _ProfessionalSidebar({
    required this.location,
    required this.capability,
    this.onNavigate,
  });

  final String location;
  final DashboardCapability capability;
  final VoidCallback? onNavigate;

  static const List<_ProNavDef> _primary = <_ProNavDef>[
    _ProNavDef(
      display: 'Dashboard',
      location: '/dashboard',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _ProNavDef(
      display: 'Find Work',
      location: '/dashboard/opportunities',
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
    ),
    _ProNavDef(
      display: 'My Jobs',
      location: '/dashboard/hires?role=professional',
      icon: Icons.work_outline,
      activeIcon: Icons.work,
    ),
    _ProNavDef(
      display: 'Messages',
      location: '/dashboard/messages',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
    ),
    _ProNavDef(
      display: 'Earnings',
      location: '/dashboard/earnings',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
    ),
    _ProNavDef(
      display: 'Profile',
      location: '/dashboard/account',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    final Color accent = roles.professionalPrimary;
    final Color accentContainer = roles.professionalContainer;

    // Overflow: every capability-visible item not covered by the six
    // reference primaries, in canonical order (preserves My Applications,
    // Notifications, Settings, etc.).
    final Set<String> primaryKeys = <String>{
      for (final _ProNavDef d in _primary) d.location,
    };
    final List<DashboardNavItem> overflow = dashboardNavItems
        .where(
          (DashboardNavItem item) =>
              item.visibleFor(hire: false, offer: true) &&
              !primaryKeys.contains(item.location),
        )
        .toList(growable: false);

    final _ProIdentity identity = _resolveIdentity(context);

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Logo row — matches reference: blue bolt tile + `Hivorr`.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Hivorr',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          // Green banner — `● Professional Dashboard`.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: accentContainer.withValues(alpha: 0.45),
              border: Border(
                top: BorderSide(color: colors.outlineVariant),
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Professional Dashboard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Both accounts keep the UI-only Professional | Client toggle so
          // the operating mode can switch back without losing the account.
          if (capability == DashboardCapability.both) ...<Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DashboardModeToggle(),
            ),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: <Widget>[
                for (final _ProNavDef def in _primary)
                  _ProNavRow(
                    label: def.display,
                    icon: def.icon,
                    activeIcon: def.activeIcon,
                    selected: _isSelected(def.location),
                    accent: accent,
                    accentContainer: accentContainer,
                    onTap: () => _go(context, def.location),
                  ),
                if (overflow.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Text(
                      'MORE',
                      style: context.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final DashboardNavItem item in overflow)
                    _ProNavRow(
                      label: item.label,
                      icon: item.icon,
                      activeIcon: item.activeIcon,
                      selected: _isSelected(item.location),
                      accent: accent,
                      accentContainer: accentContainer,
                      onTap: () => _go(context, item.location),
                    ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          // Footer user card — dynamic initials + name.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentContainer,
                    border: Border.all(
                      color: accent.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    identity.initials,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        identity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        'Professional',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
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

  Future<void> _signOut(BuildContext context) async {
    onNavigate?.call();
    try {
      await context.read<AuthProvider>().signOut();
    } catch (_) {
      // Auth provider absent (e.g. isolated widget test) — fall back home.
      if (context.mounted) context.go(RoutePaths.home);
    }
  }

  /// Resolves display name + initials from stored backend profile data.
  ///
  /// Prefers AuthSession first/last names (`user_metadata` /
  /// `entity_profiles`); falls back to displayName, then the email
  /// local-part — never hardcoded.
  _ProIdentity _resolveIdentity(BuildContext context) {
    try {
      final AuthProvider auth = context.watch<AuthProvider>();
      final session = auth.currentSession;
      final String? full = session?.fullName;
      if (full != null && full.isNotEmpty) {
        return _ProIdentity(
          name: full,
          initials: session!.initials ?? _fallbackInitials(full),
        );
      }
      final String? display = session?.displayName?.trim();
      if (display != null && display.isNotEmpty) {
        return _ProIdentity(
          name: display,
          initials: session!.initials ?? _fallbackInitials(display),
        );
      }
      final String? email = session?.email;
      if (email != null && email.isNotEmpty) {
        final String pretty = _prettifyEmailPrefix(email);
        return _ProIdentity(name: pretty, initials: _initials(pretty));
      }
    } catch (_) {
      // Provider absent — fall through to placeholder.
    }
    return const _ProIdentity(name: 'Professional', initials: 'P');
  }

  String _prettifyEmailPrefix(String email) {
    final String local = email.split('@').first.trim();
    if (local.isEmpty) return 'Professional';
    final List<String> words = local
        .split(RegExp(r'[._\-]+'))
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .toList(growable: false);
    if (words.isEmpty) return 'Professional';
    return words.join(' ');
  }

  String _initials(String name) {
    final List<String> words = name
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return 'P';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0].toUpperCase()}${words[1][0].toUpperCase()}';
  }

  String _fallbackInitials(String name) => _initials(name);
}

class _ProNavDef {
  const _ProNavDef({
    required this.display,
    required this.location,
    required this.icon,
    required this.activeIcon,
  });

  final String display;
  final String location;
  final IconData icon;
  final IconData activeIcon;
}

class _ProIdentity {
  const _ProIdentity({required this.name, required this.initials});

  final String name;
  final String initials;
}

class _ProNavRow extends StatelessWidget {
  const _ProNavRow({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.accent,
    required this.accentContainer,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final Color accent;
  final Color accentContainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? accentContainer.withValues(alpha: 0.55)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: accent.withValues(alpha: 0.25))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? activeIcon : icon,
                size: 20,
                color: selected ? accent : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                    color: selected ? accent : colors.onSurface,
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
