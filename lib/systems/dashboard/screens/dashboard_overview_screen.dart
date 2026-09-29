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
import 'package:hivorr/systems/dashboard/models/client_overview_mock.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';
import 'package:hivorr/systems/dashboard/widgets/quick_actions.dart';
import 'package:hivorr/systems/jobs/models/job_status.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Role-aware dashboard overview: the operational command center (EP-04-03).
///
/// One screen with capability variants: hire sees hiring summary + actions,
/// offer sees work summary + actions, both sees the combined command center
/// with My Work / My Hiring sections. Balanced composition — summary cards,
/// quick actions, pending items, recent jobs — never a card wall.
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
    final EntityCapability entity =
        onboarding.progress?.capability ?? EntityCapability.both;
    final DashboardCapability capability = DashboardCapability.fromEntity(
      entity,
    );
    final JobProvider jobs = context.read<JobProvider>();
    final HireProvider hires = context.read<HireProvider>();
    if (capability.showsHiring) {
      unawaited(
        jobs.loadMine(role: 'posted').then((_) => jobs.loadRecentReceived()),
      );
      unawaited(hires.loadList(role: 'client'));
    }
    if (capability.showsWork) {
      unawaited(jobs.loadDiscovery(refresh: true));
      unawaited(jobs.loadMine(role: 'applied'));
      unawaited(hires.loadList(role: 'professional'));
    }
  }

  Future<void> _refresh(DashboardCapability capability) async {
    final JobProvider jobs = context.read<JobProvider>();
    final HireProvider hires = context.read<HireProvider>();
    if (capability.showsHiring) {
      await jobs.loadMine(role: 'posted');
      await jobs.loadRecentReceived();
      await hires.loadList(role: 'client');
    }
    if (capability.showsWork) {
      await jobs.loadDiscovery(refresh: true);
      await jobs.loadMine(role: 'applied');
      await hires.loadList(role: 'professional');
    }
  }

  /// Client (employer) overview chrome matching the reference dashboard.
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
        appBar: AppBar(
          title: Text('Overview', style: context.textTheme.titleLarge),
          actions: <Widget>[
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go(RoutePaths.dashboardNotifications),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(_refresh(capability)),
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
    final DashboardCapability capability = DashboardCapability.fromEntity(
      onboarding.progress?.capability ?? EntityCapability.both,
    );
    // Operating mode for `both` users (UI-only). Falls back to combined
    // navigation when the provider is absent (e.g. legacy widget tests).
    DashboardViewMode? viewMode;
    try {
      viewMode = context.watch<DashboardViewModeProvider>().mode;
    } catch (_) {
      viewMode = null;
    }
    final bool showHiring;
    final bool showWork;
    if (capability != DashboardCapability.both || viewMode == null) {
      showHiring = capability.showsHiring;
      showWork = capability.showsWork;
    } else {
      showHiring = viewMode == DashboardViewMode.client;
      showWork = viewMode == DashboardViewMode.professional;
    }
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hires = context.watch<HireProvider>();
    // Client-only (employer) presentation follows the reference dashboard.
    // Offer and combined views keep the established layout below.
    if (showHiring && !showWork) {
      return _clientScaffold(context, capability, jobs, hires);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Overview', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.go(RoutePaths.dashboardNotifications),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_refresh(capability)),
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
                            viewMode: viewMode,
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
  const _WelcomeHeader({required this.capability, this.viewMode});

  final DashboardCapability capability;

  /// Current operating mode for `both` users; null keeps the `Both` pill.
  final DashboardViewMode? viewMode;

  @override
  Widget build(BuildContext context) {
    final bool isBothWithMode =
        capability == DashboardCapability.both && viewMode != null;
    final String subtitle = switch (capability) {
      DashboardCapability.hire =>
        'Post jobs, review applications, and hire verified professionals.',
      DashboardCapability.offer =>
        'Find jobs, manage applications, and track your work.',
      DashboardCapability.both when isBothWithMode =>
        viewMode == DashboardViewMode.professional
            ? 'Find jobs, manage applications, and track your work.'
            : 'Post jobs, review applications, and hire verified professionals.',
      DashboardCapability.both =>
        'Manage your hiring and your professional work in one place.',
    };
    final RoleThemeExtension roles = context.roleTheme;
    final (Color pillBg, Color pillFg, String pillLabel) =
        switch (capability) {
      DashboardCapability.hire => (
        roles.clientContainer,
        roles.clientPrimary,
        '${capability.label} mode',
      ),
      DashboardCapability.offer => (
        roles.professionalContainer,
        roles.professionalPrimary,
        '${capability.label} mode',
      ),
      DashboardCapability.both when isBothWithMode =>
        viewMode == DashboardViewMode.professional
            ? (
                roles.professionalContainer,
                roles.professionalPrimary,
                'Professional mode',
              )
            : (
                roles.clientContainer,
                roles.clientPrimary,
                'Client mode',
              ),
      DashboardCapability.both => (
        roles.bothContainer,
        roles.bothPrimary,
        '${capability.label} mode',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.sm,
            vertical: HivorrSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            pillLabel,
            style: context.textTheme.labelSmall?.copyWith(
              color: pillFg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          'Welcome back',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          subtitle,
          style: context.textTheme.bodyMedium?.copyWith(
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
            onTap: () =>
                context.go('${RoutePaths.dashboardHires}?role=client'),
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
            title: 'No jobs posted yet',
            subtitle:
                'Create your first job and start receiving applications from qualified professionals.',
            actionButton: HivorrButton(
              label: 'Post a Job',
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
            title: 'No work yet',
            subtitle:
                'Browse open jobs and submit your first application to get started.',
            actionButton: HivorrButton(
              label: 'Find Jobs',
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

// ── Client (employer) overview — reference dashboard presentation ──────────
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
    final ColorScheme colors = context.colorScheme;
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
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.lg,
        vertical: 14,
      ),
      child: Row(
        children: <Widget>[
          _TopBarTile(
            tooltip: 'Menu',
            icon: Icons.menu,
            onTap: () {
              final ScaffoldState? scaffold = Scaffold.maybeOf(context);
              if (scaffold != null && scaffold.hasDrawer) {
                scaffold.openDrawer();
              }
            },
          ),
          const SizedBox(width: HivorrSpacing.md),
          Text(
            'Dashboard',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _TopBarTile(
            tooltip: 'Notifications',
            icon: Icons.notifications_outlined,
            showDot: pendingApps > 0,
            onTap: () => context.go(RoutePaths.dashboardNotifications),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: roles.clientContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: roles.clientPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.xs),
                Text(
                  capability.label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: roles.clientPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Tooltip(
            message: 'Account',
            child: InkWell(
              onTap: () => context.go(RoutePaths.dashboardAccount),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer,
                  border: Border.all(color: colors.primary, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(displayName),
                  style: context.textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarTile extends StatelessWidget {
  const _TopBarTile({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Icon(icon, size: 22, color: colors.onSurfaceVariant),
              if (showDot)
                Positioned(
                  top: 10,
                  right: 11,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.surfaceContainerHighest,
                        width: 1.5,
                      ),
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

/// Client content column: hero, quick actions + active jobs beside the
/// right-rail metric grid on wide layouts, stacked otherwise, then Money.
class _ClientContent extends StatelessWidget {
  const _ClientContent({required this.maxWidth, required this.hiresEmpty});

  final double maxWidth;
  final bool hiresEmpty;

  /// Width at or above which the right metric rail docks beside the content.
  static const double railStart = 1000;

  @override
  Widget build(BuildContext context) {
    final bool wide = maxWidth >= railStart;
    // Compact vertical rhythm on phones (<600dp); desktop keeps the airy
    // reference spacing (see MobileCompact contract).
    final double sectionGap = MobileCompact.sectionGapFor(maxWidth);
    final Widget quickActions = _ClientSection(
      title: 'Quick Actions',
      child: const _ClientQuickActions(),
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
        else ...<Widget>[
          quickActions,
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
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 17 : 18,
                ),
              ),
            ),
            if (action case final Widget resolvedAction) resolvedAction,
          ],
        ),
        SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        child,
      ],
    );
  }
}

/// Blue hero card: time-aware greeting, account name, new-application line
/// and four glass stat chips (reference, left column).
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
        ? (context.screenWidth < 360 ? 16 : 20)
        : 28;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.all(heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$hour,',
            style: (compact
                    ? context.textTheme.bodyMedium
                    : context.textTheme.bodyLarge)
                ?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$displayName \u{1F3E2}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.headlineSmall
                    : context.textTheme.headlineMedium)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : 10),
          if (loading)
            Text(
              'Loading your hiring activity…',
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            )
          else if (totalApps > 0)
            Text.rich(
              TextSpan(
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'You have '),
                  TextSpan(
                    text: '$totalApps new application${totalApps == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const TextSpan(text: ' across your active jobs'),
                ],
              ),
            )
          else
            Text(
              'No new applications across your active jobs yet',
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          SizedBox(height: compact ? HivorrSpacing.md : 22),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              // Two fluid chips per row on phones so 320px never overflows;
              // desktop keeps the fixed 132dp reference chips.
              final double? statWidth = compact
                  ? (c.maxWidth - HivorrSpacing.sm) / 2
                  : null;
              return Wrap(
                spacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
                runSpacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
                children: <Widget>[
                  _HeroStat(
                    value: loading ? '…' : '$postedCount',
                    label: 'Jobs Posted',
                    width: statWidth,
                    compact: compact,
                  ),
                  _HeroStat(
                    value: loading ? '…' : '$activeHires',
                    label: 'Active Hires',
                    width: statWidth,
                    compact: compact,
                  ),
                  _HeroStat(
                    value: loading
                        ? '…'
                        : '${spent.symbol}${_grouped(spent.total)}',
                    label: 'Total Spent',
                    width: statWidth,
                    compact: compact,
                  ),
                  _HeroStat(
                    value: loading ? '…' : '$totalApps',
                    label: 'Applications',
                    width: statWidth,
                    compact: compact,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    this.width = 132,
    this.compact = false,
  });

  final String value;
  final String label;
  final double? width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? HivorrSpacing.sm : HivorrSpacing.md,
        vertical: compact ? HivorrSpacing.sm : HivorrSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.titleMedium
                    : context.textTheme.titleLarge)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
            textAlign: TextAlign.center,
          ),
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
    return Row(
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
    final double iconSize = compact ? 44 : 52;
    final (Color tileBg, Color iconFg) = switch (tint) {
      _QuickTint.lavender => (roles.clientContainer, roles.clientPrimary),
      _QuickTint.green => (ext.successContainer, ext.success),
      _QuickTint.peach => (ext.warningContainer, ext.warning),
    };
    return HivorrCard(
      onTap: onTap,
      borderRadius: 16,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? HivorrSpacing.sm : HivorrSpacing.md,
        vertical: compact ? HivorrSpacing.md : HivorrSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
            ),
            child: Icon(icon, size: compact ? 22 : 26, color: iconFg),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (compact
                    ? context.textTheme.labelMedium
                    : context.textTheme.titleSmall)
                ?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
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
      return HivorrEmptyState(
        title: 'No jobs posted yet',
        subtitle:
            'Create your first job and start receiving applications from qualified professionals.',
        actionButton: HivorrButton(
          label: 'Post a Job',
          onPressed: () => context.go(RoutePaths.dashboardJobNew),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final Job job in ordered) ...<Widget>[
          _ClientJobCard(job: job),
          const SizedBox(height: HivorrSpacing.md),
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
      return const HivorrEmptyState(
        title: 'No applications yet',
        subtitle:
            'Applications to your jobs will appear here as soon as professionals apply.',
      );
    }
    final Map<String, String> titles = <String, String>{
      for (final Job job in jobs.posted) job.id: job.title,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final JobApplication application in feed) ...<Widget>[
          _ReceivedApplicationRow(
            application: application,
            jobTitle:
                application.jobTitle ?? titles[application.jobId] ?? 'Job',
          ),
          const SizedBox(height: HivorrSpacing.md),
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
    final double avatarSize = compact ? 40 : 48;
    final String quote = application.quotedAmount == null
        ? 'Application'
        : '${application.currencyCode} '
              '${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}'
              '${application.durationDays == null ? '' : ' · ${application.durationDays}d'}';
    return HivorrCard(
      onTap: () =>
          context.go(RoutePaths.dashboardJobDetail(application.jobId)),
      borderRadius: 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
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
              size: compact ? 20 : 24,
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
                  style: context.textTheme.bodyMedium?.copyWith(
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
                const SizedBox(height: 6),
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
      borderRadius: 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Current Hires',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 17 : 18,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          if (hires.isLoading && hires.hires.isEmpty)
            const HivorrLoadingState()
          else if (current.isEmpty)
            Text(
              'No current hires yet',
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            for (int i = 0; i < current.length; i++) ...<Widget>[
              if (i > 0)
                Divider(height: HivorrSpacing.lg, color: colors.outlineVariant),
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
    return InkWell(
      onTap: () => context.go(RoutePaths.dashboardHireDetail(hire.id)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tileBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline, size: 22, color: iconFg),
            ),
            const SizedBox(width: HivorrSpacing.md),
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
    return Tooltip(
      message: 'Message',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: roles.clientContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            size: 20,
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
      borderRadius: 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
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
                      spacing: HivorrSpacing.sm,
                      runSpacing: HivorrSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        HiringStatusBadge(code: job.status),
                        if (job.location != null &&
                            job.location!.isNotEmpty)
                          _SoftChip(
                            label: job.location!,
                            background: colors.surfaceContainerHighest,
                            foreground: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                    const SizedBox(height: HivorrSpacing.sm),
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact
                              ? context.textTheme.titleSmall
                              : context.textTheme.titleMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _jobSubtitle(job),
                      style: context.textTheme.bodyMedium?.copyWith(
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(height: 4),
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
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: () =>
                    context.go(RoutePaths.dashboardJobDetail(job.id)),
                icon: const Icon(Icons.people_outline, size: 18),
                label: Text(applicants),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: HivorrSpacing.md,
                    vertical: HivorrSpacing.sm,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go(RoutePaths.dashboardMessages),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: HivorrSpacing.md,
                    vertical: HivorrSpacing.sm,
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
        // At 320px two columns would squeeze to ~136dp and clip; fall back
        // to a single column there so cards stay readable and compact.
        final bool twoCol = MobileCompact.fitsTwoColumns(c.maxWidth);
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
            onTap: () =>
                context.go('${RoutePaths.dashboardHires}?role=client'),
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
    final double tileSize = compact ? 36 : 44;
    return HivorrCard(
      onTap: onTap,
      borderRadius: 16,
      padding: const EdgeInsets.all(HivorrSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: compact ? 18 : 22, color: iconFg),
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
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? context.textTheme.titleMedium
                          : context.textTheme.titleLarge)
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
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
      borderRadius: 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Spending Overview',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 17 : 18,
            ),
          ),
          SizedBox(height: compact ? HivorrSpacing.sm : HivorrSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Monthly budget used',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Flexible(
                child: Text(
                  used,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.usedShare,
              minHeight: 8,
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
          const SizedBox(height: HivorrSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.md,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: ext.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.lock_outline, size: 20, color: ext.warning),
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
      borderRadius: 16,
      padding: EdgeInsets.all(compact ? HivorrSpacing.md : HivorrSpacing.lg),
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
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 17 : 18,
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
                child: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
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
                  height: HivorrSpacing.lg,
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
    final bool isEscrow = payment.kind == ClientPaymentKind.escrow;
    final Color tileBg =
        isEscrow ? ext.warningContainer : colors.errorContainer;
    final Color iconFg = isEscrow ? ext.warning : colors.error;
    final Color amountFg = isEscrow ? ext.warning : colors.error;
    final String amount = isEscrow
        ? '${payment.symbol}${_grouped(payment.amount)}'
        : '-${payment.symbol}${_grouped(payment.amount.abs())}';
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isEscrow ? Icons.lock_outline : Icons.arrow_upward,
            size: 22,
            color: iconFg,
          ),
        ),
        const SizedBox(width: HivorrSpacing.md),
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
            fontWeight: FontWeight.w800,
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
