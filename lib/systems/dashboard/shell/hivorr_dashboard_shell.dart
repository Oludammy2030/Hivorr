import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_sidebar.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_mode_toggle.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Persistent role-aware dashboard shell: sidebar + workspace (EP-04-03).
///
/// Desktop/tablet (>=600dp): fixed 264dp sidebar + expanded child.
/// Mobile (<600dp): AppBar + Drawer + bottom navigation bar.
///
/// Navigation items are capability-filtered: hire sees My Hiring + Shared,
/// offer sees My Work + Shared, both sees the current operating mode
/// ([DashboardViewModeProvider]: Professional → work + shared, Client →
/// hiring + shared) via the Professional | Client toggle. The toggle is
/// UI-only — the account role stays `both` and permissions are unchanged.
/// Capability resolves from [OnboardingProvider.progress] (defaults to both,
/// matching `EntityCapability.fromName`), so the shell never strands the
/// user before hydration.
class HivorrDashboardShell extends StatelessWidget {
  const HivorrDashboardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
    final EntityCapability entityCapability =
        onboarding.progress?.capability ?? EntityCapability.both;
    final DashboardCapability capability = DashboardCapability.fromEntity(
      entityCapability,
    );
    final Breakpoint bp = context.breakpoint;
    final bool isDesktop = bp != Breakpoint.mobile;
    final DashboardViewMode viewMode = context
        .watch<DashboardViewModeProvider>()
        .mode;
    final bool showModeToggle = capability == DashboardCapability.both;

    final Widget sidebar = DashboardSidebar(
      location: location,
      capability: capability,
      viewMode: viewMode,
    );

    if (isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 264,
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
              Expanded(child: _Workspace(child: child)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hivorr'),
        bottom: showModeToggle
            ? const PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: DashboardModeToggle(),
                ),
              )
            : null,
      ),
      drawer: Drawer(
        width: 300,
        child: DashboardSidebar(
          location: location,
          capability: capability,
          viewMode: viewMode,
          onNavigate: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _Workspace(child: child)),
      bottomNavigationBar: _DashboardBottomNav(
        location: location,
        capability: capability,
        viewMode: viewMode,
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

/// Compact bottom navigation for mobile: Overview + primary work/hiring
/// entries + shared entries, capability- and mode-filtered.
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.location,
    required this.capability,
    this.viewMode,
  });

  final String location;
  final DashboardCapability capability;

  /// Current operating mode for `both` users; null preserves combined nav.
  final DashboardViewMode? viewMode;

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
    final List<_BottomEntry> entries = <_BottomEntry>[
      const _BottomEntry(
        label: 'Home',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        location: '/dashboard',
      ),
      if (offer)
        const _BottomEntry(
          label: 'Jobs',
          icon: Icons.search_outlined,
          activeIcon: Icons.search,
          location: '/dashboard/opportunities',
        ),
      if (hire)
        const _BottomEntry(
          label: 'Hiring',
          icon: Icons.business_center_outlined,
          activeIcon: Icons.business_center,
          location: '/dashboard/jobs',
        ),
      const _BottomEntry(
        label: 'Messages',
        icon: Icons.mail_outline,
        activeIcon: Icons.mail,
        location: '/dashboard/messages',
      ),
      const _BottomEntry(
        label: 'Account',
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        location: '/dashboard/account',
      ),
    ];
    int index = 0;
    for (int i = 0; i < entries.length; i++) {
      if (location == entries[i].location ||
          (entries[i].location != '/dashboard' &&
              location.startsWith(entries[i].location))) {
        index = i;
      }
    }
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (int i) {
        if (location != entries[i].location) {
          context.go(entries[i].location);
        }
      },
      destinations: <Widget>[
        for (final _BottomEntry entry in entries)
          NavigationDestination(
            icon: Icon(entry.icon),
            selectedIcon: Icon(entry.activeIcon),
            label: entry.label,
          ),
      ],
    );
  }
}

class _BottomEntry {
  const _BottomEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.location,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String location;
}
