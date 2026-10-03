import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/industry.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/profession.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/taxonomy_provider.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/shared/widgets/hivorr_tint_badge.dart';
import 'package:provider/provider.dart';

/// Admin Jobs & Projects: platform hiring visibility (EP-04-03).
///
/// Visual source of truth: Admin Dashboard Jobs reference screenshot — a slim
/// total-jobs count row (the shell top bar already titles the page, §13a)
/// and a responsive 1/2/3-column grid (§21a) of white moderation cards
/// (category pill + green price, semibold title, location · relative-time
/// subtitle, status badge + applicant count, `View` / `Remove` actions;
/// terminal jobs show `View` only).
///
/// Functional source of truth: existing Hivorr architecture. Lists open jobs
/// via the shared `job_list` discovery read ([JobProvider.loadDiscovery] —
/// the same RPC any authenticated entity may call). `View` reuses the
/// existing job-detail destination ([RoutePaths.dashboardJobDetail]) via
/// `push` so back navigation returns to the moderation queue. `Remove` is a
/// confirm-gated cancellation through the existing [JobProvider.cancel]
/// (`job_cancel`) implementation — the only job-removal path in the
/// architecture; backend authority stays with the owning entity, so a denial
/// surfaces honestly instead of faking the control. Fail-closed via
/// [AdminGate] like every admin screen. No duplicate services or routes.
///
/// Fields with no backend source are never fabricated: the client-name line
/// shows the real location (or just the relative time), and the
/// Digital/Physical type pill is omitted (jobs carry no work-mode field).
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final Set<String> _actingIds = <String>{};

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

    if (!AdminGate.isAdmin(admin)) {
      return SafeArea(
        child: HivorrEmptyState(
          icon: Icon(
            Icons.admin_panel_settings_outlined,
            color: context.colorScheme.primary,
          ),
          title: 'Admin access required',
          subtitle: 'You do not have platform admin privileges.',
        ),
      );
    }

    if (jobs.isLoading && jobs.discovery.isEmpty) {
      return const SafeArea(child: HivorrLoadingState());
    }
    if (jobs.lastError != null && jobs.discovery.isEmpty) {
      return SafeArea(
        child: HivorrErrorState(
          message: 'Could not load jobs',
          detail: jobs.lastError!.message,
          onRetry: () => unawaited(jobs.loadDiscovery(refresh: true)),
        ),
      );
    }
    if (jobs.discovery.isEmpty) {
      return const SafeArea(
        child: HivorrEmptyState(
          title: 'No open jobs',
          subtitle:
              'Open hiring requests across the platform will appear here.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // Content-card columns (§21a): 1 col <600, 2 cols 600–1023, 3 cols
        // ≥1024 — never capped at 2 like the old grid.
        final int columns = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        final EdgeInsets gutter = MobileCompact.scrollPaddingFor(width);
        return RefreshIndicator(
          onRefresh: () => jobs.loadDiscovery(refresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: gutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // No in-body H1: the shell top bar already titles this page.
                Text(
                  '${jobs.discovery.length} total jobs',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
                HivorrStatGrid(
                  columns: columns,
                  maxWidth: width - gutter.horizontal,
                  children: <Widget>[
                    for (final Job job in jobs.discovery)
                      _ModerationCard(
                        job: job,
                        acting: _actingIds.contains(job.id),
                        onView: () => context.push(
                          RoutePaths.dashboardJobDetail(job.id),
                        ),
                        onRemove: () => _removeJob(context, jobs, job),
                      ),
                  ],
                ),
                if (jobs.discoveryHasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: HivorrSpacing.md,
                    ),
                    child: Center(
                      child: HivorrButton(
                        label: 'Load more',
                        variant: HivorrButtonVariant.outline,
                        size: HivorrButtonSize.small,
                        isLoading: jobs.isLoading,
                        onPressed: () => unawaited(jobs.loadDiscovery()),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: HivorrSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeJob(
    BuildContext context,
    JobProvider jobs,
    Job job,
  ) async {
    if (_actingIds.contains(job.id)) return;
    final bool confirmed = await _confirm(
      context,
      title: 'Remove',
      message:
          'Remove "${job.title}"? This cancels the job across the '
          'platform. Cancellation runs through the standard job lifecycle, '
          'so the owning client retains authority.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    setState(() => _actingIds.add(job.id));
    try {
      await jobs.cancel(job.id, reason: 'Admin moderation removal');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job removed.')));
      unawaited(jobs.loadDiscovery(refresh: true));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removal failed: ${e.message}')));
    } finally {
      if (mounted) setState(() => _actingIds.remove(job.id));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => HivorrDialog(
        title: title,
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// White moderation card from the reference: category pill + green price,
/// bold title, location · relative-time subtitle, status pill + applicant
/// count, `View` / `Remove` pills (`View` only for terminal jobs, mirroring
/// the reference completed card).
class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.job,
    required this.acting,
    required this.onView,
    required this.onRemove,
  });

  final Job job;
  final bool acting;
  final VoidCallback onView;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String? category = _categoryOf(context, job);
    final bool removable = job.isEditable;

    return HivorrCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (category != null) ...<Widget>[
                HivorrTintBadge(
                  label: category,
                  foreground: context.roleTheme.clientPrimary,
                  background: context.roleTheme.clientContainer,
                ),
                const SizedBox(width: HivorrSpacing.sm),
              ],
              const Spacer(),
              Text(
                _priceOf(job),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.appExtension.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Text(
            job.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _subtitleOf(job),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Row(
            children: <Widget>[
              HivorrBadge(
                label: _statusLabelOf(job.status),
                variant: _statusVariantOf(job.status),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Text(
                  '${job.applicationsCount} applicants',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              // Flexible trailing cluster: one line when it fits (the
              // reference look), wraps instead of overflowing under long
              // locales or narrow cards.
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: HivorrSpacing.sm,
                  runSpacing: HivorrSpacing.sm,
                  children: <Widget>[
                    HivorrTableAction(
                      icon: Icons.visibility_outlined,
                      label: 'View',
                      foreground: colors.onSurfaceVariant,
                      background: colors.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      onTap: acting ? null : onView,
                    ),
                    if (removable)
                      HivorrTableAction(
                        icon: Icons.close,
                        label: 'Remove',
                        foreground: colors.error,
                        background: colors.errorContainer,
                        onTap: acting ? null : onRemove,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Screenshot status vocabulary mapped onto the real six-state job status
/// (§21b): `open` stays open (success); active non-open work (`paused`,
/// `awarded`) reads as in-progress (warning); terminal states stay neutral,
/// with `cancelled` in error red to match the admin Suspended convention.
String _statusLabelOf(String status) => switch (status) {
  'open' => 'open',
  'paused' || 'awarded' => 'in-progress',
  'completed' => 'completed',
  'cancelled' => 'cancelled',
  _ => status,
};

HivorrBadgeVariant _statusVariantOf(String status) => switch (status) {
  'open' => HivorrBadgeVariant.success,
  'paused' || 'awarded' => HivorrBadgeVariant.warning,
  'cancelled' => HivorrBadgeVariant.error,
  _ => HivorrBadgeVariant.neutral,
};

/// Category pill resolved best-effort from the already-cached taxonomy
/// (profession name, else industry name). No new RPCs are issued for labels;
/// unresolvable jobs simply omit the pill instead of showing invented text.
String? _categoryOf(BuildContext context, Job job) {
  final TaxonomyProvider? taxonomy = _maybeTaxonomy(context);
  if (taxonomy == null) return null;
  final String? professionId = job.professionId;
  if (professionId != null && professionId.isNotEmpty) {
    for (final List<Profession> list in taxonomy.professionsByIndustry.values) {
      for (final Profession profession in list) {
        if (profession.id == professionId) return profession.name;
      }
    }
  }
  final String? industryId = job.industryId;
  if (industryId != null && industryId.isNotEmpty) {
    for (final Industry industry in taxonomy.industries) {
      if (industry.id == industryId) return industry.name;
    }
  }
  return null;
}

TaxonomyProvider? _maybeTaxonomy(BuildContext context) {
  try {
    return context.watch<TaxonomyProvider>();
  } catch (_) {
    return null;
  }
}

/// Green price from the real budget (`max`, else `min`) with a currency
/// symbol where one is unambiguous. Jobs without a budget show `—`.
String _priceOf(Job job) {
  final double? amount = job.budgetMax ?? job.budgetMin;
  if (amount == null) return '—';
  final String symbol = switch (job.currencyCode) {
    'USD' => r'$',
    'NGN' => '₦',
    'GHS' => '₵',
    'EUR' => '€',
    'GBP' => '£',
    _ => '${job.currencyCode} ',
  };
  return '$symbol${HivorrFormatters.number(amount, decimals: 0)}';
}

/// Real location (when set) plus the relative publish time.
String _subtitleOf(Job job) {
  final String when = HivorrFormatters.relative(job.postedAt ?? job.createdAt);
  final String? location = job.location?.trim();
  if (location != null && location.isNotEmpty) {
    return '$location · $when';
  }
  return when;
}
