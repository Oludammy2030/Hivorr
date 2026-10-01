import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/admin/widgets/super_admin_sidebar.dart';
import 'package:provider/provider.dart';

/// Persistent Super Admin shell: narrow left nav + top bar + workspace.
///
/// Visual source of truth: Super Admin Dashboard reference screenshots —
/// white sidebar + white top bar (hamburger, page title, notification bell
/// with red dot, `Admin` pill, live `AD` avatar), light `#F0F2F8` workspace,
/// one continuous vertical scroll owned by each screen.
///
/// Functional source of truth: existing Hivorr architecture. Fail-closed via
/// [AdminGate] over [AdminReviewProvider]; no frontend privilege escalation
/// (backend still enforces PLT002). Desktop/tablet (>=600dp): fixed sidebar
/// + expanded workspace. Mobile (<600dp): drawer + the same top bar.
class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key, required this.child});

  final Widget child;

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final AdminReviewProvider? admin = _maybeAdmin(context, listen: true);
    final bool isAdmin = AdminGate.isAdmin(admin);
    final bool loadingAdmin = admin?.isAdmin == null;
    final Breakpoint bp = context.breakpoint;
    final bool isDesktop = bp != Breakpoint.mobile;

    if (loadingAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Super Admin')),
        body: const HivorrLoadingState(),
      );
    }

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Super Admin')),
        body: SafeArea(
          child: HivorrEmptyState(
            icon: Icon(
              Icons.admin_panel_settings_outlined,
              color: context.colorScheme.primary,
            ),
            title: 'Admin access required',
            subtitle: 'You do not have platform admin privileges.',
          ),
        ),
      );
    }

    final Widget sidebar = SuperAdminSidebar(location: location);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!_sidebarCollapsed)
                SizedBox(
                  width: 248,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: context.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: sidebar,
                  ),
                ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _AdminTopBar(
                      location: location,
                      onMenu: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                    ),
                    Expanded(child: _Workspace(child: widget.child)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      drawer: Drawer(
        width: 280,
        child: SuperAdminSidebar(
          location: location,
          onNavigate: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Builder(
              builder: (BuildContext inner) => _AdminTopBar(
                location: location,
                onMenu: () => Scaffold.of(inner).openDrawer(),
              ),
            ),
            Expanded(child: _Workspace(child: widget.child)),
          ],
        ),
      ),
    );
  }

  AdminReviewProvider? _maybeAdmin(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return listen
          ? context.watch<AdminReviewProvider>()
          : context.read<AdminReviewProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

/// White top bar from the reference: hamburger + page title on the left,
/// bell with red dot + `Admin` pill + live avatar on the right.
class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.location, required this.onMenu});

  final String location;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String title = _titleFor(location);

    return Container(
      color: colors.surface,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.lg,
        vertical: HivorrSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          _ChromeButton(icon: Icons.menu, onTap: onMenu, tooltip: 'Menu'),
          const SizedBox(width: HivorrSpacing.md),
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const Spacer(),
          _NotificationButton(location: location),
          const SizedBox(width: HivorrSpacing.sm),
          const _AdminPill(),
          const SizedBox(width: HivorrSpacing.sm),
          _AdminAvatar(),
        ],
      ),
    );
  }

  String _titleFor(String loc) {
    if (loc.startsWith('/admin/users')) return 'User Management';
    if (loc.startsWith('/admin/jobs')) return 'Job Moderation';
    if (loc.startsWith('/admin/payments')) return 'Payments';
    if (loc.startsWith('/admin/settings')) return 'Settings';
    if (loc.startsWith('/admin/review-queue') ||
        loc.startsWith('/admin/verifications')) {
      return 'Verification & Approvals';
    }
    return 'Overview';
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          if (location != RoutePaths.adminVerificationApprovals) {
            context.go(RoutePaths.adminVerificationApprovals);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: 'Pending approvals',
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
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

class _AdminPill extends StatelessWidget {
  const _AdminPill();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Color admin = context.roleTheme.adminPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: admin, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'Admin',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: admin,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live Super Admin avatar: initials from [AuthProvider.currentSession],
/// never hardcoded. Falls back to "SA" only when no session exists.
class _AdminAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    String name = 'Super Admin';
    try {
      final AuthProvider auth = context.watch<AuthProvider>();
      final session = auth.currentSession;
      final String? full = session?.fullName;
      final String? display = session?.displayName?.trim();
      final String? email = session?.email;
      if (full != null && full.trim().isNotEmpty) {
        name = full.trim();
      } else if (display != null && display.isNotEmpty) {
        name = display;
      } else if (email != null && email.isNotEmpty) {
        name = email.split('@').first.trim();
        if (name.isEmpty) name = 'Super Admin';
      }
    } catch (_) {
      // Provider absent in isolated tests — keep fallback.
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: context.roleTheme.adminPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: HivorrAvatar(
        name: name,
        size: 36,
        backgroundColor: colors.secondaryContainer,
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: const Color(0xFFF0F2F8), child: child);
  }
}
