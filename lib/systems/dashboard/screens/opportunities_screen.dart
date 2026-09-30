import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/core/authentication/providers/auth_provider.dart';
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
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/systems/dashboard/models/dashboard_capability.dart';
import 'package:hivorr/systems/dashboard/providers/dashboard_view_mode_provider.dart';
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
        appBar: AppBar(
          toolbarHeight: 48,
          title: Text(
            'Find Work',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Notifications',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go(RoutePaths.dashboardNotifications),
            ),
            IconButton(
              tooltip: 'Refresh',
              iconSize: 20,
              padding: const EdgeInsets.all(HivorrSpacing.sm),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(Icons.refresh),
              onPressed: () => unawaited(_load(refresh: true)),
            ),
          ],
        ),
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
    final ColorScheme colors = context.colorScheme;
    final RoleThemeExtension roles = context.roleTheme;
    bool hasDot = false;
    try {
      hasDot = context.watch<JobProvider>().discovery.isNotEmpty;
    } catch (_) {
      hasDot = false;
    }
    final ({String name, String initials}) identity = _fwIdentity(context);
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
            'Find Work',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          _TopBarTile(
            tooltip: 'Notifications',
            icon: Icons.notifications_outlined,
            showDot: hasDot,
            onTap: () => context.go(RoutePaths.dashboardNotifications),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: roles.professionalContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: roles.professionalPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: HivorrSpacing.xs),
                Text(
                  'Professional',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: roles.professionalPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Tooltip(
            message: identity.name,
            child: InkWell(
              onTap: () => context.go(RoutePaths.dashboardAccount),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: roles.professionalContainer,
                  border: Border.all(
                    color: roles.professionalPrimary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  identity.initials,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: roles.professionalPrimary,
                    fontWeight: FontWeight.w800,
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
    return Semantics(
      textField: true,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: context.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search jobs by title, company, or skill…',
          hintStyle: context.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_outlined,
            size: 20,
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
        ),
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

/// Responsive opportunity grid (reference): two columns on wide layouts,
/// one column on narrow widths. Cards keep a fixed extent per row so the
/// action row aligns, with pull-to-refresh and infinite pagination kept.
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
        final bool twoCol = c.maxWidth >= 900;
        final bool compact = MobileCompact.isCompactWidth(c.maxWidth);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: GridView.builder(
            controller: scroll,
            padding: EdgeInsets.all(compact ? HivorrSpacing.md : 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: twoCol ? 2 : 1,
              crossAxisSpacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
              mainAxisSpacing: compact ? HivorrSpacing.sm : HivorrSpacing.md,
              mainAxisExtent: twoCol ? 330 : 310,
            ),
            itemCount:
                displayed.length + (jobs.discoveryHasMore && !_filtered() ? 1 : 0),
            itemBuilder: (BuildContext context, int i) {
              if (i >= displayed.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: HivorrSpacing.md),
                  child: HivorrLoadingState(),
                );
              }
              final Job job = displayed[i];
              return _FindWorkCard(
                job: job,
                applied: appliedIds.contains(job.id),
                onApply: () => onApply(job),
                saved: savedIds.contains(job.id),
                onToggleSaved: () => onToggleSaved(job.id),
              );
            },
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
      borderRadius: compact ? 14 : 16,
      padding: EdgeInsets.all(
        compact ? HivorrSpacing.md : HivorrSpacing.lg,
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
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _FwPill(
                            label: category,
                            background: colors.primaryContainer,
                            foreground: colors.primary,
                          ),
                          if (urgent)
                            _FwPill(
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
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 16 : 18,
                            ),
                          ),
                        Text(
                          '${job.applicationsCount} applied',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
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
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 15 : 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fwCompanyLine(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.description.split('\n').first.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontSize: compact ? 13 : 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(height: 4),
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
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
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
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
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
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: roles.professionalPrimary,
                            borderRadius: BorderRadius.circular(12),
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
                              const SizedBox(width: 6),
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: context.isDarkMode ? 1.0 : 0.55,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      saved ? Icons.favorite : Icons.favorite_border,
                      size: 22,
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: ext.successContainer,
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 6),
              Text(
                'Applied!',
                style: context.textTheme.labelLarge?.copyWith(
                  color: ext.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FwPill extends StatelessWidget {
  const _FwPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: foreground,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _sort = _FwSort.recommended;
                      _urgentOnly = false;
                    }),
                    child: const Text('Reset'),
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
    return Dialog(
      insetPadding: const EdgeInsets.all(HivorrSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HivorrSpacing.lg),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _sending
                          ? null
                          : () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: context.isDarkMode ? 1.0 : 0.55,
                          ),
                          borderRadius: BorderRadius.circular(10),
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          Color(0xFF22C55E),
                          Color(0xFF16A34A),
                        ],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_sending)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.onPrimary,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: colors.onPrimary,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _sending ? 'Submitting…' : 'Submit Application',
                          style: context.textTheme.titleMedium?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w800,
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
