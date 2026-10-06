import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/theme/app_colors.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/components/hivorr_month_bars.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/systems/dashboard/models/client_overview_mock.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';
import 'package:hivorr/systems/dashboard/widgets/overview_display_widgets.dart';
import 'package:hivorr/systems/dashboard/widgets/quick_actions.dart';
import 'package:hivorr/systems/jobs/models/job_status.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Focus-aware dashboard overview: the operational command center (EP-04-03).
///
/// One screen with focus variants: hire sees hiring summary + actions, offer
/// sees work summary + actions. Balanced composition — summary cards, quick
/// actions, pending items, recent jobs — never a card wall. Pre-hydration
/// shows the combined view (fail-open); switching sides happens in the
/// Explore/Earn launcher.
class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  State<DashboardOverviewScreen> createState() =>
      _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends State<DashboardOverviewScreen> {
  bool _hydrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hydrated) {
      _hydrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  Future<void> _hydrate() async {
    if (!mounted) return;
    final OnboardingProvider onboarding = context.read<OnboardingProvider>();
    // Fail-open pre-hydration: load both sides until the focus is known.
    final EntityCapability? focus = onboarding.progress?.capability;
    final bool hire = focus == null || focus == EntityCapability.hire;
    final bool offer = focus == null || focus == EntityCapability.offer;
    final JobProvider jobs = context.read<JobProvider>();
    final HireProvider hires = context.read<HireProvider>();
    if (hire) {
      unawaited(
        jobs.loadMine(role: 'posted').then((_) => jobs.loadRecentReceived()),
      );
      unawaited(hires.loadList(role: 'client'));
    }
    if (offer) {
      unawaited(jobs.loadDiscovery(refresh: true));
      unawaited(jobs.loadMine(role: 'applied'));
      unawaited(hires.loadList(role: 'professional'));
    }
  }

  Future<void> _refresh(DashboardCapability? capability) async {
    final JobProvider jobs = context.read<JobProvider>();
    final HireProvider hires = context.read<HireProvider>();
    // Null = pre-hydration fail-open: refresh both sides.
    if (capability == null || capability.showsHiring) {
      await jobs.loadMine(role: 'posted');
      await jobs.loadRecentReceived();
      await hires.loadList(role: 'client');
    }
    if (capability == null || capability.showsWork) {
      await jobs.loadDiscovery(refresh: true);
      await jobs.loadMine(role: 'applied');
      await hires.loadList(role: 'professional');
    }
  }

  /// Client overview chrome matching the reference dashboard.
  ///
  /// Desktop/tablet render the reference top bar above the content (the shell
  /// owns no app bar there); mobile keeps a slim app bar since the shell
  /// provides bottom-navigation chrome. Mobile uses compact padding/gaps so
  /// the layout feels designed for phones rather than a squeezed desktop.
  /// Data hooks, destinations, error/loading/empty states and the Money
  /// section are shared with the other views — only presentation differs.
  Widget _clientScaffold(
    BuildContext context,
    DashboardCapability capability,
    JobProvider jobs,
    HireProvider hires,
  ) {
    final bool hasError =
        jobs.lastError != null &&
        jobs.posted.isEmpty &&
        jobs.discovery.isEmpty;
    final bool isMobile = context.breakpoint == Breakpoint.mobile;
    Widget content = hasError
        ? _ErrorBody(
            message: jobs.lastError!.message,
            onRetry: () => unawaited(_refresh(capability)),
          )
        : RefreshIndicator(
            onRefresh: () => _refresh(capability),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: MobileCompact.scrollPaddingFor(c.maxWidth),
                  child: _ClientContent(
                    maxWidth: c.maxWidth,
                    hiresEmpty: hires.hires.isEmpty && !hires.isLoading,
                  ),
                );
              },
            ),
          );
    if (isMobile) {
      return Scaffold(
        // Mobile hamburger (upper-left): the Scaffold supplies the standard
        // menu leading automatically; the drawer below follows the
        // `mob cl handb.png` reference. Bottom navigation lives in the
        // dashboard shell and is intentionally untouched here.
        drawer: const _ClientDrawer(),
        // Client Overview/Home is the only page titled `My Hivorr`; every
        // other dashboard page shows its own title (shell owns no app bar
        // on mobile, so there is exactly one header). No refresh action —
        // pull-to-refresh on the content covers reloads.
        appBar: AppBar(
          toolbarHeight: 48,
          title: Text(
            'My Hivorr',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Notifications',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go(RoutePaths.dashboardNotifications),
            ),
          ],
        ),
        body: MobileSafeBody(child: content),
      );
    }
    content = ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: content,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ClientTopBar(capability: capability),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
    // Fail-open pre-hydration: combined view until the focus is known.
    final EntityCapability? focus = onboarding.progress?.capability;
    final DashboardCapability? capability = focus == null
        ? null
        : DashboardCapability.fromEntity(focus);
    final bool showHiring =
        capability == null || capability.showsHiring;
    final bool showWork = capability == null || capability.showsWork;
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    // Client-only presentation follows the reference dashboard.
    // Professional-only presentation follows the Professional Dashboard
    // reference (green identity). The combined view below is the
    // pre-hydration fail-open only.
    if (showHiring && !showWork) {
      return _clientScaffold(context, capability, jobs, hires);
    }
    if (showWork && !showHiring) {
      return _professionalScaffold(context, capability, jobs, hires);
    }

    final bool isMobileScaffold =
        context.breakpoint == Breakpoint.mobile;
    return Scaffold(
      // Pre-hydration fail-open shares the client Overview title (`My
      // Hivorr`) — the shell owns no app bar on mobile, so this is the
      // single header. No refresh action; the content RefreshIndicator
      // below covers reloads.
      appBar: AppBar(
        toolbarHeight: isMobileScaffold ? 48 : null,
        title: Text(
          'My Hivorr',
          style: isMobileScaffold
              ? context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : context.textTheme.titleLarge,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Notifications',
            iconSize: isMobileScaffold ? 20 : null,
            padding: isMobileScaffold
                ? const EdgeInsets.all(HivorrSpacing.sm)
                : null,
            constraints: isMobileScaffold
                ? const BoxConstraints(minWidth: 40, minHeight: 40)
                : null,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(RoutePaths.dashboardNotifications),
          ),
        ],
      ),
      body: MobileSafeBody(
        child:
            jobs.lastError != null &&
                jobs.posted.isEmpty &&
                jobs.discovery.isEmpty
            ? _ErrorBody(
                message: jobs.lastError!.message,
                onRetry: () => unawaited(_refresh(capability)),
              )
            : RefreshIndicator(
                onRefresh: () => _refresh(capability),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final bool isWide = c.maxWidth >= 720;
                    final bool compact = MobileCompact.isCompactWidth(
                      c.maxWidth,
                    );
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: MobileCompact.scrollPaddingFor(c.maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _WelcomeHeader(
                            capability: capability,
                          ),
                          const SizedBox(height: HivorrSpacing.md),
                          _MetricsGrid(
                            showHiring: showHiring,
                            showWork: showWork,
                            isWide: isWide,
                            maxWidth: c.maxWidth,
                          ),
                          SizedBox(
                            height: compact
                                ? HivorrSpacing.lg
                                : HivorrSpacing.xl,
                          ),
                          const HivorrSectionHeader(title: 'Quick actions'),
                          _QuickActions(
                            showHiring: showHiring,
                            showWork: showWork,
                          ),
                          if (showHiring) ...<Widget>[
                            SizedBox(
                              height: compact
                                  ? HivorrSpacing.lg
                                  : HivorrSpacing.xl,
                            ),
                            _HiringSection(isWide: isWide),
                          ],
                          if (showWork) ...<Widget>[
                            SizedBox(
                              height: compact
                                  ? HivorrSpacing.lg
                                  : HivorrSpacing.xl,
                            ),
                            _WorkSection(isWide: isWide),
                          ],
                          SizedBox(
                            height: compact
                                ? HivorrSpacing.lg
                                : HivorrSpacing.xl,
                          ),
                          _FinanceSection(
                            hiresEmpty: hires.hires.isEmpty && !hires.isLoading,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.capability});

  /// Null pre-hydration (fail-open loading state); otherwise the focus.
  final DashboardCapability? capability;

  @override
  Widget build(BuildContext context) {
    final String subtitle = switch (capability) {
      DashboardCapability.hire =>
        'Post jobs, review applications, and hire verified professionals.',
      DashboardCapability.offer =>
        'Find jobs, manage applications, and track your work.',
      null => 'Loading your workspace…',
    };
    final RoleThemeExtension roles = context.roleTheme;
    final (Color pillBg, Color pillFg, String pillLabel)? pill =
        switch (capability) {
      DashboardCapability.hire => (
        roles.clientContainer,
        roles.clientPrimary,
        'Client mode',
      ),
      DashboardCapability.offer => (
        roles.professionalContainer,
        roles.professionalPrimary,
        'Professional mode',
      ),
      null => null,
    };
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (pill != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.sm,
              vertical: HivorrSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: pill.$1,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pill.$3,
              style: context.textTheme.labelSmall?.copyWith(
                color: pill.$2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SizedBox(
          height: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
        ),
        Text(
          'Welcome back',
          style: (compact
                  ? context.textTheme.titleLarge
                  : context.textTheme.headlineSmall)
              ?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          subtitle,
          style: (compact
                  ? context.textTheme.bodySmall
                  : context.textTheme.bodyMedium)
              ?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.showHiring,
    required this.showWork,
    required this.isWide,
    required this.maxWidth,
  });

  final bool showHiring;
  final bool showWork;
  final bool isWide;
  final double maxWidth;
  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    final RoleThemeExtension roles = context.roleTheme;
    // Mobile: two compact columns when there is room (>=360dp), otherwise a
    // single column so cards never squeeze or overflow at 320px. Desktop
    // keeps the fixed 220dp tiles (see MobileCompact contract).
    final double cardWidth;
    if (isWide) {
      cardWidth = 220;
    } else if (MobileCompact.isCompactWidth(maxWidth) &&
        MobileCompact.fitsTwoColumns(maxWidth)) {
      cardWidth = MobileCompact.twoColumnWidth(maxWidth);
    } else {
      cardWidth = maxWidth;
    }
    final List<Widget> cards = <Widget>[];
    if (showHiring) {
      final int open = jobs.posted.where((j) => j.isOpen).length;
      cards.addAll(<Widget>[
        _Sized(
          width: cardWidth,
          child: DashboardMetricCard(
            icon: Icons.business_center_outlined,
            label: 'My Jobs',
            value: jobs.isLoading && jobs.posted.isEmpty
                ? '…'
                : '${jobs.posted.length}',
            subtitle: '$open open',
            accent: roles.clientPrimary,
            accentContainer: roles.clientContainer,
            onTap: () => context.go(RoutePaths.dashboardJobs),
          ),
        ),
        _Sized(
          width: cardWidth,
          child: DashboardMetricCard(
            icon: Icons.handshake_outlined,
            label: 'Hires',
            value: hires.isLoading && hires.hires.isEmpty
                ? '…'
                : '${hires.hires.length}',
            subtitle: 'Client side',
            accent: roles.clientPrimary,
            accentContainer: roles.clientContainer,
            // Consolidated: client hires now live under My Jobs.
            onTap: () => context.go(RoutePaths.dashboardJobs),
          ),
        ),
      ]);
    }
    if (showWork) {
      cards.addAll(<Widget>[
        _Sized(
          width: cardWidth,
          child: DashboardMetricCard(
            icon: Icons.search_outlined,
            label: 'Open Jobs',
            value: jobs.isLoading && jobs.discovery.isEmpty
                ? '…'
                : '${jobs.discovery.length}',
            subtitle: 'Available now',
            accent: roles.professionalPrimary,
            accentContainer: roles.professionalContainer,
            onTap: () => context.go(RoutePaths.dashboardOpportunities),
          ),
        ),
        _Sized(
          width: cardWidth,
          child: DashboardMetricCard(
            icon: Icons.work_outline,
            label: 'My Work',
            value: hires.isLoading && hires.hires.isEmpty
                ? '…'
                : '${hires.hires.length}',
            subtitle: 'Professional side',
            accent: roles.professionalPrimary,
            accentContainer: roles.professionalContainer,
            onTap: () =>
                context.go('${RoutePaths.dashboardHires}?role=professional'),
          ),
        ),
      ]);
    }
    final bool compact = maxWidth < 600;
    return Wrap(
      spacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
      runSpacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
      children: cards,
    );
  }
}

class _Sized extends StatelessWidget {
  const _Sized({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.showHiring, required this.showWork});

  final bool showHiring;
  final bool showWork;

  @override
  Widget build(BuildContext context) {
    final List<DashboardQuickAction> actions = <DashboardQuickAction>[];
    if (showHiring) {
      actions.addAll(<DashboardQuickAction>[
        DashboardQuickAction(
          label: 'Post a Job',
          icon: Icons.add,
          primary: true,
          onTap: () => context.go(RoutePaths.dashboardJobNew),
        ),
        DashboardQuickAction(
          label: 'My Jobs',
          icon: Icons.business_center_outlined,
          onTap: () => context.go(RoutePaths.dashboardJobs),
        ),
      ]);
    }
    if (showWork) {
      actions.addAll(<DashboardQuickAction>[
        DashboardQuickAction(
          label: 'Find Jobs',
          icon: Icons.search,
          primary: !showHiring,
          onTap: () => context.go(RoutePaths.dashboardOpportunities),
        ),
        DashboardQuickAction(
          label: 'My Applications',
          icon: Icons.send_outlined,
          onTap: () => context.go(RoutePaths.dashboardApplications),
        ),
      ]);
    }
    actions.add(
      DashboardQuickAction(
        label: 'Messages',
        icon: Icons.mail_outline,
        onTap: () => context.go(RoutePaths.dashboardMessages),
      ),
    );
    return DashboardQuickActions(actions: actions);
  }
}

class _HiringSection extends StatelessWidget {
  const _HiringSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final List<Job> recent = jobs.posted.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrSectionHeader(
          title: 'My Hiring',
          action: HivorrButton(
            label: 'View all',
            variant: HivorrButtonVariant.text,
            onPressed: () => context.go(RoutePaths.dashboardJobs),
          ),
        ),
        if (jobs.isLoading && jobs.posted.isEmpty)
          const HivorrLoadingState()
        else if (recent.isEmpty)
          HivorrEmptyState(
            compact: context.breakpoint == Breakpoint.mobile,
            title: 'No jobs posted yet',
            subtitle:
                'Create your first job and start receiving applications from qualified professionals.',
            actionButton: HivorrButton(
              label: 'Post a Job',
              size: context.breakpoint == Breakpoint.mobile
                  ? HivorrButtonSize.small
                  : HivorrButtonSize.medium,
              onPressed: () => context.go(RoutePaths.dashboardJobNew),
            ),
          )
        else
          ...recent.map(
            (Job job) => Padding(
              padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
              child: JobCard(
                job: job,
                onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkSection extends StatelessWidget {
  const _WorkSection({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    final List<Job> recentJobs = jobs.discovery.take(3).toList();
    final List<Hire> recentHires = hires.hires.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrSectionHeader(
          title: 'My Work',
          action: HivorrButton(
            label: 'Find jobs',
            variant: HivorrButtonVariant.text,
            onPressed: () => context.go(RoutePaths.dashboardOpportunities),
          ),
        ),
        if (jobs.isLoading && jobs.discovery.isEmpty)
          const HivorrLoadingState()
        else if (recentJobs.isEmpty && recentHires.isEmpty)
          HivorrEmptyState(
            compact: context.breakpoint == Breakpoint.mobile,
            title: 'No work yet',
            subtitle:
                'Browse open jobs and submit your first application to get started.',
            actionButton: HivorrButton(
              label: 'Find Jobs',
              size: context.breakpoint == Breakpoint.mobile
                  ? HivorrButtonSize.small
                  : HivorrButtonSize.medium,
              onPressed: () => context.go(RoutePaths.dashboardOpportunities),
            ),
          )
        else ...<Widget>[
          ...recentJobs.map(
            (Job job) => Padding(
              padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
              child: JobCard(
                job: job,
                onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
              ),
            ),
          ),
          ...recentHires.map(
            (Hire hire) => Padding(
              padding: const EdgeInsets.only(bottom: HivorrSpacing.sm),
              child: HireCard(
                hire: hire,
                onTap: () =>
                    context.go(RoutePaths.dashboardHireDetail(hire.id)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FinanceSection extends StatelessWidget {
  const _FinanceSection({required this.hiresEmpty});

  final bool hiresEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const HivorrSectionHeader(title: 'Money'),
        HivorrCard(
          child: DashboardQuickActions(
            actions: <DashboardQuickAction>[
              DashboardQuickAction(
                label: 'Payments',
                icon: Icons.payments_outlined,
                onTap: () => context.go(RoutePaths.dashboardPayments),
              ),
              DashboardQuickAction(
                label: 'Earnings',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => context.go(RoutePaths.dashboardEarnings),
              ),
              DashboardQuickAction(
                label: 'Escrow',
                icon: Icons.lock_outline,
                onTap: () => context.go(RoutePaths.escrow),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HivorrErrorState(
      message: 'Could not load dashboard',
      detail: message,
      onRetry: onRetry,
    );
  }
}

// ── Client overview — reference dashboard presentation ──────────
// Data hooks, destinations and terminology match the other views; only the
// layout follows the reference (top bar, blue hero, quick-action tiles,
// active-job cards, right-rail metric grid).

/// Reference top bar: menu tile, `Dashboard` title, notification bell with
/// attention dot, role pill and account avatar.
class _ClientTopBar extends StatelessWidget {
  const _ClientTopBar({required this.capability});

  final DashboardCapability capability;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    // Attention signal for the bell: open applications awaiting review.
    // NotificationProvider is not in the widget tree, so the hero's own
    // pending-application count drives the dot (clears when nothing pends).
    int pendingApps = 0;
    try {
      pendingApps = context
          .watch<JobProvider>()
          .posted
          .where((Job job) => job.isOpen)
          .fold<int>(0, (int sum, Job job) => sum + job.applicationsCount);
    } catch (_) {
      pendingApps = 0;
    }
    String displayName = capability.label;
    try {
      final String? email = context.watch<AuthProvider>().currentSession?.email;
      if (email != null && email.isNotEmpty) {
        displayName = _prettifyEmailPrefix(email);
      }
    } catch (_) {
      displayName = capability.label;
    }
    return HivorrDashboardTopBar(
      title: 'Dashboard',
      accentPrimary: roles.clientPrimary,
      accentContainer: roles.clientContainer,
      modeLabel: capability.label,
      initials: _initials(displayName),
      showDot: pendingApps > 0,
      onMenu: () {
        final ScaffoldState? scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onNotifications: () => context.go(RoutePaths.dashboardNotifications),
      onAvatar: () => context.go(RoutePaths.dashboardAccount),
    );
  }
}

/// Mobile hamburger drawer for the client dashboard (`mob cl handb.png`).
///
/// Client-only (<600dp, hire focus): logo header, `Employer Dashboard`
/// context strip, reference-ordered destinations (Dashboard active pill,
/// Post a Job primary CTA, My Jobs, Applications, Messages, Payments,
/// Profile) and an account footer with log-out. A standard [Drawer] supplies
/// the modal scrim plus scrim/back-to-close with no layout shift; the shell
/// bottom navigation is untouched. Item language mirrors
/// `DashboardSidebar` (selected = primary wash, 20dp icons).
class _ClientDrawer extends StatelessWidget {
  const _ClientDrawer();

  /// Reference drawer width: ~70% of a 390dp phone, safe at 320dp.
  static const double _width = 280;

  static const List<_ClientDrawerDef> _items = <_ClientDrawerDef>[
    _ClientDrawerDef(
      label: 'Dashboard',
      location: '/dashboard',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _ClientDrawerDef(
      label: 'My Jobs',
      location: RoutePaths.dashboardJobs,
      icon: Icons.business_center_outlined,
      activeIcon: Icons.business_center,
    ),
    _ClientDrawerDef(
      label: 'Applications',
      location: RoutePaths.dashboardApplications,
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
    ),
    _ClientDrawerDef(
      label: 'Messages',
      location: RoutePaths.dashboardMessages,
      icon: Icons.mail_outline,
      activeIcon: Icons.mail,
    ),
    _ClientDrawerDef(
      label: 'Payments',
      location: RoutePaths.dashboardPayments,
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
    ),
    _ClientDrawerDef(
      label: 'Profile',
      location: RoutePaths.dashboardAccount,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

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
    return Drawer(
      width: _width,
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
                    label: _items[0].label,
                    icon: _items[0].icon,
                    activeIcon: _items[0].activeIcon,
                    selected: _isSelected(location, _items[0].location),
                    onTap: () => _go(context, location, _items[0].location),
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
                  for (int i = 1; i < _items.length; i++)
                    _ClientDrawerItem(
                      label: _items[i].label,
                      icon: _items[i].icon,
                      activeIcon: _items[i].activeIcon,
                      selected: _isSelected(location, _items[i].location),
                      onTap: () => _go(context, location, _items[i].location),
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
    final AuthProvider auth = context.read<AuthProvider>();
    Navigator.of(context).pop();
    await auth.signOut();
    router.go(RoutePaths.login);
  }
}

class _ClientDrawerDef {
  const _ClientDrawerDef({
    required this.label,
    required this.location,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String location;
  final IconData icon;
  final IconData activeIcon;
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

/// Client content column: hero, then quick actions + active jobs beside the
/// right-rail metric grid on wide layouts. Below the rail breakpoint the
/// sections stack as one page — mobile (<600dp) follows the reference
/// `mob cl dah.png` → `mob cl das 2.png` order (stats, quick actions,
/// active jobs, recent applications, rail cards), then Money.
class _ClientContent extends StatelessWidget {
  const _ClientContent({required this.maxWidth, required this.hiresEmpty});

  final double maxWidth;
  final bool hiresEmpty;

  /// Width at or above which the right metric rail docks beside the content.
  static const double railStart = 1000;

  @override
  Widget build(BuildContext context) {
    final bool wide = maxWidth >= railStart;
    // Mobile (<600dp) stacks the metric grid below the hero per the
    // reference; the hero itself carries no stat chips there.
    // Desktop/tablet keep the reference rail 100% unchanged.
    final bool isMobileWidth = MobileCompact.isCompactWidth(maxWidth);
    // Compact vertical rhythm on phones (<600dp); desktop keeps the airy
    // reference spacing (see MobileCompact contract).
    final double sectionGap = MobileCompact.sectionGapFor(maxWidth);
    const Widget quickActions = _ClientSection(
      title: 'Quick Actions',
      child: _ClientQuickActions(),
    );
    final Widget activeJobs = _ClientSection(
      title: 'Active Jobs',
      action: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardJobs),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Manage all',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      child: const _ClientActiveJobs(),
    );
    final Widget recentApplications = _ClientSection(
      title: 'Recent Applications',
      action: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardJobs),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'View all',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      child: const _ClientRecentApplications(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ClientHero(),
        SizedBox(height: sectionGap),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    quickActions,
                    const SizedBox(height: HivorrSpacing.xl),
                    const _BrowseServicesBanner(),
                    const SizedBox(height: HivorrSpacing.xl),
                    activeJobs,
                    const SizedBox(height: HivorrSpacing.xl),
                    recentApplications,
                  ],
                ),
              ),
              const SizedBox(width: HivorrSpacing.lg),
              const SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ClientStatsGrid(),
                    SizedBox(height: HivorrSpacing.lg),
                    // TODO(client-dashboard-backend): feed live spending once
                    // the monthly-budget + escrow-hold seams exist — see
                    // client_overview_mock.dart and swap the instance below.
                    _SpendingOverviewCard(
                      summary: ClientSpendingMock.reference,
                    ),
                    SizedBox(height: HivorrSpacing.lg),
                    // TODO(client-dashboard-backend): feed live payments once
                    // the client payment-history seam exists — see
                    // client_overview_mock.dart and swap the list below.
                    _RecentPaymentsCard(
                      payments: ClientPaymentMock.reference,
                    ),
                    SizedBox(height: HivorrSpacing.lg),
                    _CurrentHiresCard(),
                  ],
                ),
              ),
            ],
          )
        else if (isMobileWidth) ...<Widget>[
          // Mobile (<600dp) follows `mob cl dah.png` → `mob cl das 2.png`
          // as one continuous page: hero, 2x2 stats, quick actions, active
          // jobs, recent applications, then the rail cards stacked below.
          const _ClientStatsGrid(),
          SizedBox(height: sectionGap),
          quickActions,
          SizedBox(height: sectionGap),
          activeJobs,
          SizedBox(height: sectionGap),
          recentApplications,
          SizedBox(height: sectionGap),
          const _CurrentHiresCard(),
          SizedBox(height: sectionGap),
          // TODO(client-dashboard-backend): mock rail cards — connect live
          // spending/payments when the seams exist (see above).
          const _SpendingOverviewCard(
            summary: ClientSpendingMock.reference,
          ),
          SizedBox(height: sectionGap),
          const _RecentPaymentsCard(
            payments: ClientPaymentMock.reference,
          ),
          SizedBox(height: sectionGap),
          const _BrowseServicesBanner(),
        ] else ...<Widget>[
          quickActions,
          SizedBox(height: sectionGap),
          const _BrowseServicesBanner(),
          SizedBox(height: sectionGap),
          const _ClientStatsGrid(),
          SizedBox(height: sectionGap),
          // TODO(client-dashboard-backend): mock rail cards — connect live
          // spending/payments when the seams exist (see above).
          const _SpendingOverviewCard(
            summary: ClientSpendingMock.reference,
          ),
          SizedBox(height: sectionGap),
          const _RecentPaymentsCard(
            payments: ClientPaymentMock.reference,
          ),
          SizedBox(height: sectionGap),
          activeJobs,
          SizedBox(height: sectionGap),
          recentApplications,
          SizedBox(height: sectionGap),
          const _CurrentHiresCard(),
        ],
        SizedBox(height: sectionGap),
        _FinanceSection(hiresEmpty: hiresEmpty),
      ],
    );
  }
}

class _ClientSection extends StatelessWidget {
  const _ClientSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action case final Widget resolvedAction) resolvedAction,
          ],
        ),
        SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
        child,
      ],
    );
  }
}

/// Blue hero card: time-aware greeting, account name and new-application
/// line. Wider layouts add the four glass stat chips; mobile (<600dp) omits
/// them — the reference stats live in the 2x2 grid below the hero.
class _ClientHero extends StatelessWidget {
  const _ClientHero();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    String displayName = DashboardCapability.hire.label;
    try {
      final String? email = context.watch<AuthProvider>().currentSession?.email;
      if (email != null && email.isNotEmpty) {
        displayName = _prettifyEmailPrefix(email);
      }
    } catch (_) {
      displayName = DashboardCapability.hire.label;
    }
    final bool loading =
        (jobs.isLoading && jobs.posted.isEmpty) ||
        (hires.isLoading && hires.hires.isEmpty);
    final int postedCount = jobs.posted.length;
    final int totalApps = jobs.posted.fold<int>(
      0,
      (int sum, Job job) => sum + job.applicationsCount,
    );
    final int activeHires = hires.hires
        .where((Hire hire) => hire.isActive)
        .length;
    final _SpentSummary spent = _spentSummary(jobs.posted, hires.hires);
    final String hour = _greeting();
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double heroPadding = compact
        ? HivorrSpacing.smMd
        : HivorrSpacing.lg;
    return Container(
      // Clip the sliding metric carousel strictly inside the blue bounds so
      // cards never paint past the rounded corners / screen edges (mobile).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
      ),
      padding: EdgeInsets.all(heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$hour,',
            style: (compact
                    ? context.textTheme.bodySmall
                    : context.textTheme.bodyLarge)
                ?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$displayName \u{1F3E2}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleLarge
                    : context.textTheme.headlineMedium)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : 10),
          if (loading)
            Text(
              'Loading your hiring activity…',
              style: (compact
                      ? context.textTheme.bodySmall
                      : context.textTheme.bodyMedium)
                  ?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            )
          else if (totalApps > 0)
            Text.rich(
              TextSpan(
                style: (compact
                        ? context.textTheme.bodySmall
                        : context.textTheme.bodyMedium)
                    ?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'You have '),
                  TextSpan(
                    text: '$totalApps new application${totalApps == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' across your active jobs'),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              'No new applications across your active jobs yet',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (compact
                      ? context.textTheme.bodySmall
                      : context.textTheme.bodyMedium)
                  ?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          // Mobile (<600dp) keeps the hero to greeting + application line —
          // the `mob cl dah.png` stats live in the 2x2 grid below the hero.
          // Wider layouts keep the reference glass-chip wrap unchanged.
          if (!compact) ...<Widget>[
            const SizedBox(height: HivorrSpacing.lg),
            Wrap(
              spacing: HivorrSpacing.md,
              runSpacing: HivorrSpacing.md,
              children: <Widget>[
                OverviewHeroStat(
                  value: loading ? '…' : '$postedCount',
                  label: 'Jobs Posted',
                  compact: false,
                ),
                OverviewHeroStat(
                  value: loading ? '…' : '$activeHires',
                  label: 'Active Hires',
                  compact: false,
                ),
                OverviewHeroStat(
                  value: loading
                      ? '…'
                      : '${spent.symbol}${_grouped(spent.total)}',
                  label: 'Total Spent',
                  compact: false,
                ),
                OverviewHeroStat(
                  value: loading ? '…' : '$totalApps',
                  label: 'Applications',
                  compact: false,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Three quick-action tiles: Post a Job, View Applications, Message Hires.
class _ClientQuickActions extends StatelessWidget {
  const _ClientQuickActions();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    // Mobile fintech quick links: compact 3-column grid. Desktop keeps the
    // reference Row unchanged. (No stretch — the Row lives in a vertical
    // scroll with unbounded height, so stretch would break layout.)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _QuickTile(
            label: 'Post a Job',
            icon: Icons.add,
            onTap: () => context.go(RoutePaths.dashboardJobNew),
          ),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        Expanded(
          child: _QuickTile(
            label: 'View Applications',
            icon: Icons.people_outline,
            tint: _QuickTint.green,
            onTap: () => context.go(RoutePaths.dashboardJobs),
          ),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        Expanded(
          child: _QuickTile(
            label: 'Message Hires',
            icon: Icons.chat_bubble_outline,
            tint: _QuickTint.peach,
            onTap: () => context.go(RoutePaths.dashboardMessages),
          ),
        ),
      ],
    );
  }
}

enum _QuickTint { lavender, green, peach }

/// Full-width entry into in-dashboard service discovery.
///
/// Client-side companion to the `Find Services` nav destination: same
/// `HivorrCard` + client-accent vocabulary as `_QuickTile`, with an explicit
/// CTA so the entry works even where the tab is one level deep (More sheet).
/// Routes inside the shell so the sidebar persists.
class _BrowseServicesBanner extends StatelessWidget {
  const _BrowseServicesBanner();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final RoleThemeExtension roles = context.roleTheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return HivorrCard(
      onTap: () => context.go(RoutePaths.dashboardServices),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 44 : 52,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              color: roles.clientContainer,
              borderRadius: BorderRadius.circular(
                compact ? ext.radiusXs : ext.radiusMd,
              ),
            ),
            child: Icon(
              Icons.storefront_outlined,
              size: compact ? 22 : 26,
              color: roles.clientPrimary,
            ),
          ),
          const SizedBox(width: HivorrSpacing.smMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Find services',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Browse verified professionals and request proposals.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Icon(
            Icons.arrow_forward,
            color: colors.primary,
            semanticLabel: 'Browse services',
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tint = _QuickTint.lavender,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final _QuickTint tint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final RoleThemeExtension roles = context.roleTheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double iconSize = compact ? 32 : 40;
    final (Color tileBg, Color iconFg) = switch (tint) {
      _QuickTint.lavender => (roles.clientContainer, roles.clientPrimary),
      _QuickTint.green => (ext.successContainer, ext.success),
      _QuickTint.peach => (ext.warningContainer, ext.warning),
    };
    return HivorrCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? HivorrSpacing.sm : HivorrSpacing.md,
        vertical: compact ? HivorrSpacing.smMd : HivorrSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(
                compact ? ext.radiusXs : ext.radiusMd,
              ),
            ),
            child: Icon(icon, size: compact ? 20 : 24, color: iconFg),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.labelSmall
                    : context.textTheme.titleSmall)
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
              // Tight 2-line banking label that never clips at 320px.
              height: compact ? 1.25 : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Recent posted jobs rendered as reference job cards (open first).
class _ClientActiveJobs extends StatelessWidget {
  const _ClientActiveJobs();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final List<Job> ordered = <Job>[
      ...jobs.posted.where((Job job) => job.isOpen),
      ...jobs.posted.where((Job job) => !job.isOpen),
    ];
    if (jobs.isLoading && jobs.posted.isEmpty) {
      return const HivorrLoadingState();
    }
    if (ordered.isEmpty) {
      final bool emptyCompact =
          context.breakpoint == Breakpoint.mobile;
      return HivorrEmptyState(
        compact: emptyCompact,
        title: 'No jobs posted yet',
        subtitle:
            'Create your first job and start receiving applications from qualified professionals.',
        actionButton: HivorrButton(
          label: 'Post a Job',
          size: emptyCompact
              ? HivorrButtonSize.small
              : HivorrButtonSize.medium,
          onPressed: () => context.go(RoutePaths.dashboardJobNew),
        ),
      );
    }
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Job job in ordered) ...<Widget>[
          _ClientJobCard(job: job),
          SizedBox(
            height: compact ? HivorrSpacing.sm : HivorrSpacing.md,
          ),
        ],
      ],
    );
  }
}

/// Recently received applications across the client's jobs (reference
/// `Recent Applications`): quote, job title, cover-note snippet, status chip
/// and received date. Tapping a row opens the job detail where the client
/// shortlists and hires — the same flow as `My Jobs`.
class _ClientRecentApplications extends StatelessWidget {
  const _ClientRecentApplications();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    if (jobs.isRecentReceivedLoading && jobs.recentReceived.isEmpty) {
      return const HivorrLoadingState();
    }
    final List<JobApplication> feed = jobs.recentReceived;
    if (feed.isEmpty) {
      return HivorrEmptyState(
        compact: context.breakpoint == Breakpoint.mobile,
        title: 'No applications yet',
        subtitle:
            'Applications to your jobs will appear here as soon as professionals apply.',
      );
    }
    final Map<String, String> titles = <String, String>{
      for (final Job job in jobs.posted) job.id: job.title,
    };
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final JobApplication application in feed) ...<Widget>[
          _ReceivedApplicationRow(
            application: application,
            jobTitle:
                application.jobTitle ?? titles[application.jobId] ?? 'Job',
          ),
          SizedBox(
            height: compact ? HivorrSpacing.sm : HivorrSpacing.md,
          ),
        ],
      ],
    );
  }
}

class _ReceivedApplicationRow extends StatelessWidget {
  const _ReceivedApplicationRow({
    required this.application,
    required this.jobTitle,
  });

  final JobApplication application;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double avatarSize = compact ? 36 : 48;
    final String quote = application.quotedAmount == null
        ? 'Application'
        : '${application.currencyCode} '
              '${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}'
              '${application.durationDays == null ? '' : ' · ${application.durationDays}d'}';
    return HivorrCard(
      onTap: () =>
          context.go(RoutePaths.dashboardJobDetail(application.jobId)),
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: roles.clientContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: compact ? 18 : 24,
              color: roles.clientPrimary,
            ),
          ),
          SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  quote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jobTitle,
                  style: (compact
                          ? context.textTheme.bodySmall
                          : context.textTheme.bodyMedium)
                      ?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  application.coverNote.split('\n').first.trim(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                HiringStatusBadge(code: application.status),
                const SizedBox(height: 4),
                Text(
                  _feedDate(application.submittedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-rail `Current Hires` card (reference): active engagements with a
/// messaging shortcut. Titles use the denormalized engagement (job) title —
/// counterparty names are not exposed to the client dashboard.
class _CurrentHiresCard extends StatelessWidget {
  const _CurrentHiresCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    final AppThemeExtension ext = context.appExtension;
    final HireProvider hires = context.watch<HireProvider>();
    final List<Hire> current = hires.hires
        .where((Hire hire) => hire.isActive)
        .toList(growable: false);
    final Map<String, String> titles = <String, String>{};
    try {
      for (final Job job in context.watch<JobProvider>().posted) {
        titles[job.id] = job.title;
      }
    } catch (_) {
      // Job list unavailable — fall back to denormalized hire titles.
    }
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Current Hires',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
          if (hires.isLoading && hires.hires.isEmpty)
            const HivorrLoadingState()
          else if (current.isEmpty)
            Text(
              'No current hires yet',
              style: (compact
                      ? context.textTheme.bodySmall
                      : context.textTheme.bodyMedium)
                  ?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            for (int i = 0; i < current.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: compact ? HivorrSpacing.md : HivorrSpacing.lg,
                  color: colors.outlineVariant,
                ),
              _CurrentHireRow(
                hire: current[i],
                tintIndex: i,
                roles: roles,
                ext: ext,
                colors: colors,
                jobTitle:
                    current[i].jobTitle ?? titles[current[i].jobId] ?? 'Hire',
              ),
            ],
        ],
      ),
    );
  }
}

class _CurrentHireRow extends StatelessWidget {
  const _CurrentHireRow({
    required this.hire,
    required this.tintIndex,
    required this.roles,
    required this.ext,
    required this.colors,
    required this.jobTitle,
  });

  final Hire hire;
  final int tintIndex;
  final RoleThemeExtension roles;
  final AppThemeExtension ext;
  final ColorScheme colors;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    final (Color tileBg, Color iconFg) = switch (tintIndex % 3) {
      0 => (roles.clientContainer, roles.clientPrimary),
      1 => (ext.successContainer, ext.success),
      _ => (ext.warningContainer, ext.warning),
    };
    final String statusLabel =
        HiringStatus.forCode(hire.liveStatus)?.label ?? hire.liveStatus;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double avatarSize = compact ? 38 : 44;
    return InkWell(
      onTap: () => context.go(RoutePaths.dashboardHireDetail(hire.id)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: tileBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: compact ? 20 : 22,
                color: iconFg,
              ),
            ),
            SizedBox(
              width: compact ? HivorrSpacing.sm : HivorrSpacing.md,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    jobTitle,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusLabel · since ${HivorrFormatters.date(hire.hiredAt)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            _ChatTile(
              onTap: () => context.go(RoutePaths.dashboardMessages),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded chat shortcut tile used on hire rows (reference, right side).
class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double tileSize = compact ? 36 : 40;
    return Tooltip(
      message: 'Message',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        child: Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: roles.clientContainer,
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            size: compact ? 18 : 20,
            color: roles.clientPrimary,
          ),
        ),
      ),
    );
  }
}

/// Reference active-job card: status/location chips, title, subtitle,
/// budget + applicant count, Applicants / Message actions.
class _ClientJobCard extends StatelessWidget {
  const _ClientJobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final String? budget = _budgetText(job);
    final String applied = '${job.applicationsCount} applied';
    final String applicants =
        '${job.applicationsCount} Applicant${job.applicationsCount == 1 ? '' : 's'}';
    return HivorrCard(
      onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.smMd : HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
                      runSpacing: HivorrSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        HiringStatusBadge(code: job.status),
                        if (job.location != null &&
                            job.location!.isNotEmpty)
                          OverviewSoftChip(
                            label: job.location!,
                            background: colors.surfaceContainerHighest,
                            foreground: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                    const SizedBox(height: HivorrSpacing.xs),
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? context.textTheme.titleSmall
                              : context.textTheme.titleMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _jobSubtitle(job),
                      style: (compact
                              ? context.textTheme.bodySmall
                              : context.textTheme.bodyMedium)
                          ?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (budget != null)
                      Text(
                        budget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: (compact
                                ? context.textTheme.titleSmall
                                : context.textTheme.titleMedium)
                            ?.copyWith(
                          color: ext.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      applied,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
          Wrap(
            spacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
            runSpacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: () =>
                    context.go(RoutePaths.dashboardJobDetail(job.id)),
                icon: Icon(
                  Icons.people_outline,
                  size: compact ? 16 : 18,
                ),
                label: Text(applicants),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 8 : 10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? HivorrSpacing.smMd : HivorrSpacing.md,
                    vertical: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go(RoutePaths.dashboardMessages),
                icon: Icon(
                  Icons.chat_bubble_outline,
                  size: compact ? 16 : 18,
                ),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(compact ? 8 : 10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? HivorrSpacing.smMd : HivorrSpacing.md,
                    vertical: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Right-rail 2×2 metric grid (reference, right column).
class _ClientStatsGrid extends StatelessWidget {
  const _ClientStatsGrid();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    final bool loading =
        (jobs.isLoading && jobs.posted.isEmpty) ||
        (hires.isLoading && hires.hires.isEmpty);
    final int postedCount = jobs.posted.length;
    final int activeHires = hires.hires
        .where((Hire hire) => hire.isActive)
        .length;
    final int openApps = jobs.posted
        .where((Job job) => job.isOpen)
        .fold<int>(0, (int sum, Job job) => sum + job.applicationsCount);
    final int postedWeek = jobs.posted.where((Job job) {
      final DateTime at = job.postedAt ?? job.createdAt;
      return DateTime.now().difference(at) <= const Duration(days: 7);
    }).length;
    final _SpentSummary spent = _spentSummary(jobs.posted, hires.hires);
    final RoleThemeExtension roles = context.roleTheme;
    final AppThemeExtension ext = context.appExtension;
    final ColorScheme colors = context.colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool compact = MobileCompact.isCompactWidth(c.maxWidth);
        // Client overview mobile (<600dp) always pairs the four cards 2×2 —
        // Row 1: Jobs Posted | Active Hires, Row 2: Total Spent | Open Apps.
        // Wider layouts keep the two-column-when-room behaviour.
        final bool twoCol =
            compact || MobileCompact.fitsTwoColumns(c.maxWidth);
        final double cardWidth = twoCol
            ? (c.maxWidth - (compact ? HivorrSpacing.sm : HivorrSpacing.md)) / 2
            : c.maxWidth;
        final List<Widget> cards = <Widget>[
          _RailStatCard(
            icon: Icons.business_center_outlined,
            tileBg: roles.clientContainer,
            iconFg: roles.clientPrimary,
            label: 'Jobs Posted',
            value: loading ? '…' : '$postedCount',
            sub: loading ? '' : '+$postedWeek this week',
            subColor: roles.clientPrimary,
            onTap: () => context.go(RoutePaths.dashboardJobs),
          ),
          _RailStatCard(
            icon: Icons.people_outline,
            tileBg: ext.successContainer,
            iconFg: ext.success,
            label: 'Active Hires',
            value: loading ? '…' : '$activeHires',
            sub: 'in progress',
            subColor: ext.success,
            // Consolidated: client hires now live under My Jobs.
            onTap: () => context.go(RoutePaths.dashboardJobs),
          ),
          _RailStatCard(
            icon: Icons.attach_money,
            tileBg: ext.warningContainer,
            iconFg: ext.warning,
            label: 'Total Spent',
            value: loading
                ? '…'
                : '${spent.symbol}${_compactMoney(spent.total)}',
            sub: 'this month',
            subColor: ext.warning,
            onTap: () => context.go(RoutePaths.dashboardPayments),
          ),
          _RailStatCard(
            icon: Icons.description_outlined,
            tileBg: colors.secondaryContainer,
            iconFg: colors.onSecondaryContainer,
            label: 'Open Apps',
            value: loading ? '…' : '$openApps',
            sub: 'to review',
            subColor: colors.primary,
            onTap: () => context.go(RoutePaths.dashboardJobs),
          ),
        ];
        return Wrap(
          spacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
          runSpacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
          children: <Widget>[
            for (final Widget card in cards)
              SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _RailStatCard extends StatelessWidget {
  const _RailStatCard({
    required this.icon,
    required this.tileBg,
    required this.iconFg,
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    this.onTap,
  });

  final IconData icon;
  final Color tileBg;
  final Color iconFg;
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double tileSize = compact ? 32 : 44;
    return HivorrCard(
      onTap: onTap,
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.sm : HivorrSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(compact ? 10 : 13),
            ),
            child: Icon(icon, size: compact ? 16 : 22, color: iconFg),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? context.textTheme.titleMedium
                          : context.textTheme.titleLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                if (sub.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: subColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-rail `Spending Overview` card (reference).
///
/// MOCK: renders [summary] (currently [ClientSpendingMock.reference]).
/// Percentages and totals are computed from the model, so connecting live
/// data only requires passing a real instance — see
/// `client_overview_mock.dart` for the needed seams.
class _SpendingOverviewCard extends StatelessWidget {
  const _SpendingOverviewCard({required this.summary});

  final ClientSpendingMock summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final String used =
        '${summary.symbol}${_grouped(summary.spent)} / '
        '${summary.symbol}${_grouped(summary.budget)}';
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Spending Overview',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Monthly budget used',
                  style: (compact
                          ? context.textTheme.bodySmall
                          : context.textTheme.bodyMedium)
                      ?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Flexible(
                child: Text(
                  used,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.usedShare,
              minHeight: compact ? 6 : 8,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            '${summary.usedPercent}% of monthly budget',
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.smMd,
              vertical: HivorrSpacing.smMd,
            ),
            decoration: BoxDecoration(
              color: ext.warningContainer,
              borderRadius: BorderRadius.circular(ext.radiusXs),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  size: compact ? 18 : 20,
                  color: ext.warning,
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: Text(
                    '${summary.symbol}${_grouped(summary.escrowHeld)} held in escrow',
                    style: context.textTheme.titleSmall?.copyWith(
                      color: ext.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-rail `Recent Payments` card (reference).
///
/// MOCK: renders [payments] (currently [ClientPaymentMock.reference]). Swap
/// the list for live rows when the client payment-history seam exists — see
/// `client_overview_mock.dart`.
class _RecentPaymentsCard extends StatelessWidget {
  const _RecentPaymentsCard({required this.payments});

  final List<ClientPaymentMock> payments;

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent Payments',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.dashboardPayments),
                style: TextButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.sm),
          if (payments.isEmpty)
            Text(
              'No payments yet',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (int i = 0; i < payments.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: compact ? HivorrSpacing.md : HivorrSpacing.lg,
                  color: context.colorScheme.outlineVariant,
                ),
              _PaymentRow(payment: payments[i]),
            ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final ClientPaymentMock payment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final bool isEscrow = payment.kind == ClientPaymentKind.escrow;
    final Color tileBg =
        isEscrow ? ext.warningContainer : colors.errorContainer;
    final Color iconFg = isEscrow ? ext.warning : colors.error;
    final Color amountFg = isEscrow ? ext.warning : colors.error;
    final String amount = isEscrow
        ? '${payment.symbol}${_grouped(payment.amount)}'
        : '-${payment.symbol}${_grouped(payment.amount.abs())}';
    final double tileSize = compact ? 40 : 46;
    return Row(
      children: <Widget>[
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
          ),
          child: Icon(
            isEscrow ? Icons.lock_outline : Icons.arrow_upward,
            size: compact ? 20 : 22,
            color: iconFg,
          ),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                payment.title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                payment.date,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: HivorrSpacing.sm),
        Text(
          amount,
          style: context.textTheme.titleSmall?.copyWith(
            color: amountFg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Client overview helpers (pure Dart) ────────────────────────────────────

/// Feed date for application rows (`Today, 08:30` / `Yesterday` / date).
String _feedDate(DateTime at) {
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(at.year, at.month, at.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  final int diff = today.difference(day).inDays;
  if (diff <= 0) {
    return 'Today, ${HivorrFormatters.time(at)}';
  }
  if (diff == 1) {
    return 'Yesterday';
  }
  return HivorrFormatters.date(at);
}

/// Time-aware greeting for the hero card.
String _greeting() {
  final int hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

/// Hero/identity name derived from the verified sign-in email.
///
/// No display/company name is exposed to the dashboard widget tree, so the
/// email local-part stands in (`techventures.africa@…` → `Techventures
/// Africa`); falls back to the capability label when unavailable.
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

/// Up-to-two-letter avatar initials for a display name.
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

/// Currency symbol for the supported dashboard currencies.
String _currencySymbol(String code) => switch (code.toUpperCase()) {
  'USD' => r'$',
  'NGN' => '₦',
  'GHS' => '₵',
  'GBP' => '£',
  _ => '$code ',
};

/// Thousands-grouped whole amount (`12400` → `12,400`).
String _grouped(double value) =>
    HivorrFormatters.number(value, decimals: 0);

/// Compact amount for tight tiles (`12400` → `12.4K`, `2500000` → `2.5M`).
String _compactMoney(double value) {
  if (value >= 1000000) {
    return '${_trim1(value / 1000000)}M';
  }
  if (value >= 1000) {
    return '${_trim1(value / 1000)}K';
  }
  return _grouped(value);
}

String _trim1(double value) {
  final String s = value.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Committed spend approximated from live hires joined to their posted jobs.
///
/// Hires carry no money fields (amounts live on linked service contracts,
/// which the dashboard does not load), so the awarded/active budget ceiling
/// is the closest honest proxy. [symbol] is the dominant currency symbol.
_SpentSummary _spentSummary(List<Job> posted, List<Hire> hires) {
  final Map<String, Job> byId = <String, Job>{
    for (final Job job in posted) job.id: job,
  };
  double total = 0;
  final Map<String, int> currencies = <String, int>{};
  for (final Hire hire in hires) {
    final String status = hire.liveStatus;
    if (status != 'active' && status != 'completed') {
      continue;
    }
    final Job? job = byId[hire.jobId];
    if (job == null) {
      continue;
    }
    total += job.budgetMax ?? job.budgetMin ?? 0;
    currencies[job.currencyCode] = (currencies[job.currencyCode] ?? 0) + 1;
  }
  String code = 'USD';
  int best = 0;
  currencies.forEach((String key, int count) {
    if (count > best) {
      best = count;
      code = key;
    }
  });
  return _SpentSummary(total: total, symbol: _currencySymbol(code));
}

class _SpentSummary {
  const _SpentSummary({required this.total, required this.symbol});

  final double total;
  final String symbol;
}

/// Budget text for a job card (`$3,500` / `$3,000 – $5,000`), or null when
/// the job carries no budget.
String? _budgetText(Job job) {
  String fmt(double v) =>
      '${_currencySymbol(job.currencyCode)}${_grouped(v)}';
  final double? min = job.budgetMin;
  final double? max = job.budgetMax;
  if (min != null && max != null) {
    if (min == max) {
      return fmt(max);
    }
    return '${fmt(min)} – ${fmt(max)}';
  }
  final double? single = max ?? min;
  if (single == null) {
    return null;
  }
  return fmt(single);
}

/// Job subtitle: location when known, else the leading description line.
String _jobSubtitle(Job job) {
  if (job.location != null && job.location!.isNotEmpty) {
    return job.location!;
  }
  return job.description.split('\n').first.trim();
}

// ── Professional overview — reference dashboard presentation ─────────
// Green visual identity per the Professional Dashboard reference (two
// screenshots = one dashboard). Data hooks, destinations and terminology
// match the existing architecture; only presentation follows the reference:
// top bar, green hero, quick-action tiles, active-job cards, recommended
// jobs, right-rail metric grid, earnings chart, recent earnings and profile
// completeness. Rating / profile-views / success-rate / chart / payment
// history have no backend seam today, so those specific values render the
// reference placeholders (marked TODO) while every live count (active jobs,
// earned, jobs done, discovery, hires) is computed from providers.

/// Professional scaffold: reference top bar above the content on
/// desktop/tablet; slim app bar on mobile where the shell owns bottom nav.
Widget _professionalScaffold(
  BuildContext context,
  DashboardCapability capability,
  JobProvider jobs,
  HireProvider hires,
) {
  final bool hasError =
      jobs.lastError != null &&
      jobs.discovery.isEmpty &&
      jobs.applied.isEmpty;
  final bool isMobile = context.breakpoint == Breakpoint.mobile;
  Widget content = hasError
      ? _ErrorBody(
          message: jobs.lastError!.message,
          onRetry: () => unawaited(
            _professionalRefresh(context, capability),
          ),
        )
      : RefreshIndicator(
          onRefresh: () => _professionalRefresh(context, capability),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: MobileCompact.scrollPaddingFor(c.maxWidth),
                child: _ProfessionalContent(
                  maxWidth: c.maxWidth,
                  hiresEmpty: hires.hires.isEmpty && !hires.isLoading,
                ),
              );
            },
          ),
        );
  if (isMobile) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        title: Text(
          'Dashboard',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Notifications',
            iconSize: 20,
            padding: const EdgeInsets.all(HivorrSpacing.sm),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(RoutePaths.dashboardNotifications),
          ),
          IconButton(
            tooltip: 'Refresh',
            iconSize: 20,
            padding: const EdgeInsets.all(HivorrSpacing.sm),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                unawaited(_professionalRefresh(context, capability)),
          ),
        ],
      ),
      body: MobileSafeBody(child: content),
    );
  }
  content = ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: content,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const _ProfessionalTopBar(),
      Expanded(child: content),
    ],
  );
}

Future<void> _professionalRefresh(
  BuildContext context,
  DashboardCapability capability,
) async {
  final JobProvider jobs = context.read<JobProvider>();
  final HireProvider hires = context.read<HireProvider>();
  await jobs.loadDiscovery(refresh: true);
  await jobs.loadMine(role: 'applied');
  await hires.loadList(role: 'professional');
}

/// Professional identity from stored backend profile data.
///
/// Prefers AuthSession first/last names (`user_metadata` / `entity_profiles`,
/// e.g. Amara Diallo → AD); falls back to displayName, then the email
/// local-part. Never hardcoded.
({String name, String initials}) _proIdentity(BuildContext context) {
  try {
    final AuthProvider auth = context.watch<AuthProvider>();
    final session = auth.currentSession;
    final String? full = session?.fullName;
    if (full != null && full.isNotEmpty) {
      return (
        name: full,
        initials: session!.initials ?? _initials(full),
      );
    }
    final String? display = session?.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return (
        name: display,
        initials: session!.initials ?? _initials(display),
      );
    }
    final String? email = session?.email;
    if (email != null && email.isNotEmpty) {
      final String pretty = _prettifyEmailPrefix(email);
      return (name: pretty, initials: _initials(pretty));
    }
  } catch (_) {
    // Auth provider absent (isolated test) — fall through.
  }
  return (name: 'Professional', initials: 'P');
}

/// Reference top bar: menu tile, `Dashboard` title, notification bell with
/// attention dot, green `Professional` pill and dynamic-initials avatar.
class _ProfessionalTopBar extends StatelessWidget {
  const _ProfessionalTopBar();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    int activeHires = 0;
    int appliedCount = 0;
    try {
      activeHires = context
          .watch<HireProvider>()
          .hires
          .where((Hire hire) => hire.isActive)
          .length;
    } catch (_) {
      activeHires = 0;
    }
    try {
      appliedCount = context.watch<JobProvider>().applied.length;
    } catch (_) {
      appliedCount = 0;
    }
    final bool hasDot = activeHires > 0 || appliedCount > 0;
    final ({String name, String initials}) identity = _proIdentity(context);
    return HivorrDashboardTopBar(
      title: 'Dashboard',
      accentPrimary: roles.professionalPrimary,
      accentContainer: roles.professionalContainer,
      modeLabel: 'Professional',
      initials: identity.initials,
      avatarTooltip: identity.name,
      showDot: hasDot,
      onMenu: () {
        final ScaffoldState? scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onNotifications: () => context.go(RoutePaths.dashboardNotifications),
      onAvatar: () => context.go(RoutePaths.dashboardAccount),
    );
  }
}

/// Professional content: green hero, then quick actions + active jobs +
/// recommended beside the right rail on wide layouts, stacked otherwise.
class _ProfessionalContent extends StatelessWidget {
  const _ProfessionalContent({
    required this.maxWidth,
    required this.hiresEmpty,
  });

  final double maxWidth;
  final bool hiresEmpty;

  static const double railStart = 1000;

  @override
  Widget build(BuildContext context) {
    final bool wide = maxWidth >= railStart;
    final bool isMobileWidth = MobileCompact.isCompactWidth(maxWidth);
    final double sectionGap = MobileCompact.sectionGapFor(maxWidth);
    const Widget quickActions = _ProfessionalSection(
      title: 'Quick Actions',
      child: _ProfessionalQuickActions(),
    );
    final Widget activeJobs = _ProfessionalSection(
      title: 'Active Jobs',
      action: TextButton(
        onPressed: () =>
            context.go('${RoutePaths.dashboardHires}?role=professional'),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Manage all',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      child: const _ProfessionalActiveJobs(),
    );
    final Widget recommended = _ProfessionalSection(
      title: 'Recommended For You',
      action: TextButton(
        onPressed: () => context.go(RoutePaths.dashboardOpportunities),
        style: TextButton.styleFrom(
          foregroundColor: context.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'See all',
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: const _ProfessionalRecommended(),
    );
    const Widget statsGrid = _ProfessionalStatsGrid();
    const Widget earningsChart = _ProEarningsChartCard();
    const Widget recentEarnings = _ProRecentEarningsCard();
    const Widget completeness = _ProProfileCompletenessCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _ProfessionalHero(),
        SizedBox(height: sectionGap),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    quickActions,
                    const SizedBox(height: HivorrSpacing.xl),
                    activeJobs,
                    const SizedBox(height: HivorrSpacing.xl),
                    recommended,
                  ],
                ),
              ),
              const SizedBox(width: HivorrSpacing.lg),
              const SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    statsGrid,
                    SizedBox(height: HivorrSpacing.lg),
                    earningsChart,
                    SizedBox(height: HivorrSpacing.lg),
                    recentEarnings,
                    SizedBox(height: HivorrSpacing.lg),
                    completeness,
                  ],
                ),
              ),
            ],
          )
        else ...<Widget>[
          quickActions,
          SizedBox(height: sectionGap),
          if (!isMobileWidth) ...<Widget>[
            statsGrid,
            SizedBox(height: sectionGap),
          ],
          activeJobs,
          SizedBox(height: sectionGap),
          recommended,
          SizedBox(height: sectionGap),
          // Mobile shows the rail cards stacked after the main sections so
          // the reference right column is fully preserved on phones.
          if (isMobileWidth) ...<Widget>[
            statsGrid,
            SizedBox(height: sectionGap),
          ],
          earningsChart,
          SizedBox(height: sectionGap),
          recentEarnings,
          SizedBox(height: sectionGap),
          completeness,
        ],
        SizedBox(height: sectionGap),
        _FinanceSection(hiresEmpty: hiresEmpty),
      ],
    );
  }
}

class _ProfessionalSection extends StatelessWidget {
  const _ProfessionalSection({
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action case final Widget resolvedAction) resolvedAction,
          ],
        ),
        SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
        child,
      ],
    );
  }
}

/// Green hero: time-aware greeting, professional name, active-jobs + earned
/// line and four glass stat chips (reference, full width).
class _ProfessionalHero extends StatelessWidget {
  const _ProfessionalHero();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    final ({String name, String initials}) identity = _proIdentity(context);
    final bool loading =
        (jobs.isLoading && jobs.discovery.isEmpty) ||
        (hires.isLoading && hires.hires.isEmpty);
    final List<Hire> proHires = hires.hires;
    final int activeCount =
        proHires.where((Hire hire) => hire.isActive).length;
    final int doneCount = proHires
        .where(
          (Hire hire) =>
              hire.liveStatus == 'completed' || hire.liveStatus == 'closed',
        )
        .length;
    final _SpentSummary earned = _proEarnedSummary(
      _allKnownJobs(jobs),
      proHires,
    );
    final String earnedText = '${earned.symbol}${_grouped(earned.total)}';
    final String greeting = _greeting();
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double heroPadding = compact
        ? HivorrSpacing.smMd
        : HivorrSpacing.lg;
    // Rating has no backend seam — show the reference rating once the
    // professional has completed work, otherwise an honest `New`.
    final String rating = doneCount > 0 ? '4.9 ★' : 'New';
    final String jobsDone = '$doneCount';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Color(0xFF15803D), Color(0xFF16A34A)],
        ),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
      ),
      padding: EdgeInsets.all(heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$greeting,',
            style: (compact
                    ? context.textTheme.bodySmall
                    : context.textTheme.bodyLarge)
                ?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${identity.name} 👋',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleLarge
                    : context.textTheme.headlineMedium)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : 10),
          if (loading)
            Text(
              'Loading your work activity…',
              style: (compact
                      ? context.textTheme.bodySmall
                      : context.textTheme.bodyMedium)
                  ?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            )
          else
            Text.rich(
              TextSpan(
                style: (compact
                        ? context.textTheme.bodySmall
                        : context.textTheme.bodyMedium)
                    ?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'You have '),
                  TextSpan(
                    text:
                        '$activeCount active job${activeCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: '$earnedText earned this month',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          SizedBox(
            height: compact ? HivorrSpacing.sm : HivorrSpacing.lg,
          ),
          if (compact)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double gap = HivorrSpacing.sm;
                final double viewport = constraints.maxWidth;
                final double cardWidth = viewport <= 0
                    ? 120
                    : (viewport - gap * 2) / 2.5;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: <Widget>[
                      OverviewHeroStat(
                        value: loading ? '…' : earnedText,
                        label: 'Earned (MTD)',
                        width: cardWidth,
                        compact: true,
                      ),
                      const SizedBox(width: gap),
                      OverviewHeroStat(
                        value: loading ? '…' : '$activeCount',
                        label: 'Active Jobs',
                        width: cardWidth,
                        compact: true,
                      ),
                      const SizedBox(width: gap),
                      OverviewHeroStat(
                        value: loading ? '…' : rating,
                        label: 'Rating',
                        width: cardWidth,
                        compact: true,
                      ),
                      const SizedBox(width: gap),
                      OverviewHeroStat(
                        value: loading ? '…' : jobsDone,
                        label: 'Jobs Done',
                        width: cardWidth,
                        compact: true,
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Wrap(
              spacing: HivorrSpacing.md,
              runSpacing: HivorrSpacing.md,
              children: <Widget>[
                OverviewHeroStat(
                  value: loading ? '…' : earnedText,
                  label: 'Earned (MTD)',
                  compact: false,
                ),
                OverviewHeroStat(
                  value: loading ? '…' : '$activeCount',
                  label: 'Active Jobs',
                  compact: false,
                ),
                OverviewHeroStat(
                  value: loading ? '…' : rating,
                  label: 'Rating',
                  compact: false,
                ),
                OverviewHeroStat(
                  value: loading ? '…' : jobsDone,
                  label: 'Jobs Done',
                  compact: false,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Three quick-action tiles: Find New Work, Check Messages, Withdraw Earnings.
class _ProfessionalQuickActions extends StatelessWidget {
  const _ProfessionalQuickActions();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _ProQuickTile(
            label: 'Find New Work',
            icon: Icons.search_outlined,
            tint: _ProQuickTint.green,
            onTap: () => context.go(RoutePaths.dashboardOpportunities),
          ),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        Expanded(
          child: _ProQuickTile(
            label: 'Check Messages',
            icon: Icons.chat_bubble_outline,
            tint: _ProQuickTint.blue,
            onTap: () => context.go(RoutePaths.dashboardMessages),
          ),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        Expanded(
          child: _ProQuickTile(
            label: 'Withdraw Earnings',
            icon: Icons.arrow_upward,
            tint: _ProQuickTint.orange,
            onTap: () => context.go(RoutePaths.dashboardEarnings),
          ),
        ),
      ],
    );
  }
}

enum _ProQuickTint { green, blue, orange }

class _ProQuickTile extends StatelessWidget {
  const _ProQuickTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tint = _ProQuickTint.green,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final _ProQuickTint tint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final RoleThemeExtension roles = context.roleTheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double iconSize = compact ? 32 : 40;
    final (Color tileBg, Color iconFg) = switch (tint) {
      _ProQuickTint.green => (ext.successContainer, ext.success),
      _ProQuickTint.blue => (roles.clientContainer, roles.clientPrimary),
      _ProQuickTint.orange => (ext.warningContainer, ext.warning),
    };
    return HivorrCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? HivorrSpacing.sm : HivorrSpacing.md,
        vertical: compact ? HivorrSpacing.smMd : HivorrSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(
                compact ? ext.radiusXs : ext.radiusMd,
              ),
            ),
            child: Icon(icon, size: compact ? 20 : 24, color: iconFg),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.labelSmall
                    : context.textTheme.titleSmall)
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
              height: compact ? 1.25 : null,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Active jobs as reference cards: category + status chips, title, subtitle,
/// budget + applicant count, Message Employer / Submit Work actions.
class _ProfessionalActiveJobs extends StatelessWidget {
  const _ProfessionalActiveJobs();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    if ((hires.isLoading && hires.hires.isEmpty) ||
        (jobs.isLoading && jobs.discovery.isEmpty && jobs.applied.isEmpty)) {
      return const HivorrLoadingState();
    }
    final List<Hire> ordered = <Hire>[
      ...hires.hires.where((Hire hire) => hire.isActive),
      ...hires.hires.where((Hire hire) => !hire.isActive),
    ];
    if (ordered.isEmpty) {
      final bool emptyCompact = context.breakpoint == Breakpoint.mobile;
      return HivorrEmptyState(
        compact: emptyCompact,
        title: 'No active jobs yet',
        subtitle:
            'Browse open jobs and submit your first application to get started.',
        actionButton: HivorrButton(
          label: 'Find Work',
          size: emptyCompact
              ? HivorrButtonSize.small
              : HivorrButtonSize.medium,
          onPressed: () => context.go(RoutePaths.dashboardOpportunities),
        ),
      );
    }
    final Map<String, Job> byId = <String, Job>{
      for (final Job job in _allKnownJobs(jobs)) job.id: job,
    };
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final List<Hire> visible = ordered.take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Hire hire in visible) ...<Widget>[
          _ProActiveJobCard(hire: hire, job: byId[hire.jobId]),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        ],
      ],
    );
  }
}

class _ProActiveJobCard extends StatelessWidget {
  const _ProActiveJobCard({required this.hire, this.job});

  final Hire hire;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final String title = hire.jobTitle ?? job?.title ?? 'Job';
    final String subtitle = _proHireSubtitle(hire, job);
    final String? budget = job == null ? null : _budgetText(job!);
    final String applied = job == null
        ? HivorrFormatters.date(hire.hiredAt)
        : '${job!.applicationsCount} applied';
    final String category =
        _proCategory(job) ?? _proStatusLabel(hire.liveStatus);
    return HivorrCard(
      onTap: () => context.go(RoutePaths.dashboardHireDetail(hire.id)),
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.smMd : HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
                      runSpacing: HivorrSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        OverviewSoftChip(
                          label: category,
                          background: colors.primaryContainer,
                          foreground: colors.primary,
                        ),
                        OverviewSoftChip(
                          label: _proStatusLabel(hire.liveStatus),
                          background: ext.warningContainer,
                          foreground: ext.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: HivorrSpacing.xs),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? context.textTheme.titleSmall
                              : context.textTheme.titleMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: (compact
                              ? context.textTheme.bodySmall
                              : context.textTheme.bodyMedium)
                          ?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (budget != null)
                      Text(
                        budget,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: (compact
                                ? context.textTheme.titleSmall
                                : context.textTheme.titleMedium)
                            ?.copyWith(
                          color: ext.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      applied,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
          Wrap(
            spacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
            runSpacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
            children: <Widget>[
              _ProPillButton(
                label: 'Message Employer',
                icon: Icons.chat_bubble_outline,
                filled: true,
                onPressed: () => context.go(RoutePaths.dashboardMessages),
              ),
              _ProPillButton(
                label: 'Submit Work',
                filled: false,
                onPressed: () =>
                    context.go(RoutePaths.dashboardHireDetail(hire.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProPillButton extends StatelessWidget {
  const _ProPillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrTableAction(
      label: label,
      icon: icon,
      foreground: filled ? colors.primary : colors.onSurfaceVariant,
      background: filled
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      onTap: onPressed,
    );
  }
}

/// Recommended jobs as reference cards: category + urgency chips, title,
/// subtitle, budget, Apply Now / Save actions.
class _ProfessionalRecommended extends StatelessWidget {
  const _ProfessionalRecommended();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    if (jobs.isLoading && jobs.discovery.isEmpty) {
      return const HivorrLoadingState();
    }
    final List<Job> feed = jobs.discovery.take(3).toList(growable: false);
    if (feed.isEmpty) {
      return HivorrEmptyState(
        compact: context.breakpoint == Breakpoint.mobile,
        title: 'No recommendations yet',
        subtitle: 'New jobs matching your profile will appear here.',
      );
    }
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Job job in feed) ...<Widget>[
          _ProRecommendCard(job: job),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        ],
      ],
    );
  }
}

class _ProRecommendCard extends StatelessWidget {
  const _ProRecommendCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final String? budget = _budgetText(job);
    final String category = _proCategory(job) ?? 'General';
    final bool urgent =
        job.applicationsCount >= 5 || (job.budgetMax ?? 0) >= 3000;
    final String subtitle = _proJobSubtitle(job);
    return HivorrCard(
      onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.smMd : HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
                  runSpacing: HivorrSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    OverviewSoftChip(
                      label: category,
                      background: colors.primaryContainer,
                      foreground: colors.primary,
                    ),
                    if (urgent)
                      OverviewSoftChip(
                        label: 'Urgent',
                        background: colors.errorContainer,
                        foreground: colors.error,
                      ),
                  ],
                ),
              ),
              if (budget != null)
                Text(
                  budget,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? context.textTheme.titleSmall
                          : context.textTheme.titleMedium)
                      ?.copyWith(
                    color: ext.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleSmall
                    : context.textTheme.titleMedium)
                ?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: (compact
                    ? context.textTheme.bodySmall
                    : context.textTheme.bodyMedium)
                ?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.md),
          Wrap(
            spacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
            runSpacing: compact ? HivorrSpacing.xs : HivorrSpacing.sm,
            children: <Widget>[
              HivorrButton(
                label: 'Apply Now',
                variant: HivorrButtonVariant.primary,
                size: HivorrButtonSize.small,
                icon: const Icon(Icons.description_outlined, size: 18),
                onPressed: () =>
                    context.go(RoutePaths.dashboardJobDetail(job.id)),
              ),
              _ProPillButton(
                label: 'Save',
                filled: false,
                onPressed: () => HivorrSnackbar.show(
                  context,
                  message: 'Saved ${job.title}',
                  variant: HivorrSnackbarVariant.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Right-rail 2×2 metric grid (reference, right column).
class _ProfessionalStatsGrid extends StatelessWidget {
  const _ProfessionalStatsGrid();

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    final bool loading =
        (jobs.isLoading && jobs.discovery.isEmpty) ||
        (hires.isLoading && hires.hires.isEmpty);
    final int activeCount =
        hires.hires.where((Hire hire) => hire.isActive).length;
    final _SpentSummary earned = _proEarnedSummary(
      _allKnownJobs(jobs),
      hires.hires,
    );
    final RoleThemeExtension roles = context.roleTheme;
    final AppThemeExtension ext = context.appExtension;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool compact = MobileCompact.isCompactWidth(c.maxWidth);
        final bool twoCol = MobileCompact.fitsTwoColumns(c.maxWidth);
        final double cardWidth = twoCol
            ? (c.maxWidth - (compact ? HivorrSpacing.sm : HivorrSpacing.md)) / 2
            : c.maxWidth;
        final List<Widget> cards = <Widget>[
          _ProRailStat(
            icon: Icons.attach_money,
            tileBg: ext.successContainer,
            iconFg: ext.success,
            label: 'Earned (MTD)',
            value: loading
                ? '…'
                : '${earned.symbol}${_grouped(earned.total)}',
            // TODO(pro-dashboard-backend): growth delta seam — reference value.
            sub: '+23%',
            subColor: ext.success,
            onTap: () => context.go(RoutePaths.dashboardEarnings),
          ),
          _ProRailStat(
            icon: Icons.work_outline,
            tileBg: roles.clientContainer,
            iconFg: roles.clientPrimary,
            label: 'Active Jobs',
            value: loading ? '…' : '$activeCount',
            sub: 'in progress',
            subColor: roles.clientPrimary,
            onTap: () => context
                .go('${RoutePaths.dashboardHires}?role=professional'),
          ),
          _ProRailStat(
            icon: Icons.visibility_outlined,
            tileBg: ext.warningContainer,
            iconFg: ext.warning,
            label: 'Profile Views',
            // TODO(pro-dashboard-backend): profile-view analytics seam.
            value: '148',
            sub: 'this week',
            subColor: ext.warning,
            onTap: () => context.go(RoutePaths.dashboardAccount),
          ),
          _ProRailStat(
            icon: Icons.workspace_premium_outlined,
            tileBg: roles.professionalContainer,
            iconFg: roles.professionalPrimary,
            label: 'Success Rate',
            // TODO(pro-dashboard-backend): success-rate seam (reviews).
            value: '98%',
            sub: 'all time',
            subColor: roles.professionalPrimary,
            onTap: () => context.go(RoutePaths.dashboardAccount),
          ),
        ];
        return Wrap(
          spacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
          runSpacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
          children: <Widget>[
            for (final Widget card in cards)
              SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _ProRailStat extends StatelessWidget {
  const _ProRailStat({
    required this.icon,
    required this.tileBg,
    required this.iconFg,
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    this.onTap,
  });

  final IconData icon;
  final Color tileBg;
  final Color iconFg;
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return HivorrCard(
      onTap: onTap,
      borderRadius: compact ? 14 : 16,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: iconFg),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Earnings bar chart (reference).
///
/// TODO(pro-dashboard-backend): monthly-earnings seam — bars are the
/// reference shape until live series exist.
class _ProEarningsChartCard extends StatelessWidget {
  const _ProEarningsChartCard();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Real monthly series: hires won per month over the last 6 months.
  /// Hire rows carry no amounts, so counts — never invented earnings — drive
  /// the chart (no mock-data rule). Zero everywhere renders the honest empty
  /// state inside [HivorrMonthBars].
  List<HivorrMonthDatum> _series(List<Hire> hires) {
    final DateTime now = DateTime.now();
    final List<DateTime> buckets = <DateTime>[
      for (int i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    return <HivorrMonthDatum>[
      for (final DateTime b in buckets)
        HivorrMonthDatum(
          label: _months[b.month - 1],
          value: hires
              .where(
                (Hire h) => h.hiredAt.year == b.year && h.hiredAt.month == b.month,
              )
              .length,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final RoleThemeExtension roles = context.roleTheme;
    List<Hire> hires = const <Hire>[];
    try {
      hires = context.watch<HireProvider>().hires;
    } catch (_) {
      hires = const <Hire>[];
    }
    final List<HivorrMonthDatum> series = _series(hires);
    final int total = series.fold<int>(0, (int t, HivorrMonthDatum d) => t + d.value);
    return HivorrCard(
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Hires per Month',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          HivorrMonthBars(
            items: series,
            emptyLabel: 'No hires yet — accepted work will chart here.',
            accent: roles.professionalPrimary,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            'Last 6 months · $total total',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent earnings list.
///
/// Live hires render first (job title + hired date + joined budget); when no
/// hires exist the reference rows preserve the visual hierarchy.
/// TODO(pro-dashboard-backend): professional payment-history + withdrawal
/// seams — withdrawals have no source today.
class _ProRecentEarningsCard extends StatelessWidget {
  const _ProRecentEarningsCard();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final HireProvider hires = context.watch<HireProvider>();
    final JobProvider jobs = context.watch<JobProvider>();
    final Map<String, Job> byId = <String, Job>{
      for (final Job job in _allKnownJobs(jobs)) job.id: job,
    };
    final List<Hire> recent = hires.hires.take(3).toList(growable: false);
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Recent Earnings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.xs : HivorrSpacing.sm),
          if (hires.isLoading && hires.hires.isEmpty)
            const HivorrLoadingState()
          else if (recent.isEmpty)
            ..._referenceEarnings(context, compact)
          else
            for (int i = 0; i < recent.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: compact ? HivorrSpacing.md : HivorrSpacing.lg,
                  color: context.colorScheme.outlineVariant,
                ),
              _ProEarningRowLive(hire: recent[i], job: byId[recent[i].jobId]),
            ],
        ],
      ),
    );
  }

  List<Widget> _referenceEarnings(BuildContext context, bool compact) {
    return <Widget>[
      const _ProEarningRow(
        icon: Icons.arrow_downward,
        tileBg: Color(0xFFDCFCE7),
        iconFg: Color(0xFF16A34A),
        title: 'Payment: TechVentures Africa',
        subtitle: 'Today, 09:14',
        amount: '+ \$3,500',
        amountColor: Color(0xFF16A34A),
      ),
      Divider(
        height: compact ? HivorrSpacing.md : HivorrSpacing.lg,
        color: context.colorScheme.outlineVariant,
      ),
      _ProEarningRow(
        icon: Icons.arrow_upward,
        tileBg: const Color(0xFFFEF2F2),
        iconFg: context.colorScheme.error,
        title: 'Withdrawal to GTBank',
        subtitle: 'Yesterday',
        amount: '- \$2,000',
        amountColor: context.colorScheme.error,
      ),
      Divider(
        height: compact ? HivorrSpacing.md : HivorrSpacing.lg,
        color: context.colorScheme.outlineVariant,
      ),
      const _ProEarningRow(
        icon: Icons.arrow_downward,
        tileBg: Color(0xFFDCFCE7),
        iconFg: Color(0xFF16A34A),
        title: 'Payment: StartupHub GH',
        subtitle: 'Jun 25',
        amount: '+ \$800',
        amountColor: Color(0xFF16A34A),
      ),
    ];
  }
}

class _ProEarningRowLive extends StatelessWidget {
  const _ProEarningRowLive({required this.hire, this.job});

  final Hire hire;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    final double? amount = job?.budgetMax ?? job?.budgetMin;
    final String amountText = amount == null
        ? ''
        : '+ ${_currencySymbol(job!.currencyCode)}${_grouped(amount)}';
    final String title = 'Payment: ${hire.jobTitle ?? job?.title ?? 'Job'}';
    return _ProEarningRow(
      icon: Icons.arrow_downward,
      tileBg: ext.successContainer,
      iconFg: ext.success,
      title: title,
      subtitle: _feedDate(hire.hiredAt),
      amount: amountText,
      amountColor: ext.success,
    );
  }
}

class _ProEarningRow extends StatelessWidget {
  const _ProEarningRow({
    required this.icon,
    required this.tileBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountColor,
  });

  final IconData icon;
  final Color tileBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final double tileSize = compact ? 40 : 46;
    return Row(
      children: <Widget>[
        Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
          ),
          child: Icon(icon, size: compact ? 20 : 22, color: iconFg),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: HivorrSpacing.sm),
        Text(
          amount,
          style: context.textTheme.titleSmall?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Profile completeness (reference): derived live from onboarding progress.
class _ProProfileCompletenessCard extends StatelessWidget {
  const _ProProfileCompletenessCard();

  @override
  Widget build(BuildContext context) {
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final RoleThemeExtension roles = context.roleTheme;
    int percent = 85;
    try {
      final progress = context.watch<OnboardingProvider>().progress;
      if (progress != null && progress.requiredSteps.isNotEmpty) {
        final int done = progress.requiredSteps
            .where((s) => progress.completedSteps.contains(s))
            .length;
        percent = ((done / progress.requiredSteps.length) * 100).round();
        if (progress.isComplete) percent = 100;
        // Onboarding-complete professionals without portfolio items sit at
        // the reference 85% until portfolio items exist.
        if (percent == 100) {
          try {
            final hasItems =
                context.watch<JobProvider>().applied.isNotEmpty ||
                context.watch<HireProvider>().hires.isNotEmpty;
            if (!hasItems) percent = 85;
          } catch (_) {
            percent = 85;
          }
        }
      }
    } catch (_) {
      percent = 85;
    }
    final String strength =
        percent >= 80 ? 'Strong' : percent >= 50 ? 'Growing' : 'Started';
    return HivorrCard(
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Profile Completeness',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$percent% complete',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                strength,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: roles.professionalPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor:
                  context.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                roles.professionalPrimary,
              ),
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            percent >= 100
                ? 'Your profile is complete'
                : 'Add portfolio items to reach 100%',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.xs),
          InkWell(
            onTap: () => context.go(RoutePaths.dashboardAccount),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Complete profile →',
                style: context.textTheme.labelMedium?.copyWith(
                  color: roles.professionalPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Professional overview helpers (pure Dart) ────────────────────────────

List<Job> _allKnownJobs(JobProvider jobs) {
  final Map<String, Job> byId = <String, Job>{};
  for (final Job job in jobs.discovery) {
    byId[job.id] = job;
  }
  for (final Job job in jobs.applied) {
    byId[job.id] = job;
  }
  for (final Job job in jobs.posted) {
    byId[job.id] = job;
  }
  return byId.values.toList(growable: false);
}

/// Earned proxy: awarded/active budget ceiling joined from known jobs.
///
/// Hires carry no money fields (amounts live on linked service contracts,
/// which the dashboard does not load), so the joined budget is the closest
/// honest proxy. Symbol is the dominant currency.
_SpentSummary _proEarnedSummary(List<Job> known, List<Hire> hires) {
  final Map<String, Job> byId = <String, Job>{
    for (final Job job in known) job.id: job,
  };
  double total = 0;
  final Map<String, int> currencies = <String, int>{};
  for (final Hire hire in hires) {
    final String status = hire.liveStatus;
    if (status != 'active' &&
        status != 'completed' &&
        status != 'closed') {
      continue;
    }
    final Job? job = byId[hire.jobId];
    if (job == null) continue;
    total += job.budgetMax ?? job.budgetMin ?? 0;
    currencies[job.currencyCode] = (currencies[job.currencyCode] ?? 0) + 1;
  }
  String code = 'USD';
  int best = 0;
  currencies.forEach((String key, int count) {
    if (count > best) {
      best = count;
      code = key;
    }
  });
  return _SpentSummary(total: total, symbol: _currencySymbol(code));
}

String _proHireSubtitle(Hire hire, Job? job) {
  if (job?.location != null && job!.location!.isNotEmpty) {
    final String? client = _proClientOf(job);
    if (client != null && client.isNotEmpty) {
      return '$client · ${job.location!}';
    }
    return job.location!;
  }
  if (hire.jobTitle != null && hire.jobTitle!.isNotEmpty) {
    return 'Hired ${HivorrFormatters.date(hire.hiredAt)}';
  }
  return HivorrFormatters.date(hire.hiredAt);
}

String? _proClientOf(Job job) {
  // Client display names are not exposed to the professional dashboard;
  // the description lead stands in where a company name would render.
  final String lead = job.description.split('\n').first.trim();
  if (lead.isEmpty || lead.length > 40) return null;
  return lead;
}

String _proJobSubtitle(Job job) {
  if (job.location != null && job.location!.isNotEmpty) {
    final String lead = job.description.split('\n').first.trim();
    if (lead.isNotEmpty && lead.length <= 32) {
      return '$lead · ${job.location!}';
    }
    return job.location!;
  }
  return job.description.split('\n').first.trim();
}

/// Category chip: profession/industry short label when short, else status.
String? _proCategory(Job? job) {
  if (job == null) return null;
  final String? raw = job.professionId ?? job.industryId;
  if (raw == null || raw.isEmpty) return null;
  final String cleaned = raw
      .split(RegExp(r'[-_]'))
      .map((String p) =>
          p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase())
      .join(' ');
  if (cleaned.length > 18) return null;
  return cleaned;
}

String _proStatusLabel(String code) {
  final String lower = code.toLowerCase();
  if (lower == 'active') return 'in progress';
  if (lower == 'completed' || lower == 'closed') return 'completed';
  if (lower == 'pending') return 'pending';
  if (lower == 'cancelled') return 'cancelled';
  if (lower == 'disputed') return 'disputed';
  if (lower == 'open') return 'open';
  if (lower.isEmpty) return 'active';
  return lower;
}
