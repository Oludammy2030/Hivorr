import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:hivorr/systems/onboarding/models/entity_capability.dart';
import 'package:provider/provider.dart';

/// Professional job discovery (EP-04-03).
///
/// `GET job_list` (open only) with full-text search, pull-to-refresh, and
/// infinite-style pagination via the next cursor. Tapping a card opens the
/// job detail with the apply flow.
class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({super.key});

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  String? _query;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(refresh: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) =>
      context.read<JobProvider>().loadDiscovery(
        search: _query?.isEmpty ?? true ? null : _query,
        refresh: refresh,
      );

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = value.trim().isEmpty ? null : value.trim());
      unawaited(_load(refresh: true));
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 200) {
      return;
    }
    final JobProvider jobs = context.read<JobProvider>();
    if (!jobs.isLoading && jobs.discoveryHasMore) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Find Jobs', style: context.textTheme.titleLarge),
      ),
      body: MobileSafeBody(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HivorrSpacing.md,
                HivorrSpacing.sm,
                HivorrSpacing.md,
                HivorrSpacing.xs,
              ),
              child: HivorrTextField(
                controller: _search,
                hint: 'Search jobs…',
                prefix: const Icon(Icons.search_outlined),
                onChanged: _onSearchChanged,
              ),
            ),
            if (jobs.discovery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HivorrSpacing.md,
                  0,
                  HivorrSpacing.md,
                  HivorrSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    jobs.discoveryHasMore
                        ? '${jobs.discovery.length}+ open jobs'
                        : '${jobs.discovery.length} open jobs',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _Body(jobs: jobs, onRetry: () => _load(refresh: true)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.jobs, required this.onRetry});

  final JobProvider jobs;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (jobs.isLoading && jobs.discovery.isEmpty) {
      return const HivorrLoadingState();
    }
    if (jobs.lastError != null && jobs.discovery.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (jobs.discovery.isEmpty) {
      return const HivorrEmptyState(
        title: 'No open jobs right now',
        subtitle:
            'New hiring requests appear here as soon as clients publish them. Check back soon.',
      );
    }
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.all(HivorrSpacing.md),
        itemCount: jobs.discovery.length + (jobs.discoveryHasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: HivorrSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          if (i >= jobs.discovery.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: HivorrSpacing.md),
              child: HivorrLoadingState(),
            );
          }
          final Job job = jobs.discovery[i];
          return JobCard(
            job: job,
            onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
          );
        },
      ),
    );
  }
}

/// Role-aware Applications entry (EP-04-03).
///
/// Professionals see their own applications list ([_ProfessionalApplicationsScreen],
/// the pre-existing screen); hiring-side clients see the Jobs + Applicants
/// inbox ([_ClientApplicationsScreen]) matching the Applications reference:
/// the Jobs panel lists posted jobs, the Applications panel shows applicants
/// for the selected job, and each panel scrolls independently.
class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool hiring = false;
    try {
      final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
      final DashboardCapability capability = DashboardCapability.fromEntity(
        onboarding.progress?.capability ?? EntityCapability.both,
      );
      DashboardViewMode? mode;
      try {
        mode = context.watch<DashboardViewModeProvider>().mode;
      } catch (_) {
        mode = null;
      }
      if (capability == DashboardCapability.hire) {
        hiring = true;
      } else if (capability == DashboardCapability.both &&
          mode == DashboardViewMode.client) {
        hiring = true;
      }
    } catch (_) {
      hiring = false;
    }
    if (hiring) return const _ClientApplicationsScreen();
    return const _ProfessionalApplicationsScreen();
  }
}

/// Professional's own applications with a status filter (EP-04-03).
class _ProfessionalApplicationsScreen extends StatefulWidget {
  const _ProfessionalApplicationsScreen();

  @override
  State<_ProfessionalApplicationsScreen> createState() =>
      _ProfessionalApplicationsScreenState();
}

class _ProfessionalApplicationsScreenState
    extends State<_ProfessionalApplicationsScreen> {
  List<JobApplication> _items = const <JobApplication>[];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  static const List<String?> _filters = <String?>[
    null,
    'submitted',
    'shortlisted',
    'accepted',
    'rejected',
    'withdrawn',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Applications read through the service layer directly: the provider
      // owns jobs + selection, while lists stay screen-local (mirrors the
      // admin directory pattern of provider-backed search + local results).
      final page = await context.read<JobProvider>().listApplications(
        status: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _items = page.applications;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Applications', style: context.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: HivorrSpacing.md,
                  vertical: HivorrSpacing.xs,
                ),
                itemCount: _filters.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: HivorrSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final String? filter = _filters[i];
                  return HivorrChip(
                    label: filter == null ? 'All' : _label(filter),
                    isSelected: _statusFilter == filter,
                    onSelected: (_) {
                      setState(() => _statusFilter = filter);
                      unawaited(_load());
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const HivorrLoadingState()
                  : _error != null
                  ? HivorrErrorState(
                      message: 'Could not load applications',
                      detail: _error!,
                      onRetry: () => unawaited(_load()),
                    )
                  : _items.isEmpty
                  ? HivorrEmptyState(
                      title: 'No applications yet',
                      subtitle:
                          'Browse open jobs and submit your first application to get started.',
                      actionButton: HivorrButton(
                        label: 'Find Jobs',
                        onPressed: () =>
                            context.go(RoutePaths.dashboardOpportunities),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(HivorrSpacing.md),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: HivorrSpacing.sm),
                        itemBuilder: (BuildContext context, int i) {
                          final JobApplication application = _items[i];
                          return ApplicationCard(
                            application: application,
                            onTap: () => context.go(
                              RoutePaths.dashboardJobDetail(application.jobId),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String status) => status[0].toUpperCase() + status.substring(1);
}

/// Client Applications inbox (hiring side).
///
/// Two connected panels from the reference: the Jobs panel lists posted jobs
/// (open, in progress, completed) and the Applications panel shows applicants
/// for the selected job. Selecting another job reloads only the Applications
/// panel. Each panel owns its scroll controller so scrolling applicants never
/// moves the Jobs panel. Applicant actions reuse the existing seams:
/// View Profile → public profile, Message → messages, Hire → `hire_accept`
/// via [HireProvider], Reject/Shortlist → [JobProvider].
class _ClientApplicationsScreen extends StatefulWidget {
  const _ClientApplicationsScreen();

  @override
  State<_ClientApplicationsScreen> createState() =>
      _ClientApplicationsScreenState();
}

class _ClientApplicationsScreenState extends State<_ClientApplicationsScreen> {
  static const double _contentMaxWidth = 1120;
  static const double _jobsPanelWidth = 300;
  static const double _twoPaneBreakpoint = 900;

  final ScrollController _jobsScroll = ScrollController();
  final ScrollController _appsScroll = ScrollController();

  String? _selectedJobId;
  List<JobApplication> _apps = const <JobApplication>[];
  final Map<String, List<JobApplication>> _appsCache =
      <String, List<JobApplication>>{};
  bool _appsLoading = false;
  String? _appsError;
  bool _jobsRequested = false;
  final Set<String> _acting = <String>{};

  @override
  void dispose() {
    _jobsScroll.dispose();
    _appsScroll.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() =>
      context.read<JobProvider>().loadMine(role: 'posted');

  Future<void> _loadApps(String jobId, {bool refresh = false}) async {
    if (!refresh && _appsCache.containsKey(jobId)) {
      if (mounted) {
        setState(() {
          _apps = _appsCache[jobId]!;
          _appsLoading = false;
          _appsError = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _appsLoading = true;
        _appsError = null;
      });
    }
    try {
      final page = await context.read<JobProvider>().listApplicationsForJob(
        jobId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _apps = page.applications;
        _appsCache[jobId] = page.applications;
        _appsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _appsLoading = false;
        _appsError = e.message;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _appsLoading = false;
        _appsError = e.toString();
      });
    }
  }

  void _ensureSelection(List<Job> posted) {
    if (posted.isEmpty) return;
    final bool stillValid =
        _selectedJobId != null &&
        posted.any((Job j) => j.id == _selectedJobId);
    if (!stillValid) {
      _selectedJobId = posted.first.id;
      unawaited(_loadApps(_selectedJobId!));
    }
  }

  void _selectJob(String jobId) {
    if (_selectedJobId == jobId) return;
    setState(() {
      _selectedJobId = jobId;
      _apps = _appsCache[jobId] ?? const <JobApplication>[];
      _appsError = null;
      _appsLoading = !_appsCache.containsKey(jobId);
    });
    if (!_appsCache.containsKey(jobId)) {
      unawaited(_loadApps(jobId));
    }
  }

  void _snack(String message, HivorrSnackbarVariant variant) {
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(context, message: message, variant: variant),
    );
  }

  Future<void> _runAction(
    String applicationId,
    Future<dynamic> Function() action,
    String success,
  ) async {
    setState(() => _acting.add(applicationId));
    try {
      final dynamic result = await action();
      if (!mounted) return;
      if (result is JobApplication && _selectedJobId != null) {
        final List<JobApplication> updated = _apps
            .map((JobApplication a) => a.id == result.id ? result : a)
            .toList(growable: false);
        setState(() {
          _apps = updated;
          _appsCache[_selectedJobId!] = updated;
        });
      } else if (_selectedJobId != null) {
        unawaited(_loadApps(_selectedJobId!, refresh: true));
      }
      unawaited(_loadJobs());
      _snack(success, HivorrSnackbarVariant.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _acting.remove(applicationId));
    }
  }

  void _shortlist(JobApplication application) {
    final JobProvider jobs = context.read<JobProvider>();
    unawaited(
      _runAction(
        application.id,
        () => jobs.shortlistApplication(application.id),
        'Application shortlisted.',
      ),
    );
  }

  void _reject(JobApplication application) {
    final JobProvider jobs = context.read<JobProvider>();
    unawaited(
      _runAction(
        application.id,
        () => jobs.rejectApplication(application.id),
        'Application rejected.',
      ),
    );
  }

  void _hire(JobApplication application) {
    HireProvider? hires;
    try {
      hires = context.read<HireProvider>();
    } catch (_) {
      hires = null;
    }
    if (hires == null) {
      _snack(
        'Hiring is unavailable right now.',
        HivorrSnackbarVariant.error,
      );
      return;
    }
    final HireProvider hireProvider = hires;
    unawaited(
      _runAction(
        application.id,
        () => hireProvider.acceptHire(application.id),
        'Professional hired.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final List<Job> posted = jobs.posted;
    if (!_jobsRequested) {
      _jobsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadJobs());
      });
    } else {
      _ensureSelection(posted);
    }
    final Job? selected = _selectedJobId == null
        ? null
        : posted.where((Job j) => j.id == _selectedJobId).firstOrNull;

    final bool isMobile = context.breakpoint == Breakpoint.mobile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text(
                'Applications',
                style: context.textTheme.titleLarge,
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (!isMobile) const _ApplicationsTopBar(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _contentMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(HivorrSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Applications',
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: HivorrSpacing.xs),
                        Text(
                          'Review and manage applicants for your jobs',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: HivorrSpacing.lg),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (
                              BuildContext context,
                              BoxConstraints c,
                            ) {
                              final bool wide =
                                  c.maxWidth >= _twoPaneBreakpoint;
                              if (!wide) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _JobsPanel(
                                      jobs: jobs,
                                      posted: posted,
                                      selectedId: _selectedJobId,
                                      scrollController: _jobsScroll,
                                      horizontal: true,
                                      onSelect: _selectJob,
                                      onRetry: _loadJobs,
                                    ),
                                    const SizedBox(
                                      height: HivorrSpacing.md,
                                    ),
                                    Expanded(
                                      child: _ApplicantsPanel(
                                        job: selected,
                                        apps: _apps,
                                        loading: _appsLoading,
                                        error: _appsError,
                                        acting: _acting,
                                        scrollController: _appsScroll,
                                        onRetry: selected == null
                                            ? null
                                            : () => _loadApps(
                                                selected.id,
                                                refresh: true,
                                              ),
                                        onShortlist: _shortlist,
                                        onHire: _hire,
                                        onReject: _reject,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  SizedBox(
                                    width: _jobsPanelWidth,
                                    child: _JobsPanel(
                                      jobs: jobs,
                                      posted: posted,
                                      selectedId: _selectedJobId,
                                      scrollController: _jobsScroll,
                                      horizontal: false,
                                      onSelect: _selectJob,
                                      onRetry: _loadJobs,
                                    ),
                                  ),
                                  const SizedBox(width: HivorrSpacing.md),
                                  Expanded(
                                    child: _ApplicantsPanel(
                                      job: selected,
                                      apps: _apps,
                                      loading: _appsLoading,
                                      error: _appsError,
                                      acting: _acting,
                                      scrollController: _appsScroll,
                                      onRetry: selected == null
                                          ? null
                                          : () => _loadApps(
                                              selected.id,
                                              refresh: true,
                                            ),
                                      onShortlist: _shortlist,
                                      onHire: _hire,
                                      onReject: _reject,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop top bar matching the reference: menu tile, page title, bell,
/// Client pill and account avatar.
class _ApplicationsTopBar extends StatelessWidget {
  const _ApplicationsTopBar();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final roleTheme = context.roleTheme;
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
            'Applications',
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
              color: roleTheme.clientContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: roleTheme.clientPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.xs),
                Text(
                  'Client',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: roleTheme.clientPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          InkWell(
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
                'TV',
                style: context.textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
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
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
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
                      border: Border.all(color: colors.surface, width: 1.5),
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

/// White rounded panel shell shared by both panes.
class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final double radius = context.appExtension.radiusMd + 4;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Left pane: posted jobs with their own independent scroll.
class _JobsPanel extends StatelessWidget {
  const _JobsPanel({
    required this.jobs,
    required this.posted,
    required this.selectedId,
    required this.scrollController,
    required this.horizontal,
    required this.onSelect,
    required this.onRetry,
  });

  final JobProvider jobs;
  final List<Job> posted;
  final String? selectedId;
  final ScrollController scrollController;
  final bool horizontal;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Padding(
        padding: const EdgeInsets.all(HivorrSpacing.md),
        child: horizontal
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _yourJobsLabel(context),
                  const SizedBox(height: HivorrSpacing.sm),
                  SizedBox(
                    height: 108,
                    child: _jobsContent(context),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _yourJobsLabel(context),
                  const SizedBox(height: HivorrSpacing.sm),
                  Expanded(child: _jobsContent(context)),
                ],
              ),
      ),
    );
  }

  Widget _yourJobsLabel(BuildContext context) {
    return Text(
      'YOUR JOBS',
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _jobsContent(BuildContext context) {
    if (jobs.isLoading && posted.isEmpty) {
      return const HivorrLoadingState();
    }
    if (jobs.lastError != null && posted.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (posted.isEmpty) {
      return const HivorrEmptyState(
        title: 'No jobs posted yet',
        subtitle: 'Post a job to start receiving applications.',
      );
    }
    if (horizontal) {
      return ListView.separated(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: posted.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: HivorrSpacing.sm),
        itemBuilder: (BuildContext context, int i) => SizedBox(
          width: 260,
          child: _JobRow(
            job: posted[i],
            selected: posted[i].id == selectedId,
            onTap: () => onSelect(posted[i].id),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      itemCount: posted.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: HivorrSpacing.xs),
      itemBuilder: (BuildContext context, int i) => _JobRow(
        job: posted[i],
        selected: posted[i].id == selectedId,
        onTap: () => onSelect(posted[i].id),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.selected,
    required this.onTap,
  });

  final Job job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(HivorrSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(
                    alpha: context.isDarkMode ? 0.4 : 0.5,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                job.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Wrap(
                spacing: HivorrSpacing.xs,
                runSpacing: HivorrSpacing.xs,
                children: <Widget>[
                  _AppsCountPill(count: job.applicationsCount),
                  _JobStatusPill(status: job.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppsCountPill extends StatelessWidget {
  const _AppsCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: context.isDarkMode ? 0.5 : 0.7,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count apps',
        style: context.textTheme.labelSmall?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _JobStatusPill extends StatelessWidget {
  const _JobStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final ext = context.appExtension;
    final _PillTone tone = switch (status) {
      'open' => _PillTone(
          fill: ext.successContainer,
          text: ext.onSuccessContainer,
          label: 'open',
        ),
      'awarded' => _PillTone(
          fill: ext.warningContainer,
          text: ext.onWarningContainer,
          label: 'in progress',
        ),
      'completed' => _PillTone(
          fill: ext.warningContainer,
          text: ext.onWarningContainer,
          label: 'completed',
        ),
      _ => _PillTone(
          fill: colors.surfaceContainerHighest.withValues(
            alpha: context.isDarkMode ? 1.0 : 0.6,
          ),
          text: colors.onSurfaceVariant,
          label: status,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tone.label,
        style: context.textTheme.labelSmall?.copyWith(
          color: tone.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PillTone {
  const _PillTone({
    required this.fill,
    required this.text,
    required this.label,
  });

  final Color fill;
  final Color text;
  final String label;
}

/// Right pane: applicants for the selected job with its own scroll.
class _ApplicantsPanel extends StatelessWidget {
  const _ApplicantsPanel({
    required this.job,
    required this.apps,
    required this.loading,
    required this.error,
    required this.acting,
    required this.scrollController,
    required this.onRetry,
    required this.onShortlist,
    required this.onHire,
    required this.onReject,
  });

  final Job? job;
  final List<JobApplication> apps;
  final bool loading;
  final String? error;
  final Set<String> acting;
  final ScrollController scrollController;
  final Future<void> Function()? onRetry;
  final ValueChanged<JobApplication> onShortlist;
  final ValueChanged<JobApplication> onHire;
  final ValueChanged<JobApplication> onReject;

  @override
  Widget build(BuildContext context) {
    final Job? selectedJob = job;
    return _PanelCard(
      child: Padding(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (selectedJob == null)
              Text(
                'Select a job',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              _ApplicantsHeader(job: selectedJob, count: apps.length),
            const SizedBox(height: HivorrSpacing.sm),
            Divider(height: 1, color: context.colorScheme.outlineVariant),
            const SizedBox(height: HivorrSpacing.md),
            Expanded(child: _applicantsContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _applicantsContent(BuildContext context) {
    if (job == null) {
      return const HivorrEmptyState(
        title: 'No job selected',
        subtitle: 'Select a job to review its applicants.',
      );
    }
    if (loading && apps.isEmpty) {
      return const HivorrLoadingState();
    }
    if (error != null && apps.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load applicants',
        detail: error!,
        onRetry: onRetry == null ? null : () => unawaited(onRetry!()),
      );
    }
    if (apps.isEmpty) {
      return const HivorrEmptyState(
        title: 'No applicants yet',
        subtitle:
            'Applications from professionals will appear here once they apply.',
      );
    }
    final Widget list = ListView.separated(
      controller: scrollController,
      itemCount: apps.length,
      separatorBuilder: (BuildContext context, int _) => Column(
        children: <Widget>[
          const SizedBox(height: HivorrSpacing.md),
          Divider(height: 1, color: context.colorScheme.outlineVariant),
          const SizedBox(height: HivorrSpacing.md),
        ],
      ),
      itemBuilder: (BuildContext context, int i) {
        final JobApplication application = apps[i];
        return _ApplicantCard(
          application: application,
          busy: acting.contains(application.id),
          onShortlist: () => onShortlist(application),
          onHire: () => onHire(application),
          onReject: () => onReject(application),
        );
      },
    );
    if (onRetry == null) return list;
    return RefreshIndicator(
      onRefresh: onRetry!,
      child: list,
    );
  }
}

class _ApplicantsHeader extends StatelessWidget {
  const _ApplicantsHeader({required this.job, required this.count});

  final Job job;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final ext = context.appExtension;
    final double? budget = job.budgetMax ?? job.budgetMin;
    final String subtitle = budget == null
        ? '$count applications'
        : '$count applications · \$${HivorrFormatters.number(budget, decimals: 0)} budget';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                job.title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: job.status == 'open'
                ? ext.successContainer
                : ext.warningContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            job.status == 'awarded' ? 'in progress' : job.status,
            style: context.textTheme.labelMedium?.copyWith(
              color: job.status == 'open'
                  ? ext.onSuccessContainer
                  : ext.onWarningContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Applicant card from the reference: avatar, status pill, cover note,
/// quote/duration chips and View Profile / Message / Hire / Reject actions.
///
/// Identity fields beyond the application row are not exposed by the
/// jobs RPC, so the header falls back to an `Applicant · <id>` label with
/// deterministic initials rather than inventing names, roles or ratings.
class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.application,
    required this.busy,
    required this.onShortlist,
    required this.onHire,
    required this.onReject,
  });

  final JobApplication application;
  final bool busy;
  final VoidCallback onShortlist;
  final VoidCallback onHire;
  final VoidCallback onReject;

  String get _shortId {
    final String id = application.professionalEntityId.trim();
    if (id.isEmpty) return '—';
    return id.length <= 6 ? id : id.substring(0, 6);
  }

  String get _initials {
    final String alnum = application.professionalEntityId.replaceAll(
      RegExp('[^A-Za-z0-9]'),
      '',
    );
    if (alnum.isEmpty) return 'AP';
    if (alnum.length == 1) return alnum.toUpperCase();
    return alnum.substring(0, 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool active =
        application.status == 'submitted' ||
        application.status == 'shortlisted';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer.withValues(
                  alpha: context.isDarkMode ? 0.5 : 0.7,
                ),
                border: Border.all(color: colors.primary, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: context.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Applicant · $_shortId',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _metaLine(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            _ApplicationStatusPill(status: application.status),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Container(
          padding: const EdgeInsets.all(HivorrSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(
              alpha: context.isDarkMode ? 1.0 : 0.45,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            application.coverNote,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurface,
            ),
          ),
        ),
        if (application.quotedAmount != null ||
            application.durationDays != null) ...<Widget>[
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.xs,
            runSpacing: HivorrSpacing.xs,
            children: <Widget>[
              if (application.quotedAmount != null)
                _MetaChip(
                  text:
                      '${application.currencyCode} ${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}',
                ),
              if (application.durationDays != null)
                _MetaChip(text: '${application.durationDays} days'),
            ],
          ),
        ],
        const SizedBox(height: HivorrSpacing.sm),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            if (application.status == 'submitted')
              _PrimaryAction(
                label: 'Shortlist',
                icon: Icons.check,
                enabled: !busy,
                onTap: onShortlist,
              ),
            if (application.status == 'shortlisted')
              _PrimaryAction(
                label: 'Hire',
                icon: Icons.check,
                enabled: !busy,
                onTap: onHire,
              ),
            if (application.isAccepted)
              _PrimaryAction(
                label: 'Hired',
                icon: Icons.check,
                enabled: false,
                onTap: () {},
              ),
            _TintedAction(
              label: 'Message',
              icon: Icons.chat_bubble_outline,
              fill: colors.primaryContainer.withValues(
                alpha: context.isDarkMode ? 0.4 : 0.55,
              ),
              foreground: colors.primary,
              onTap: () => context.go(RoutePaths.dashboardMessages),
            ),
            _TintedAction(
              label: 'View Profile',
              icon: null,
              fill: colors.surfaceContainerHighest.withValues(
                alpha: context.isDarkMode ? 1.0 : 0.45,
              ),
              foreground: colors.onSurfaceVariant,
              onTap: () => context.go(
                RoutePaths.publicProfile(
                  slug: 'professional',
                  id: application.professionalEntityId,
                ),
              ),
            ),
            if (active)
              _TintedAction(
                label: busy ? 'Working…' : 'Reject',
                icon: Icons.close,
                fill: colors.errorContainer,
                foreground: colors.error,
                onTap: busy ? null : onReject,
              ),
          ],
        ),
      ],
    );
  }

  String _metaLine() {
    final List<String> parts = <String>[];
    if (application.quotedAmount != null) {
      parts.add(
        '${application.currencyCode} ${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}',
      );
    }
    if (application.durationDays != null) {
      parts.add('${application.durationDays}d');
    }
    parts.add(HivorrFormatters.relative(application.submittedAt));
    return parts.join(' · ');
  }
}

class _ApplicationStatusPill extends StatelessWidget {
  const _ApplicationStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final ext = context.appExtension;
    final _PillTone tone = switch (status) {
      'shortlisted' => _PillTone(
          fill: colors.primaryContainer.withValues(
            alpha: context.isDarkMode ? 0.5 : 0.7,
          ),
          text: colors.primary,
          label: 'shortlisted',
        ),
      'submitted' => _PillTone(
          fill: ext.warningContainer,
          text: ext.onWarningContainer,
          label: 'submitted',
        ),
      'accepted' => _PillTone(
          fill: ext.successContainer,
          text: ext.onSuccessContainer,
          label: 'accepted',
        ),
      _ => _PillTone(
          fill: colors.surfaceContainerHighest.withValues(
            alpha: context.isDarkMode ? 1.0 : 0.6,
          ),
          text: colors.onSurfaceVariant,
          label: status,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tone.label,
        style: context.textTheme.labelMedium?.copyWith(
          color: tone.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: context.isDarkMode ? 1.0 : 0.45,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Widget body = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: enabled
            ? colors.primary
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.onPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (!enabled) return body;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: body,
      ),
    );
  }
}

class _TintedAction extends StatelessWidget {
  const _TintedAction({
    required this.label,
    required this.fill,
    required this.foreground,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color fill;
  final Color foreground;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Widget body = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: onTap == null ? fill.withValues(alpha: 0.6) : fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: body,
      ),
    );
  }
}
