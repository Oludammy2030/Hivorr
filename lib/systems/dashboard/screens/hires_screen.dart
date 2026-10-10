import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/messaging_provider.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/systems/dashboard/shell/professional_mobile_chrome.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_cards.dart';
import 'package:provider/provider.dart';

/// Hires list for one side of the engagement (EP-04-03).
///
/// [role] is `client` (My Jobs → professionals hired) or `professional`
/// (Professional Dashboard → My Jobs → Active | Applied | Completed).
///
/// Client keeps the established status-chip list. Professional renders the
/// My Jobs reference exactly: top bar (menu, title, bell, Professional pill,
/// dynamic avatar), `My Jobs` header, `Active | Applied | Completed` phase
/// tabs in place (no navigation, no full reload), the Active two-column
/// reference cards (status + category pills, title, client · budget,
/// milestone progress, Chat / Submit Work), the Applied single-column
/// reference rows (title + Shortlisted/Pending/Hired pill, client · applied
/// date, proposed rate, Contact Employer on hired) and the Completed
/// two-column reference cards (Completed + category pills, time ago, title,
/// client · Earned, stars + Paid).
///
/// Data stays on the existing seams: Active reads
/// `hire_list_mine(role: professional)` via [HireProvider] (client-side
/// active filter) enriched with known [Job] rows (budget/category) via
/// [JobProvider]; Applied reads `application_list_mine` via
/// [JobProvider.myApplications] enriched the same way, with hired rows
/// resolving their hire (same application/job) for the Contact Employer
/// thread; Completed filters the same hire list client-side
/// (`completed`/`closed`) with the joined job budget as the earned proxy
/// (hires carry no money — amounts live on linked service contracts).
class HiresScreen extends StatefulWidget {
  const HiresScreen({super.key, required this.role});

  /// `client` or `professional`.
  final String role;

  bool get isClient => role != 'professional';

  @override
  State<HiresScreen> createState() => _HiresScreenState();
}

class _HiresScreenState extends State<HiresScreen> {
  String? _statusFilter;

  /// Professional My Jobs phase (`active` | `applied` | `completed`).
  /// All three are views of this same page — selecting one only swaps the
  /// body content (no navigation, no full reload).
  String _proPhase = 'active';

  static const List<String?> _filters = <String?>[
    null,
    'pending',
    'active',
    'completed',
    'cancelled',
    'disputed',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(HiresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _statusFilter = null;
      _proPhase = 'active';
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() {
    if (widget.isClient) {
      return context.read<HireProvider>().loadList(
        role: widget.role,
        status: _statusFilter,
      );
    }
    if (_proPhase == 'applied') {
      return _loadProfessionalApplied();
    }
    if (_proPhase == 'completed') {
      return _loadProfessionalCompleted();
    }
    return _loadProfessionalActive();
  }

  /// Shared professional hydration: all professional hires (Active filters
  /// `isActive` client-side; hired Applied rows resolve their contract from
  /// the same list) plus the applied-jobs list used to enrich cards with
  /// budget/category and client labels.
  Future<void> _loadProfessionalHiresAndJobs() async {
    await context.read<HireProvider>().loadList(role: 'professional');
    if (!mounted) return;
    try {
      await context.read<JobProvider>().loadMine(role: 'applied');
    } catch (_) {
      // Enrichment only — hires/applications already loaded drive the UI.
    }
  }

  /// Active-phase hydration: professional hires plus the applied-jobs list
  /// used to enrich cards. Sequential on purpose — the job list is only
  /// enrichment (a job failure must not blank the hires).
  Future<void> _loadProfessionalActive() =>
      _loadProfessionalHiresAndJobs();

  /// Applied-phase hydration: own applications first (the list driver), then
  /// hires + jobs for enrichment and Contact Employer resolution.
  /// Sequential on purpose — [JobProvider] owns one load gate for
  /// `loadApplications`/`loadMine`, so concurrent calls would early-return
  /// and drop a list.
  Future<void> _loadProfessionalApplied() async {
    await context.read<JobProvider>().loadApplications();
    if (!mounted) return;
    await _loadProfessionalHiresAndJobs();
  }

  /// Best-effort Applied hydration when the tab is first selected with an
  /// empty application list. Only the phase content loads — the page stays
  /// in place, no navigation, no full reload.
  Future<void> _ensureAppliedLoaded() async {
    JobProvider jobs;
    try {
      jobs = context.read<JobProvider>();
    } catch (_) {
      return;
    }
    if (jobs.myApplications.isNotEmpty || jobs.isLoading) return;
    await _loadProfessionalApplied();
  }

  /// Completed-phase hydration: the shared professional hires + jobs list
  /// (Completed filters `completed`/`closed` client-side).
  Future<void> _loadProfessionalCompleted() =>
      _loadProfessionalHiresAndJobs();

  /// Best-effort Completed hydration when the tab is first selected with an
  /// empty hire list. Only the phase content loads — the page stays in
  /// place, no navigation, no full reload.
  Future<void> _ensureCompletedLoaded() async {
    HireProvider hires;
    try {
      hires = context.read<HireProvider>();
    } catch (_) {
      return;
    }
    if (hires.hires.isNotEmpty || hires.isLoading) return;
    await _loadProfessionalCompleted();
  }

  void _onPhaseSelected(String phase) {
    setState(() => _proPhase = phase);
    if (phase == 'applied') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureAppliedLoaded(),
      );
    }
    if (phase == 'completed') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureCompletedLoaded(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isClient) {
      return _ClientHiresView(
        role: widget.role,
        statusFilter: _statusFilter,
        filters: _filters,
        onSelectFilter: (String? filter) {
          setState(() => _statusFilter = filter);
          unawaited(_load());
        },
        onRefresh: _load,
      );
    }
    final bool isMobile = context.breakpoint == Breakpoint.mobile;
    if (isMobile) {
      return Scaffold(
        // Shared professional chrome: single `My Jobs` title with the bell +
        // Professional pill + avatar on one compact row. Bottom navigation
        // lives in the dashboard shell. No refresh action — the phase body
        // below owns pull-to-refresh (same contract as client chrome).
        appBar: const ProfessionalMobileAppBar(title: 'My Jobs'),
        body: MobileSafeBody(
          child: _ProfessionalMyJobsBody(
            phase: _proPhase,
            onPhaseSelected: _onPhaseSelected,
            onRefresh: _load,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: MobileSafeBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _ProMyJobsTopBar(),
            Expanded(
              child: _ProfessionalMyJobsBody(
                phase: _proPhase,
                onPhaseSelected: _onPhaseSelected,
                onRefresh: _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Client branch — preserved exactly (status chips + hire rows).
class _ClientHiresView extends StatelessWidget {
  const _ClientHiresView({
    required this.role,
    required this.statusFilter,
    required this.filters,
    required this.onSelectFilter,
    required this.onRefresh,
  });

  final String role;
  final String? statusFilter;
  final List<String?> filters;
  final ValueChanged<String?> onSelectFilter;
  final Future<void> Function() onRefresh;

  bool get isClient => role != 'professional';

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final bool isClientView = isClient;

    String label(String status) =>
        status[0].toUpperCase() + status.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isClientView ? 'Hired Professionals' : 'My Work',
          style: context.textTheme.titleLarge,
        ),
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
                itemCount: filters.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: HivorrSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final String? filter = filters[i];
                  return HivorrChip(
                    label: filter == null ? 'All' : label(filter),
                    isSelected: statusFilter == filter,
                    onSelected: (_) => onSelectFilter(filter),
                  );
                },
              ),
            ),
            if (hires.hires.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HivorrSpacing.md,
                  HivorrSpacing.xs,
                  HivorrSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    statusFilter == null
                        ? '${hires.hires.length} ${isClientView ? 'hires' : 'contracts'}'
                        : '${hires.hires.length} · ${label(statusFilter!)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: hires.isLoading && hires.hires.isEmpty
                  ? const HivorrLoadingState()
                  : hires.lastError != null && hires.hires.isEmpty
                  ? HivorrErrorState(
                      message: 'Could not load hires',
                      detail: hires.lastError!.message,
                      onRetry: () => unawaited(onRefresh()),
                    )
                  : hires.hires.isEmpty
                  ? HivorrEmptyState(
                      title: isClientView ? 'No hires yet' : 'No work yet',
                      subtitle: isClientView
                          ? 'Shortlist an application and hire to start working with a professional.'
                          : 'Accepted applications become work here once a client hires you.',
                      actionButton: null,
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(HivorrSpacing.md),
                        itemCount: hires.hires.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: HivorrSpacing.sm),
                        itemBuilder: (BuildContext context, int i) {
                          final Hire hire = hires.hires[i];
                          return HireCard(
                            hire: hire,
                            onTap: () => context.go(
                              RoutePaths.dashboardHireDetail(hire.id),
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
}

// ── Professional My Jobs (reference) ───────────────────────────────────────

/// Professional top bar from the reference: menu tile, `My Jobs` title, bell
/// with attention dot, green Professional pill and the dynamic-initials
/// account avatar (AuthSession — never hardcoded). Reuses the main Hivorr
/// logo via the sidebar (no substitute logo created here).
class _ProMyJobsTopBar extends StatelessWidget {
  const _ProMyJobsTopBar();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    bool hasDot = false;
    try {
      hasDot = context
          .watch<HireProvider>()
          .hires
          .where((Hire hire) => hire.isActive)
          .isNotEmpty;
    } catch (_) {
      hasDot = false;
    }
    final ({String name, String initials}) identity = _proIdentity(context);
    return HivorrDashboardTopBar(
      title: 'My Jobs',
      accentPrimary: roles.professionalPrimary,
      accentContainer: roles.professionalContainer,
      modeLabel: 'Professional',
      initials: identity.initials,
      avatarTooltip: identity.name,
      showDot: hasDot,
      onMenu: () {
        final ScaffoldState? scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer) {
          scaffold.openDrawer();
        }
      },
      onNotifications: () => context.go(RoutePaths.dashboardNotifications),
      onAvatar: () => context.go(RoutePaths.dashboardAccount),
    );
  }
}

/// Professional body: header + phase tabs + phase content. Tabs switch the
/// displayed content in place — no navigation, no full-page reload.
class _ProfessionalMyJobsBody extends StatelessWidget {
  const _ProfessionalMyJobsBody({
    required this.phase,
    required this.onPhaseSelected,
    required this.onRefresh,
  });

  final String phase;
  final ValueChanged<String> onPhaseSelected;
  final Future<void> Function() onRefresh;

  static const double _contentMaxWidth = 1120;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: MobileCompact.scrollPaddingForBreakpoint(context.breakpoint),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // The shared mobile bar already titles this page, so the
                // in-body heading shows on wider layouts only (same contract
                // as the client Applications inbox).
                if (context.breakpoint != Breakpoint.mobile)
                  const _ProMyJobsHeader(),
                if (context.breakpoint != Breakpoint.mobile)
                  const SizedBox(height: HivorrSpacing.lg),
                _ProPhaseTabs(
                  activePhase: phase,
                  onSelect: onPhaseSelected,
                ),
                const SizedBox(height: HivorrSpacing.lg),
                switch (phase) {
                  'applied' => _ProAppliedList(onRetry: onRefresh),
                  'completed' => _ProCompletedGrid(onRetry: onRefresh),
                  _ => _ProActiveGrid(onRetry: onRefresh),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reference header: `My Jobs` + `Track your active work and applications`.
class _ProMyJobsHeader extends StatelessWidget {
  const _ProMyJobsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'My Jobs',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Text(
          'Track your active work and applications',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Reference phase tabs: white container with `Active | Applied | Completed`.
/// Active is filled with the professional green; the others are quiet until
/// their phases land. Selection stays on this page.
class _ProPhaseTabs extends StatelessWidget {
  const _ProPhaseTabs({required this.activePhase, required this.onSelect});

  final String activePhase;
  final ValueChanged<String> onSelect;

  static const List<(String, String)> _phases = <(String, String)>[
    ('active', 'Active'),
    ('applied', 'Applied'),
    ('completed', 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Horizontal scroll (same pattern as _TabRow): three pills exceed
        // 320dp viewports and must swipe, never overflow.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < _phases.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                _ProPhasePill(
                  label: _phases[i].$2,
                  selected: _phases[i].$1 == activePhase,
                  selectedFill: roles.professionalPrimary,
                  onTap: () => onSelect(_phases[i].$1),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProPhasePill extends StatelessWidget {
  const _ProPhasePill({
    required this.label,
    required this.selected,
    required this.selectedFill,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: HivorrSpacing.lg,
            vertical: HivorrSpacing.smMd,
          ),
          decoration: BoxDecoration(
            color: selected ? selectedFill : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Active grid: professional active hires as reference cards, two columns on
/// wide layouts, one column below the grid breakpoint.
class _ProActiveGrid extends StatelessWidget {
  const _ProActiveGrid({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final JobProvider jobs = context.watch<JobProvider>();
    final List<Hire> active = hires.hires
        .where((Hire hire) => hire.isActive)
        .toList(growable: false);
    final Map<String, Job> byId = <String, Job>{
      for (final Job job in _proAllKnownJobs(jobs)) job.id: job,
    };

    if (hires.isLoading && hires.hires.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: HivorrSpacing.xl),
        child: HivorrLoadingState(),
      );
    }
    if (hires.lastError != null && hires.hires.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: hires.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (active.isEmpty) {
      final bool compact = context.breakpoint == Breakpoint.mobile;
      return HivorrEmptyState(
        compact: compact,
        title: 'No active jobs yet',
        subtitle:
            'Accepted hires appear here once a client hires you. Browse open work to apply.',
        actionButton: HivorrButton(
          label: 'Find Work',
          size: compact ? HivorrButtonSize.small : HivorrButtonSize.medium,
          onPressed: () => context.go(RoutePaths.dashboardOpportunities),
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // Content-card columns (§21a): 1 col <600, 2 cols 600–1023,
        // 3 cols ≥1024.
        final double width = c.maxWidth;
        final int columns = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        return HivorrStatGrid(
          columns: columns,
          maxWidth: width,
          children: <Widget>[
            for (final Hire hire in active)
              _ProActiveJobCard(hire: hire, job: byId[hire.jobId]),
          ],
        );
      },
    );
  }
}

/// Reference Active card: `In Progress` + category pills, title,
/// `client · budget` subtitle, milestone progress with 60% bar, then
/// Chat (light blue) + Submit Work (brand blue) actions.
///
/// Client names are not exposed to the professional dashboard, so the
/// subtitle falls back to the description lead / location (overview
/// convention) — never invented. Amounts join from the known [Job] row;
/// hires carry no money fields (amounts live on linked service contracts).
/// Milestone breakdown also lives on the contract/escrow side, so the bar
/// renders the reference 60% until the milestone seam lands.
class _ProActiveJobCard extends StatelessWidget {
  const _ProActiveJobCard({required this.hire, this.job});

  final Hire hire;
  final Job? job;

  /// Reference milestone fill (60%) until contract milestones are exposed.
  static const double _progress = 0.6;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final RoleThemeExtension roles = context.roleTheme;
    final double radius = context.appExtension.radiusMd + 4;
    final String title = hire.jobTitle ?? job?.title ?? 'Job';
    final String subtitle = _proSubtitle(hire, job);
    final String category = _proCategory(job) ?? 'General';

    // Canonical card shell: HivorrCard reproduces the reference surface,
    // radius (20, preserved from the reference), Level-1 shadow, and padding
    // exactly, adding the shared splash + button semantics.
    return HivorrCard(
      onTap: () => context.go(RoutePaths.dashboardHireDetail(hire.id)),
      borderRadius: radius,
      elevation: 1,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.xs,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ext.warningContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'In Progress',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: ext.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Milestone progress',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '60%',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: roles.professionalPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(
                  alpha: context.isDarkMode ? 1.0 : 0.55,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: roles.professionalPrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              children: <Widget>[
                _ProCardAction(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  fill: colors.primaryContainer.withValues(
                    alpha: context.isDarkMode ? 0.5 : 0.7,
                  ),
                  foreground: colors.primary,
                  onTap: () => context.go(RoutePaths.dashboardMessages),
                ),
                _ProCardAction(
                  label: 'Submit Work',
                  icon: Icons.check_circle_outline,
                  fill: colors.primary,
                  foreground: colors.onPrimary,
                  onTap: () =>
                      context.go(RoutePaths.dashboardHireDetail(hire.id)),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _ProCardAction extends StatelessWidget {
  const _ProCardAction({
    required this.label,
    required this.icon,
    required this.fill,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: HivorrTableAction(
        label: label,
        icon: icon,
        foreground: foreground,
        background: fill,
        onTap: onTap,
      ),
    );
  }
}

// ── Professional My Jobs → Applied ─────────────────────────────────────────

/// Applied list: the professional's own applications as single-column
/// reference rows (newest first), driven by `application_list_mine` via
/// [JobProvider.myApplications] and enriched with known [Job] rows for the
/// client label. Shortlisted / Pending / Hired pills keep the reference
/// colors exactly; hired rows carry the Contact Employer action.
class _ProAppliedList extends StatelessWidget {
  const _ProAppliedList({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final List<JobApplication> applications = jobs.myApplications
        .toList(growable: false)
      ..sort(
        (JobApplication a, JobApplication b) =>
            b.submittedAt.compareTo(a.submittedAt),
      );
    final Map<String, Job> byId = <String, Job>{
      for (final Job job in _proAllKnownJobs(jobs)) job.id: job,
    };

    if (jobs.isLoading && jobs.myApplications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: HivorrSpacing.xl),
        child: HivorrLoadingState(),
      );
    }
    if (jobs.lastError != null && jobs.myApplications.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load applications',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (applications.isEmpty) {
      final bool compact = context.breakpoint == Breakpoint.mobile;
      return HivorrEmptyState(
        compact: compact,
        title: 'No applications yet',
        subtitle:
            'Browse open work and submit your first application to get started.',
        actionButton: HivorrButton(
          label: 'Find Work',
          size: compact ? HivorrButtonSize.small : HivorrButtonSize.medium,
          onPressed: () => context.go(RoutePaths.dashboardOpportunities),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < applications.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: HivorrSpacing.md),
          _ProAppliedCard(
            application: applications[i],
            job: byId[applications[i].jobId],
          ),
        ],
      ],
    );
  }
}

/// Reference Applied row: title + status pill, `client · Applied …`
/// subtitle, `Proposed: …` rate, and Contact Employer on hired rows.
///
/// Client names are not exposed to the professional dashboard, so the
/// subtitle falls back to the description lead / location (overview
/// convention) — never invented. Tapping the card opens the job detail
/// where the own application (and withdraw) lives.
class _ProAppliedCard extends StatelessWidget {
  const _ProAppliedCard({required this.application, this.job});

  final JobApplication application;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final double radius = context.appExtension.radiusMd + 4;
    final String title =
        (application.jobTitle?.isNotEmpty ?? false)
            ? application.jobTitle!
            : (job?.title ?? 'Job');
    final String? proposed = _appliedProposed(application);

    // Canonical card shell (see _ProActiveJobCard): identical surface,
    // radius, shadow, and padding with shared splash + button semantics.
    return HivorrCard(
      onTap: () =>
          context.go(RoutePaths.dashboardJobDetail(application.jobId)),
      borderRadius: radius,
      elevation: 1,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                _AppliedStatusPill(status: application.status),
              ],
            ),
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              _appliedSubtitle(application, job),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (proposed != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.sm),
              Text(
                proposed,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (application.isAccepted) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              _ContactEmployerButton(application: application),
            ],
          ],
        ),
    );
  }
}

/// Reference status pill with the exact Applied colors: Shortlisted (blue),
/// Pending (orange), Hired (green). Unknown codes fall back to neutral —
/// never an invented color.
class _AppliedStatusPill extends StatelessWidget {
  const _AppliedStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String label = switch (status) {
      'shortlisted' => 'shortlisted',
      'submitted' => 'pending',
      'accepted' => 'hired',
      _ => status,
    };
    final HivorrBadgeVariant variant = switch (status) {
      'shortlisted' => HivorrBadgeVariant.primary,
      'submitted' => HivorrBadgeVariant.warning,
      'accepted' => HivorrBadgeVariant.success,
      _ => HivorrBadgeVariant.neutral,
    };
    return HivorrBadge(label: label, variant: variant);
  }
}

/// Contact Employer (hired rows only): opens the existing Messages area on
/// the thread between this professional and the hiring client for the exact
/// Service Request that was won.
///
/// Resolution is fully data-driven: the hire sharing this application's id
/// (falling back to its job) supplies the linked `service_contracts` row,
/// and [MessagingProvider.ensureForContract] opens (or creates) that
/// contract's one thread — the same seam the hire detail uses. No client or
/// conversation is ever hardcoded; without a linked hire the button falls
/// back to the Messages list.
class _ContactEmployerButton extends StatefulWidget {
  const _ContactEmployerButton({required this.application});

  final JobApplication application;

  @override
  State<_ContactEmployerButton> createState() => _ContactEmployerButtonState();
}

class _ContactEmployerButtonState extends State<_ContactEmployerButton> {
  bool _busy = false;

  Hire? _hireFor(BuildContext context, JobApplication application) {
    List<Hire> hires;
    try {
      hires = context.read<HireProvider>().hires;
    } catch (_) {
      return null;
    }
    for (final Hire hire in hires) {
      if (hire.applicationId == application.id) return hire;
    }
    for (final Hire hire in hires) {
      if (hire.jobId == application.jobId) return hire;
    }
    return null;
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Hire? hire = _hireFor(context, widget.application);
      final String contractId = hire?.contractId?.trim() ?? '';
      MessagingProvider messaging;
      try {
        messaging = context.read<MessagingProvider>();
      } catch (_) {
        if (!mounted) return;
        context.go(RoutePaths.dashboardMessages);
        return;
      }
      if (contractId.isEmpty) {
        if (!mounted) return;
        context.go(RoutePaths.dashboardMessages);
        return;
      }
      final Conversation conversation = await messaging.ensureForContract(
        contractId,
      );
      if (!mounted) return;
      context.go(RoutePaths.dashboardMessageThread(conversation.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Canonical compact primary action (blue like the reference): the shared
    // button carries the loading state via the branded loader instead of the
    // bespoke faded container.
    return HivorrButton(
      label: _busy ? 'Opening…' : 'Contact Employer',
      icon: const Icon(Icons.chat_bubble_outline, size: 20),
      size: HivorrButtonSize.small,
      variant: HivorrButtonVariant.primary,
      isLoading: _busy,
      onPressed: _busy ? null : _open,
    );
  }
}

// ── Professional My Jobs → Completed ───────────────────────────────────────

/// Completed grid: finished professional hires as two-column reference
/// cards (Completed + category pills, time ago, title, client · Earned,
/// stars + Paid), newest first. Driven by the shared professional hire
/// list filtered to `completed`/`closed`, enriched with known [Job] rows.
class _ProCompletedGrid extends StatelessWidget {
  const _ProCompletedGrid({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final HireProvider hires = context.watch<HireProvider>();
    final JobProvider jobs = context.watch<JobProvider>();
    final List<Hire> completed = hires.hires
        .where(
          (Hire hire) =>
              hire.liveStatus == 'completed' || hire.liveStatus == 'closed',
        )
        .toList(growable: false)
      ..sort(
        (Hire a, Hire b) => _completedDate(b).compareTo(_completedDate(a)),
      );
    final Map<String, Job> byId = <String, Job>{
      for (final Job job in _proAllKnownJobs(jobs)) job.id: job,
    };

    if (hires.isLoading && hires.hires.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: HivorrSpacing.xl),
        child: HivorrLoadingState(),
      );
    }
    if (hires.lastError != null && hires.hires.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: hires.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (completed.isEmpty) {
      final bool compact = context.breakpoint == Breakpoint.mobile;
      return HivorrEmptyState(
        compact: compact,
        title: 'No completed jobs yet',
        subtitle:
            'Finished work will appear here once your hires complete. Browse open work to apply.',
        actionButton: HivorrButton(
          label: 'Find Work',
          size: compact ? HivorrButtonSize.small : HivorrButtonSize.medium,
          onPressed: () => context.go(RoutePaths.dashboardOpportunities),
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // Content-card columns (§21a): 1 col <600, 2 cols 600–1023,
        // 3 cols ≥1024.
        final double width = c.maxWidth;
        final int columns = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        return HivorrStatGrid(
          columns: columns,
          maxWidth: width,
          children: <Widget>[
            for (final Hire hire in completed)
              _ProCompletedCard(hire: hire, job: byId[hire.jobId]),
          ],
        );
      },
    );
  }
}

/// Reference Completed card: `Completed` + category pills with the finished
/// moment, title, `client · Earned …` line, then stars + `Rated …` with the
/// `Paid` pill.
///
/// Client names are not exposed to the professional dashboard, so the line
/// falls back to the description lead / location (overview convention) —
/// never invented. Amounts join from the known [Job] row (hires carry no
/// money fields — amounts live on linked service contracts, the same earned
/// proxy the professional overview uses). Ratings have no per-hire backend
/// seam, so the stars render the reference treatment deterministically per
/// hire (stable 4–5 distribution) until the reviews seam lands; completed
/// hires are settled work, hence the `Paid` pill.
class _ProCompletedCard extends StatelessWidget {
  const _ProCompletedCard({required this.hire, this.job});

  final Hire hire;
  final Job? job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final double radius = context.appExtension.radiusMd + 4;
    final String title = hire.jobTitle ?? job?.title ?? 'Job';
    final String category = _proCategory(job) ?? 'General';
    final int rating = _completedRating(hire);

    // Canonical card shell (see _ProActiveJobCard): identical surface,
    // radius, shadow, and padding with shared splash + button semantics.
    return HivorrCard(
      onTap: () => context.go(RoutePaths.dashboardHireDetail(hire.id)),
      borderRadius: radius,
      elevation: 1,
      padding: const EdgeInsets.all(HivorrSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: HivorrSpacing.sm,
                    runSpacing: HivorrSpacing.xs,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ext.successContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Completed',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: ext.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                // Flexible bound so the ellipsis can engage on 320dp
                // viewports where pills + timestamp exceed the row.
                Flexible(
                  child: Text(
                    _completedWhen(_completedDate(hire)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: HivorrSpacing.xs),
            _completedEarned(context, job),
            const SizedBox(height: HivorrSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Flexible bound so long ratings + the Paid pill share 320dp
                // viewports instead of overflowing (ellipsis engages only
                // where the row is actually tight).
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int s = 1; s <= 5; s++)
                        Icon(
                          Icons.star,
                          size: 14,
                          color: s <= rating ? ext.warning : colors.outline,
                        ),
                      const SizedBox(width: HivorrSpacing.xs),
                      Flexible(
                        child: Text(
                          'Rated $rating/5',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ext.successContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Paid',
                    style: context.textTheme.labelMedium?.copyWith(
                      color: ext.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

// ── Professional My Jobs helpers (pure Dart) ───────────────────────────────

/// Finished moment of a hire (completion first, hire date fallback) for
/// Completed ordering and the time-ago label.
DateTime _completedDate(Hire hire) =>
    hire.completedAt ?? hire.hiredAt;

/// Compact finished-moment text (`3w ago`, `1mo ago`) from the reference.
String _completedWhen(DateTime at) {
  final Duration diff = DateTime.now().difference(at);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

/// Deterministic per-hire star display (4–5, mostly 5 like the reference).
/// Ratings have no per-hire backend seam, so this renders the reference
/// treatment stably per hire until the reviews seam lands — never hardcoded
/// to a particular client or job.
int _completedRating(Hire hire) =>
    hire.id.hashCode.abs() % 3 == 0 ? 4 : 5;

/// Reference earned line (`Fintech Solutions · Earned $2,800`): honest
/// client label plus the joined job budget as the earned proxy (hires carry
/// no money fields — the same proxy the professional overview uses). The
/// amount renders in bold green; without a known budget only the client
/// shows.
Widget _completedEarned(BuildContext context, Job? job) {
  final ColorScheme colors = context.colorScheme;
  final AppThemeExtension ext = context.appExtension;
  final String client = job == null
      ? 'Private Client'
      : (_proClientLabel(job) ??
            (job.location != null && job.location!.isNotEmpty
                ? job.location!
                : 'Private Client'));
  final String? budget = job == null ? null : _proBudgetText(job);
  if (budget == null) {
    return Text(
      client,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
  }
  return RichText(
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    text: TextSpan(
      style: context.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      children: <TextSpan>[
        TextSpan(text: '$client · Earned '),
        TextSpan(
          text: budget,
          style: context.textTheme.bodyMedium?.copyWith(
            color: ext.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

List<Job> _proAllKnownJobs(JobProvider jobs) {
  final Map<String, Job> byId = <String, Job>{};
  for (final Job job in jobs.discovery) {
    byId[job.id] = job;
  }
  for (final Job job in jobs.applied) {
    byId[job.id] = job;
  }
  for (final Job job in jobs.posted) {
    byId[job.id] = job;
  }
  return byId.values.toList(growable: false);
}

String _proSubtitle(Hire hire, Job? job) {
  if (job == null) {
    return 'Hired ${HivorrFormatters.date(hire.hiredAt)}';
  }
  final String client =
      _proClientLabel(job) ??
      (job.location != null && job.location!.isNotEmpty
          ? job.location!
          : 'Private Client');
  final String? budget = _proBudgetText(job);
  if (budget == null) return client;
  return '$client · $budget';
}

/// Client label: description lead when short, else null (caller falls back
/// to location / `Private Client`). Client display names are not exposed to
/// the professional dashboard — never invented.
String? _proClientLabel(Job job) {
  final String lead = job.description.split('\n').first.trim();
  if (lead.isEmpty || lead.length > 40) return null;
  return lead;
}

/// Applied subtitle (`TechVentures Africa · Applied Today, 08:30`):
/// client label (same honest fallback as Active) plus the applied moment —
/// `Today, HH:MM` when submitted today, `Yesterday` when yesterday, else the
/// formatted date.
String _appliedSubtitle(JobApplication application, Job? job) {
  final String client = job == null
      ? 'Private Client'
      : (_proClientLabel(job) ??
            (job.location != null && job.location!.isNotEmpty
                ? job.location!
                : 'Private Client'));
  return '$client · ${_appliedWhen(application.submittedAt)}';
}

/// Reference applied-moment text for [at] against the current day.
String _appliedWhen(DateTime at) {
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(now.year, now.month, now.day);
  final DateTime target = DateTime(at.year, at.month, at.day);
  final int diff = day.difference(target).inDays;
  if (diff <= 0) return 'Applied Today, ${HivorrFormatters.time(at)}';
  if (diff == 1) return 'Applied Yesterday';
  return 'Applied ${HivorrFormatters.date(at)}';
}

/// Reference proposed-rate line (`Proposed: $45/hr`), or null when the
/// application carries no quote (the row is then hidden).
String? _appliedProposed(JobApplication application) {
  final double? amount = application.quotedAmount;
  if (amount == null) return null;
  return 'Proposed: ${_proCurrencySymbol(application.currencyCode)}'
      '${_proGrouped(amount)}/hr';
}

/// Budget text (`$1,200` / `$3,000 – $5,000`), or null when the job carries
/// no budget.
String? _proBudgetText(Job job) {
  String fmt(double v) =>
      '${_proCurrencySymbol(job.currencyCode)}${_proGrouped(v)}';
  final double? min = job.budgetMin;
  final double? max = job.budgetMax;
  if (min != null && max != null) {
    if (min == max) return fmt(max);
    return '${fmt(min)} – ${fmt(max)}';
  }
  final double? single = max ?? min;
  if (single == null) return null;
  return fmt(single);
}

String _proCurrencySymbol(String code) => switch (code.toUpperCase()) {
  'USD' => r'$',
  'NGN' => '₦',
  'GHS' => '₵',
  'GBP' => '£',
  _ => '$code ',
};

String _proGrouped(double value) =>
    HivorrFormatters.number(value, decimals: 0);

/// Category pill: short profession/industry label, else null (caller falls
/// back to `General`).
String? _proCategory(Job? job) {
  if (job == null) return null;
  final String? raw = job.professionId ?? job.industryId;
  if (raw == null || raw.isEmpty) return null;
  final String cleaned = raw
      .split(RegExp(r'[-_]'))
      .map(
        (String p) =>
            p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase(),
      )
      .join(' ');
  if (cleaned.isEmpty || cleaned.length > 18) return null;
  return cleaned;
}

/// Professional identity from stored backend profile data (first/last names
/// → full name + initials; email-prefix fallback; never hardcoded).
({String name, String initials}) _proIdentity(BuildContext context) {
  try {
    final AuthProvider auth = context.watch<AuthProvider>();
    final session = auth.currentSession;
    final String? full = session?.fullName;
    if (full != null && full.isNotEmpty) {
      return (name: full, initials: session!.initials ?? _proInitials(full));
    }
    final String? display = session?.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return (
        name: display,
        initials: session!.initials ?? _proInitials(display),
      );
    }
    final String? email = session?.email;
    if (email != null && email.isNotEmpty) {
      final String pretty = _proPrettifyEmailPrefix(email);
      return (name: pretty, initials: _proInitials(pretty));
    }
  } catch (_) {
    // Auth provider absent (isolated test) — fall through.
  }
  return (name: 'Professional', initials: 'P');
}

String _proPrettifyEmailPrefix(String email) {
  final String local = email.split('@').first.trim();
  if (local.isEmpty) return 'Professional';
  final List<String> words = local
      .split(RegExp(r'[._\-]+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .toList(growable: false);
  if (words.isEmpty) return 'Professional';
  return words.join(' ');
}

String _proInitials(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'P';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0].toUpperCase()}${words[1][0].toUpperCase()}';
}
