import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_sidebar.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Persistent role-aware dashboard shell: sidebar + workspace (EP-04-03).
///
/// Desktop/tablet (>=600dp): fixed 264dp sidebar + expanded child.
/// Mobile (<600dp): AppBar + Drawer + bottom navigation bar.
///
/// Navigation items are capability-filtered: hire sees My Hiring + Shared,
/// offer sees My Work + Shared, both sees the single combined navigation.
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

    final Widget sidebar = DashboardSidebar(
      location: location,
      capability: capability,
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
      appBar: AppBar(title: const Text('Hivorr')),
      drawer: Drawer(
        width: 300,
        child: DashboardSidebar(
          location: location,
          capability: capability,
          onNavigate: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(child: _Workspace(child: child)),
      bottomNavigationBar: _DashboardBottomNav(
        location: location,
        capability: capability,
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: context.colorScheme.surface, child: child);
  }
}

/// Compact bottom navigation for mobile: Overview + primary work/hiring
/// entries + shared entries, capability-filtered.
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({required this.location, required this.capability});

  final String location;
  final DashboardCapability capability;

  @override
  Widget build(BuildContext context) {
    final bool hire = capability.showsHiring;
    final bool offer = capability.showsWork;
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
