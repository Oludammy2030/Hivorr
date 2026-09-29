import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/systems/dashboard/widgets/dashboard_cards.dart';
import 'package:provider/provider.dart';

/// Admin Jobs & Projects: platform hiring visibility (EP-04-03).
///
/// Lists open jobs across the platform (`job_list` discovery read — the same
/// RPC any authenticated entity may call) so platform operators can observe
/// hiring activity. Per-row moderation (pause/cancel foreign jobs) is not
/// granted: no admin jobs RPC exists yet, and client authority stays with
/// the owning entity — the screen states this explicitly instead of faking
/// controls. Fail-closed via [AdminGate] like every admin screen.
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    if (!mounted) return;
    final AdminReviewProvider admin = context.read<AdminReviewProvider>();
    await admin.checkAdmin();
    if (!mounted) return;
    if (AdminGate.isAdmin(admin)) {
      unawaited(context.read<JobProvider>().loadDiscovery(refresh: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider admin = context.watch<AdminReviewProvider>();
    final JobProvider jobs = context.watch<JobProvider>();
    final bool isAdmin = AdminGate.isAdmin(admin);

    return Scaffold(
      appBar: AppBar(
        title: Text('Jobs & Projects', style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                unawaited(jobs.loadDiscovery(refresh: true)),
          ),
        ],
      ),
      body: SafeArea(
        child: !isAdmin
            ? HivorrEmptyState(
                icon: Icon(Icons.admin_panel_settings_outlined,
                    color: context.colorScheme.primary),
                title: 'Admin access required',
                subtitle: 'You do not have platform admin privileges.',
              )
            : jobs.isLoading && jobs.discovery.isEmpty
            ? const HivorrLoadingState()
            : jobs.lastError != null && jobs.discovery.isEmpty
            ? HivorrErrorState(
                message: 'Could not load jobs',
                detail: jobs.lastError!.message,
                onRetry: () =>
                    unawaited(jobs.loadDiscovery(refresh: true)),
              )
            : jobs.discovery.isEmpty
            ? const HivorrEmptyState(
                title: 'No open jobs',
                subtitle:
                    'Open hiring requests across the platform will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(HivorrSpacing.lg),
                itemCount: jobs.discovery.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: HivorrSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final job = jobs.discovery[i];
                  return JobCard(
                    job: job,
                    onTap: () =>
                        context.go(RoutePaths.dashboardJobDetail(job.id)),
                  );
                },
              ),
      ),
    );
  }
}
