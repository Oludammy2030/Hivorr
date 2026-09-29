import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_nav_item.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_more_sheet.dart';
import 'package:hivorr/systems/dashboard/shell/dashboard_sidebar.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_mode_toggle.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Persistent role-aware dashboard shell: sidebar + workspace (EP-04-03).
///
/// Desktop/tablet (>=600dp): fixed 264dp sidebar + expanded child.
/// Mobile (<600dp): slim AppBar + bottom navigation bar (Home + mode-relevant
/// primary + Messages + More). The drawer is intentionally absent on mobile;
/// overflow destinations live in [DashboardMoreSheet].
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
      body: SafeArea(
        top: true,
        bottom: false,
        child: _Workspace(child: child),
      ),
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

/// Mobile bottom navigation (<600dp): mode-relevant primaries + `More`.
///
/// Primaries come from [mobilePrimaryNavItems] so `both` users see the active
/// mode (Client → Hiring, Professional → Jobs) instead of a mixed bar. The
/// bar auto-hides while the keyboard is open so inputs and chat composers
/// keep full height, and respects the bottom safe area (home indicator).
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
    // Give chat inputs and forms full height while typing.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final bool hire;
    final bool offer;
    if (capability != DashboardCapability.both || viewMode == null) {
      hire = capability.showsHiring;
      offer = capability.showsWork;
    } else {
      hire = viewMode == DashboardViewMode.client;
      offer = viewMode == DashboardViewMode.professional;
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
                capability: capability,
                viewMode: viewMode,
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
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_outlined),
            selectedIcon: const Icon(Icons.more_horiz),
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
