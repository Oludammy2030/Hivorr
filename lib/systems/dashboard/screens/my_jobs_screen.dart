import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/conversation.dart';
import 'package:hivorr/data/entities/hire.dart';
import 'package:hivorr/data/entities/job.dart';
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
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/systems/dashboard/shell/client_mobile_chrome.dart';
import 'package:hivorr/systems/dashboard/widgets/hiring_status_badge.dart';
import 'package:provider/provider.dart';

/// Client's posted jobs with reference tab filters (EP-04-03).
///
/// One page, six selectable views at the top of the body:
///
/// `All Jobs | Open | In Progress | Completed | Cancelled | Disputed`
///
/// backed by `GET job_list_mine(posted)` with client-side filtering:
/// all → everything, open → `open`, in progress → `awarded`,
/// completed → `completed`, cancelled → `cancelled`, disputed → jobs with
/// at least one `disputed` hire (jobs carry no disputed code — disputes live
/// on the linked hire/contract, consolidated here from the former Hires hub).
/// Draft/paused rows only surface under All Jobs (no server vocabulary
/// change). Card actions reuse the existing destinations: Applications/title
/// → job detail (applications inbox), Chat → messages, Close → `cancel` with
/// confirm (hidden once terminal). Each card also carries its Engagements
/// (linked hires consolidated from Hires): live status badges plus View Hire
/// (hire detail), Message (contract thread), Contract (escrow), Cancel Hire
/// (pending, with confirm), Complete Hire (completed contract) and File
/// Dispute (escrow) — same seams the hire detail uses.
/// Visual direction matches the My Posted Jobs reference: light page
/// background, white two-column cards, pill tabs, green price, blue
/// applications CTA.
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  static const List<_JobsTab> _tabs = <_JobsTab>[
    _JobsTab(label: 'All Jobs', key: 'all'),
    _JobsTab(label: 'Open', key: 'open'),
    _JobsTab(label: 'In Progress', key: 'awarded'),
    _JobsTab(label: 'Completed', key: 'completed'),
    _JobsTab(label: 'Cancelled', key: 'cancelled'),
    _JobsTab(label: 'Disputed', key: 'disputed'),
  ];

  static const double _contentMaxWidth = 1120;


  String _activeTab = 'all';
  final Set<String> _closing = <String>{};
  final Set<String> _actingHires = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final JobProvider jobs = context.read<JobProvider>();
    final HireProvider hires = context.read<HireProvider>();
    await jobs.loadMine(role: 'posted');
    await hires.loadList(role: 'client');
  }

  Future<void> _refreshHires() =>
      context.read<HireProvider>().loadList(role: 'client');

  /// Groups client hires by their job for card-level engagement sections.
  Map<String, List<Hire>> _hiresByJob(List<Hire> hires) {
    final Map<String, List<Hire>> byJob = <String, List<Hire>>{};
    for (final Hire hire in hires) {
      byJob.putIfAbsent(hire.jobId, () => <Hire>[]).add(hire);
    }
    return byJob;
  }

  List<Job> _filtered(List<Job> posted, Map<String, List<Hire>> hiresByJob) {
    switch (_activeTab) {
      case 'open':
        return posted.where((Job j) => j.status == 'open').toList();
      case 'awarded':
        return posted.where((Job j) => j.status == 'awarded').toList();
      case 'completed':
        return posted.where((Job j) => j.status == 'completed').toList();
      case 'cancelled':
        return posted.where((Job j) => j.status == 'cancelled').toList();
      case 'disputed':
        return posted
            .where(
              (Job j) => (hiresByJob[j.id] ?? const <Hire>[]).any(
                (Hire h) => h.liveStatus == 'disputed',
              ),
            )
            .toList();
      case 'all':
      default:
        return posted;
    }
  }

  void _snack(String message, HivorrSnackbarVariant variant) {
    ScaffoldMessenger.of(context).showSnackBar(
      HivorrSnackbar.show(context, message: message, variant: variant),
    );
  }

  Future<void> _confirmClose(Job job) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Close job?'),
        content: Text(
          'This will cancel "${job.title}" and close it to new applications.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Open'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Close Job'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing.add(job.id));
    try {
      await context.read<JobProvider>().cancel(job.id);
      if (!mounted) return;
      _snack('Job closed.', HivorrSnackbarVariant.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _closing.remove(job.id));
    }
  }

  /// Cancels a pending hire (consolidated from the Hires hub — same
  /// `HireProvider.cancelHire` seam the hire detail uses).
  Future<void> _confirmCancelHire(Hire hire) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancel hire?'),
        content: Text(
          'This will cancel the hire for "${hire.jobTitle ?? 'this job'}" '
          'and release the professional.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Hire'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancel Hire'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actingHires.add(hire.id));
    try {
      await context.read<HireProvider>().cancelHire(hire.id);
      if (!mounted) return;
      _snack('Hire cancelled.', HivorrSnackbarVariant.success);
      unawaited(_refreshHires());
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _actingHires.remove(hire.id));
    }
  }

  /// Completes a hire on a completed contract (consolidated from the Hires
  /// hub — same `HireProvider.completeHire` seam the hire detail uses).
  Future<void> _completeHire(Hire hire) async {
    if (_actingHires.contains(hire.id)) return;
    setState(() => _actingHires.add(hire.id));
    try {
      await context.read<HireProvider>().completeHire(hire.id);
      if (!mounted) return;
      _snack('Hire completed.', HivorrSnackbarVariant.success);
      unawaited(_refreshHires());
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _actingHires.remove(hire.id));
    }
  }

  /// Opens the contract thread for a hire (same
  /// `MessagingProvider.ensureForContract` seam the hire detail uses),
  /// falling back to the Messages list when no thread resolves.
  Future<void> _openHireThread(Hire hire) async {
    final String contractId = hire.contractId?.trim() ?? '';
    if (contractId.isEmpty) {
      if (mounted) context.go(RoutePaths.dashboardMessages);
      return;
    }
    try {
      final Conversation conversation = await context
          .read<MessagingProvider>()
          .ensureForContract(contractId);
      if (!mounted) return;
      context.go(RoutePaths.dashboardMessageThread(conversation.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message, HivorrSnackbarVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final HireProvider hireProvider = context.watch<HireProvider>();
    final List<Job> posted = jobs.posted;
    final Map<String, List<Hire>> hiresByJob = _hiresByJob(
      hireProvider.hires,
    );
    final List<Job> filtered = _filtered(posted, hiresByJob);
    final int openCount = posted.where((Job j) => j.status == 'open').length;
    final bool isMobile = context.breakpoint == Breakpoint.mobile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: isMobile ? const ClientDashboardDrawer() : null,
      appBar: isMobile
          ? const ClientMobileAppBar(title: 'My Jobs')
          : null,
      body: MobileSafeBody(
        child: Column(
          children: <Widget>[
            if (!isMobile) const _MyJobsTopBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: MobileCompact.scrollPaddingForBreakpoint(
                    context.breakpoint,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _PageHeader(
                            total: posted.length,
                            openCount: openCount,
                          ),
                          SizedBox(
                            height: isMobile
                                ? HivorrSpacing.md
                                : HivorrSpacing.lg,
                          ),
                          _TabRow(
                            tabs: _tabs,
                            activeKey: _activeTab,
                            onSelect: (String key) =>
                                setState(() => _activeTab = key),
                          ),
                          SizedBox(
                            height: isMobile
                                ? HivorrSpacing.md
                                : HivorrSpacing.lg,
                          ),
                          _Body(
                            jobs: jobs,
                            posted: posted,
                            filtered: filtered,
                            activeTab: _activeTab,
                            closing: _closing,
                            hiresByJob: hiresByJob,
                            actingHires: _actingHires,
                            onRetry: _load,
                            onClose: _confirmClose,
                            onCancelHire: _confirmCancelHire,
                            onCompleteHire: _completeHire,
                            onMessageHire: _openHireThread,
                          ),
                        ],
                      ),
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

class _JobsTab {
  const _JobsTab({required this.label, required this.key});

  final String label;
  final String key;
}

/// Desktop top bar matching the reference: menu tile, page title, bell,
/// Client pill and account avatar.
class _MyJobsTopBar extends StatelessWidget {
  const _MyJobsTopBar();

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
      title: 'My Jobs',
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

/// Title row from the reference with the Post New Job CTA.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.total, required this.openCount});

  final int total;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    // Phones keep the title on one line next to a compact CTA: the smaller
    // title style + small button fit 320dp side by side, centered so neither
    // side drifts. Wider layouts keep the reference arrangement untouched.
    final bool compact = context.breakpoint == Breakpoint.mobile;
    return Row(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'My Posted Jobs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? context.textTheme.titleSmall
                        : context.textTheme.headlineSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                '$total jobs · $openCount open',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? HivorrSpacing.sm : HivorrSpacing.md),
        HivorrButton(
          label: 'Post New Job',
          icon: const Icon(Icons.add, size: 20),
          size: compact ? HivorrButtonSize.small : HivorrButtonSize.medium,
          onPressed: () => context.go(RoutePaths.dashboardJobNew),
        ),
      ],
    );
  }
}

/// Pill tab row: All Jobs | Open | In Progress | Completed | Cancelled | Disputed.
class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.tabs,
    required this.activeKey,
    required this.onSelect,
  });

  final List<_JobsTab> tabs;
  final String activeKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: HivorrSpacing.sm),
                HivorrChip(
                  label: tabs[i].label,
                  isSelected: tabs[i].key == activeKey,
                  onSelected: (_) => onSelect(tabs[i].key),
                ),
              ],
            ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.jobs,
    required this.posted,
    required this.filtered,
    required this.activeTab,
    required this.closing,
    required this.hiresByJob,
    required this.actingHires,
    required this.onRetry,
    required this.onClose,
    required this.onCancelHire,
    required this.onCompleteHire,
    required this.onMessageHire,
  });

  final JobProvider jobs;
  final List<Job> posted;
  final List<Job> filtered;
  final String activeTab;
  final Set<String> closing;
  final Map<String, List<Hire>> hiresByJob;
  final Set<String> actingHires;
  final Future<void> Function() onRetry;
  final Future<void> Function(Job job) onClose;
  final Future<void> Function(Hire hire) onCancelHire;
  final Future<void> Function(Hire hire) onCompleteHire;
  final Future<void> Function(Hire hire) onMessageHire;

  @override
  Widget build(BuildContext context) {
    if (jobs.isLoading && posted.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: HivorrSpacing.xl),
        child: HivorrLoadingState(),
      );
    }
    if (jobs.lastError != null && posted.isEmpty) {
      return HivorrErrorState(
        message: 'Could not load jobs',
        detail: jobs.lastError!.message,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (filtered.isEmpty) {
      final bool isAllEmpty = posted.isEmpty;
      return HivorrEmptyState(
        title: isAllEmpty ? 'No jobs posted yet' : _emptyTitle(activeTab),
        subtitle: isAllEmpty
            ? 'Create your first job and start receiving applications from qualified professionals.'
            : 'Try a different tab.',
        actionButton: isAllEmpty
            ? HivorrButton(
                label: 'Post New Job',
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => context.go(RoutePaths.dashboardJobNew),
              )
            : null,
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        Widget card(Job job) => _PostedJobCard(
              job: job,
              hires: hiresByJob[job.id] ?? const <Hire>[],
              closing: closing.contains(job.id),
              actingHires: actingHires,
              onClose: () => onClose(job),
              onCancelHire: onCancelHire,
              onCompleteHire: onCompleteHire,
              onMessageHire: onMessageHire,
            );
        // Content-card columns (§21a): 1 col <600, 2 cols 600–1023,
        // 3 cols ≥1024.
        final double width = c.maxWidth;
        final int columns = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        return HivorrStatGrid(
          columns: columns,
          maxWidth: width,
          children: <Widget>[
            for (final Job job in filtered) card(job),
          ],
        );
      },
    );
  }

  String _emptyTitle(String tab) => switch (tab) {
        'open' => 'No open jobs',
        'awarded' => 'Nothing in progress',
        'completed' => 'No completed jobs',
        'cancelled' => 'No cancelled jobs',
        'disputed' => 'No disputed jobs',
        _ => 'Nothing here yet',
      };
}

/// Reference job card: category + status pills, green price, title,
/// client · location, Applications / Chat / Close actions, plus the
/// Engagements section (linked hires consolidated from the Hires hub).
class _PostedJobCard extends StatelessWidget {
  const _PostedJobCard({
    required this.job,
    required this.hires,
    required this.closing,
    required this.actingHires,
    required this.onClose,
    required this.onCancelHire,
    required this.onCompleteHire,
    required this.onMessageHire,
  });

  final Job job;

  /// Linked hires for this job (may be empty — section hidden then).
  final List<Hire> hires;
  final bool closing;
  final Set<String> actingHires;
  final VoidCallback onClose;
  final Future<void> Function(Hire hire) onCancelHire;
  final Future<void> Function(Hire hire) onCompleteHire;
  final Future<void> Function(Hire hire) onMessageHire;

  bool get _closable => job.isEditable || job.isAwarded;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String? preview = _jobPreview(job);
    final double radius = context.appExtension.radiusMd + 4;
    return InkWell(
      onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
      borderRadius: BorderRadius.circular(radius),
      child: Container(
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
        padding: const EdgeInsets.all(HivorrSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: HivorrSpacing.xs,
                    runSpacing: HivorrSpacing.xs,
                    children: <Widget>[
                      _CategoryPill(job: job),
                      _StatusPill(status: job.status),
                      _LocationPill(job: job),
                    ],
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                _PriceBlock(job: job),
              ],
            ),
            const SizedBox(height: HivorrSpacing.sm),
            Text(
              job.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (preview != null) ...<Widget>[
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                preview,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              GestureDetector(
                onTap: () =>
                    context.go(RoutePaths.dashboardJobDetail(job.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Read more',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: HivorrSpacing.sm),
            ] else ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
            ],
            // Equal-height cluster: the primary button enforces the 48dp
            // touch floor, so each ghost pill sits in a fixed-height wrapper
            // (Center with widthFactor keeps widths content-based while
            // centering vertically). The wrap still flows on narrow screens.
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              HivorrButton(
                label: '${job.applicationsCount} Applicants',
                variant: HivorrButtonVariant.primary,
                size: HivorrButtonSize.small,
                icon: const Icon(Icons.group_outlined, size: 18),
                onPressed: () =>
                    context.go(RoutePaths.dashboardApplicationsFor(job.id)),
              ),
              // Fixed 48dp height matches the primary button; widthFactor
              // keeps the width content-based while centering vertically.
              SizedBox(
                height: 48,
                child: Center(
                  widthFactor: 1.0,
                  child: _GhostButton(
                    label: 'Message',
                    icon: Icons.chat_bubble_outline,
                    fill: colors.surfaceContainerHighest.withValues(
                      alpha: context.isDarkMode ? 1.0 : 0.45,
                    ),
                    foreground: colors.onSurfaceVariant,
                    onTap: () => context.go(RoutePaths.dashboardMessages),
                  ),
                ),
              ),
                if (_closable)
                  SizedBox(
                    height: 48,
                    child: Center(
                      widthFactor: 1.0,
                      child: _GhostButton(
                        label: closing ? 'Closing…' : 'Close',
                        icon: Icons.close,
                        fill: colors.errorContainer,
                        foreground: colors.error,
                        onTap: closing ? null : onClose,
                      ),
                    ),
                  ),
              ],
            ),
            if (hires.isNotEmpty) ...<Widget>[
              const SizedBox(height: HivorrSpacing.md),
              _EngagementsBlock(
                hires: hires,
                actingHires: actingHires,
                onCancelHire: onCancelHire,
                onCompleteHire: onCompleteHire,
                onMessageHire: onMessageHire,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Two-line description preview for the card body (the location chip
  /// above stays the single location display). Null when empty.
  String? _jobPreview(Job job) {
    final String description = job.description.trim();
    return description.isEmpty ? null : description;
  }
}

/// Location pill for the top chips row (falls back to `Remote`,
/// matching the previous subtitle convention).
class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final String location = (job.location ?? '').trim();
    return HivorrBadge(
      label: location.isEmpty ? 'Remote' : location,
      variant: HivorrBadgeVariant.neutral,
    );
  }
}

/// Engagements consolidated from the Hires hub: one row per linked hire
/// with its live status badge plus the hire-level actions that previously
/// lived behind Hires → hire detail.
///
/// Cancel Hire (pending hires, confirmed), Complete Hire (completed
/// contracts), Message (contract thread), Contract (linked escrow) and File
/// Dispute (escrow dispute filing) all reuse the hire-detail seams — nothing
/// is duplicated, and no hire data, record or workflow is lost.
class _EngagementsBlock extends StatelessWidget {
  const _EngagementsBlock({
    required this.hires,
    required this.actingHires,
    required this.onCancelHire,
    required this.onCompleteHire,
    required this.onMessageHire,
  });

  final List<Hire> hires;
  final Set<String> actingHires;
  final Future<void> Function(Hire hire) onCancelHire;
  final Future<void> Function(Hire hire) onCompleteHire;
  final Future<void> Function(Hire hire) onMessageHire;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(
          alpha: context.isDarkMode ? 1.0 : 0.45,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Engagements (${hires.length})',
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
          for (int i = 0; i < hires.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: HivorrSpacing.sm),
            _EngagementRow(
              hire: hires[i],
              acting: actingHires.contains(hires[i].id),
              warningFill: ext.warningContainer,
              warningForeground: ext.warning,
              onCancelHire: onCancelHire,
              onCompleteHire: onCompleteHire,
              onMessageHire: onMessageHire,
            ),
          ],
        ],
      ),
    );
  }
}

class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.hire,
    required this.acting,
    required this.warningFill,
    required this.warningForeground,
    required this.onCancelHire,
    required this.onCompleteHire,
    required this.onMessageHire,
  });

  final Hire hire;
  final bool acting;
  final Color warningFill;
  final Color warningForeground;
  final Future<void> Function(Hire hire) onCancelHire;
  final Future<void> Function(Hire hire) onCompleteHire;
  final Future<void> Function(Hire hire) onMessageHire;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String? contractId = hire.contractId?.trim().isEmpty ?? true
        ? null
        : hire.contractId!.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                hire.jobTitle ?? 'Hire',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: HivorrSpacing.sm),
            HiringStatusBadge(code: hire.liveStatus),
          ],
        ),
        const SizedBox(height: HivorrSpacing.xs),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            _GhostButton(
              label: 'View Hire',
              icon: Icons.visibility_outlined,
              fill: colors.primaryContainer.withValues(
                alpha: context.isDarkMode ? 0.5 : 0.7,
              ),
              foreground: colors.primary,
              onTap: () =>
                  context.go(RoutePaths.dashboardHireDetail(hire.id)),
            ),
            _GhostButton(
              label: 'Message',
              icon: Icons.chat_bubble_outline,
              fill: colors.surface,
              foreground: colors.onSurfaceVariant,
              onTap: () => onMessageHire(hire),
            ),
            if (contractId != null)
              _GhostButton(
                label: 'View Contract',
                icon: Icons.description_outlined,
                fill: colors.surface,
                foreground: colors.onSurfaceVariant,
                onTap: () =>
                    context.go(RoutePaths.contractDetail(contractId)),
              ),
            if (contractId != null)
              _GhostButton(
                label: 'Escrow',
                icon: Icons.lock_outline,
                fill: colors.surface,
                foreground: colors.onSurfaceVariant,
                onTap: () =>
                    context.go('/finance/escrow/$contractId'),
              ),
            if (hire.isPending)
              _GhostButton(
                label: acting ? 'Cancelling…' : 'Cancel Hire',
                icon: Icons.close,
                fill: colors.errorContainer,
                foreground: colors.error,
                onTap: acting ? null : () => onCancelHire(hire),
              ),
            if (hire.liveStatus == 'completed')
              _GhostButton(
                label: acting ? 'Working…' : 'Complete Hire',
                icon: Icons.check_circle_outline,
                fill: colors.primary,
                foreground: colors.onPrimary,
                onTap: acting ? null : () => onCompleteHire(hire),
              ),
            if (contractId != null)
              _GhostButton(
                label: 'File Dispute',
                icon: Icons.flag_outlined,
                fill: warningFill,
                foreground: warningForeground,
                onTap: () =>
                    context.go(RoutePaths.disputesFile(contractId)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Category pill: taxonomy id when bound, else General (no fake names).
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final String raw =
        (job.industryId ?? job.professionId ?? 'General').trim();
    final String label = raw.isEmpty ? 'General' : _short(raw);
    return HivorrBadge(label: label, variant: HivorrBadgeVariant.primary);
  }

  String _short(String value) {
    final String single = value.split('/').last.split('|').first.trim();
    if (single.length <= 14) return _capitalized(single);
    return _capitalized(single.substring(0, 14));
  }

  String _capitalized(String value) {
    if (value.isEmpty) return 'General';
    return value[0].toUpperCase() + value.substring(1);
  }
}

/// Status pill: open → green, awarded/in progress → orange,
/// completed → gray, everything else → neutral.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String label = switch (status) {
      'open' => 'open',
      'awarded' => 'in progress',
      'completed' => 'completed',
      _ => status,
    };
    final HivorrBadgeVariant variant = switch (status) {
      'open' => HivorrBadgeVariant.success,
      'awarded' => HivorrBadgeVariant.warning,
      _ => HivorrBadgeVariant.neutral,
    };
    return HivorrBadge(label: label, variant: variant);
  }
}

/// Green fixed-price block with the applied count underneath.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final double? amount = job.budgetMax ?? job.budgetMin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (amount != null)
          Text(
            '\$${HivorrFormatters.number(amount, decimals: 0)}',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.appExtension.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          '${job.applicationsCount} applied',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget action = HivorrTableAction(
      label: label,
      icon: icon,
      foreground: foreground,
      background: onTap == null ? fill.withValues(alpha: 0.6) : fill,
      onTap: onTap,
    );
    if (onTap == null) return action;
    return Semantics(
      button: true,
      label: label,
      child: action,
    );
  }
}
