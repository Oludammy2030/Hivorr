import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/app/widgets/hivorr_loader.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/entities/job_application.dart';
import 'package:hivorr/data/entities/public_profile.dart';
import 'package:hivorr/data/providers/hire_provider.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/data/providers/onboarding_provider.dart';
import 'package:hivorr/data/repositories/portfolio_repository.dart';
import 'package:hivorr/shared/components/hivorr_dashboard_top_bar.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/shared/widgets/hivorr_tint_badge.dart';
import 'package:hivorr/systems/dashboard/shell/client_mobile_chrome.dart';
import 'package:hivorr/systems/dashboard/shell/professional_mobile_chrome.dart';
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

/// Client-side sort for the loaded discovery list (Filter sheet).
///
/// Applied to a copy of the loaded page only — server ranking stays
/// authoritative (`AGENT.md:7`); this never refetches or reorders remotely.
enum _FwSort { recommended, newest, budgetHigh, mostApplied }

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;
  String? _query;
  _FwSort _sort = _FwSort.recommended;
  bool _urgentOnly = false;

  /// Session-local saved marks (heart toggle). UI-only — no saved-jobs
  /// backend seam exists, so nothing is persisted or synced.
  final Set<String> _savedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
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

  /// Initial hydration: discovery first, then the professional's own
  /// applications (sequential — both flip the same provider load gate, so
  /// concurrent calls would early-return and drop a list). The own
  /// applications drive the per-card Applied state.
  Future<void> _init() async {
    await _load(refresh: true);
    if (!mounted) return;
    await context.read<JobProvider>().loadApplications();
  }

  /// Pull-to-refresh scope: discovery page plus the own-application marks.
  Future<void> _refresh() async {
    await _load(refresh: true);
    if (!mounted) return;
    await context.read<JobProvider>().loadApplications();
  }

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

  /// Discovery list with the session-local Filter sheet applied
  /// (urgent-only + sort on a copy; server order untouched by default).
  List<Job> _displayJobs(JobProvider jobs) {
    List<Job> list = jobs.discovery;
    if (_urgentOnly) {
      list = list
          .where((Job job) => job.applicationsCount >= _kFwUrgentThreshold)
          .toList(growable: false);
    }
    switch (_sort) {
      case _FwSort.recommended:
        return list;
      case _FwSort.newest:
        final List<Job> sorted = list.toList();
        sorted.sort(
          (Job a, Job b) => _fwPostedAt(b).compareTo(_fwPostedAt(a)),
        );
        return sorted;
      case _FwSort.budgetHigh:
        final List<Job> sorted = list.toList();
        sorted.sort(
          (Job a, Job b) => _fwBudgetValue(
            b,
          ).compareTo(_fwBudgetValue(a)),
        );
        return sorted;
      case _FwSort.mostApplied:
        final List<Job> sorted = list.toList();
        sorted.sort(
          (Job a, Job b) => b.applicationsCount.compareTo(a.applicationsCount),
        );
        return sorted;
    }
  }

  Future<void> _openFilterSheet() async {
    final _FwFilterResult? result = await showModalBottomSheet<_FwFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => _FwFilterSheet(
        sort: _sort,
        urgentOnly: _urgentOnly,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _sort = result.sort;
      _urgentOnly = result.urgentOnly;
    });
  }

  void _toggleSaved(String jobId) {
    setState(() {
      if (!_savedIds.remove(jobId)) {
        _savedIds.add(jobId);
      }
    });
  }

  /// Opens the application overlay for [job], unless the professional
  /// already applied (data-driven guard — the card then shows Applied).
  Future<void> _openApply(Job job, Set<String> appliedIds) async {
    if (appliedIds.contains(job.id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'You have already applied to this job.',
          variant: HivorrSnackbarVariant.info,
        ),
      );
      return;
    }
    final bool? submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext context) => _FwApplyDialog(job: job),
    );
    if (!mounted || submitted != true) return;
    // Submission succeeded: refresh the own-application marks (Applied
    // state) and the discovery counts, then confirm.
    await context.read<JobProvider>().loadApplications();
    if (!mounted) return;
    await _load(refresh: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(
        context,
        message: 'Application submitted.',
        variant: HivorrSnackbarVariant.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = context.breakpoint == Breakpoint.mobile;
    if (isMobile) {
      return Scaffold(
        // Shared professional chrome: single `Find Work` title with the
        // bell + Professional pill + avatar on one compact row. Bottom
        // navigation lives in the dashboard shell. No refresh action — the
        // grid below owns pull-to-refresh (same contract as client chrome).
        appBar: const ProfessionalMobileAppBar(title: 'Find Work'),
        body: MobileSafeBody(
          child: _FindWorkContent(
            search: _search,
            scroll: _scroll,
            onSearchChanged: _onSearchChanged,
            onOpenFilter: _openFilterSheet,
            onRefresh: _refresh,
            onApply: _openApply,
            displayJobs: _displayJobs,
            savedIds: _savedIds,
            onToggleSaved: _toggleSaved,
            filterActive:
                _sort != _FwSort.recommended || _urgentOnly,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _FindWorkTopBar(),
        Expanded(
          child: _FindWorkContent(
            search: _search,
            scroll: _scroll,
            onSearchChanged: _onSearchChanged,
            onOpenFilter: _openFilterSheet,
            onRefresh: _refresh,
            onApply: _openApply,
            displayJobs: _displayJobs,
            savedIds: _savedIds,
            onToggleSaved: _toggleSaved,
            filterActive:
                _sort != _FwSort.recommended || _urgentOnly,
          ),
        ),
      ],
    );
  }
}

/// Applied-applications threshold behind the `Urgent` pill and the
/// urgent-only filter (shared with the professional overview convention).
const int _kFwUrgentThreshold = 5;

/// Professional `Find Work` top bar (reference): menu tile, page title,
/// notification bell with attention dot, green Professional pill and the
/// dynamic-initials account avatar.
class _FindWorkTopBar extends StatelessWidget {
  const _FindWorkTopBar();

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    bool hasDot = false;
    try {
      hasDot = context.watch<JobProvider>().discovery.isNotEmpty;
    } catch (_) {
      hasDot = false;
    }
    final ({String name, String initials}) identity = _fwIdentity(context);
    return HivorrDashboardTopBar(
      title: 'Find Work',
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

/// Reference content: white search header (search field + green Filter
/// button + availability subtitle) above the light-grey opportunity grid.
class _FindWorkContent extends StatelessWidget {
  const _FindWorkContent({
    required this.search,
    required this.scroll,
    required this.onSearchChanged,
    required this.onOpenFilter,
    required this.onRefresh,
    required this.onApply,
    required this.displayJobs,
    required this.savedIds,
    required this.onToggleSaved,
    required this.filterActive,
  });

  final TextEditingController search;
  final ScrollController scroll;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilter;
  final Future<void> Function() onRefresh;

  /// Opens the application overlay for [job] with the current applied marks.
  final Future<void> Function(Job job, Set<String> appliedIds) onApply;
  final List<Job> Function(JobProvider jobs) displayJobs;
  final Set<String> savedIds;
  final ValueChanged<String> onToggleSaved;
  final bool filterActive;

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final bool searching =
        search.text.trim().isNotEmpty;
    // Data-driven applied marks: every own application row (any status —
    // one row exists per job+professional) marks its job as Applied.
    final Set<String> appliedIds = <String>{
      for (final JobApplication app in jobs.myApplications) app.jobId,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ColoredBox(
          color: context.colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(
              context.breakpoint == Breakpoint.mobile
                  ? HivorrSpacing.md
                  : HivorrSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _FindWorkSearchField(
                        controller: search,
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: HivorrSpacing.sm),
                    _FindWorkFilterButton(
                      active: filterActive,
                      onPressed: onOpenFilter,
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.sm),
                _FindWorkSubtitle(
                  total: jobs.discovery.length,
                  hasMore: jobs.discoveryHasMore,
                  searching: searching,
                  query: search.text.trim(),
                  shown: displayJobs(jobs).length,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _FindWorkGrid(
              jobs: jobs,
              displayed: displayJobs(jobs),
              searching: searching,
              scroll: scroll,
              onRefresh: onRefresh,
              appliedIds: appliedIds,
              onApply: (Job job) => onApply(job, appliedIds),
              savedIds: savedIds,
              onToggleSaved: onToggleSaved,
            ),
          ),
        ),
      ],
    );
  }
}

/// Borderless filled search field (reference): light-grey rounded input with
/// a search prefix.
class _FindWorkSearchField extends StatelessWidget {
  const _FindWorkSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    // Canonical search field (§21f): tint preserved via fillColor, focus
    // resolves to primary per the design system (focus rings are never
    // role-colored).
    return HivorrTextField(
      controller: controller,
      onChanged: onChanged,
      hint: 'Search jobs by title, company, or skill…',
      prefix: Icon(
        Icons.search_outlined,
        size: 20,
        color: colors.onSurfaceVariant,
      ),
      fillColor: colors.surfaceContainerHighest.withValues(
        alpha: context.isDarkMode ? 1.0 : 0.55,
      ),
    );
  }
}

/// Green Filter button (reference): funnel icon + label, filled with the
/// professional accent; dot badge while a filter is active.
class _FindWorkFilterButton extends StatelessWidget {
  const _FindWorkFilterButton({
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    final ColorScheme colors = context.colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: roles.professionalPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: colors.onPrimary,
                ),
                if (active)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colors.onPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: roles.professionalPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: HivorrSpacing.xs),
            Text(
              'Filter',
              style: context.textTheme.labelLarge?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindWorkSubtitle extends StatelessWidget {
  const _FindWorkSubtitle({
    required this.total,
    required this.hasMore,
    required this.searching,
    required this.query,
    required this.shown,
  });

  final int total;
  final bool hasMore;
  final bool searching;
  final String query;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (searching) {
      text = shown == 1
          ? '1 result for "$query"'
          : '$shown results for "$query"';
    } else if (hasMore) {
      text = '$total+ opportunities available · Matched to your skills';
    } else if (total == 1) {
      text = '1 opportunity available · Matched to your skills';
    } else {
      text = '$total opportunities available · Matched to your skills';
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Responsive opportunity grid (reference): content-card columns per §21a
/// (1 col <600, 2 cols 600–1023, 3 cols ≥1024). Cards are content-driven —
/// the old fixed 310/330dp extents forced empty space into every card.
/// Pull-to-refresh and infinite pagination are kept.
class _FindWorkGrid extends StatelessWidget {
  const _FindWorkGrid({
    required this.jobs,
    required this.displayed,
    required this.searching,
    required this.scroll,
    required this.onRefresh,
    required this.appliedIds,
    required this.onApply,
    required this.savedIds,
    required this.onToggleSaved,
  });

  final JobProvider jobs;
  final List<Job> displayed;
  final bool searching;
  final ScrollController scroll;
  final Future<void> Function() onRefresh;

  /// Own-application job marks driving the per-card Applied state.
  final Set<String> appliedIds;

  /// Opens the application overlay for a not-yet-applied job.
  final ValueChanged<Job> onApply;
  final Set<String> savedIds;
  final ValueChanged<String> onToggleSaved;

  @override
  Widget build(BuildContext context) {
    if (jobs.isLoading && jobs.discovery.isEmpty) {
      return const HivorrLoadingState();
    }
    if (jobs.lastError != null && jobs.discovery.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRefresh()),
      );
    }
    if (jobs.discovery.isEmpty) {
      return const HivorrEmptyState(
        title: 'No open jobs right now',
        subtitle:
            'New hiring requests appear here as soon as clients publish them. Check back soon.',
      );
    }
    if (displayed.isEmpty) {
      return HivorrEmptyState(
        title: searching ? 'No matches found' : 'No urgent jobs right now',
        subtitle: searching
            ? 'Try a different keyword or clear the search.'
            : 'Clear the urgent-only filter to see every opportunity.',
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double width = c.maxWidth;
        final int columns = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        final bool compact = MobileCompact.isCompactWidth(width);
        final EdgeInsets gutter = EdgeInsets.all(
          compact ? HivorrSpacing.md : HivorrSpacing.lg,
        );
        final bool showLoader =
            jobs.discoveryHasMore && !_filtered();
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            controller: scroll,
            padding: gutter,
            child: Column(
              children: <Widget>[
                HivorrStatGrid(
                  columns: columns,
                  maxWidth: width - gutter.horizontal,
                  gap: compact ? HivorrSpacing.sm : HivorrSpacing.md,
                  children: <Widget>[
                    for (final Job job in displayed)
                      _FindWorkCard(
                        job: job,
                        applied: appliedIds.contains(job.id),
                        onApply: () => onApply(job),
                        saved: savedIds.contains(job.id),
                        onToggleSaved: () => onToggleSaved(job.id),
                      ),
                  ],
                ),
                if (showLoader)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: HivorrSpacing.md,
                    ),
                    child: HivorrLoadingState(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The trailing pagination loader belongs to the unfiltered server feed;
  /// filtered/sorted views page through the loaded copy instead.
  bool _filtered() => displayed.length != jobs.discovery.length;
}

/// Reference opportunity card: category pills left with price + applicant
/// count right, title, description, location + time-ago meta, then a green
/// Apply Now action (light-green Applied pill once the professional's own
/// application exists for the job) beside a session-local save toggle.
class _FindWorkCard extends StatelessWidget {
  const _FindWorkCard({
    required this.job,
    required this.applied,
    required this.onApply,
    required this.saved,
    required this.onToggleSaved,
  });

  final Job job;

  /// Whether the logged-in professional already applied (own application
  /// row exists) — drives the Applied state, never hardcoded.
  final bool applied;

  /// Opens the application overlay (guarded: applied jobs never reach it).
  final VoidCallback onApply;
  final bool saved;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    final AppThemeExtension ext = context.appExtension;
    final bool compact = context.breakpoint == Breakpoint.mobile;
    final String? budget = _fwBudget(job);
    final bool urgent = job.applicationsCount >= _kFwUrgentThreshold;
    final String category = _fwCategory(job) ?? 'Open';
    final String postedAgo = _fwTimeAgo(_fwPostedAt(job));
    // The detail tap covers the header block only (sibling of the action
    // row): nesting the Apply/Save buttons inside a card-wide InkWell
    // would fire both taps from one press.
    return HivorrCard(
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.smMd : HivorrSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Wrap(
                        spacing: HivorrSpacing.sm,
                        runSpacing: HivorrSpacing.xs,
                        children: <Widget>[
                          HivorrTintBadge(
                            label: category,
                            background: colors.primaryContainer,
                            foreground: colors.primary,
                          ),
                          if (urgent)
                            HivorrTintBadge(
                              label: 'Urgent',
                              background: colors.errorContainer,
                              foreground: colors.error,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: HivorrSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (budget != null)
                          Text(
                            budget,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: ext.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          '${job.applicationsCount} applied',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.sm),
                Text(
                  job.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fwCompanyLine(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.description.split('\n').first.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              if (job.location != null && job.location!.isNotEmpty) ...<Widget>[
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    job.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
              ],
              Icon(
                Icons.schedule_outlined,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                postedAgo,
                style: context.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: applied
                    ? _FwAppliedPill(
                        onTap: () => context.go(
                          RoutePaths.dashboardJobDetail(job.id),
                        ),
                      )
                    : InkWell(
                        onTap: onApply,
                        borderRadius: BorderRadius.circular(
                          ext.radiusXs,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: HivorrSpacing.smMd,
                          ),
                          decoration: BoxDecoration(
                            color: roles.professionalPrimary,
                            borderRadius: BorderRadius.circular(
                              ext.radiusXs,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: colors.onPrimary,
                              ),
                              const SizedBox(width: HivorrSpacing.xs),
                              Text(
                                'Apply Now',
                                style: context.textTheme.labelLarge?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Tooltip(
                message: saved ? 'Saved' : 'Save',
                child: InkWell(
                  onTap: onToggleSaved,
                  borderRadius: BorderRadius.circular(ext.radiusXs),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: context.isDarkMode ? 1.0 : 0.55,
                      ),
                      borderRadius: BorderRadius.circular(ext.radiusXs),
                    ),
                    child: Icon(
                      saved ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: saved
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
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

/// Applied state (reference): light-green action tile with a check mark
/// and bold green label, replacing Apply Now on the applied job only.
/// Tapping still opens the job detail (own application + withdraw live
/// there), so the tile never dead-ends.
class _FwAppliedPill extends StatelessWidget {
  const _FwAppliedPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeExtension ext = context.appExtension;
    return Tooltip(
      message: 'You have applied to this job',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext.radiusXs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: HivorrSpacing.smMd,
          ),
          decoration: BoxDecoration(
            color: ext.successContainer,
            borderRadius: BorderRadius.circular(ext.radiusXs),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                size: 20,
                color: ext.success,
              ),
              const SizedBox(width: HivorrSpacing.xs),
              Text(
                'Applied!',
                style: context.textTheme.labelLarge?.copyWith(
                  color: ext.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter sheet result (sort + urgent-only over the loaded discovery page).
class _FwFilterResult {
  const _FwFilterResult({required this.sort, required this.urgentOnly});

  final _FwSort sort;
  final bool urgentOnly;
}

/// Session-local filter sheet: sort order plus an urgent-only switch.
/// Sorting/filtering applies to the already-loaded discovery page — no new
/// backend query, server ranking stays authoritative.
class _FwFilterSheet extends StatefulWidget {
  const _FwFilterSheet({required this.sort, required this.urgentOnly});

  final _FwSort sort;
  final bool urgentOnly;

  @override
  State<_FwFilterSheet> createState() => _FwFilterSheetState();
}

class _FwFilterSheetState extends State<_FwFilterSheet> {
  late _FwSort _sort = widget.sort;
  late bool _urgentOnly = widget.urgentOnly;

  static const List<(_FwSort, String)> _options = <(_FwSort, String)>[
    (_FwSort.recommended, 'Recommended'),
    (_FwSort.newest, 'Newest first'),
    (_FwSort.budgetHigh, 'Highest budget'),
    (_FwSort.mostApplied, 'Most applied'),
  ];

  @override
  Widget build(BuildContext context) {
    final RoleThemeExtension roles = context.roleTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            HivorrSpacing.lg,
            0,
            HivorrSpacing.lg,
            HivorrSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Filter',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  HivorrButton(
                    label: 'Reset',
                    variant: HivorrButtonVariant.text,
                    onPressed: () => setState(() {
                      _sort = _FwSort.recommended;
                      _urgentOnly = false;
                    }),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Sort by',
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              RadioGroup<_FwSort>(
                groupValue: _sort,
                onChanged: (_FwSort? v) {
                  if (v != null) setState(() => _sort = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (_FwSort value, String label) in _options)
                      RadioListTile<_FwSort>(
                        value: value,
                        title: Text(label),
                        activeColor: roles.professionalPrimary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              SwitchListTile(
                value: _urgentOnly,
                onChanged: (bool v) => setState(() => _urgentOnly = v),
                title: const Text('Urgent only'),
                subtitle: Text(
                  'Jobs with $_kFwUrgentThreshold+ applications',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                activeThumbColor: roles.professionalPrimary,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: HivorrSpacing.sm),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  _FwFilterResult(sort: _sort, urgentOnly: _urgentOnly),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: roles.professionalPrimary,
                  foregroundColor: context.colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Show results',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Application overlay (reference): centered white dialog over the dimmed
/// Find Work page — no navigation. Proposed rate + cover letter + optional
/// portfolio link, submitted through the shared [JobProvider.apply] seam so
/// the row lands in Client → Applications for this job like any other
/// application. The caller refreshes its lists on a `true` pop.
class _FwApplyDialog extends StatefulWidget {
  const _FwApplyDialog({required this.job});

  final Job job;

  @override
  State<_FwApplyDialog> createState() => _FwApplyDialogState();
}

class _FwApplyDialogState extends State<_FwApplyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _cover = TextEditingController();
  final TextEditingController _portfolio = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _rate.dispose();
    _cover.dispose();
    _portfolio.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    final ColorScheme colors = context.colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: context.textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(
        alpha: context.isDarkMode ? 1.0 : 0.55,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: context.roleTheme.professionalPrimary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.xs),
      child: Text(
        text,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final String cover = _cover.text.trim();
    final String link = _portfolio.text.trim();
    final String coverNote = link.isEmpty ? cover : '$cover\n\nPortfolio: $link';
    // Backend CHECK is 20–2000 chars on the stored note (link included).
    if (coverNote.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: 'Cover letter plus link must fit 2000 characters.',
          variant: HivorrSnackbarVariant.error,
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<JobProvider>().apply(
        jobId: widget.job.id,
        coverNote: coverNote,
        quotedAmount: _fwParseRate(_rate.text),
        currencyCode: widget.job.currencyCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // A duplicate race (row already exists server-side) still ends in
      // the Applied state once the marks refresh — never a dead error.
      await context.read<JobProvider>().loadApplications();
      if (!mounted) return;
      final bool nowApplied = context
          .read<JobProvider>()
          .myApplications
          .any((JobApplication app) => app.jobId == widget.job.id);
      if (nowApplied) {
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        HivorrSnackbar.show(
          context,
          message: e.message,
          variant: HivorrSnackbarVariant.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    // Canonical dialog chrome (radius + overlay shadow); the form, fields
    // (validators live on the TextFormFields below — HivorrTextField carries
    // no validator, so the fields stay), and the role-green submit stay.
    return HivorrDialog(
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Submit Application',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _sending
                          ? null
                          : () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(
                        context.appExtension.radiusSm,
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: context.isDarkMode ? 1.0 : 0.55,
                          ),
                          borderRadius: BorderRadius.circular(
                            context.appExtension.radiusSm,
                          ),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.lg),
                _label('Your Proposed Rate'),
                TextFormField(
                  controller: _rate,
                  keyboardType: TextInputType.text,
                  decoration: _fieldDecoration(r'e.g. $45/hr or $2,500 fixed'),
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return _fwParseRate(v) == null
                        ? 'Enter an amount, e.g. 2500.'
                        : null;
                  },
                ),
                const SizedBox(height: HivorrSpacing.md),
                _label('Cover Letter'),
                TextFormField(
                  controller: _cover,
                  maxLines: 5,
                  minLines: 5,
                  decoration: _fieldDecoration(
                    "Explain why you're the best fit for this role…",
                  ),
                  validator: (String? v) {
                    final String t = (v ?? '').trim();
                    if (t.length < 20 || t.length > 2000) {
                      return 'Cover letter must be 20 to 2000 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: HivorrSpacing.md),
                _label('Relevant Portfolio Link (optional)'),
                TextFormField(
                  controller: _portfolio,
                  keyboardType: TextInputType.url,
                  decoration: _fieldDecoration(
                    'github.com/yourname or portfolio.com',
                  ),
                  validator: (String? v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return v.trim().length >= 4
                        ? null
                        : 'Enter a valid link.';
                  },
                ),
                const SizedBox(height: HivorrSpacing.lg),
                InkWell(
                  onTap: _sending ? null : _submit,
                  borderRadius: BorderRadius.circular(
                    context.appExtension.radiusSm,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    // Flat role fill: the bespoke green gradient carried raw
                    // hex outside the design system; the flat accent keeps
                    // the green identity in the canonical flat-fill language.
                    decoration: BoxDecoration(
                      color: _sending
                          ? roles.professionalPrimary.withValues(alpha: 0.6)
                          : roles.professionalPrimary,
                      borderRadius: BorderRadius.circular(
                        context.appExtension.radiusSm,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_sending)
                          HivorrLoader(size: 20, color: colors.onPrimary)
                        else
                          Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: colors.onPrimary,
                          ),
                        const SizedBox(width: HivorrSpacing.sm),
                        Text(
                          _sending ? 'Submitting…' : 'Submit Application',
                style: context.textTheme.titleMedium?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Find Work helpers (pure Dart) ──────────────────────────────────────────

/// Company line: client display names are not exposed to the professional
/// dashboard, so the description lead stands in (overview convention).
String _fwCompanyLine(Job job) {
  final String lead = job.description.split('\n').first.trim();
  if (lead.isEmpty) return 'Private Client';
  if (lead.length > 48) return lead.substring(0, 48).trimRight();
  return lead;
}

/// Category pill: short profession/industry label, else null (caller falls
/// back to the `Open` status pill).
String? _fwCategory(Job job) {
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

DateTime _fwPostedAt(Job job) =>
    job.postedAt ?? job.createdAt;

double _fwBudgetValue(Job job) =>
    job.budgetMax ?? job.budgetMin ?? 0;

/// Budget text (`$3,500` / `$3,000 – $5,000`), or null when unordered.
String? _fwBudget(Job job) {
  String fmt(double v) =>
      '${_fwCurrencySymbol(job.currencyCode)}${_fwGrouped(v)}';
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

/// Parses the first positive amount out of free-text rate input
/// (`$2,500 fixed` → `2500`, `45/hr` → `45`), or null when no usable
/// amount is present. The stored quote stays numeric for the backend
/// while the professional keeps the reference's free-text field.
double? _fwParseRate(String input) {
  final RegExpMatch? match = RegExp(
    r'[\d,]+(\.\d+)?',
  ).firstMatch(input);
  if (match == null) return null;
  final double? value = double.tryParse(
    match.group(0)!.replaceAll(',', ''),
  );
  if (value == null || value <= 0) return null;
  return value;
}

String _fwCurrencySymbol(String code) => switch (code.toUpperCase()) {
  'USD' => r'$',
  'NGN' => '₦',
  'GHS' => '₵',
  'GBP' => '£',
  _ => '$code ',
};

String _fwGrouped(double value) =>
    HivorrFormatters.number(value, decimals: 0);

/// Compact time-ago (`30m ago`, `2h ago`, `3d ago`) from the posted date.
String _fwTimeAgo(DateTime at) {
  final Duration diff = DateTime.now().difference(at);
  if (diff.isNegative || diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

/// Professional identity from stored backend profile data (first/last
/// names → full name + initials; email-prefix fallback; never hardcoded).
({String name, String initials}) _fwIdentity(BuildContext context) {
  try {
    final AuthProvider auth = context.watch<AuthProvider>();
    final session = auth.currentSession;
    final String? full = session?.fullName;
    if (full != null && full.isNotEmpty) {
      return (name: full, initials: session!.initials ?? _fwInitials(full));
    }
    final String? display = session?.displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return (
        name: display,
        initials: session!.initials ?? _fwInitials(display),
      );
    }
    final String? email = session?.email;
    if (email != null && email.isNotEmpty) {
      final String pretty = _fwPrettifyEmailPrefix(email);
      return (name: pretty, initials: _fwInitials(pretty));
    }
  } catch (_) {
    // Auth provider absent (isolated test) — fall through.
  }
  return (name: 'Professional', initials: 'P');
}

String _fwPrettifyEmailPrefix(String email) {
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

String _fwInitials(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return 'P';
  if (words.length == 1) return words.first[0].toUpperCase();
  return '${words.first[0].toUpperCase()}${words[1][0].toUpperCase()}';
}

/// Role-aware Applications entry (EP-04-03).
///
/// Professionals see their own applications list ([_ProfessionalApplicationsScreen],
/// the pre-existing screen); hiring-side clients see the Jobs + Applicants
/// inbox ([_ClientApplicationsScreen]) matching the Applications reference:
/// the Jobs panel lists posted jobs, the Applications panel shows applicants
/// for the selected job, and each panel scrolls independently.
class MyApplicationsScreen extends StatelessWidget {
  const MyApplicationsScreen({super.key, this.initialJobId});

  /// Optional preselected job for the client inbox (e.g. `?job=` deep link
  /// from a My Jobs card). Ignored when unknown; the professional list does
  /// not take a job context.
  final String? initialJobId;

  @override
  Widget build(BuildContext context) {
    bool hiring = false;
    try {
      final OnboardingProvider onboarding = context.watch<OnboardingProvider>();
      final EntityCapability? focus = onboarding.progress?.capability;
      hiring = focus == EntityCapability.hire;
    } catch (_) {
      hiring = false;
    }
    if (hiring) return _ClientApplicationsScreen(initialJobId: initialJobId);
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
      // Shared professional chrome: single `My Applications` title with the
      // bell + Professional pill + avatar on one compact row. Bottom
      // navigation lives in the dashboard shell. Reloads stay on the
      // in-body filter chips + retry states (same contract as client).
      appBar: const ProfessionalMobileAppBar(title: 'My Applications'),
      // Bottom-navigation safe-area contract: the shell owns the bottom
      // inset, so MobileSafeBody (not a bottom-padding SafeArea) wraps the
      // body; the list keeps the 32dp bottom clearance token.
      body: MobileSafeBody(
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
                        padding: MobileCompact.scrollPadding,
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
  const _ClientApplicationsScreen({this.initialJobId});

  /// Preselected job (see [MyApplicationsScreen.initialJobId]).
  final String? initialJobId;

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
  final Map<String, bool> _appsHasMoreCache = <String, bool>{};
  // Phase 4: applicant identities resolved from the existing public-profile
  // read path (`PortfolioRepository.getPublicProfile`, approved-gate
  // respected), keyed by professional entity id. `null` value = gated or
  // missing profile → graceful generic fallback (never raw ids, never
  // fabricated names). Absent key = not yet resolved or transient failure
  // (retried on the next load).
  final Map<String, PublicProfile?> _identities = <String, PublicProfile?>{};
  final Set<String> _identityPending = <String>{};
  // Phase 5: review selection. The right pane shows the applicant list until
  // the client taps a card, then the dedicated detail view for that
  // application (same pane on desktop, full-width on mobile — one
  // experience, no competing routes). Cleared whenever the job changes.
  String? _selectedApplicationId;
  bool _appsHasMore = false;
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

  /// Non-blocking count refresh (Phase 2): re-reads `job_list_mine(posted)`
  /// for authoritative `applications_count` without tripping the shared
  /// loading gate or blanking the jobs panel on failure.
  Future<void> _refreshCounts() =>
      context.read<JobProvider>().refreshPosted();

  /// Resolves display identities for [apps] via the existing
  /// [PortfolioRepository] read path (single RPC per applicant, cached by
  /// entity id). Rows carrying the submit-time identity snapshot
  /// (`hasIdentitySnapshot`) need no RPC and are skipped — the snapshot is
  /// authoritative. Runs in the background without blocking the list: each
  /// resolution rebuilds once on completion. Never throws — failures leave
  /// the generic fallback in place.
  void _resolveIdentities(List<JobApplication> apps) {
    PortfolioRepository? portfolios;
    try {
      portfolios = context.read<PortfolioRepository>();
    } catch (_) {
      return;
    }
    final PortfolioRepository repo = portfolios;
    final Set<String> seen = <String>{};
    for (final JobApplication app in apps) {
      if (app.hasIdentitySnapshot) continue;
      final String entityId = app.professionalEntityId.trim();
      if (entityId.isEmpty || !seen.add(entityId)) continue;
      if (_identities.containsKey(entityId) ||
          _identityPending.contains(entityId)) {
        continue;
      }
      _identityPending.add(entityId);
      unawaited(
        repo.getPublicProfile(entityId).then((PublicProfile? profile) {
          _identityPending.remove(entityId);
          if (!mounted) return;
          // Only the gated/missing case caches `null`; transient errors
          // throw and stay uncached so the next load retries.
          setState(() => _identities[entityId] = profile);
        }).catchError((Object _) {
          _identityPending.remove(entityId);
          return null;
        }),
      );
    }
  }

  Future<void> _loadApps(String jobId, {bool refresh = false}) async {
    if (!refresh && _appsCache.containsKey(jobId)) {
      if (mounted) {
        setState(() {
          _apps = _appsCache[jobId]!;
          _appsHasMore = _appsHasMoreCache[jobId] ?? false;
          _appsLoading = false;
          _appsError = null;
        });
        _resolveIdentities(_appsCache[jobId]!);
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
        _appsHasMore = page.hasMore;
        _appsHasMoreCache[jobId] = page.hasMore;
        _appsLoading = false;
      });
      _resolveIdentities(page.applications);
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
    // Prefer an explicitly requested job (e.g. `?job=` deep link) until the
    // client picks another one; otherwise keep the current selection, else
    // fall back to the first job. Invalid ids degrade to the default.
    final String? preferred = _selectedJobId ?? widget.initialJobId;
    final bool stillValid =
        preferred != null && posted.any((Job j) => j.id == preferred);
    if (!stillValid) {
      _selectedJobId = posted.first.id;
      _selectedApplicationId = null;
      unawaited(_loadApps(_selectedJobId!));
    } else if (_selectedJobId == null) {
      // Reached only when `preferred` validated above.
      _selectedJobId = preferred;
      _selectedApplicationId = null;
      unawaited(_loadApps(preferred));
    }
  }

  void _selectJob(String jobId) {
    if (_selectedJobId == jobId) return;
    setState(() {
      _selectedJobId = jobId;
      _selectedApplicationId = null;
      _apps = _appsCache[jobId] ?? const <JobApplication>[];
      _appsHasMore = _appsHasMoreCache[jobId] ?? false;
      _appsError = null;
      _appsLoading = !_appsCache.containsKey(jobId);
    });
    if (!_appsCache.containsKey(jobId)) {
      unawaited(_loadApps(jobId));
    } else {
      _resolveIdentities(_appsCache[jobId]!);
    }
  }

  /// Opens the dedicated review view for [application] (Phase 5: review
  /// before deciding — decision actions live in the detail, not the list).
  void _selectApplication(JobApplication application) {
    setState(() => _selectedApplicationId = application.id);
  }

  /// Returns from the detail view to the applicant list.
  void _clearApplicationSelection() {
    setState(() => _selectedApplicationId = null);
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
      // Status transitions leave the trigger count unchanged, but a hire
      // rewrites many rows (winner accepted, rest rejected) and flips the job
      // to awarded — refresh both the list and the authoritative counts.
      unawaited(_refreshCounts());
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
      drawer: isMobile ? const ClientDashboardDrawer() : null,
      appBar: isMobile
          ? const ClientMobileAppBar(title: 'Applications')
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
                        // The shared mobile bar already titles this page, so
                        // the in-body heading shows on wider layouts only.
                        if (!isMobile) ...<Widget>[
                          Text(
                            'Applications',
                            style: context.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: HivorrSpacing.xs),
                        ],
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
                                // Phones (<600dp) use the reference Select Job
                                // dropdown; larger narrow layouts keep the
                                // horizontal jobs strip untouched.
                                if (isMobile) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      _SelectJobDropdown(
                                        jobs: jobs,
                                        posted: posted,
                                        selectedId: _selectedJobId,
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
                                          identities: _identities,
                                          selectedId: _selectedApplicationId,
                                          onSelect: _selectApplication,
                                          onBack: _clearApplicationSelection,
                                          hasMore: _appsHasMore,
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
                                        identities: _identities,
                                        selectedId: _selectedApplicationId,
                                        onSelect: _selectApplication,
                                        onBack: _clearApplicationSelection,
                                        hasMore: _appsHasMore,
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
                                      identities: _identities,
                                      selectedId: _selectedApplicationId,
                                      onSelect: _selectApplication,
                                      onBack: _clearApplicationSelection,
                                      hasMore: _appsHasMore,
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
    return HivorrDashboardTopBar(
      title: 'Applications',
      accentPrimary: roleTheme.clientPrimary,
      accentContainer: roleTheme.clientContainer,
      modeLabel: 'Client',
      initials: 'TV',
      showDot: pendingApps > 0,
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

/// Mobile (<600dp) job picker matching the `mob cl app` reference: a
/// `Select Job` label over a filled dropdown field. Opening it lists every
/// posted job (native menu — scrollable and viewport-constrained, so long
/// lists and long titles stay usable); picking one reuses [_selectJob], so
/// the applicants panel below reloads per job exactly like desktop.
class _SelectJobDropdown extends StatelessWidget {
  const _SelectJobDropdown({
    required this.jobs,
    required this.posted,
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
  });

  final JobProvider jobs;
  final List<Job> posted;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    if (jobs.isLoading && posted.isEmpty) {
      final Color fill = colors.surfaceContainerHighest.withValues(
        alpha: context.isDarkMode ? 1.0 : 0.45,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Select Job',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.md,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                Text(
                  'Loading jobs…',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (jobs.lastError != null && posted.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    final Color fill = colors.surfaceContainerHighest.withValues(
      alpha: context.isDarkMode ? 1.0 : 0.45,
    );
    final bool enabled = posted.isNotEmpty;
    final String? value =
        selectedId != null && posted.any((Job job) => job.id == selectedId)
        ? selectedId
        : null;
    OutlineInputBorder border(Color? side, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: side == null
              ? BorderSide.none
              : BorderSide(color: side, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Select Job',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        DropdownButtonFormField<String>(
          // Rebuild per selection so `initialValue` always reflects the
          // selected job; expanded so long titles ellipsize in place.
          key: ValueKey<String?>('select-job-$value'),
          isExpanded: true,
          initialValue: value,
          hint: Text(
            'Select a job',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          items: <DropdownMenuItem<String>>[
            for (final Job job in posted)
              DropdownMenuItem<String>(
                value: job.id,
                child: Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: enabled
              ? (String? id) {
                  if (id != null) onSelect(id);
                }
              : null,
          style: context.textTheme.bodyLarge?.copyWith(
            color: colors.onSurface,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: HivorrSpacing.md,
              vertical: 15,
            ),
            border: border(null),
            enabledBorder: border(null),
            focusedBorder: border(colors.primary, 1.5),
            errorBorder: border(colors.error),
            focusedErrorBorder: border(colors.error, 1.5),
          ),
        ),
      ],
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

/// Merged applicant identity for inbox surfaces (Phase 5).
///
/// Snapshot-first: the submit-time snapshot on the application row needs no
/// RPC; the resolved public profile fills snapshot-less rows only.
/// Whitelisted public fields throughout — never private account data, never
/// raw ids, never fabricated names. `displayName`/`headline` are null when
/// neither source has them (caller renders the generic fallback); the slug
/// always resolves (cosmetic route segment, `:id` is authoritative).
({String? displayName, String? headline, String profileSlug})
    _applicantIdentity(
  JobApplication application,
  Map<String, PublicProfile?> identities,
) {
  final PublicProfile? resolved =
      identities[application.professionalEntityId.trim()];
  final String? snapshotName = application.applicantDisplayName?.trim();
  final String? displayName = (snapshotName != null && snapshotName.isNotEmpty)
      ? snapshotName
      : resolved?.displayName.trim().isNotEmpty == true
          ? resolved!.displayName.trim()
          : null;
  final String? snapshotProfession =
      application.applicantProfessionName?.trim();
  final String? headline =
      (snapshotProfession != null && snapshotProfession.isNotEmpty)
          ? snapshotProfession
          : resolved?.professionName?.trim().isNotEmpty == true
              ? resolved!.professionName!.trim()
              : resolved?.industryName?.trim().isNotEmpty == true
                  ? resolved!.industryName!.trim()
                  : null;
  final String? snapshotSlug = application.applicantProfessionSlug?.trim();
  final String profileSlug = (snapshotSlug != null && snapshotSlug.isNotEmpty)
      ? snapshotSlug
      : resolved?.professionSlug?.trim().isNotEmpty == true
          ? resolved!.professionSlug!.trim()
          : 'professional';
  return (
    displayName: displayName,
    headline: headline,
    profileSlug: profileSlug,
  );
}

/// Right pane: applicants for the selected job with its own scroll.
///
/// The header total is the authoritative trigger-maintained
/// `job.applicationsCount` (same source as the My Jobs badges) so the two
/// surfaces stay consistent. The loaded list (`application_list_for_job`,
/// capped at 50) may be a subset — truncation is surfaced explicitly as
/// "Showing X of N" instead of silently showing a divergent length.
///
/// Phase 5 review flow: the pane shows the concise applicant list until
/// [selectedId] names an application, then the dedicated detail view for a
/// focused proposal review (one experience across mobile and desktop).
class _ApplicantsPanel extends StatelessWidget {
  const _ApplicantsPanel({
    required this.job,
    required this.apps,
    this.identities = const <String, PublicProfile?>{},
    this.hasMore = false,
    required this.loading,
    required this.error,
    required this.acting,
    required this.scrollController,
    required this.onRetry,
    required this.onShortlist,
    required this.onHire,
    required this.onReject,
    this.selectedId,
    this.onSelect,
    this.onBack,
  });

  final Job? job;
  final List<JobApplication> apps;
  final Map<String, PublicProfile?> identities;
  final bool hasMore;
  final bool loading;
  final String? error;
  final Set<String> acting;
  final ScrollController scrollController;
  final Future<void> Function()? onRetry;
  final ValueChanged<JobApplication> onShortlist;
  final ValueChanged<JobApplication> onHire;
  final ValueChanged<JobApplication> onReject;
  final String? selectedId;
  final ValueChanged<JobApplication>? onSelect;
  final VoidCallback? onBack;

  JobApplication? get _selected {
    final String? id = selectedId;
    if (id == null) return null;
    for (final JobApplication app in apps) {
      if (app.id == id) return app;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final Job? selectedJob = job;
    final JobApplication? selected = _selected;
    return _PanelCard(
      child: Padding(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (selected != null && selectedJob != null) ...<Widget>[
              _DetailBackRow(onBack: onBack),
              const SizedBox(height: HivorrSpacing.sm),
              _ApplicantsHeader(
                job: selectedJob,
                loadedCount: apps.length,
                hasMore: hasMore,
                loading: loading && apps.isEmpty,
              ),
            ] else if (selectedJob == null)
              Text(
                'Select a job',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              _ApplicantsHeader(
                job: selectedJob,
                loadedCount: apps.length,
                hasMore: hasMore,
                loading: loading && apps.isEmpty,
              ),
            const SizedBox(height: HivorrSpacing.sm),
            Divider(height: 1, color: context.colorScheme.outlineVariant),
            const SizedBox(height: HivorrSpacing.md),
            Expanded(child: _applicantsContent(context, selected)),
          ],
        ),
      ),
    );
  }

  Widget _applicantsContent(BuildContext context, JobApplication? selected) {
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
    // Dedicated review view: the selected application opens here so the
    // client reads the full proposal before deciding. The row is looked up
    // live so post-action status updates converge without a refetch.
    if (selected != null) {
      final ({String? displayName, String? headline, String profileSlug})
          identity = _applicantIdentity(selected, identities);
      final Widget detail = _ApplicationDetail(
        application: selected,
        displayName: identity.displayName,
        headline: identity.headline,
        profileSlug: identity.profileSlug,
        busy: acting.contains(selected.id),
        onShortlist: () => onShortlist(selected),
        onHire: () => onHire(selected),
        onReject: () => onReject(selected),
      );
      if (onRetry == null) {
        return SingleChildScrollView(
          controller: scrollController,
          child: detail,
        );
      }
      return RefreshIndicator(
        onRefresh: onRetry!,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: detail,
        ),
      );
    }
    // The selection names an application that is no longer in the loaded
    // list (e.g. withdrawn elsewhere and refreshed): offer the way back
    // instead of a dead end.
    if (selectedId != null) {
      return HivorrEmptyState(
        title: 'Application unavailable',
        subtitle:
            'This application is no longer in the loaded list. Pull to refresh or pick another applicant.',
        actionButton: onBack == null
            ? null
            : HivorrButton(
                label: 'Back to applicants',
                variant: HivorrButtonVariant.secondary,
                onPressed: onBack!,
              ),
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
        final ({String? displayName, String? headline, String profileSlug})
            identity = _applicantIdentity(application, identities);
        return _ApplicantCard(
          application: application,
          displayName: identity.displayName,
          headline: identity.headline,
          profileSlug: identity.profileSlug,
          onTap: onSelect == null ? null : () => onSelect!(application),
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

/// Back row rendered above the job header while a review is open.
class _DetailBackRow extends StatelessWidget {
  const _DetailBackRow({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _TintedAction(
        label: 'Applicants',
        icon: Icons.arrow_back,
        fill: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: context.isDarkMode ? 1.0 : 0.45,
        ),
        foreground: context.colorScheme.onSurfaceVariant,
        onTap: onBack,
      ),
    );
  }
}

class _ApplicantsHeader extends StatelessWidget {
  const _ApplicantsHeader({
    required this.job,
    required this.loadedCount,
    this.hasMore = false,
    this.loading = false,
  });

  final Job job;
  final int loadedCount;
  final bool hasMore;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final ext = context.appExtension;
    final double? budget = job.budgetMax ?? job.budgetMin;
    // Authoritative total shares the My Jobs badge source
    // (`jobs.applications_count`, INSERT/DELETE trigger). The loaded list is
    // paged (limit 50), so truncation is stated explicitly. When the trigger
    // lags behind a freshly loaded list, the fresher list length wins to
    // avoid showing "Showing 2 of 1".
    final int total = job.applicationsCount;
    final String countText;
    if (loading) {
      countText = total > 0 ? '$total applications' : 'Loading applications…';
    } else if (hasMore || loadedCount < total) {
      countText = total > 0
          ? '$total applications · Showing $loadedCount'
          : 'No applications yet';
    } else if (loadedCount > total) {
      countText = '$loadedCount applications';
    } else {
      countText = '$total applications';
    }
    final String subtitle = budget == null
        ? countText
        : '$countText · \$${HivorrFormatters.number(budget, decimals: 0)} budget';
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
                  fontWeight: FontWeight.w600,
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

/// Concise applicant row (Phase 5): identity, status, and a clamped proposal
/// preview. The whole card is the select target that opens the dedicated
/// review view — decision actions deliberately live in the detail, never on
/// the list, so the client reviews before deciding.
///
/// [displayName]/[headline] arrive pre-merged from the caller (snapshot
/// first, public-profile fallback); when absent the header falls back to a
/// generic `Applicant` label with `AP` initials — never a raw database
/// identifier, never a fabricated name.
class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.application,
    this.displayName,
    this.headline,
    this.profileSlug = 'professional',
    this.onTap,
  });

  final JobApplication application;
  final String? displayName;
  final String? headline;
  final String profileSlug;
  final VoidCallback? onTap;

  String get _initials {
    final String? name = displayName;
    if (name == null) return 'AP';
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'AP';
    if (parts.length == 1) {
      final String word = parts.first;
      return word.length == 1
          ? word.toUpperCase()
          : word.substring(0, 2).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get _title => displayName ?? 'Applicant';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ApplicantAvatar(initials: _initials),
            const SizedBox(width: HivorrSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (headline != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      headline!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
        // Clamped preview: the full proposal lives in the review view.
        Text(
          application.coverNote,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Tap to review the full proposal',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
    final VoidCallback? tap = onTap;
    if (tap == null) return body;
    return Semantics(
      button: true,
      label: 'Review application from $_title',
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
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

/// Circular initials avatar shared by the list rows and the review view.
class _ApplicantAvatar extends StatelessWidget {
  const _ApplicantAvatar({required this.initials, this.size = 52});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer.withValues(
          alpha: context.isDarkMode ? 0.5 : 0.7,
        ),
        border: Border.all(color: colors.primary, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: context.textTheme.titleMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Dedicated application-review view (Phase 5).
///
/// Opened by tapping an applicant row so the client reads the full proposal
/// and all submitted details before deciding. Decision actions reuse the
/// existing status seams with identical rules (Shortlist iff `submitted`,
/// Hire iff `shortlisted`, Reject iff active with confirmation, hired pill
/// once accepted). Pre-hire messaging keeps the existing messages-list seam
/// — no hire is forced and no parallel thread system is introduced. Success
/// is only reported after the underlying RPC succeeds (via the shared
/// `_runAction`); failures surface as error snackbars.
class _ApplicationDetail extends StatelessWidget {
  const _ApplicationDetail({
    required this.application,
    this.displayName,
    this.headline,
    this.profileSlug = 'professional',
    required this.busy,
    required this.onShortlist,
    required this.onHire,
    required this.onReject,
  });

  final JobApplication application;
  final String? displayName;
  final String? headline;
  final String profileSlug;
  final bool busy;
  final VoidCallback onShortlist;
  final VoidCallback onHire;
  final VoidCallback onReject;

  String get _title => displayName ?? 'Applicant';

  String get _initials {
    final String? name = displayName;
    if (name == null) return 'AP';
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'AP';
    if (parts.length == 1) {
      final String word = parts.first;
      return word.length == 1
          ? word.toUpperCase()
          : word.substring(0, 2).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _confirmReject(BuildContext context) async {
    if (busy) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reject application?'),
        content: Text(
          'This will reject the application from "$_title". '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) onReject();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final bool active =
        application.status == 'submitted' ||
        application.status == 'shortlisted';
    final String price = application.quotedAmount == null
        ? '—'
        : '${application.currencyCode} '
            '${HivorrFormatters.number(application.quotedAmount!, decimals: 0)}';
    final String duration = application.durationDays == null
        ? '—'
        : '${application.durationDays} days';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ApplicantAvatar(initials: _initials, size: 64),
            const SizedBox(width: HivorrSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (headline != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      headline!,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _ApplicationStatusPill(status: application.status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.md),
        Container(
          padding: const EdgeInsets.all(HivorrSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(
              alpha: context.isDarkMode ? 1.0 : 0.45,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: <Widget>[
              _DetailInfoRow(label: 'Proposed price', value: price),
              const SizedBox(height: HivorrSpacing.xs),
              _DetailInfoRow(label: 'Duration', value: duration),
              const SizedBox(height: HivorrSpacing.xs),
              _DetailInfoRow(
                label: 'Submitted',
                value: HivorrFormatters.relative(application.submittedAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: HivorrSpacing.md),
        Text(
          'Proposal',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: HivorrSpacing.xs),
        // Full write-up: soft-wraps in the pane width, so long proposals
        // stay readable on narrow screens with vertical scroll only.
        Text(
          application.coverNote,
          style: context.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: HivorrSpacing.lg),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            if (application.status == 'submitted')
              _PrimaryAction(
                label: busy ? 'Working…' : 'Shortlist',
                icon: Icons.check,
                enabled: !busy,
                onTap: onShortlist,
              ),
            if (application.status == 'shortlisted')
              _PrimaryAction(
                label: busy ? 'Working…' : 'Hire',
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
                  slug: profileSlug,
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
                onTap: busy ? null : () => _confirmReject(context),
              ),
          ],
        ),
      ],
    );
  }
}

/// Label/value row inside the review info panel.
class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: HivorrSpacing.md),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
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
