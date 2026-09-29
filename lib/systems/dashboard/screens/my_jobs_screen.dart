import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:provider/provider.dart';

/// Client's posted jobs with a status filter (EP-04-03).
///
/// `GET job_list_mine(posted)`. One [JobCard] per job, pull-to-refresh, a
/// create action, and branded loading/error/empty states. Follows the
/// `MyListingsScreen` lifecycle convention (one-shot initial load).
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  String? _statusFilter;

  static const List<String?> _filters = <String?>[
    null,
    'draft',
    'open',
    'paused',
    'awarded',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<JobProvider>().loadMine(role: 'posted');

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final filtered = _statusFilter == null
        ? jobs.posted
        : jobs.posted.where((j) => j.status == _statusFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('My Jobs', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Post a job',
            icon: const Icon(Icons.add),
            onPressed: () => context.go(RoutePaths.dashboardJobNew),
          ),
        ],
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
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: _Body(jobs: jobs, filtered: filtered, onRetry: _load),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(RoutePaths.dashboardJobNew),
        icon: const Icon(Icons.add),
        label: const Text('Post a Job'),
      ),
    );
  }

  String _label(String status) => status[0].toUpperCase() + status.substring(1);
}

class _Body extends StatelessWidget {
  const _Body({
    required this.jobs,
    required this.filtered,
    required this.onRetry,
  });

  final JobProvider jobs;
  final List<Job> filtered;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (jobs.isLoading && jobs.posted.isEmpty) {
      return const HivorrLoadingState();
    }
    if (jobs.lastError != null && jobs.posted.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (filtered.isEmpty) {
      return HivorrEmptyState(
        title: jobs.posted.isEmpty
            ? 'No jobs posted yet'
            : 'Nothing with this status',
        subtitle: jobs.posted.isEmpty
            ? 'Create your first job and start receiving applications from qualified professionals.'
            : 'Try a different status filter.',
        actionButton: jobs.posted.isEmpty
            ? HivorrButton(
                label: 'Post a Job',
                onPressed: () => context.go(RoutePaths.dashboardJobNew),
              )
            : null,
      );
    }
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.all(HivorrSpacing.md),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: HivorrSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final Job job = filtered[i];
          return JobCard(
            job: job,
            onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
          );
        },
      ),
    );
  }
}
