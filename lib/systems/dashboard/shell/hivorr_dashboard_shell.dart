import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_paths.dart';
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
/// Mobile (<600dp): bottom navigation bar with the focus-relevant primaries.
/// Hire focus reaches every destination through the client hamburger drawer,
/// so no `More` tab is rendered there; professional focus (which has no
/// drawer) keeps `More` for its overflow destinations in
/// [DashboardMoreSheet].
///
/// Navigation items are focus-filtered: hire sees My Jobs + Shared, offer
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

    // Mobile (<600dp) carries no shell app bar: each dashboard screen owns
    // its single page title (Overview shows `My Hivorr`, every other page
    // shows its own title), so a static shell title would duplicate the
    // header hierarchy. Bottom navigation lives here and is untouched.
    return Scaffold(
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

/// Mobile bottom navigation (<600dp): focus-relevant primaries.
///
/// Primaries come from [mobilePrimaryNavItems] so the bar matches the current
/// focus (hire → My Jobs, offer → Jobs). Hire focus omits `More` — the client
/// hamburger drawer already covers every destination. Professional focus
/// keeps `More` for its overflow destinations in [DashboardMoreSheet]. The
/// bar auto-hides while the keyboard is open so inputs and chat composers
/// keep full height, and respects the bottom safe area (home indicator).
class _DashboardBottomNav extends StatelessWidget {
  const _DashboardBottomNav({
    required this.location,
    required this.hire,
    required this.offer,
  });

  final String location;
  final bool hire;
  final bool offer;

  /// `More` survives only where no drawer covers the overflow destinations
  /// (professional focus, including fail-open).
  bool get _showMore => offer;

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
    final bool moreSelected =
        _showMore &&
        !isMobilePrimaryLocation(location, hire: hire, offer: offer);
    final int index = _sectionIndex(location, primaries);
    final int selectedIndex = moreSelected ? primaries.length : index;
    // Professional-only focus carries the green identity into the selected
    // tab indicator/icon/label; hire and fail-open focuses keep the
    // brand-blue default (client unaffected). Scoped to this bar only.
    final bool isProfessional = offer && !hire;
    final ThemeData theme = Theme.of(context);
    final ColorScheme barScheme = isProfessional
        ? theme.colorScheme.copyWith(
            primary: context.roleTheme.professionalPrimary,
            secondaryContainer:
                context.roleTheme.professionalContainer,
            onSecondaryContainer:
                context.roleTheme.professionalPrimary,
          )
        : theme.colorScheme;
    return SafeArea(
      top: false,
      bottom: true,
      minimum: const EdgeInsets.only(bottom: 4),
      // Compact label sizing keeps every label on one line down to 320dp
      // (five destinations share 64dp each); icon sizing is set per
      // destination below. Scoped to this bar only.
      child: Theme(
        data: theme.copyWith(
          colorScheme: barScheme,
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll<TextStyle>(
              (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                fontSize: 11,
              ),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (int i) {
            if (_showMore && i >= primaries.length) {
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
            if (i < primaries.length && location != primaries[i].location) {
              context.go(primaries[i].location);
            }
          },
          destinations: <Widget>[
            for (final DashboardNavItem item in primaries)
              NavigationDestination(
                icon: _destinationIcon(context, item, selected: false),
                selectedIcon: _destinationIcon(context, item, selected: true),
                label: _shortLabel(item),
              ),
            if (_showMore)
              const NavigationDestination(
                icon: Icon(Icons.more_horiz_outlined, size: _iconSize),
                selectedIcon: Icon(Icons.more_horiz, size: _iconSize),
                label: 'More',
              ),
          ],
        ),
      ),
    );
  }

  /// Compact destination icon (22dp keeps five tabs balanced at 320px while
  /// the 48dp+ destination keeps a comfortable touch target). The Post Job
  /// action stays brand-blue in both states per the reference.
  static const double _iconSize = 22;

  static Widget _destinationIcon(
    BuildContext context,
    DashboardNavItem item, {
    required bool selected,
  }) {
    if (item.location == RoutePaths.dashboardJobNew) {
      return Icon(
        Icons.add_circle,
        size: _iconSize + 2,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return Icon(
      selected ? item.activeIcon : item.icon,
      size: _iconSize,
    );
  }

  /// Resolves [location] to its primary tab, mapping consolidated sections
  /// to the primary that owns them (client hires live under My Jobs).
  /// Exact matches win over prefix matches (so `/dashboard/jobs/new`
  /// highlights Post Job, not My Jobs). Unmatched locations fall back to
  /// the first tab.
  static int _sectionIndex(
    String location,
    List<DashboardNavItem> primaries,
  ) {
    String base = location.split('?').first;
    if (base == '/dashboard/hires' || base.startsWith('/dashboard/hires/')) {
      base = '/dashboard/jobs';
    }
    if (base == '/dashboard/applications' ||
        base.startsWith('/dashboard/applications/')) {
      base = '/dashboard/jobs';
    }
    for (int i = 0; i < primaries.length; i++) {
      if (primaries[i].location.split('?').first == base) {
        return i;
      }
    }
    for (int i = 0; i < primaries.length; i++) {
      final String itemBase = primaries[i].location.split('?').first;
      if (itemBase == '/dashboard') {
        if (base == '/dashboard') return i;
      } else if (base.startsWith('$itemBase/')) {
        return i;
      }
    }
    return 0;
  }

  /// Short bar labels that fit 320px wide (up to five destinations at the
  /// compact label size). The jobs list uses the approved `My Jobs`
  /// product terminology; discovery shortens to `Services` on the bar only
  /// (drawer and sidebar keep `Find Services`).
  String _shortLabel(DashboardNavItem item) {
    return switch (item.location) {
      '/dashboard' => 'Home',
      '/dashboard/opportunities' => 'Jobs',
      '/dashboard/jobs' => 'My Jobs',
      '/dashboard/jobs/new' => 'Post Job',
      '/dashboard/services' => 'Services',
      '/dashboard/messages' => 'Messages',
      _ => item.label,
    };
  }
}
