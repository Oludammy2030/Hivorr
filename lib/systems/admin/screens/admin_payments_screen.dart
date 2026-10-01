import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/shared/components/hivorr_mini_bars.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Admin Payments: platform money-movement operations.
///
/// Visual source of truth: the Admin Dashboard reference screenshots (same
/// white 20px cards, tinted pills, w800 titles, and grey subtitles as
/// Overview / Users / Job Moderation). No payments-specific mock exists, so
/// this screen speaks the established admin visual language instead of
/// inventing a new one.
///
/// Functional source of truth: existing Hivorr architecture. A codebase +
/// migration audit confirmed every money read is self-scoped
/// (`financial_escrow_get`, `financial_status_get`, `dispute_list` are all
/// party/entity-scoped; the only platform-wide admin RPCs are
/// `platform_admin_*`, `manage_user_*`, and the verification review queue).
/// There is no platform transaction-feed RPC, so this screen shows only real,
/// platform-visible data and honest unavailable states — never fabricated
/// totals or transaction rows:
///
/// * Open budgeted demand — derived live from the shared `job_list`
///   discovery read ([JobProvider]), labelled with its loaded scope.
/// * Pending verifications — the live review queue ([AdminReviewProvider]),
///   the payout-readiness pipeline.
/// * Payout readiness — KYC-tier distribution over loaded directory rows
///   ([ManageUserProvider], reused [HivorrMiniBars]).
/// * Escrow holdings — explicit unavailable state naming the missing admin
///   aggregate RPC (per-project reads only).
///
/// Every action navigates to an existing destination. Fail-closed via
/// [AdminGate] like every admin screen. No duplicate services or routes.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
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
      // Provider absent in isolated tests — panels stay in empty states.
    }
    try {
      unawaited(context.read<JobProvider>().loadDiscovery(refresh: true));
    } catch (_) {
      // Optional provider — demand card stays unavailable.
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
          icon: Icon(Icons.admin_panel_settings_outlined,
              color: context.colorScheme.primary),
          title: 'Admin access required',
          subtitle: 'You do not have platform admin privileges.',
        ),
      );
    }

    List<Job> discovery = const <Job>[];
    bool jobsLoading = false;
    try {
      final JobProvider jobs = context.watch<JobProvider>();
      discovery = jobs.discovery;
      jobsLoading = jobs.isLoading;
    } catch (_) {
      // Keep unavailable states.
    }
    ManageUserProvider? users;
    try {
      users = context.watch<ManageUserProvider>();
    } catch (_) {
      users = null;
    }

    final _Demand demand = _demandOf(discovery);
    final String pending = admin.isLoadingQueue && admin.queue.isEmpty
        ? '…'
        : '${admin.queue.length}';

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int statCols = width >= 1100 ? 2 : (width >= 700 ? 2 : 1);
        final bool wideSecondRow = width >= 1100;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Payments',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Platform money movement',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: HivorrSpacing.lg),
              _StatGrid(
                columns: statCols,
                maxWidth: width,
                cards: <Widget>[
                  _PayStatCard(
                    icon: Icons.payments_outlined,
                    iconBg: context.roleTheme.clientContainer,
                    iconFg: context.roleTheme.clientPrimary,
                    label: 'Open Budgeted Demand',
                    value: demand.value,
                    sub: demand.sub,
                    subColor: context.roleTheme.clientPrimary,
                    onTap: () => context.go(RoutePaths.adminJobs),
                  ),
                  _PayStatCard(
                    icon: Icons.verified_user_outlined,
                    iconBg: context.appExtension.successContainer,
                    iconFg: context.appExtension.success,
                    label: 'Pending Verifications',
                    value: pending,
                    sub: 'Payout-readiness pipeline',
                    subColor: context.appExtension.success,
                    onTap: () => context.go(
                        RoutePaths.adminVerificationApprovals),
                  ),
                ],
              ),
              const SizedBox(height: HivorrSpacing.lg),
              if (jobsLoading && discovery.isEmpty)
                const HivorrLoadingState()
              else if (wideSecondRow)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _KycReadinessCard(users: users),
                    ),
                    const SizedBox(width: HivorrSpacing.lg),
                    const Expanded(
                      child: _EscrowHoldingsCard(),
                    ),
                  ],
                )
              else ...<Widget>[
                _KycReadinessCard(users: users),
                const SizedBox(height: HivorrSpacing.lg),
                const _EscrowHoldingsCard(),
              ],
              const SizedBox(height: HivorrSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.columns,
    required this.maxWidth,
    required this.cards,
  });

  final int columns;
  final double maxWidth;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    const double gap = HivorrSpacing.md;
    final double cardWidth =
        (maxWidth - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: <Widget>[
        for (final Widget card in cards)
          SizedBox(width: cardWidth, child: card),
      ],
    );
  }
}

class _PayStatCard extends StatelessWidget {
  const _PayStatCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String value;
  final String sub;
  final Color subColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Widget body = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: iconFg),
          ),
          const SizedBox(width: HivorrSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: body,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
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

/// KYC-tier distribution over loaded directory rows — the payout-readiness
/// picture (cashout limits are KYC-derived). Reuses [HivorrMiniBars]; scope
/// is labelled so partial pagination is never mistaken for a platform total.
class _KycReadinessCard extends StatelessWidget {
  const _KycReadinessCard({required this.users});

  final ManageUserProvider? users;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final ManageUserProvider? provider = users;
    final List<HivorrBarDatum> items =
        provider == null ? const <HivorrBarDatum>[] : _kycOf(provider);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Payout Readiness — KYC Tiers',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Material(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () =>
                      context.go(RoutePaths.adminManageUsers),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text(
                      'View Users',
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.roleTheme.clientPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.md),
          if (provider == null ||
              (provider.isLoading && !provider.isListHydrated))
            const HivorrLoadingState()
          else ...<Widget>[
            HivorrMiniBars(
              items: items,
              emptyLabel:
                  'No KYC tiers on the loaded directory rows yet.',
              accent: context.roleTheme.adminPrimary,
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              provider.isListHydrated
                  ? 'Across ${provider.users.length} loaded rows · '
                      '${provider.totalCount} total users'
                  : 'Directory not loaded yet.',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Honest unavailable state: per-project escrow reads exist, but no admin
/// aggregate RPC reports platform-wide held totals — so none are shown.
class _EscrowHoldingsCard extends StatelessWidget {
  const _EscrowHoldingsCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Escrow Holdings',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: HivorrSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 22,
                  color: context.roleTheme.adminPrimary,
                ),
              ),
              const SizedBox(width: HivorrSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'No platform escrow aggregate yet.',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Escrow reads are per-project (financial_escrow_get). '
                      'Platform-wide held totals need an admin aggregate RPC — '
                      'no mock totals are shown.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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

class _Demand {
  const _Demand({required this.value, required this.sub});

  final String value;
  final String sub;
}

/// Open budgeted demand derived from loaded discovery jobs, grouped by
/// currency with the scope labelled. `—` when nothing budgeted is loaded.
_Demand _demandOf(List<Job> jobs) {
  final List<Job> budgeted = jobs
      .where((Job job) => (job.budgetMax ?? job.budgetMin) != null)
      .toList(growable: false);
  if (budgeted.isEmpty) {
    return const _Demand(
      value: '—',
      sub: 'No budgets in loaded jobs',
    );
  }
  final Map<String, double> sums = <String, double>{};
  final Map<String, int> counts = <String, int>{};
  for (final Job job in budgeted) {
    final double amount = job.budgetMax ?? job.budgetMin ?? 0;
    sums[job.currencyCode] = (sums[job.currencyCode] ?? 0) + amount;
    counts[job.currencyCode] = (counts[job.currencyCode] ?? 0) + 1;
  }
  String top = sums.keys.first;
  for (final String code in sums.keys) {
    if ((counts[code] ?? 0) > (counts[top] ?? 0)) top = code;
  }
  final String symbol = switch (top) {
    'USD' => r'$',
    'NGN' => '₦',
    'GHS' => '₵',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$top ',
  };
  final int others = sums.keys.length - 1;
  return _Demand(
    value:
        '$symbol${HivorrFormatters.number(sums[top] ?? 0, decimals: 0)}',
    sub: '${counts[top]} of ${jobs.length} loaded jobs · $top'
        '${others > 0 ? ' · +$others more currencies' : ''}',
  );
}

List<HivorrBarDatum> _kycOf(ManageUserProvider provider) {
  final Map<String, int> counts = <String, int>{};
  for (final ManageUserListItem user in provider.users) {
    final String? tier = user.kycTier;
    final String label =
        (tier == null || tier.isEmpty) ? 'Unassigned' : tier;
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final List<MapEntry<String, int>> entries = counts.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
        b.value.compareTo(a.value));
  return <HivorrBarDatum>[
    for (final MapEntry<String, int> entry in entries)
      HivorrBarDatum(label: entry.key, value: entry.value),
  ];
}
