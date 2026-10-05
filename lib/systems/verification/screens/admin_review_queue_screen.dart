import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
import 'package:hivorr/shared/components/hivorr_data_table.dart';
import 'package:hivorr/shared/components/hivorr_stat_card.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_formatters.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_avatar.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_chip.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/verification/widgets/review_detail_panels.dart';
import 'package:provider/provider.dart';

/// Admin review queue screen: Professional Verification Queue.
///
/// Enterprise triage layout: breadcrumbs + four-metric row + pending
/// submissions table + contextual right-side review panel. The table and the
/// metrics bind to real [AdminReviewProvider] data only — metrics without a
/// backend source render an explicit "Unavailable" state, never invented
/// figures. The pushed detail route stays for narrow widths and deep links.
class AdminReviewQueueScreen extends StatefulWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  State<AdminReviewQueueScreen> createState() => _AdminReviewQueueScreenState();
}

/// Client-side sort over the loaded page (the queue RPC exposes no sort).
enum _SortMode { newest, oldest, name }

class _AdminReviewQueueScreenState extends State<AdminReviewQueueScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Server-side submission-type filter (passed to `loadQueue`).
  String? _selectedType;

  /// Client-side filters over the loaded page (the queue RPC accepts only
  /// `submissionType`; search, lifecycle status, profession, and sort apply
  /// locally, mirroring the directory pattern without inventing params).
  String _query = '';
  String? _statusFilter;
  String? _professionFilter;
  _SortMode _sortMode = _SortMode.newest;

  /// Slide-over selection. `null` auto-resolves to the first visible row;
  /// [_panelClosed] suppresses that auto-select after an explicit close.
  String? _selectedId;
  bool _panelClosed = false;
  String? _pendingAuditId;

  static const List<String?> _typeOptions = <String?>[
    null,
    'trade_proof',
    'identity_document',
    'certification',
  ];

  static const List<String?> _statusOptions = <String?>[
    null,
    'pending',
    'in_review',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AdminReviewProvider>();
      // Retained so polling stops on dispose, when ancestor lookup no
      // longer resolves (unmounted context).
      _provider = provider;
      // Ensure admin flag is hydrated, then load queue.
      unawaited(
        provider.checkAdmin().then((_) {
          if (!mounted) return;
          if (AdminGate.isAdmin(provider)) {
            unawaited(provider.loadQueue());
            unawaited(provider.loadMetrics());
            provider.startPolling();
          }
        }),
      );
    });
  }

  AdminReviewProvider? _provider;

  @override
  void dispose() {
    _provider?.stopPolling();
    _provider = null;
    _searchController.dispose();
    super.dispose();
  }

  void _selectType(String? type) {
    setState(() {
      _selectedType = type;
      _selectedId = null;
      _panelClosed = false;
    });
    final AdminReviewProvider provider = context.read<AdminReviewProvider>();
    unawaited(_loadQueuePage(provider));
    unawaited(provider.loadMetrics(submissionType: type));
  }

  /// Server filter bundle mirroring the client-side [_visible] view, so the
  /// loaded pages already narrow/order server-side and pagination counts
  /// stay honest. The status chip stays client-only (`p_status` default).
  String get _sortParam => switch (_sortMode) {
    _SortMode.oldest => 'oldest',
    _SortMode.name => 'name',
    _SortMode.newest => 'newest',
  };

  String? _professionIdFor(List<AdminReviewQueueEntry> queue, String? name) {
    if (name == null) return null;
    for (final AdminReviewQueueEntry e in queue) {
      if ((e.professionName ?? '').trim() == name &&
          (e.professionId ?? '').isNotEmpty) {
        return e.professionId;
      }
    }
    return null;
  }

  Future<void> _loadQueuePage(AdminReviewProvider provider) {
    final String query = _query.trim();
    return provider.loadQueue(
      submissionType: _selectedType,
      search: query.isEmpty ? null : query,
      professionId: _professionIdFor(provider.queue, _professionFilter),
      sort: _sortParam,
    );
  }

  Future<void> _loadMorePage(AdminReviewProvider provider) {
    final String query = _query.trim();
    return provider.loadMore(
      submissionType: _selectedType,
      search: query.isEmpty ? null : query,
      professionId: _professionIdFor(provider.queue, _professionFilter),
      sort: _sortParam,
    );
  }

  /// Client-side view over the loaded page: search, status, profession, sort.
  /// Mirrors the server filters sent by [_loadQueuePage] so rows stay
  /// consistent before the reload lands; the status chip is client-only.
  List<AdminReviewQueueEntry> _visible(List<AdminReviewQueueEntry> queue) {
    Iterable<AdminReviewQueueEntry> items = queue;
    final String query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where(
        (AdminReviewQueueEntry e) =>
            e.entityName.toLowerCase().contains(query) ||
            (e.entityLegalName?.toLowerCase().contains(query) ?? false) ||
            e.credentialName.toLowerCase().contains(query),
      );
    }
    if (_statusFilter != null) {
      items = items.where(
        (AdminReviewQueueEntry e) =>
            _normalizedStatus(e.status) == _statusFilter,
      );
    }
    if (_professionFilter != null) {
      items = items.where(
        (AdminReviewQueueEntry e) =>
            (e.professionName ?? '') == _professionFilter,
      );
    }
    final List<AdminReviewQueueEntry> sorted = items.toList(growable: false)
      ..sort((AdminReviewQueueEntry a, AdminReviewQueueEntry b) {
        switch (_sortMode) {
          case _SortMode.oldest:
            return a.submittedAt.compareTo(b.submittedAt);
          case _SortMode.name:
            return a.entityName.toLowerCase().compareTo(
              b.entityName.toLowerCase(),
            );
          case _SortMode.newest:
            return b.submittedAt.compareTo(a.submittedAt);
        }
      });
    return sorted;
  }

  bool get _isFiltered =>
      _query.trim().isNotEmpty ||
      _statusFilter != null ||
      _professionFilter != null;

  /// Distinct profession names in the loaded queue for the filter chips.
  List<String> _professions(List<AdminReviewQueueEntry> queue) {
    final Set<String> names = <String>{};
    for (final AdminReviewQueueEntry e in queue) {
      final String? name = e.professionName?.trim();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    final List<String> sorted = names.toList(growable: false)..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminReviewProvider>();

    // No nested chrome: the shell top bar already titles this page
    // 'Professional Verification Queue' (§13a shell rule).
    return SafeArea(child: _body(provider));
  }

  Widget _body(AdminReviewProvider provider) {
    if (!AdminGate.isAdmin(provider)) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.admin_panel_settings_outlined,
          color: context.colorScheme.primary,
        ),
        title: 'Admin access required',
        subtitle: 'You do not have platform admin privileges.',
      );
    }
    if (provider.isLoadingQueue && provider.queue.isEmpty) {
      return const HivorrLoadingState();
    }
    if (provider.lastError != null && provider.queue.isEmpty) {
      return _pageScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _breadcrumbs(),
            const SizedBox(height: HivorrSpacing.md),
            HivorrEmptyState(
              icon: Icon(
                Icons.error_outline,
                color: context.colorScheme.error,
              ),
              title: 'Failed to load queue',
              subtitle: provider.lastError!.message,
              actionButton: HivorrButton(
                label: 'Retry',
                variant: HivorrButtonVariant.outline,
                size: HivorrButtonSize.small,
                onPressed: () => provider.loadQueue(
                  submissionType: _selectedType,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (provider.queue.isEmpty) {
      return _pageScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _breadcrumbs(),
            const SizedBox(height: HivorrSpacing.md),
            _metricsRow(provider, _metricsColumns(context)),
            const SizedBox(height: HivorrSpacing.md),
            HivorrEmptyState(
              icon: Icon(Icons.task_alt, color: context.colorScheme.primary),
              title: 'Queue is clear',
              subtitle: 'No submissions are awaiting review.',
            ),
          ],
        ),
      );
    }
    final List<AdminReviewQueueEntry> visible = _visible(provider.queue);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final EdgeInsets gutter = MobileCompact.scrollPaddingFor(width);
        // Enterprise workspace: table + docked review panel.
        if (width >= 1100) {
          return _workspace(provider, visible, gutter);
        }
        // Compact table (720–1100) or stacked cards (<720).
        return _pageScroll(
          physics: const AlwaysScrollableScrollPhysics(),
          onRefresh: () => _refreshAll(provider),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _breadcrumbs(),
              const SizedBox(height: HivorrSpacing.md),
              _metricsRow(provider, width >= 1024 ? 4 : 2),
              const SizedBox(height: HivorrSpacing.md),
              _filterHeader(provider, visible),
              const SizedBox(height: HivorrSpacing.md),
              if (width >= 720)
                _submissionsTableCard(provider, visible)
              else
                _narrowCards(provider, visible),
              _loadMoreFooter(provider),
            ],
          ),
        );
      },
    );
  }

  int _metricsColumns(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return width >= 1024 ? 4 : 2;
  }

  Widget _pageScroll({
    required Widget child,
    ScrollPhysics? physics,
    Future<void> Function()? onRefresh,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final EdgeInsets gutter = MobileCompact.scrollPaddingFor(
          constraints.maxWidth,
        );
        final Widget scroll = SingleChildScrollView(
          physics: physics ?? const AlwaysScrollableScrollPhysics(),
          padding: gutter,
          child: child,
        );
        if (onRefresh == null) return scroll;
        return RefreshIndicator(onRefresh: onRefresh, child: scroll);
      },
    );
  }

  /// Breadcrumb line (single Text so shell-title assertions stay exact).
  Widget _breadcrumbs() {
    return Text(
      'Admin / Professional Verification Queue',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Four-column metrics row bound to `verification_review_metrics_get`.
  /// Pending + in-review come from the RPC when loaded (else the loaded
  /// page, labeled as such). Throughput cards render "Unavailable" only
  /// when the trailing window holds no decided rows or metrics failed.
  Widget _metricsRow(AdminReviewProvider provider, int columns) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final AdminReviewMetrics? metrics = provider.metrics;
    final int inReview = metrics?.inReviewTotal ?? provider.inReviewCount;
    final int? serverTotal = provider.serverTotalCount;
    final String pendingSub;
    if (metrics != null) {
      pendingSub = '$inReview in review · server total';
    } else if (serverTotal != null) {
      pendingSub = '$inReview in review · server total';
    } else if (provider.hasMore) {
      pendingSub = '$inReview in review · more on server';
    } else {
      pendingSub = '$inReview in review';
    }
    final String avgValue = metrics == null
        ? '—'
        : _formatAvgSeconds(metrics.avgVerificationSeconds);
    final String avgSub = metrics == null
        ? 'Unavailable · needs backend'
        : (metrics.avgVerificationSeconds == null
            ? 'No decisions in window'
            : 'Trailing ${metrics.periodDays} days');
    final String approvedValue =
        metrics == null ? '—' : '${metrics.approvedToday}';
    final String approvedSub = metrics == null
        ? 'Unavailable · needs backend'
        : 'Since UTC midnight';
    final String rejectionValue = metrics == null
        ? '—'
        : _formatRate(metrics.rejectionRate);
    final String rejectionSub = metrics == null
        ? 'Trailing 30 days · needs backend'
        : (metrics.rejectionRate == null
            ? 'No decisions in window'
            : 'Trailing ${metrics.periodDays} days · '
                '${metrics.decidedTotal} decided');
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;
        return HivorrStatGrid(
          columns: columns,
          maxWidth: maxWidth,
          children: <Widget>[
            HivorrStatCard(
              compact: true,
              icon: Icons.pending_actions_outlined,
              iconBackground: colors.primaryContainer,
              iconForeground: colors.onPrimaryContainer,
              label: 'Total Pending Reviews',
              value: '${provider.pendingTotal}',
              sub: pendingSub,
            ),
            HivorrStatCard(
              compact: true,
              icon: Icons.schedule_outlined,
              iconBackground: colors.surfaceContainerHighest,
              iconForeground: colors.onSurfaceVariant,
              label: 'Avg. Verification Time',
              value: avgValue,
              sub: avgSub,
            ),
            HivorrStatCard(
              compact: true,
              icon: Icons.check_circle_outline,
              iconBackground: ext.successContainer,
              iconForeground: ext.onSuccessContainer,
              label: 'Approved Today',
              value: approvedValue,
              sub: approvedSub,
            ),
            HivorrStatCard(
              compact: true,
              icon: Icons.block_outlined,
              iconBackground: ext.warningContainer,
              iconForeground: ext.onWarningContainer,
              label: 'Rejection Rate',
              value: rejectionValue,
              sub: rejectionSub,
            ),
          ],
        );
      },
    );
  }

  Widget _filterHeader(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    final List<String> professions = _professions(provider.queue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HivorrTextField(
          controller: _searchController,
          hint: 'Search applicants...',
          textInputAction: TextInputAction.search,
          onSubmitted: (String value) {
            setState(() => _query = value.trim());
            unawaited(
              _loadQueuePage(context.read<AdminReviewProvider>()),
            );
          },
          prefix: Icon(
            Icons.search,
            color: context.colorScheme.onSurfaceVariant,
          ),
          fillColor: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            for (final String? type in _typeOptions)
              HivorrChip(
                label: type == null ? 'All types' : _typeLabel(type),
                isSelected: _selectedType == type,
                onSelected: (_) => _selectType(type),
              ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            for (final String? status in _statusOptions)
              HivorrChip(
                label: status == null ? 'All statuses' : _statusLabel(status),
                isSelected: _statusFilter == status,
                onSelected: (_) => setState(() => _statusFilter = status),
              ),
          ],
        ),
        if (professions.isNotEmpty) ...<Widget>[
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            children: <Widget>[
              HivorrChip(
                label: 'All professions',
                isSelected: _professionFilter == null,
                onSelected: (_) => _applyProfessionFilter(null),
              ),
              for (final String name in professions)
                HivorrChip(
                  label: name,
                  isSelected: _professionFilter == name,
                  onSelected: (_) => _applyProfessionFilter(name),
                ),
            ],
          ),
        ],
        const SizedBox(height: HivorrSpacing.sm),
        Wrap(
          spacing: HivorrSpacing.sm,
          runSpacing: HivorrSpacing.sm,
          children: <Widget>[
            HivorrChip(
              label: 'Newest',
              isSelected: _sortMode == _SortMode.newest,
              onSelected: (_) => _applySort(_SortMode.newest),
            ),
            HivorrChip(
              label: 'Oldest',
              isSelected: _sortMode == _SortMode.oldest,
              onSelected: (_) => _applySort(_SortMode.oldest),
            ),
            HivorrChip(
              label: 'Name A–Z',
              isSelected: _sortMode == _SortMode.name,
              onSelected: (_) => _applySort(_SortMode.name),
            ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          _countLine(provider, visible),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Profession + sort chips reload the first server page (resetting the
  /// selection) and keep the matching client-side view as a safety net.
  void _applyProfessionFilter(String? name) {
    setState(() {
      _professionFilter = name;
      _selectedId = null;
      _panelClosed = false;
    });
    unawaited(_loadQueuePage(context.read<AdminReviewProvider>()));
  }

  void _applySort(_SortMode mode) {
    setState(() {
      _sortMode = mode;
      _selectedId = null;
      _panelClosed = false;
    });
    unawaited(_loadQueuePage(context.read<AdminReviewProvider>()));
  }

  String _countLine(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    final int total = provider.pendingTotal;
    if (_isFiltered) return '${visible.length} of $total shown';
    return '$total awaiting review';
  }

  /// Mean turnaround for the metrics card. Null (no decided rows in the
  /// window) renders as "Unavailable", never zero.
  String _formatAvgSeconds(double? seconds) {
    if (seconds == null || seconds.isNaN || seconds < 0) return '—';
    if (seconds < 60) return '${seconds.round()}s';
    final double minutes = seconds / 60;
    if (minutes < 60) return '${minutes.round()}m';
    final double hours = minutes / 60;
    if (hours < 48) {
      final String text = hours.toStringAsFixed(hours < 10 ? 1 : 0);
      return '${_trimZero(text)}h';
    }
    final double days = hours / 24;
    final String text = days.toStringAsFixed(days < 10 ? 1 : 0);
    return '${_trimZero(text)}d';
  }

  String _trimZero(String text) =>
      text.endsWith('.0') ? text.substring(0, text.length - 2) : text;

  /// Rejection share for the metrics card. Null renders as "Unavailable".
  String _formatRate(double? rate) {
    if (rate == null || rate.isNaN || rate < 0) return '—';
    return '${(rate * 100).toStringAsFixed(1)}%';
  }

  /// Enterprise submissions table (≥720dp): compact, readable, real rows.
  /// Category and document cells use combined strings (never invented
  /// per-document labels or risk scores — both lack backend sources).
  ///
  /// TODO(backend): risk-score column needs a risk policy + score column/RPC
  /// (omitted by approval); per-document ID/Passport/Degree labels need a
  /// document taxonomy or multi-doc list on the queue DTO.
  Widget _submissionsTableCard(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    final ColorScheme colors = context.colorScheme;
    if (visible.isEmpty) {
      return HivorrCard(
        child: HivorrEmptyState(
          icon: Icon(
            Icons.search_off,
            color: colors.onSurfaceVariant,
          ),
          title: 'No matches',
          subtitle: 'Try a different search or filter.',
        ),
      );
    }
    return HivorrCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HivorrSpacing.md,
              HivorrSpacing.md,
              HivorrSpacing.md,
              HivorrSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Pending Professional Submissions',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: HivorrSpacing.sm),
                HivorrBadge(
                  label: '${provider.pendingTotal} pending',
                  variant: HivorrBadgeVariant.neutral,
                ),
              ],
            ),
          ),
          HivorrDataTable(
            columns: const <HivorrDataColumn>[
              HivorrDataColumn('Professional', flex: 22),
              HivorrDataColumn('Category', flex: 16),
              HivorrDataColumn('Documents', flex: 14),
              HivorrDataColumn('Submitted', flex: 14),
              HivorrDataColumn('Actions', flex: 10),
            ],
            rows: <HivorrDataRow>[
              for (final AdminReviewQueueEntry entry in visible)
                HivorrDataRow(
                  onTap: () => _onRowTap(entry),
                  cells: <HivorrDataCell>[
                    HivorrDataCell(_nameCell(entry), flex: 22),
                    HivorrDataCell(_categoryCell(entry), flex: 16),
                    HivorrDataCell(_documentCell(entry), flex: 14),
                    HivorrDataCell(_submittedCell(entry), flex: 14),
                    HivorrDataCell(_reviewActionCell(entry), flex: 10),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nameCell(AdminReviewQueueEntry entry) {
    final String name = entry.entityName.isNotEmpty
        ? entry.entityName
        : 'Unknown entity';
    return Row(
      children: <Widget>[
        HivorrAvatar(
          name: name,
          size: 32,
          backgroundColor: _avatarTint(context, name),
        ),
        const SizedBox(width: HivorrSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.credentialName.isNotEmpty
                    ? entry.credentialName
                    : _typeLabel(entry.submissionType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Combined profession + type string: honest about the single
  /// `profession_name` join and never a fabricated skills list.
  Widget _categoryCell(AdminReviewQueueEntry entry) {
    final String profession = (entry.professionName ?? '').trim();
    final String type = _typeLabel(entry.submissionType);
    final String line = profession.isNotEmpty
        ? '$profession · $type'
        : type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          line,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        HivorrBadge(
          label: _statusLabel(entry.status),
          variant: _statusVariant(entry.status),
        ),
      ],
    );
  }

  /// Honest document indicator: file kind from the real `document_path`
  /// (image / PDF / missing). Never invents ID/Passport/Degree labels.
  Widget _documentCell(AdminReviewQueueEntry entry) {
    final ColorScheme colors = context.colorScheme;
    final String? path = entry.documentPath?.trim();
    final IconData icon;
    final String label;
    final Color tint;
    if (path == null || path.isEmpty) {
      icon = Icons.attach_file_outlined;
      label = 'No file attached';
      tint = colors.onSurfaceVariant;
    } else if (path.toLowerCase().endsWith('.pdf')) {
      icon = Icons.picture_as_pdf_outlined;
      label = 'PDF document';
      tint = colors.error;
    } else {
      icon = Icons.image_outlined;
      label = 'Image document';
      tint = colors.onSurfaceVariant;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: HivorrSpacing.xs),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }

  Widget _submittedCell(AdminReviewQueueEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          HivorrFormatters.date(entry.submittedAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          HivorrFormatters.relative(entry.submittedAt),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _reviewActionCell(AdminReviewQueueEntry entry) {
    final ColorScheme colors = context.colorScheme;
    final bool selected = _selectedId == entry.submissionId;
    return HivorrTableAction(
      label: selected ? 'Open' : 'Review',
      icon: Icons.visibility_outlined,
      foreground: selected ? colors.onPrimary : colors.onPrimaryContainer,
      background: selected ? colors.primary : colors.primaryContainer,
      onTap: () => _onRowTap(entry),
    );
  }

  /// Stacked submission rows for narrow screens (<720dp table→card rule).
  Widget _narrowCards(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    if (visible.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.search_off,
          color: context.colorScheme.onSurfaceVariant,
        ),
        title: 'No matches',
        subtitle: 'Try a different search or filter.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HivorrCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Pending Professional Submissions',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HivorrBadge(
                label: '${provider.pendingTotal} pending',
                variant: HivorrBadgeVariant.neutral,
              ),
            ],
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
        for (final AdminReviewQueueEntry entry in visible) ...<Widget>[
          _ApplicantCard(
            key: ValueKey<String>(entry.submissionId),
            entry: entry,
            // Narrow mode opens the pushed detail route (which claims
            // on open); the wide workspace claims on tap.
            onTap: () => unawaited(
              context.pushNamed(
                RouteNames.adminReviewDetail,
                pathParameters: <String, String>{
                  'submissionId': entry.submissionId,
                },
              ),
            ),
          ),
          const SizedBox(height: HivorrSpacing.sm),
        ],
      ],
    );
  }

  Widget _loadMoreFooter(AdminReviewProvider provider) {
    if (provider.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(HivorrSpacing.md),
        child: Center(
          child: HivorrButton(
            label: 'Load more',
            variant: HivorrButtonVariant.outline,
            size: HivorrButtonSize.small,
            isLoading: provider.isLoadingQueue,
            onPressed: () => _loadMorePage(provider),
          ),
        ),
      );
    }
    return const SizedBox(height: HivorrSpacing.md);
  }

  /// Enterprise workspace (≥1100dp): shared header on top, then the
  /// submissions table beside a docked review panel for the selection.
  Widget _workspace(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
    EdgeInsets gutter,
  ) {
    final AdminReviewQueueEntry? selected = _resolveSelection(
      provider,
      visible,
    );
    return Padding(
      padding: gutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _breadcrumbs(),
          const SizedBox(height: HivorrSpacing.md),
          _metricsRow(provider, 4),
          const SizedBox(height: HivorrSpacing.md),
          _filterHeader(provider, visible),
          const SizedBox(height: HivorrSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _refreshAll(provider),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _submissionsTableCard(provider, visible),
                          _loadMoreFooter(provider),
                        ],
                      ),
                    ),
                  ),
                ),
                if (selected != null) ...<Widget>[
                  const SizedBox(width: HivorrSpacing.md),
                  SizedBox(
                    width: 400,
                    child: _reviewPanel(provider, selected, visible),
                  ),
                ] else ...<Widget>[
                  const SizedBox(width: HivorrSpacing.md),
                  SizedBox(width: 400, child: _selectionPrompt()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Row tap: wide workspace selects into the docked panel; narrow widths
  /// push the detail route.
  void _onRowTap(AdminReviewQueueEntry entry) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= 1100) {
      _openForReview(entry.submissionId);
      return;
    }
    unawaited(
      context.pushNamed(
        RouteNames.adminReviewDetail,
        pathParameters: <String, String>{'submissionId': entry.submissionId},
      ),
    );
  }

  Widget _selectionPrompt() {
    return HivorrCard(
      child: HivorrEmptyState(
        icon: Icon(
          Icons.person_search_outlined,
          color: context.colorScheme.onSurfaceVariant,
        ),
        title: 'Select a submission',
        subtitle: 'Applicant details appear here for review.',
      ),
    );
  }

  /// Right-side review panel: header with explicit close, registered-vs-
  /// submitted comparison, applicant profile depth (experience, education,
  /// skills from `verification_review_profile_get`), document viewer,
  /// decision actions, and the audit trail. Keyed content resets per
  /// applicant.
  Widget _reviewPanel(
    AdminReviewProvider provider,
    AdminReviewQueueEntry selected,
    List<AdminReviewQueueEntry> visible,
  ) {
    final int index = visible.indexWhere(
      (AdminReviewQueueEntry e) => e.submissionId == selected.submissionId,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _reviewPanelHeader(selected, index, visible.length),
          const SizedBox(height: HivorrSpacing.md),
          ReviewComparisonCard(
            key: ValueKey<String>('${selected.submissionId}-compare'),
            entry: selected,
          ),
          const SizedBox(height: HivorrSpacing.md),
          ReviewProfileSections(
            key: ValueKey<String>('${selected.submissionId}-profile'),
          ),
          const SizedBox(height: HivorrSpacing.md),
          ReviewDocumentPanel(
            key: ValueKey<String>(selected.submissionId),
            entry: selected,
          ),
          const SizedBox(height: HivorrSpacing.md),
          ReviewActionsPanel(
            key: ValueKey<String>('${selected.submissionId}-actions'),
            entry: selected,
            onResolved: () => _onDecisionResolved(provider, selected),
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const ReviewAuditList(),
        ],
      ),
    );
  }

  Widget _reviewPanelHeader(
    AdminReviewQueueEntry selected,
    int index,
    int total,
  ) {
    final ColorScheme colors = context.colorScheme;
    final String name = selected.entityName.isNotEmpty
        ? selected.entityName
        : 'Unknown entity';
    return HivorrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              HivorrAvatar(
                name: name,
                size: 40,
                backgroundColor: _avatarTint(context, name),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selected.credentialName.isNotEmpty
                          ? selected.credentialName
                          : _typeLabel(selected.submissionType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: HivorrSpacing.sm),
              HivorrBadge(
                label: _statusLabel(selected.status),
                variant: _statusVariant(selected.status),
              ),
              const SizedBox(width: HivorrSpacing.xs),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: 'Close review panel',
                  icon: const Icon(Icons.close),
                  onPressed: _closePanel,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.xs),
          Text(
            index >= 0
                ? 'Reviewing ${index + 1} of $total · ${HivorrFormatters.date(selected.submittedAt)}'
                : HivorrFormatters.date(selected.submittedAt),
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _closePanel() {
    setState(() {
      _selectedId = null;
      _panelClosed = true;
    });
  }

  /// Reloads the queue page and the throughput metrics together (metrics are
  /// scoped to the active type filter, matching the queue).
  Future<void> _refreshAll(AdminReviewProvider provider) async {
    await _loadQueuePage(provider);
    await provider.loadMetrics(submissionType: _selectedType);
  }

  void _onDecisionResolved(
    AdminReviewProvider provider,
    AdminReviewQueueEntry decided,
  ) {
    final bool approved = provider.lastError == null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Submission decided.'
                : 'Decision failed: ${provider.lastError?.message}',
          ),
        ),
      );
    }
    // The provider already removed the decided row; reopen on the next
    // visible applicant so triage continues without navigation.
    setState(() {
      _selectedId = null;
      _panelClosed = false;
    });
    unawaited(provider.loadMetrics(submissionType: _selectedType));
  }

  /// Explicit workspace open: claims the item for review, then loads its
  /// audit trail and applicant profile for the details pane. Claim failures
  /// are best-effort (provider holds the error) and never block selection.
  void _openForReview(String submissionId) {
    setState(() {
      _selectedId = submissionId;
      _panelClosed = false;
    });
    final AdminReviewProvider provider =
        context.read<AdminReviewProvider>();
    unawaited(provider.startReview(submissionId));
    unawaited(provider.loadAuditTrail(submissionId));
    unawaited(provider.loadReviewProfile(submissionId));
  }

  /// Resolves the workspace selection: the chosen submission when still
  /// visible, else the first visible row (auto-advance after decisions).
  /// Kicks off the audit + profile loads once per selection.
  AdminReviewQueueEntry? _resolveSelection(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    if (visible.isEmpty || _panelClosed) return null;
    AdminReviewQueueEntry? selected;
    if (_selectedId != null) {
      for (final AdminReviewQueueEntry entry in visible) {
        if (entry.submissionId == _selectedId) {
          selected = entry;
          break;
        }
      }
    }
    if (selected == null) {
      final String? activeId = provider.activeSubmissionId;
      if (activeId != null) {
        for (final AdminReviewQueueEntry entry in visible) {
          if (entry.submissionId == activeId) {
            selected = entry;
            break;
          }
        }
      }
    }
    selected ??= visible.first;
    if (provider.activeSubmissionId != selected.submissionId &&
        _pendingAuditId != selected.submissionId) {
      _pendingAuditId = selected.submissionId;
      final String id = selected.submissionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(context.read<AdminReviewProvider>().loadAuditTrail(id));
        unawaited(context.read<AdminReviewProvider>().loadReviewProfile(id));
      });
    }
    return selected;
  }
}

/// Compact applicant card: avatar, name, type + credential, status badge,
/// submitted date. Single 16dp card padding (the old card nested a second
/// 16dp inset). Tappable via [HivorrCard.onTap].
class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final AdminReviewQueueEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String name = entry.entityName.isNotEmpty
        ? entry.entityName
        : 'Unknown entity';
    return HivorrCard(
      elevation: 1,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          HivorrAvatar(
            name: name,
            size: 32,
            backgroundColor: _avatarTint(context, name),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Text(
                  '${_typeLabel(entry.submissionType)} · ${entry.credentialName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.xs),
                Row(
                  children: <Widget>[
                    HivorrBadge(
                      label: _statusLabel(entry.status),
                      variant: _statusVariant(entry.status),
                    ),
                    const SizedBox(width: HivorrSpacing.xs),
                    Expanded(
                      child: Text(
                        HivorrFormatters.relative(entry.submittedAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Human labels for server submission-type codes (never raw codes in UI).
String _typeLabel(String type) => switch (type) {
  'trade_proof' => 'Trade proof',
  'identity_document' => 'Identity document',
  'certification' => 'Certification',
  _ => type,
};

/// Server `in_review` and legacy camelCase `inReview` mean the same thing;
/// the provider now writes the server form, this also reads old rows.
String _normalizedStatus(String status) => switch (status) {
  'in_review' || 'inReview' => 'in_review',
  _ => status,
};

String _statusLabel(String status) => switch (_normalizedStatus(status)) {
  'pending' => 'Pending',
  'in_review' => 'In review',
  'approved' => 'Approved',
  'rejected' => 'Rejected',
  'requires_resubmission' => 'Requires resubmission',
  _ => status,
};

HivorrBadgeVariant _statusVariant(String status) =>
    switch (_normalizedStatus(status)) {
      'pending' => HivorrBadgeVariant.warning,
      'in_review' => HivorrBadgeVariant.info,
      'approved' => HivorrBadgeVariant.success,
      'rejected' => HivorrBadgeVariant.error,
      'requires_resubmission' => HivorrBadgeVariant.warning,
      _ => HivorrBadgeVariant.neutral,
    };

/// Deterministic container tint per name from theme pairs (directory
/// convention). Foreground stays `onPrimaryContainer` via [HivorrAvatar].
Color _avatarTint(BuildContext context, String name) {
  final RoleThemeExtension roles = context.roleTheme;
  final AppThemeExtension ext = context.appExtension;
  final List<Color> tints = <Color>[
    roles.clientContainer,
    ext.successContainer,
    ext.warningContainer,
    ext.infoContainer,
  ];
  int hash = 0;
  for (final int code in name.codeUnits) {
    hash = (hash * 31 + code) % 1000003;
  }
  return tints[hash % tints.length];
}
