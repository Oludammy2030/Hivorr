import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
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
      body: SafeArea(
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

/// Professional's own applications with a status filter (EP-04-03).
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
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
