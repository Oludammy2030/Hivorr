import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/systems/dashboard/dashboard_sign_out.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Shared mobile chrome for the Client Dashboard (<600dp).
///
/// One app bar ([ClientMobileAppBar]) plus one hamburger drawer
/// ([ClientDashboardDrawer]) serve every client page: the shell owns no app
/// bar on mobile, so this single implementation keeps hamburger + title on
/// the left and bell + Client pill + avatar on the right — one compact row
/// everywhere, mirroring the desktop `HivorrDashboardTopBar`. Overview/Home
/// is titled `Hivorr` (brand as home); every other page passes its own
/// title. Professional surfaces keep their own bars — see [showClientMenu].
///
/// Visual language mirrors `DashboardSidebar` (selected = primary wash, 20dp
/// icons) and `HivorrDashboardTopBar` (`Menu`/`Notifications` tooltips).
class ClientMobileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ClientMobileAppBar({super.key, required this.title});

  /// Page title (`Hivorr` on Overview/Home, the page title elsewhere).
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 48,
      leadingWidth: 44,
      titleSpacing: HivorrSpacing.sm,
      leading: IconButton(
        tooltip: 'Menu',
        iconSize: 20,
        padding: const EdgeInsets.all(HivorrSpacing.sm),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: <Widget>[
        _BellAction(pendingApps: _pendingApplications(context)),
        const _ClientPill(),
        _AvatarAction(displayName: _displayName(context)),
      ],
    );
  }

  /// Open applications awaiting review drive the bell dot (clears when
  /// nothing pends). Missing providers resolve to zero.
  static int _pendingApplications(BuildContext context) {
    try {
      return context
          .watch<JobProvider>()
          .posted
          .where((Job job) => job.isOpen)
          .fold<int>(0, (int sum, Job job) => sum + job.applicationsCount);
    } catch (_) {
      return 0;
    }
  }

  /// Account name from the verified sign-in email (same rule as the overview
  /// hero); falls back to the client label when unavailable.
  static String _displayName(BuildContext context) {
    try {
      final String? email =
          context.watch<AuthProvider>().currentSession?.email;
      if (email != null && email.isNotEmpty) {
        return _prettifyEmailPrefix(email);
      }
    } catch (_) {
      // Provider absent — fall through to the label.
    }
    return DashboardCapability.hire.label;
  }
}

/// Notification bell with the attention dot (desktop top-bar language).
class _BellAction extends StatelessWidget {
  const _BellAction({required this.pendingApps});

  final int pendingApps;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return IconButton(
      tooltip: 'Notifications',
      iconSize: 20,
      padding: const EdgeInsets.all(HivorrSpacing.sm),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: () => context.go(RoutePaths.dashboardNotifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.notifications_outlined),
          if (pendingApps > 0)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: HivorrSpacing.sm,
                height: HivorrSpacing.sm,
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact Client indicator pill (desktop top-bar language).
class _ClientPill extends StatelessWidget {
  const _ClientPill();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    return Center(
      child: Container(
        key: const ValueKey<String>('client-indicator'),
        margin: const EdgeInsets.only(right: HivorrSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: HivorrSpacing.sm,
          vertical: HivorrSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: roles.clientContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: roles.clientPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: HivorrSpacing.xs),
            Text(
              'Client',
              style: context.textTheme.labelSmall?.copyWith(
                color: roles.clientPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact account avatar opening the profile (desktop top-bar language).
class _AvatarAction extends StatelessWidget {
  const _AvatarAction({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    return Tooltip(
      message: 'Profile',
      child: SizedBox(
        width: 44,
        height: 48,
        child: Center(
          child: InkWell(
            onTap: () => context.go(RoutePaths.dashboardAccount),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roles.clientContainer,
                border: Border.all(
                  color: roles.clientPrimary,
                  width: 1.5,
                ),
              ),
              child: Text(
                _initials(displayName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  color: roles.clientPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the client hamburger drawer applies here.
///
/// Hire focus (and fail-open pre-hydration, mirroring `dashboardVisibility`)
/// shows it; professional focus keeps its existing chrome untouched. A
/// missing provider (isolated widget tests) resolves to false so legacy
/// bars keep rendering.
bool showClientMenu(BuildContext context) {
  try {
    final EntityCapability? focus = context
        .read<OnboardingProvider>()
        .progress
        ?.capability;
    if (focus == null) {
      return true;
    }
    return DashboardCapability.fromEntity(focus).showsHiring;
  } catch (_) {
    return false;
  }
}

/// Mobile hamburger drawer for the client dashboard (`mob cl handb.png`).
///
/// Logo header, `Employer Dashboard` context strip, the full hire-visible
/// destination set derived from the shared [dashboardNavItems] config (so
/// mobile can never drift behind desktop: Dashboard active pill, Post a Job
/// primary CTA, then every hiring + shared entry in canonical order, plus
/// the Explore launcher the `More` sheet used to carry) and an account
/// footer with log-out. Standard [Drawer] behavior: modal scrim plus
/// scrim/back to close, no layout shift; the shell bottom navigation is
/// untouched.
class ClientDashboardDrawer extends StatelessWidget {
  const ClientDashboardDrawer({super.key});

  /// Reference drawer width: ~70% of a 390dp phone, safe at 320dp.
  static const double width = 280;

  /// Hire-visible destinations from the shared config, in canonical desktop
  /// order. Post a Job renders as the reference CTA (not a row); the
  /// Overview entry is labeled `Dashboard` per the reference.
  static List<DashboardNavItem> get _items => dashboardNavItems
      .where(
        (DashboardNavItem item) =>
            item.visibleFor(hire: true, offer: false) &&
            item.location != RoutePaths.dashboardJobNew,
      )
      .toList(growable: false);

  static String _label(DashboardNavItem item) =>
      item.location == '/dashboard' ? 'Dashboard' : item.label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    // `/dashboard` fallback keeps router-less harnesses (isolated widget
    // tests) rendering the Dashboard-active reference state.
    String location = '/dashboard';
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      location = '/dashboard';
    }
    String displayName = DashboardCapability.hire.label;
    try {
      final String? email =
          context.watch<AuthProvider>().currentSession?.email;
      if (email != null && email.isNotEmpty) {
        displayName = _prettifyEmailPrefix(email);
      }
    } catch (_) {
      displayName = DashboardCapability.hire.label;
    }
    final List<DashboardNavItem> items = _items;
    return Drawer(
      width: width,
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HivorrSpacing.md,
                HivorrSpacing.md,
                HivorrSpacing.md,
                HivorrSpacing.smMd,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.flash_on_rounded,
                      color: colors.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.sm),
                  Expanded(
                    child: Text(
                      'Hivorr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: roles.clientContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: HivorrSpacing.md,
                vertical: HivorrSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: HivorrSpacing.sm,
                    height: HivorrSpacing.sm,
                    decoration: BoxDecoration(
                      color: roles.clientPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.sm),
                  Text(
                    'Employer Dashboard',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: roles.clientPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: HivorrSpacing.sm,
                ),
                children: <Widget>[
                  _ClientDrawerItem(
                    label: _label(items[0]),
                    icon: items[0].icon,
                    activeIcon: items[0].activeIcon,
                    selected: _isSelected(location, items[0].location),
                    onTap: () => _go(context, location, items[0].location),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HivorrSpacing.smMd,
                      vertical: HivorrSpacing.xs,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _go(context, location, RoutePaths.dashboardJobNew),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Post a Job'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: HivorrSpacing.smMd,
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  for (int i = 1; i < items.length; i++)
                    _ClientDrawerItem(
                      label: _label(items[i]),
                      icon: items[i].icon,
                      activeIcon: items[i].activeIcon,
                      selected: _isSelected(location, items[i].location),
                      onTap: () => _go(context, location, items[i].location),
                    ),
                  // Explore launcher the `More` sheet used to carry, kept so
                  // no desktop destination loses mobile access.
                  _ClientDrawerItem(
                    label: 'Explore more ways to use Hivorr',
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    selected: _isSelected(
                      location,
                      RoutePaths.activities,
                    ),
                    onTap: () =>
                        _go(context, location, RoutePaths.activities),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(HivorrSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: roles.clientContainer,
                      border: Border.all(
                        color: roles.clientPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _initials(displayName),
                      style: context.textTheme.titleSmall?.copyWith(
                        color: roles.clientPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.smMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Employer',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    iconSize: 20,
                    padding: const EdgeInsets.all(HivorrSpacing.sm),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: const Icon(Icons.logout_outlined),
                    color: colors.onSurfaceVariant,
                    onPressed: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isSelected(String location, String itemLocation) {
    final String base = itemLocation.split('?').first;
    if (base == '/dashboard') {
      return location == '/dashboard';
    }
    return location == base || location.startsWith('$base/');
  }

  /// Closes the drawer first (mirroring `DashboardSidebar._go`), then routes
  /// only when the destination actually changes.
  static void _go(BuildContext context, String location, String path) {
    Navigator.of(context).pop();
    final String base = path.split('?').first;
    final String currentBase = location.split('?').first;
    if (currentBase != base) {
      context.go(path);
    }
  }

  static Future<void> _signOut(BuildContext context) async {
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    await signOutAndEvictMessagingCache(context);
    router.go(RoutePaths.login);
  }
}

class _ClientDrawerItem extends StatelessWidget {
  const _ClientDrawerItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.smMd,
        vertical: 2,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.md,
            vertical: HivorrSpacing.smMd,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? activeIcon : icon,
                size: 20,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.primary : colors.onSurface,
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

/// Display identity derived from the verified sign-in email (same rule as
/// the overview hero): the local-part stands in where no display name is
/// exposed. Never a fabricated company name.
String _prettifyEmailPrefix(String email) {
  final String local = email.split('@').first.trim();
  if (local.isEmpty) {
    return DashboardCapability.hire.label;
  }
  final List<String> words = local
      .split(RegExp(r'[._\-]+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .toList(growable: false);
  if (words.isEmpty) {
    return DashboardCapability.hire.label;
  }
  return words.join(' ');
}

/// Up-to-two-letter avatar initials for a display identity.
String _initials(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return '•';
  }
  final String first = words.first[0].toUpperCase();
  if (words.length == 1) {
    return first;
  }
  return '$first${words[1][0].toUpperCase()}';
}
