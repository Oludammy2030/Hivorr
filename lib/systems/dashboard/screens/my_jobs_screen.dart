import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_paths.dart';
import 'package:hivorr/core/api/exceptions/api_exception.dart';
import 'package:hivorr/data/entities/job.dart';
import 'package:hivorr/data/providers/job_provider.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/breakpoints.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_error_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_snackbar.dart';
import 'package:provider/provider.dart';

/// Client's posted jobs with reference tab filters (EP-04-03).
///
/// One page, four selectable views at the top of the body:
///
/// `All Jobs | Open | In Progress | Completed`
///
/// backed by `GET job_list_mine(posted)` with client-side filtering:
/// all → everything, open → `open`, in progress → `awarded`,
/// completed → `completed`. Draft/paused/cancelled rows only surface under
/// All Jobs (no server vocabulary change). Card actions reuse the existing
/// destinations: Applications/title → job detail (applications inbox),
/// Chat → messages, Close → `cancel` with confirm (hidden once terminal).
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
  ];

  static const double _contentMaxWidth = 1120;
  static const double _gridBreakpoint = 900;

  String _activeTab = 'all';
  final Set<String> _closing = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<JobProvider>().loadMine(role: 'posted');

  List<Job> _filtered(List<Job> posted) {
    switch (_activeTab) {
      case 'open':
        return posted.where((Job j) => j.status == 'open').toList();
      case 'awarded':
        return posted.where((Job j) => j.status == 'awarded').toList();
      case 'completed':
        return posted.where((Job j) => j.status == 'completed').toList();
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

  @override
  Widget build(BuildContext context) {
    final JobProvider jobs = context.watch<JobProvider>();
    final List<Job> posted = jobs.posted;
    final List<Job> filtered = _filtered(posted);
    final int openCount = posted.where((Job j) => j.status == 'open').length;
    final bool isMobile = context.breakpoint == Breakpoint.mobile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isMobile
          ? AppBar(
              title: Text('My Jobs', style: context.textTheme.titleLarge),
            )
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
                            gridBreakpoint: _gridBreakpoint,
                            onRetry: _load,
                            onClose: _confirmClose,
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
/// Employer pill and account avatar.
class _MyJobsTopBar extends StatelessWidget {
  const _MyJobsTopBar();

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
            'My Jobs',
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
                  'Employer',
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

/// Title row from the reference with the Post New Job CTA.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.total, required this.openCount});

  final int total;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'My Posted Jobs',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: HivorrSpacing.xs),
              Text(
                '$total jobs · $openCount open',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: HivorrSpacing.md),
        HivorrButton(
          label: 'Post New Job',
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => context.go(RoutePaths.dashboardJobNew),
        ),
      ],
    );
  }
}

/// Pill tab row: All Jobs | Open | In Progress | Completed.
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
            _TabPill(
              label: tabs[i].label,
              selected: tabs[i].key == activeKey,
              onTap: () => onSelect(tabs[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
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
    required this.gridBreakpoint,
    required this.onRetry,
    required this.onClose,
  });

  final JobProvider jobs;
  final List<Job> posted;
  final List<Job> filtered;
  final String activeTab;
  final Set<String> closing;
  final double gridBreakpoint;
  final Future<void> Function() onRetry;
  final Future<void> Function(Job job) onClose;

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
        if (c.maxWidth < gridBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < filtered.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: HivorrSpacing.md),
                _PostedJobCard(
                  job: filtered[i],
                  closing: closing.contains(filtered[i].id),
                  onClose: () => onClose(filtered[i]),
                ),
              ],
            ],
          );
        }
        final List<List<Job>> rows = <List<Job>>[];
        for (int i = 0; i < filtered.length; i += 2) {
          rows.add(filtered.sublist(
            i,
            i + 2 > filtered.length ? filtered.length : i + 2,
          ));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int r = 0; r < rows.length; r++) ...<Widget>[
              if (r > 0) const SizedBox(height: HivorrSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _PostedJobCard(
                      job: rows[r][0],
                      closing: closing.contains(rows[r][0].id),
                      onClose: () => onClose(rows[r][0]),
                    ),
                  ),
                  const SizedBox(width: HivorrSpacing.md),
                  Expanded(
                    child: rows[r].length > 1
                        ? _PostedJobCard(
                            job: rows[r][1],
                            closing: closing.contains(rows[r][1].id),
                            onClose: () => onClose(rows[r][1]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  String _emptyTitle(String tab) => switch (tab) {
        'open' => 'No open jobs',
        'awarded' => 'Nothing in progress',
        'completed' => 'No completed jobs',
        _ => 'Nothing here yet',
      };
}

/// Reference job card: category + status pills, green price, title,
/// client · location, Applications / Chat / Close actions.
class _PostedJobCard extends StatelessWidget {
  const _PostedJobCard({
    required this.job,
    required this.closing,
    required this.onClose,
  });

  final Job job;
  final bool closing;
  final VoidCallback onClose;

  bool get _closable => job.isEditable || job.isAwarded;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
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
        padding: const EdgeInsets.all(HivorrSpacing.lg),
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
            const SizedBox(height: HivorrSpacing.xs),
            Text(
              _subtitle(job),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HivorrSpacing.md),
            Wrap(
              spacing: HivorrSpacing.sm,
              runSpacing: HivorrSpacing.sm,
              children: <Widget>[
                _ApplicationsButton(job: job),
                _GhostButton(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  fill: colors.surfaceContainerHighest.withValues(
                    alpha: context.isDarkMode ? 1.0 : 0.45,
                  ),
                  foreground: colors.onSurfaceVariant,
                  onTap: () => context.go(RoutePaths.dashboardMessages),
                ),
                if (_closable)
                  _GhostButton(
                    label: closing ? 'Closing…' : 'Close',
                    icon: Icons.close,
                    fill: colors.errorContainer,
                    foreground: colors.error,
                    onTap: closing ? null : onClose,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Job job) {
    final String location = (job.location ?? '').trim();
    return location.isEmpty ? 'Remote' : location;
  }
}

/// Category pill: taxonomy id when bound, else General (no fake names).
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String raw =
        (job.industryId ?? job.professionId ?? 'General').trim();
    final String label = raw.isEmpty ? 'General' : _short(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: context.isDarkMode ? 0.5 : 0.7,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
    final ColorScheme colors = context.colorScheme;
    final ext = context.appExtension;
    final _Tone tone = switch (status) {
      'open' => _Tone(
          fill: ext.successContainer,
          text: ext.onSuccessContainer,
          label: 'open',
        ),
      'awarded' => _Tone(
          fill: ext.warningContainer,
          text: ext.onWarningContainer,
          label: 'in progress',
        ),
      'completed' => _Tone(
          fill: colors.surfaceContainerHighest.withValues(
            alpha: context.isDarkMode ? 1.0 : 0.6,
          ),
          text: colors.onSurfaceVariant,
          label: 'completed',
        ),
      _ => _Tone(
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

class _Tone {
  const _Tone({required this.fill, required this.text, required this.label});

  final Color fill;
  final Color text;
  final String label;
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
              fontWeight: FontWeight.w800,
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

class _ApplicationsButton extends StatelessWidget {
  const _ApplicationsButton({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => context.go(RoutePaths.dashboardJobDetail(job.id)),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.group_outlined, size: 16, color: colors.onPrimary),
              const SizedBox(width: 6),
              Text(
                '${job.applicationsCount} Applications',
                style: context.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimary,
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
    final Widget body = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: onTap == null ? fill.withValues(alpha: 0.6) : fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
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
