import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_more_sheet.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_sidebar.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Capability visibility flags for the dashboard shell.
///
/// Derived from [OnboardingProvider.progress]: a hydrated focus filters to its
/// side; unhydrated (null) shows everything (fail-open) so the shell never
/// strands the user before hydration. There is no combined mode — switching
/// sides happens in the Explore/Earn launcher.
({bool hire, bool offer}) dashboardVisibility(OnboardingProvider onboarding) {
  final EntityCapability? focus = onboarding.progress?.capability;
  if (focus == null) {
    return (hire: true, offer: true);
  }
  final DashboardCapability capability = DashboardCapability.fromEntity(focus);
  return (hire: capability.showsHiring, offer: capability.showsWork);
}

/// Persistent role-aware dashboard shell: sidebar + workspace (EP-04-03).
///
/// Desktop/tablet (>=600dp): fixed 264dp sidebar + expanded child.
/// Mobile (<600dp): slim AppBar + bottom navigation bar (Home + focus-relevant
/// primary + Messages + More). The drawer is intentionally absent on mobile;
/// overflow destinations live in [DashboardMoreSheet].
///
/// Navigation items are focus-filtered: hire sees My Hiring + Shared, offer
/// sees My Work + Shared. Switching sides happens in the Explore/Earn
/// launcher (`/activities`), never via an in-shell toggle.
class HivorrDashboardShell extends StatelessWidget {
  const HivorrDashboardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
    final ({bool hire, bool offer}) visibility = dashboardVisibility(
      onboarding,
    );

    final Widget sidebar = DashboardSidebar(
      location: location,
      hire: visibility.hire,
      offer: visibility.offer,
    );

    if (context.breakpoint != Breakpoint.mobile) {
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
      body: SafeArea(
        top: true,
        bottom: false,
        child: _Workspace(child: child),
      ),
      bottomNavigationBar: _DashboardBottomNav(
        location: location,
        hire: visibility.hire,
        offer: visibility.offer,
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

/// Mobile bottom navigation (<600dp): focus-relevant primaries + `More`.
///
/// Primaries come from [mobilePrimaryNavItems] so the bar matches the current
/// focus (hire → Hiring, offer → Jobs). The bar auto-hides while the keyboard
/// is open so inputs and chat composers keep full height, and respects the
/// bottom safe area (home indicator).
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.location,
    required this.hire,
    required this.offer,
  });

  final String location;
  final bool hire;
  final bool offer;

  @override
  Widget build(BuildContext context) {
    // Give chat inputs and forms full height while typing.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final List<DashboardNavItem> primaries = mobilePrimaryNavItems(
      hire: hire,
      offer: offer,
    );
    final bool moreSelected = !isMobilePrimaryLocation(
      location,
      hire: hire,
      offer: offer,
    );
    int index = 0;
    for (int i = 0; i < primaries.length; i++) {
      final String base = primaries[i].location.split('?').first;
      if (base == '/dashboard') {
        if (location == '/dashboard') index = i;
      } else if (location == base || location.startsWith('$base/')) {
        index = i;
      }
    }
    final int selectedIndex = moreSelected ? primaries.length : index;
    return SafeArea(
      top: false,
      bottom: true,
      minimum: const EdgeInsets.only(bottom: 4),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (int i) {
          if (i >= primaries.length) {
            unawaited(
              DashboardMoreSheet.show(
                context,
                location: location,
                hire: hire,
                offer: offer,
              ),
            );
            return;
          }
          if (location != primaries[i].location) {
            context.go(primaries[i].location);
          }
        },
        destinations: <Widget>[
          for (final DashboardNavItem item in primaries)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: _shortLabel(item),
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  /// Short bar labels that fit 320px wide (4–5 destinations).
  String _shortLabel(DashboardNavItem item) {
    return switch (item.location) {
      '/dashboard' => 'Home',
      '/dashboard/opportunities' => 'Jobs',
      '/dashboard/jobs' => 'Hiring',
      '/dashboard/messages' => 'Messages',
      _ => item.label,
    };
  }
}
