import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Notifications center: activity feed derived from hiring data (EP-04-04).
///
/// There is no remote notification feed yet, so this screen aggregates real
/// lifecycle events the entity already owns — hires won/created/completed,
/// application decisions, job publishes/awards — newest first. It upgrades
/// to a push feed later without changing its item contract.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<HireProvider>().loadList();
      if (!mounted) return;
      await context.read<JobProvider>().loadApplications();
      if (!mounted) return;
      await context.read<JobProvider>().loadMine(role: 'posted');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<_ActivityItem> _items() {
    final String? entityId = context
        .read<AuthProvider>()
        .currentSession
        ?.entityId;
    final HireProvider hires = context.read<HireProvider>();
    final JobProvider jobs = context.read<JobProvider>();
    final List<_ActivityItem> items = <_ActivityItem>[];

    for (final Hire hire in hires.hires) {
      final bool mine =
          entityId != null && entityId == hire.professionalEntityId;
      final String job = hire.jobTitle ?? 'A job';
      items.add(
        _ActivityItem(
          at: hire.hiredAt,
          icon: Icons.handshake_outlined,
          title: mine ? 'You were hired' : 'Professional hired',
          subtitle: job,
          route: RoutePaths.dashboardHireDetail(hire.id),
        ),
      );
      if (hire.completedAt != null) {
        items.add(
          _ActivityItem(
            at: hire.completedAt!,
            icon: Icons.task_alt_outlined,
            title: 'Hire completed',
            subtitle: job,
            route: RoutePaths.dashboardHireDetail(hire.id),
          ),
        );
      }
      if (hire.cancelledAt != null) {
        items.add(
          _ActivityItem(
            at: hire.cancelledAt!,
            icon: Icons.cancel_outlined,
            title: 'Hire cancelled',
            subtitle: job,
            route: RoutePaths.dashboardHireDetail(hire.id),
          ),
        );
      }
    }

    for (final JobApplication application in jobs.myApplications) {
      if (application.status == 'accepted' ||
          application.status == 'rejected') {
        items.add(
          _ActivityItem(
            at: application.decidedAt ?? application.submittedAt,
            icon: application.status == 'accepted'
                ? Icons.check_circle_outline
                : Icons.highlight_off_outlined,
            title: application.status == 'accepted'
                ? 'Application accepted'
                : 'Application not selected',
            subtitle: application.jobTitle ?? 'An application',
            route: RoutePaths.dashboardJobDetail(application.jobId),
          ),
        );
      }
    }

    for (final Job job in jobs.posted) {
      if (job.postedAt != null) {
        items.add(
          _ActivityItem(
            at: job.postedAt!,
            icon: Icons.publish_outlined,
            title: 'Job published',
            subtitle: job.title,
            route: RoutePaths.dashboardJobDetail(job.id),
          ),
        );
      }
      if (job.awardedAt != null) {
        items.add(
          _ActivityItem(
            at: job.awardedAt!,
            icon: Icons.emoji_events_outlined,
            title: 'Job awarded',
            subtitle: job.title,
            route: RoutePaths.dashboardJobDetail(job.id),
          ),
        );
      }
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(30).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_load()),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const HivorrLoadingState()
            : _error != null
            ? HivorrErrorState(
                message: 'Could not load activity',
                detail: _error!,
                onRetry: () => unawaited(_load()),
              )
            : Builder(
                builder: (BuildContext context) {
                  final List<_ActivityItem> items = _items();
                  if (items.isEmpty) {
                    return const HivorrEmptyState(
                      icon: Icon(Icons.notifications_outlined),
                      title: 'No notifications yet',
                      subtitle:
                          'Hire updates, application decisions, and payment events will appear here.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(HivorrSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: HivorrSpacing.sm),
                      itemBuilder: (BuildContext context, int i) {
                        final _ActivityItem item = items[i];
                        return HivorrCard(
                          onTap: () => context.go(item.route),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                item.icon,
                                size: 22,
                                color: context.colorScheme.primary,
                              ),
                              const SizedBox(width: HivorrSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      item.title,
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                HivorrFormatters.relative(item.at),
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.at,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final DateTime at;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}
