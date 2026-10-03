import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/repositories/admin_review_repository.dart';
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
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:hivorr/systems/verification/widgets/review_detail_panels.dart';
import 'package:provider/provider.dart';

/// Admin review queue screen (EP-02-11 §5.6, §10).
///
/// Displays pending verification submissions fetched from the server via the
/// admin review RPCs. Tapping a queue entry navigates to the detail screen.
/// Approve/reject actions are handled by the detail screen; this screen
/// provides the overview list with optional type filtering.
class AdminReviewQueueScreen extends StatefulWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  State<AdminReviewQueueScreen> createState() => _AdminReviewQueueScreenState();
}

class _AdminReviewQueueScreenState extends State<AdminReviewQueueScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Server-side submission-type filter (passed to `loadQueue`).
  String? _selectedType;

  /// Client-side filters over the loaded page (the queue RPC accepts only
  /// `submissionType`; entity search and lifecycle status filter locally,
  /// mirroring the directory pattern without inventing server params).
  String _query = '';
  String? _statusFilter;
  bool _newestFirst = true;

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
      // Ensure admin flag is hydrated, then load queue.
      unawaited(
        provider.checkAdmin().then((_) {
          if (!mounted) return;
          if (AdminGate.isAdmin(provider)) {
            unawaited(provider.loadQueue());
          }
        }),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectType(String? type) {
    setState(() => _selectedType = type);
    unawaited(
      context.read<AdminReviewProvider>().loadQueue(submissionType: type),
    );
  }

  /// Client-side view over the loaded page: search, status, newest/oldest.
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
    final List<AdminReviewQueueEntry> sorted = items.toList(growable: false)
      ..sort(
        (AdminReviewQueueEntry a, AdminReviewQueueEntry b) =>
            _newestFirst
                ? b.submittedAt.compareTo(a.submittedAt)
                : a.submittedAt.compareTo(b.submittedAt),
      );
    return sorted;
  }

  bool get _isFiltered =>
      _query.trim().isNotEmpty || _statusFilter != null;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminReviewProvider>();

    // No nested chrome: the shell top bar already titles this page
    // 'Verification & Approvals' (§13a shell rule).
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
      return HivorrEmptyState(
        icon: Icon(Icons.error_outline, color: context.colorScheme.error),
        title: 'Failed to load queue',
        subtitle: provider.lastError!.message,
      );
    }
    if (provider.queue.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(Icons.task_alt, color: context.colorScheme.primary),
        title: 'Queue is clear',
        subtitle: 'No submissions are awaiting review.',
      );
    }
    final List<AdminReviewQueueEntry> visible = _visible(provider.queue);
    return RefreshIndicator(
      onRefresh: () => provider.loadQueue(submissionType: _selectedType),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final EdgeInsets gutter = MobileCompact.scrollPaddingFor(width);
          // Master-detail workspace on wide rails (Phase 2); the pushed
          // detail route stays for narrow widths and deep links.
          if (width >= 1100) {
            return _workspace(provider, visible, gutter, width);
          }
          // Applicant-card columns (§21a): 2 cols 600–1100, 1 below.
          final int columns = width >= 600 ? 2 : 1;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: gutter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                HivorrTextField(
                  controller: _searchController,
                  hint: 'Search applicants...',
                  textInputAction: TextInputAction.search,
                  onSubmitted: (String value) =>
                      setState(() => _query = value.trim()),
                  prefix: Icon(
                    Icons.search,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  fillColor: context.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
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
                        label: status == null
                            ? 'All statuses'
                            : _statusLabel(status),
                        isSelected: _statusFilter == status,
                        onSelected: (_) =>
                            setState(() => _statusFilter = status),
                      ),
                    HivorrChip(
                      label: 'Newest first',
                      isSelected: _newestFirst,
                      onSelected: (_) => setState(
                        () => _newestFirst = !_newestFirst,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HivorrSpacing.sm),
                Text(
                  _isFiltered
                      ? '${visible.length} of ${provider.queue.length} shown'
                      : '${provider.queue.length} awaiting review',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: HivorrSpacing.sm),
                if (visible.isEmpty)
                  HivorrEmptyState(
                    icon: Icon(
                      Icons.search_off,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    title: 'No matches',
                    subtitle: 'Try a different search or filter.',
                  )
                else
                  HivorrStatGrid(
                    columns: columns,
                    maxWidth: width - gutter.horizontal,
                    children: <Widget>[
                      for (final AdminReviewQueueEntry entry in visible)
                        _ApplicantCard(
                          key: ValueKey<String>(entry.submissionId),
                          entry: entry,
                          // Narrow mode opens the pushed detail route (which
                          // claims on open); the workspace claims on tap.
                          onTap: () => context.pushNamed(
                            RouteNames.adminReviewDetail,
                            pathParameters: <String, String>{
                              'submissionId': entry.submissionId,
                            },
                          ),
                        ),
                    ],
                  ),
                if (provider.hasMore)
                  Padding(
                    padding: const EdgeInsets.all(HivorrSpacing.md),
                    child: Center(
                      child: HivorrButton(
                        label: 'Load more',
                        variant: HivorrButtonVariant.outline,
                        size: HivorrButtonSize.small,
                        isLoading: provider.isLoadingQueue,
                        onPressed: () => provider.loadMore(
                          submissionType: _selectedType,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: HivorrSpacing.md),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Master-detail workspace (≥1100dp): shared filter header on top, then a
  /// 380dp applicant list beside the detail panels for the selection.
  /// Both panes scroll independently; pull-to-refresh covers both.
  Widget _workspace(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
    EdgeInsets gutter,
    double width,
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
          _filterHeader(provider, visible),
          const SizedBox(height: HivorrSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 380,
                  child: _listPane(provider, visible, selected),
                ),
                const SizedBox(width: HivorrSpacing.md),
                Expanded(child: _detailsPane(selected)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterHeader(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HivorrTextField(
          controller: _searchController,
          hint: 'Search applicants...',
          textInputAction: TextInputAction.search,
          onSubmitted: (String value) =>
              setState(() => _query = value.trim()),
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
            HivorrChip(
              label: 'Newest first',
              isSelected: _newestFirst,
              onSelected: (_) => setState(
                () => _newestFirst = !_newestFirst,
              ),
            ),
          ],
        ),
        const SizedBox(height: HivorrSpacing.sm),
        Text(
          _isFiltered
              ? '${visible.length} of ${provider.queue.length} shown'
              : '${provider.queue.length} awaiting review',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: HivorrSpacing.sm),
      ],
    );
  }

  /// Left pane: single-column applicant list with selection ring + footer.
  Widget _listPane(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
    AdminReviewQueueEntry? selected,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (visible.isEmpty)
            HivorrEmptyState(
              icon: Icon(
                Icons.search_off,
                color: context.colorScheme.onSurfaceVariant,
              ),
              title: 'No matches',
              subtitle: 'Try a different search or filter.',
            )
          else
            for (final AdminReviewQueueEntry entry in visible) ...<Widget>[
              _ApplicantCard(
                key: ValueKey<String>(entry.submissionId),
                entry: entry,
                selected:
                    selected?.submissionId == entry.submissionId,
                onTap: () => _openForReview(entry.submissionId),
              ),
              const SizedBox(height: HivorrSpacing.sm),
            ],
          if (provider.hasMore)
            Padding(
              padding: const EdgeInsets.all(HivorrSpacing.md),
              child: Center(
                child: HivorrButton(
                  label: 'Load more',
                  variant: HivorrButtonVariant.outline,
                  size: HivorrButtonSize.small,
                  isLoading: provider.isLoadingQueue,
                  onPressed: () => provider.loadMore(
                    submissionType: _selectedType,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Right pane: shared detail panels for the selection, or a prompt.
  /// Keyed by submission so notes/document state resets per applicant.
  Widget _detailsPane(AdminReviewQueueEntry? selected) {
    if (selected == null) {
      return HivorrEmptyState(
        icon: Icon(
          Icons.person_search_outlined,
          color: context.colorScheme.onSurfaceVariant,
        ),
        title: 'Select a submission',
        subtitle: 'Applicant details appear here for review.',
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReviewEntityCard(entry: selected),
          const SizedBox(height: HivorrSpacing.md),
          ReviewComparisonCard(
            key: ValueKey<String>('${selected.submissionId}-compare'),
            entry: selected,
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
            // The queue updates itself on resolve; selection advances
            // automatically through [_resolveSelection].
            onResolved: () {},
          ),
          const SizedBox(height: HivorrSpacing.lg),
          const ReviewAuditList(),
        ],
      ),
    );
  }

  String? _pendingAuditId;

  /// Explicit workspace open: claims the item for review, then loads its
  /// audit trail for the details pane. Claim failures are best-effort
  /// (provider holds the error) and never block selection.
  void _openForReview(String submissionId) {
    final AdminReviewProvider provider =
        context.read<AdminReviewProvider>();
    unawaited(provider.startReview(submissionId));
    unawaited(provider.loadAuditTrail(submissionId));
  }

  /// Resolves the workspace selection: the active submission when still
  /// visible, else the first visible row (auto-advance after decisions).
  /// Kicks off the audit load once per selection.
  AdminReviewQueueEntry? _resolveSelection(
    AdminReviewProvider provider,
    List<AdminReviewQueueEntry> visible,
  ) {
    if (visible.isEmpty) return null;
    final String? activeId = provider.activeSubmissionId;
    AdminReviewQueueEntry? selected;
    if (activeId != null) {
      for (final AdminReviewQueueEntry entry in visible) {
        if (entry.submissionId == activeId) {
          selected = entry;
          break;
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
    this.selected = false,
  });

  final AdminReviewQueueEntry entry;
  final VoidCallback onTap;

  /// Selection ring for the workspace list pane.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String name = entry.entityName.isNotEmpty
        ? entry.entityName
        : 'Unknown entity';
    final Widget card = HivorrCard(
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
    if (!selected) return card;
    final AppThemeExtension ext = context.appExtension;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.primary, width: 2),
        borderRadius: BorderRadius.circular(ext.radiusMd),
      ),
      child: card,
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
