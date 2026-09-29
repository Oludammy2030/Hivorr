import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/components/hivorr_section_header.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/quick_actions.dart';
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
      unawaited(jobs.loadMine(role: 'posted'));
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
      await hires.loadList(role: 'client');
    }
    if (capability.showsWork) {
      await jobs.loadDiscovery(refresh: true);
      await jobs.loadMine(role: 'applied');
      await hires.loadList(role: 'professional');
    }
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
      body: SafeArea(
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
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(HivorrSpacing.lg),
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
                          const SizedBox(height: HivorrSpacing.xl),
                          const HivorrSectionHeader(title: 'Quick actions'),
                          _QuickActions(
                            showHiring: showHiring,
                            showWork: showWork,
                          ),
                          if (showHiring) ...<Widget>[
                            const SizedBox(height: HivorrSpacing.xl),
                            _HiringSection(isWide: isWide),
                          ],
                          if (showWork) ...<Widget>[
                            const SizedBox(height: HivorrSpacing.xl),
                            _WorkSection(isWide: isWide),
                          ],
                          const SizedBox(height: HivorrSpacing.xl),
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
    final double cardWidth = isWide ? 220 : maxWidth;
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
    return Wrap(
      spacing: HivorrSpacing.md,
      runSpacing: HivorrSpacing.md,
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
