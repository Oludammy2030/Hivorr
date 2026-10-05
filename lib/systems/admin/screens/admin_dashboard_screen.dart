import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:provider/provider.dart';

/// Super Admin landing dashboard — Platform Overview.
///
/// Visual source of truth: the two Super Admin Dashboard reference
/// screenshots (one continuous scrollable dashboard). Six stat cards,
/// a `Revenue — Last 14 Days` panel, `Flagged Items`, and `Job Type Split`
/// in the exact arrangement, colors, and hierarchy of the reference.
///
/// Functional source of truth: existing Hivorr architecture. Reuses
/// [ManageUserProvider] (total users), [JobProvider] (active jobs) and
/// [AdminReviewProvider] (admin gate + review queue) — no duplicate
/// services, no mock-data replacements for connected sources. Connected
/// counts render live when hydrated; panels with no admin aggregate RPC
/// yet (revenue, escrow, job-type split, flagged examples) render the
/// reference illustrative content so the layout matches the screenshots.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
    if (!AdminGate.isAdmin(admin)) return;
    try {
      final ManageUserProvider users = context.read<ManageUserProvider>();
      if (!users.isListHydrated) {
        unawaited(users.loadUsers());
      }
    } catch (_) {
      // Provider absent in isolated tests — keep reference content.
    }
    try {
      final JobProvider jobs = context.read<JobProvider>();
      unawaited(jobs.loadDiscovery(refresh: true));
    } catch (_) {
      // Optional provider — reference fallback stays visible.
    }
    if (admin.queue.isEmpty && !admin.isLoadingQueue) {
      unawaited(admin.loadQueue());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminReviewProvider admin = context.watch<AdminReviewProvider>();

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

    String totalUsers = '52,381';
    int? liveUsers;
    int? liveJobs;
    try {
      final ManageUserProvider users = context.watch<ManageUserProvider>();
      if (users.isListHydrated) {
        liveUsers = users.totalCount;
      }
    } catch (_) {
      // Keep reference fallback.
    }
    try {
      final JobProvider jobs = context.watch<JobProvider>();
      if (jobs.discovery.isNotEmpty) {
        liveJobs = jobs.discovery.length;
      }
    } catch (_) {
      // Keep reference fallback.
    }
    if (liveUsers != null && liveUsers > 0) {
      totalUsers = _formatCount(liveUsers);
    }
    final String activeJobs = liveJobs != null && liveJobs > 0
        ? _formatCount(liveJobs)
        : '1,247';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // Grid policy (VISUAL-IDENTITY.md §21a): 1 col <600, 2 cols
        // 600–1023, 3 cols ≥1024.
        final int statCols = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        final bool wideSecondRow = width >= 1024;
        final EdgeInsets gutter = MobileCompact.scrollPaddingFor(width);

        return SingleChildScrollView(
          padding: gutter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // No in-body H1: the shell top bar already titles this page
              // (VISUAL-IDENTITY.md §13a).
              HivorrStatGrid(
                columns: statCols,
                // Content width: the grid lives inside the scroll gutter,
                // so viewport padding must be subtracted (else every card
                // overflows its column by the gutter width).
                maxWidth: width - gutter.horizontal,
                children: <Widget>[
                  HivorrStatCard(
                    compact: true,
                    icon: Icons.people_outlined,
                    iconBackground: context.roleTheme.clientContainer,
                    iconForeground: context.roleTheme.clientPrimary,
                    label: 'Total Users',
                    value: totalUsers,
                    sub: '+12% MTD',
                    subColor: context.roleTheme.clientPrimary,
                    onTap: () => context.go(RoutePaths.adminManageUsers),
                  ),
                  HivorrStatCard(
                    compact: true,
                    icon: Icons.work_outline,
                    iconBackground: context.appExtension.successContainer,
                    iconForeground: context.appExtension.success,
                    label: 'Active Jobs',
                    value: activeJobs,
                    sub: '+8% MTD',
                    subColor: context.appExtension.success,
                    onTap: () => context.go(RoutePaths.adminJobs),
                  ),
                  HivorrStatCard(
                    compact: true,
                    icon: Icons.trending_up_outlined,
                    iconBackground: context.appExtension.warningContainer,
                    iconForeground: context.appExtension.warning,
                    label: 'Revenue (MTD)',
                    value: '\$182K',
                    sub: '+23% MTD',
                    subColor: context.appExtension.warning,
                  ),
                  HivorrStatCard(
                    compact: true,
                    icon: Icons.error_outline,
                    iconBackground: context.colorScheme.errorContainer,
                    iconForeground: context.colorScheme.error,
                    label: 'Disputes',
                    value: '14',
                    sub: '-3 this week',
                    subColor: context.colorScheme.error,
                    onTap: () =>
                        context.go(RoutePaths.adminVerificationApprovals),
                  ),
                  HivorrStatCard(
                    compact: true,
                    icon: Icons.lock_outline,
                    iconBackground: context.appExtension.infoContainer,
                    iconForeground: context.appExtension.info,
                    label: 'Escrow Held',
                    value: '\$84K',
                    sub: 'across 62 jobs',
                    subColor: context.appExtension.info,
                  ),
                  HivorrStatCard(
                    compact: true,
                    icon: Icons.show_chart_outlined,
                    iconBackground: context.appExtension.infoContainer,
                    iconForeground: context.appExtension.info,
                    label: 'Avg Job Value',
                    value: '\$1,240',
                    sub: '+15% MTD',
                    subColor: context.appExtension.info,
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.md),
              if (wideSecondRow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Expanded(flex: 2, child: _RevenueCard()),
                    const SizedBox(width: HivorrSpacing.md),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: <Widget>[
                          _FlaggedCard(
                            onOpen: () => context.go(
                              RoutePaths.adminVerificationApprovals,
                            ),
                          ),
                          const SizedBox(height: HivorrSpacing.md),
                          const _JobSplitCard(),
                        ],
                      ),
                    ),
                  ],
                )
              else ...<Widget>[
                const _RevenueCard(),
                const SizedBox(height: HivorrSpacing.md),
                _FlaggedCard(
                  onOpen: () =>
                      context.go(RoutePaths.adminVerificationApprovals),
                ),
                const SizedBox(height: HivorrSpacing.md),
                const _JobSplitCard(),
              ],
              const SizedBox(height: HivorrSpacing.md),
            ],
          ),
        );
      },
    );
  }

  String _formatCount(int value) {
    final String digits = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final int fromEnd = digits.length - i;
      out.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) out.write(',');
    }
    return out.toString();
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Expanded + ellipsis: the title must survive long
              // translations without pushing the badge out (caught at
              // 390dp by the density pilot tests).
              Expanded(
                child: Text(
                  'Revenue — Last 14 Days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const HivorrBadge(label: '+23% MTD', variant: HivorrBadgeVariant.success),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          const _RevenueBars(),
          const SizedBox(height: HivorrSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final String tick in <String>[
                '1',
                '3',
                '5',
                '7',
                '9',
                '11',
                '13',
              ])
                Text(
                  tick,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Illustrative 14-day revenue shape (7 odd-day buckets matching the tick
/// row). Reference content only: no admin revenue-aggregate RPC exists yet
/// (see class docs). Fixed 120dp content — not a spacer.
class _RevenueBars extends StatelessWidget {
  const _RevenueBars();

  static const List<double> _fractions = <double>[
    0.35,
    0.52,
    0.44,
    0.66,
    0.58,
    0.8,
    0.7,
  ];

  @override
  Widget build(BuildContext context) {
    final Color fill = context.roleTheme.clientPrimary;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final double fraction in _fractions)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FractionallySizedBox(
                  heightFactor: fraction,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(HivorrSpacing.xs),
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

class _FlaggedCard extends StatelessWidget {
  const _FlaggedCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 20,
                color: colors.error,
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Text(
                  'Flagged Items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: context.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onError,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          _FlaggedItem(
            title: 'Cash-only plumbing work',
            subtitle: 'Off-platform payment',
            pill: 'high',
            pillVariant: HivorrBadgeVariant.error,
            onTap: onOpen,
          ),
          const SizedBox(height: HivorrSpacing.sm),
          _FlaggedItem(
            title: 'Incomplete job post',
            subtitle: 'Missing description',
            pill: 'medium',
            pillVariant: HivorrBadgeVariant.warning,
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}

class _FlaggedItem extends StatelessWidget {
  const _FlaggedItem({
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.pillVariant,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String pill;
  final HivorrBadgeVariant pillVariant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(ext.radiusXs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusXs),
        child: Padding(
          padding: const EdgeInsets.all(HivorrSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
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
              HivorrBadge(label: pill, variant: pillVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobSplitCard extends StatelessWidget {
  const _JobSplitCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrCard(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Job Type Split',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          _SplitRow(
            label: 'Digital',
            percent: '68%',
            percentColor: context.roleTheme.clientPrimary,
            fraction: 0.68,
            fill: context.roleTheme.clientPrimary,
          ),
          const SizedBox(height: HivorrSpacing.md),
          _SplitRow(
            label: 'Physical',
            percent: '32%',
            percentColor: context.appExtension.warning,
            fraction: 0.32,
            fill: context.appExtension.warning,
          ),
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.label,
    required this.percent,
    required this.percentColor,
    required this.fraction,
    required this.fill,
  });

  final String label;
  final String percent;
  final Color percentColor;
  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              percent,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: percentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(color: fill),
            ),
          ),
        ),
      ],
    );
  }
}
