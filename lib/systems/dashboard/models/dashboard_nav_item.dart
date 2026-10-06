import 'package:flutter/material.dart';

/// Navigation sections for the focus-filtered dashboard nav (EP-04-03).
///
/// Pre-hydration (focus unknown) shows all sections with headers (My Work /
/// My Hiring / Shared); hire focus sees hiring + shared; offer focus sees
/// work + shared. No mode state — visibility is pure focus filtering.
enum DashboardNavSection {
  /// Professional-work side.
  work('My Work'),

  /// Hiring side.
  hiring('My Hiring'),

  /// Shared across both sides.
  shared('Shared');

  const DashboardNavSection(this.label);

  /// Section header label.
  final String label;
}

/// A single dashboard navigation destination (EP-04-03).
class DashboardNavItem {
  const DashboardNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.location,
    required this.section,
    this.showForHire = true,
    this.showForOffer = true,
  });

  /// Nav label.
  final String label;

  /// Idle icon.
  final IconData icon;

  /// Selected icon.
  final IconData activeIcon;

  /// Target location.
  final String location;

  /// Section grouping.
  final DashboardNavSection section;

  /// Visible for the hire focus.
  final bool showForHire;

  /// Visible for the offer focus.
  final bool showForOffer;

  /// Whether the current focus (as hire/offer flags) may see this item.
  /// Both flags true (pre-hydration fail-open) sees everything.
  bool visibleFor({required bool hire, required bool offer}) {
    if (hire && offer) return true;
    if (hire) return showForHire;
    return showForOffer;
  }
}

/// Mobile primary destinations for the bottom navigation (<600dp).
///
/// Returns at most the focus-relevant primaries in bar order:
/// hire → Overview, My Jobs, Find Services, Messages;
/// offer → Overview, Find Jobs, Messages;
/// unhydrated (both flags) → Overview, My Jobs, Find Jobs, Messages
/// (Find Services stays one tap away under `More` so the bar never exceeds
/// five destinations).
/// The `More` tab itself is rendered by the shell and is not included here.
List<DashboardNavItem> mobilePrimaryNavItems({
  required bool hire,
  required bool offer,
}) {
  DashboardNavItem byLocation(String location) {
    return dashboardNavItems.firstWhere(
      (DashboardNavItem item) => item.location == location,
    );
  }

  final List<DashboardNavItem> primaries = <DashboardNavItem>[
    byLocation('/dashboard'),
  ];
  if (hire) {
    primaries.add(byLocation('/dashboard/jobs'));
  }
  // Hiring-side marketplace discovery: a primary tab for hire
  // focus, rendered inside the dashboard shell (`/dashboard/services`) so
  // the sidebar persists. The unhydrated set keeps four primaries
  // (bar-crowding guard) with Find Services under `More`.
  if (hire && !offer) {
    primaries.add(byLocation('/dashboard/services'));
  }
  if (offer) {
    primaries.add(byLocation('/dashboard/opportunities'));
  }
  primaries.add(byLocation('/dashboard/messages'));
  return primaries;
}

/// Mobile overflow destinations shown under the `More` bottom sheet.
///
/// Every capability-visible item that is not already a primary tab, in the
/// canonical [dashboardNavItems] order (section grouping preserved by the
/// sheet). Comparison is by `location + label` so the shared
/// `/dashboard/applications` work/hiring variants do not collapse into each
/// other when `hire && offer`.
List<DashboardNavItem> mobileOverflowNavItems({
  required bool hire,
  required bool offer,
}) {
  final List<DashboardNavItem> primaries = mobilePrimaryNavItems(
    hire: hire,
    offer: offer,
  );
  final Set<String> primaryKeys = <String>{
    for (final DashboardNavItem item in primaries)
      '${item.location}|${item.label}',
  };
  return dashboardNavItems
      .where(
        (DashboardNavItem item) =>
            item.visibleFor(hire: hire, offer: offer) &&
            !primaryKeys.contains('${item.location}|${item.label}'),
      )
      .toList(growable: false);
}

/// Whether [location] is covered by one of the mobile primary tabs.
bool isMobilePrimaryLocation(
  String location, {
  required bool hire,
  required bool offer,
}) {
  final List<DashboardNavItem> primaries = mobilePrimaryNavItems(
    hire: hire,
    offer: offer,
  );
  for (final DashboardNavItem item in primaries) {
    final String base = item.location.split('?').first;
    if (base == '/dashboard') {
      if (location == '/dashboard') return true;
    } else if (location == base || location.startsWith('$base/')) {
      return true;
    }
  }
  return false;
}

/// The full dashboard navigation, in canonical section order.
const List<DashboardNavItem> dashboardNavItems = <DashboardNavItem>[
  DashboardNavItem(
    label: 'Overview',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    location: '/dashboard',
    section: DashboardNavSection.shared,
  ),
  // My Work (professional side).
  DashboardNavItem(
    label: 'Find Jobs',
    icon: Icons.search_outlined,
    activeIcon: Icons.search,
    location: '/dashboard/opportunities',
    section: DashboardNavSection.work,
    showForHire: false,
  ),
  DashboardNavItem(
    label: 'My Applications',
    icon: Icons.send_outlined,
    activeIcon: Icons.send,
    location: '/dashboard/applications',
    section: DashboardNavSection.work,
    showForHire: false,
  ),
  DashboardNavItem(
    label: 'My Work',
    icon: Icons.work_outline,
    activeIcon: Icons.work,
    location: '/dashboard/hires?role=professional',
    section: DashboardNavSection.work,
    showForHire: false,
  ),
  DashboardNavItem(
    label: 'Earnings',
    icon: Icons.account_balance_wallet_outlined,
    activeIcon: Icons.account_balance_wallet,
    location: '/dashboard/earnings',
    section: DashboardNavSection.work,
    showForHire: false,
  ),
  // My Hiring (client side).
  DashboardNavItem(
    label: 'Post a Job',
    icon: Icons.add_circle_outline,
    activeIcon: Icons.add_circle,
    location: '/dashboard/jobs/new',
    section: DashboardNavSection.hiring,
    showForOffer: false,
  ),
  DashboardNavItem(
    label: 'My Jobs',
    icon: Icons.business_center_outlined,
    activeIcon: Icons.business_center,
    location: '/dashboard/jobs',
    section: DashboardNavSection.hiring,
    showForOffer: false,
  ),
  DashboardNavItem(
    label: 'Find Services',
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
    location: '/dashboard/services',
    section: DashboardNavSection.hiring,
    showForOffer: false,
  ),
  DashboardNavItem(
    label: 'Applications',
    icon: Icons.group_outlined,
    activeIcon: Icons.group,
    location: '/dashboard/applications',
    section: DashboardNavSection.hiring,
    showForOffer: false,
  ),
  // NOTE: the client `Hires` hub was consolidated into `My Jobs`
  // (engagements + Cancelled/Disputed tabs live on the job cards), so no
  // client-side Hires destination remains. The professional `My Work`
  // (`/dashboard/hires?role=professional`) and the hire-detail route stay —
  // My Jobs engagement actions deep-link into them.
  DashboardNavItem(
    label: 'Payments',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments,
    location: '/dashboard/payments',
    section: DashboardNavSection.hiring,
    showForOffer: false,
  ),
  // Shared.
  DashboardNavItem(
    label: 'Messages',
    icon: Icons.mail_outline,
    activeIcon: Icons.mail,
    location: '/dashboard/messages',
    section: DashboardNavSection.shared,
  ),
  DashboardNavItem(
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    location: '/dashboard/notifications',
    section: DashboardNavSection.shared,
  ),
  DashboardNavItem(
    label: 'Profile',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    location: '/dashboard/account',
    section: DashboardNavSection.shared,
  ),
  DashboardNavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    location: '/dashboard/settings',
    section: DashboardNavSection.shared,
  ),
];
