import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/shared/components/hivorr_data_table.dart';
import 'package:hivorr/shared/components/hivorr_dialog.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/layouts/mobile_compact.dart';
import 'package:hivorr/shared/widgets/hivorr_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_capability_badge.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_divider.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:hivorr/shared/widgets/hivorr_table_action.dart';
import 'package:hivorr/shared/widgets/hivorr_text_field.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Manage User directory screen (EP-02-11 admin console).
///
/// Visual source of truth: Admin Dashboard Users reference screenshot — a
/// slim count + `Export CSV` row (the shell top bar already titles the page,
/// VISUAL-IDENTITY.md §13a), then a white rounded card holding the search
/// field and the User | Role | Jobs | Status | Joined | Actions table
/// (`HivorrDataTable`, §21c).
///
/// Functional source of truth: existing Hivorr architecture. Directory data
/// flows through [ManageUserProvider] (search + status + pagination);
/// gating is fail-closed via [AdminGate] over [AdminReviewProvider].
/// Row actions reuse existing workflows only: `View` opens the existing
/// user-detail screen (profile, KYC, verification summary, lifecycle +
/// onboarding reset), `Suspend` reuses `setUserStatus('suspended')` with a
/// confirm gate. `Export CSV` serializes the currently loaded directory
/// rows via the existing `file_picker` save dialog — no placeholder
/// buttons, no duplicate services, no mock data.
///
/// [capability] is the Users submenu filter per the Super Admin spec:
/// `null` = All Users, `professional` = offer+both, `client` = hire+both.
/// A user with `both` appears in all three views (single population).
class ManageUserScreen extends StatefulWidget {
  const ManageUserScreen({super.key, this.capability});

  final String? capability;

  @override
  State<ManageUserScreen> createState() => _ManageUserScreenState();
}

class _ManageUserScreenState extends State<ManageUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  bool _exporting = false;

  String? get _capability => widget.capability;

  String get _populationLabel => switch (_capability) {
    'professional' => 'professionals',
    'client' => 'clients',
    _ => 'total users',
  };

  String get _emptySubtitle => switch (_capability) {
    'professional' => 'No professionals match the current filters.',
    'client' => 'No clients match the current filters.',
    _ => 'No users match the current search and filters.',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AdminReviewProvider admin = context.read<AdminReviewProvider>();
      final ManageUserProvider manage = context.read<ManageUserProvider>();
      // Hydrate the shared admin flag, then load the directory for admins.
      unawaited(
        admin.checkAdmin().then((_) {
          if (!mounted) return;
          if (AdminGate.isAdmin(admin)) {
            unawaited(manage.loadUsers(capability: _capability));
          }
        }),
      );
    });
  }

  @override
  void didUpdateWidget(ManageUserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capability != widget.capability) {
      final ManageUserProvider manage = context.read<ManageUserProvider>();
      final AdminReviewProvider admin = context.read<AdminReviewProvider>();
      if (AdminGate.isAdmin(admin)) {
        unawaited(
          manage.loadUsers(
            capability: _capability,
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            status: _selectedStatus,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ManageUserProvider provider = context.watch<ManageUserProvider>();
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // Six columns + dual action pills need ~160dp for Actions alone, so
        // this table flips to cards below 900dp (content-driven exception to
        // the §21a 720dp table rule — a 720dp viewport cannot host both
        // pills without overflow).
        final bool wide = width >= 900;
        return RefreshIndicator(
          onRefresh: () => provider.loadUsers(
            search: provider.search,
            status: provider.statusFilter,
            capability: _capability,
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: MobileCompact.scrollPaddingFor(width),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _DirectoryHeader(
                  totalLabel: provider.isListHydrated
                      ? '${_formatCount(provider.totalCount)} $_populationLabel'
                      : (provider.isLoading
                            ? 'Loading users…'
                            : 'User directory'),
                  exporting: _exporting,
                  canExport: provider.users.isNotEmpty && !_exporting,
                  onExport: () => _exportCsv(context, provider),
                ),
                const SizedBox(height: HivorrSpacing.md),
                _DirectoryCard(
                  wide: wide,
                  searchController: _searchController,
                  selectedStatus: _selectedStatus,
                  provider: provider,
                  capability: _capability,
                  emptySubtitle: _emptySubtitle,
                  onSearch: (String value) => unawaited(
                    provider.loadUsers(
                      search: value.trim().isEmpty ? null : value.trim(),
                      status: _selectedStatus,
                      capability: _capability,
                    ),
                  ),
                  onStatusSelected: (String? status) {
                    setState(() => _selectedStatus = status);
                    unawaited(
                      provider.loadUsers(
                        search: _searchController.text.trim().isEmpty
                            ? null
                            : _searchController.text.trim(),
                        status: status,
                        capability: _capability,
                      ),
                    );
                  },
                  onView: (ManageUserListItem user) => context.pushNamed(
                    RouteNames.adminManageUserDetail,
                    pathParameters: <String, String>{'userId': user.id},
                  ),
                  onSuspend: (ManageUserListItem user) =>
                      _suspendUser(context, provider, user),
                  onLoadMore: () => unawaited(provider.loadMore()),
                  onRetry: () => unawaited(
                    provider.loadUsers(
                      search: provider.search,
                      status: provider.statusFilter,
                      capability: _capability,
                    ),
                  ),
                ),
                const SizedBox(height: HivorrSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _suspendUser(
    BuildContext context,
    ManageUserProvider provider,
    ManageUserListItem user,
  ) async {
    final String name = _displayNameOf(user);
    final bool confirmed = await _confirm(
      context,
      title: 'Suspend',
      message:
          'Suspend $name? The account is temporarily disabled. '
          'You can reactivate it from the user detail screen.',
      confirmLabel: 'Suspend',
    );
    if (!confirmed || !context.mounted) return;
    await provider.setUserStatus(user.id, 'suspended');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.lastError == null
              ? '$name suspended.'
              : 'Action failed: ${provider.lastError!.message}',
        ),
      ),
    );
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

  /// Serializes the currently loaded directory rows to CSV and opens the
  /// platform save dialog (`file_picker`, already a project dependency).
  /// Exports the live provider rows — never fabricated content.
  Future<void> _exportCsv(
    BuildContext context,
    ManageUserProvider provider,
  ) async {
    if (_exporting || provider.users.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final String csv = _buildCsv(provider.users);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csv));
      final Uri? saved = await FilePicker.saveFile(
        dialogTitle: 'Export users CSV',
        fileName: 'hivorr_users.csv',
        mimeType: 'text/csv',
        bytes: bytes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == null
                ? 'Export cancelled.'
                : kIsWeb
                ? 'Exported ${provider.users.length} users to downloads.'
                : 'Exported ${provider.users.length} users to $saved.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _buildCsv(List<ManageUserListItem> users) {
    final StringBuffer out = StringBuffer();
    out.writeln(
      'id,display_name,legal_name,capability,status,kyc_tier,roles,is_admin,onboarding_completed,created_at',
    );
    for (final ManageUserListItem user in users) {
      out.writeln(
        <String>[
          _csvCell(user.id),
          _csvCell(user.displayName),
          _csvCell(user.legalName ?? ''),
          _csvCell(user.capability ?? ''),
          _csvCell(user.status),
          _csvCell(user.kycTier ?? ''),
          _csvCell(user.roles.join(';')),
          _csvCell(user.isAdmin ? 'true' : 'false'),
          _csvCell(user.onboardingCompleted ? 'true' : 'false'),
          _csvCell(user.createdAt.toIso8601String()),
        ].join(','),
      );
    }
    return out.toString();
  }

  String _csvCell(String value) {
    if (value.contains(RegExp(r'[",\n\r]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _formatCount(int value) =>
      NumberFormat.decimalPattern('en').format(value);
}

/// Slim count + Export CSV row. No in-body title: the shell top bar already
/// titles this page (VISUAL-IDENTITY.md §13a).
class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.totalLabel,
    required this.exporting,
    required this.canExport,
    required this.onExport,
  });

  final String totalLabel;
  final bool exporting;
  final bool canExport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            totalLabel,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        HivorrButton(
          label: 'Export CSV',
          variant: HivorrButtonVariant.text,
          size: HivorrButtonSize.small,
          icon: const Icon(Icons.filter_list_outlined, size: 18),
          isLoading: exporting,
          onPressed: canExport ? onExport : null,
        ),
      ],
    );
  }
}

/// White rounded card holding search + the user table.
class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.wide,
    required this.searchController,
    required this.selectedStatus,
    required this.provider,
    required this.capability,
    required this.emptySubtitle,
    required this.onSearch,
    required this.onStatusSelected,
    required this.onView,
    required this.onSuspend,
    required this.onLoadMore,
    required this.onRetry,
  });

  final bool wide;
  final TextEditingController searchController;
  final String? selectedStatus;
  final ManageUserProvider provider;
  final String? capability;
  final String emptySubtitle;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatusSelected;
  final ValueChanged<ManageUserListItem> onView;
  final ValueChanged<ManageUserListItem> onSuspend;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return HivorrCard(
      padding: EdgeInsets.zero,
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: _SearchField(
              controller: searchController,
              selectedStatus: selectedStatus,
              onSearch: onSearch,
              onStatusSelected: onStatusSelected,
            ),
          ),
          const HivorrDivider(),
          _Body(
            wide: wide,
            provider: provider,
            emptySubtitle: emptySubtitle,
            onView: onView,
            onSuspend: onSuspend,
            onLoadMore: onLoadMore,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Filled grey search field from the reference, with the status filter
/// integrated as a trailing icon so existing filtering stays accessible
/// without altering the prototype layout.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.selectedStatus,
    required this.onSearch,
    required this.onStatusSelected,
  });

  final TextEditingController controller;
  final String? selectedStatus;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    return HivorrTextField(
      controller: controller,
      hint: 'Search users...',
      textInputAction: TextInputAction.search,
      onSubmitted: onSearch,
      prefix: Icon(Icons.search, color: colors.onSurfaceVariant),
      suffix: PopupMenuButton<String?>(
        icon: Icon(
          Icons.filter_list_outlined,
          color: selectedStatus == null
              ? colors.onSurfaceVariant
              : context.roleTheme.clientPrimary,
        ),
        tooltip: selectedStatus == null
            ? 'Filter by status'
            : 'Status: $selectedStatus',
        onSelected: onStatusSelected,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
          const PopupMenuItem<String?>(
            value: null,
            child: Text('All statuses'),
          ),
          const PopupMenuItem<String?>(
            value: 'active',
            child: Text('Active'),
          ),
          const PopupMenuItem<String?>(
            value: 'suspended',
            child: Text('Suspended'),
          ),
          const PopupMenuItem<String?>(
            value: 'deactivated',
            child: Text('Deactivated'),
          ),
          const PopupMenuItem<String?>(
            value: 'deleted',
            child: Text('Deleted'),
          ),
        ],
      ),
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.wide,
    required this.provider,
    required this.emptySubtitle,
    required this.onView,
    required this.onSuspend,
    required this.onLoadMore,
    required this.onRetry,
  });

  final bool wide;
  final ManageUserProvider provider;
  final String emptySubtitle;
  final ValueChanged<ManageUserListItem> onView;
  final ValueChanged<ManageUserListItem> onSuspend;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(HivorrSpacing.md),
        child: HivorrLoadingState(),
      );
    }
    // Empty/error states carry their own internal padding.
    if (provider.lastError != null && provider.users.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(Icons.error_outline, color: context.colorScheme.error),
        title: 'Failed to load users',
        subtitle: provider.lastError!.message,
      );
    }
    if (provider.users.isEmpty) {
      return HivorrEmptyState(
        icon: Icon(Icons.group_outlined, color: context.colorScheme.primary),
        title: 'No users found',
        subtitle: emptySubtitle,
      );
    }
    if (wide) {
      return _UserTable(
        provider: provider,
        onView: onView,
        onSuspend: onSuspend,
        onLoadMore: onLoadMore,
        onRetry: onRetry,
      );
    }
    return _UserList(
      provider: provider,
      onView: onView,
      onSuspend: onSuspend,
      onLoadMore: onLoadMore,
    );
  }
}

/// Wide table matching the reference columns:
/// User | Role | Jobs | Status | Joined | Actions.
class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.provider,
    required this.onView,
    required this.onSuspend,
    required this.onLoadMore,
    required this.onRetry,
  });

  final ManageUserProvider provider;
  final ValueChanged<ManageUserListItem> onView;
  final ValueChanged<ManageUserListItem> onSuspend;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final List<ManageUserListItem> users = provider.users;
    return Column(
      children: <Widget>[
        HivorrDataTable(
          // Actions carries flex 16 (not 14): the dual pills need ~160dp
          // and the user cell ellipsizes, so it donates the room.
          columns: const <HivorrDataColumn>[
            HivorrDataColumn('User', flex: 20),
            HivorrDataColumn('Role', flex: 11),
            HivorrDataColumn('Jobs', flex: 6),
            HivorrDataColumn('Status', flex: 9),
            HivorrDataColumn('Joined', flex: 9),
            HivorrDataColumn('Actions', flex: 16),
          ],
          rows: <HivorrDataRow>[
            for (final ManageUserListItem user in users)
              HivorrDataRow(
                cells: <HivorrDataCell>[
                  HivorrDataCell(_UserCell(user: user), flex: 20),
                  HivorrDataCell(
                    HivorrCapabilityBadge(capability: user.capability),
                    flex: 11,
                  ),
                  const HivorrDataCell(_JobsCell(), flex: 6),
                  HivorrDataCell(_UserStatusBadge(user: user), flex: 9),
                  HivorrDataCell(
                    _JoinedCell(createdAt: user.createdAt),
                    flex: 9,
                  ),
                  HivorrDataCell(
                    _UserActions(
                      user: user,
                      onView: () => onView(user),
                      onSuspend: () => onSuspend(user),
                    ),
                    flex: 16,
                  ),
                ],
              ),
          ],
        ),
        if (provider.lastError != null)
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: Text(
              provider.lastError!.message,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ),
        if (provider.hasMore)
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: HivorrButton(
              label: 'Load more',
              variant: HivorrButtonVariant.outline,
              size: HivorrButtonSize.small,
              isLoading: provider.isLoading,
              onPressed: onLoadMore,
            ),
          )
        else
          const SizedBox(height: HivorrSpacing.md),
      ],
    );
  }
}

/// View + Suspend pills for one directory row (table and narrow cards share
/// the table variant; narrow cards use full buttons — see [_NarrowCard]).
class _UserActions extends StatelessWidget {
  const _UserActions({
    required this.user,
    required this.onView,
    required this.onSuspend,
  });

  final ManageUserListItem user;
  final VoidCallback onView;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final bool suspendable = user.status == 'active';
    return Row(
      children: <Widget>[
        HivorrTableAction(
          label: 'View',
          foreground: context.roleTheme.clientPrimary,
          background: context.roleTheme.clientContainer,
          onTap: onView,
        ),
        if (suspendable) ...<Widget>[
          const SizedBox(width: HivorrSpacing.sm),
          HivorrTableAction(
            label: 'Suspend',
            foreground: context.colorScheme.error,
            background: context.colorScheme.errorContainer,
            onTap: onSuspend,
          ),
        ],
      ],
    );
  }
}

/// Narrow card list: same pills, typography, and actions as the table.
class _UserList extends StatelessWidget {
  const _UserList({
    required this.provider,
    required this.onView,
    required this.onSuspend,
    required this.onLoadMore,
  });

  final ManageUserProvider provider;
  final ValueChanged<ManageUserListItem> onView;
  final ValueChanged<ManageUserListItem> onSuspend;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final List<ManageUserListItem> users = provider.users;
    return Column(
      children: <Widget>[
        for (int i = 0; i < users.length; i++) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HivorrSpacing.md,
              HivorrSpacing.smMd,
              HivorrSpacing.md,
              0,
            ),
            child: _NarrowCard(
              user: users[i],
              onView: () => onView(users[i]),
              onSuspend: () => onSuspend(users[i]),
            ),
          ),
          if (i == users.length - 1)
            const SizedBox(height: HivorrSpacing.md),
        ],
        if (provider.hasMore)
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: HivorrButton(
              label: 'Load more',
              variant: HivorrButtonVariant.outline,
              size: HivorrButtonSize.small,
              isLoading: provider.isLoading,
              onPressed: onLoadMore,
            ),
          )
        else
          const SizedBox(height: HivorrSpacing.sm),
      ],
    );
  }
}

class _NarrowCard extends StatelessWidget {
  const _NarrowCard({
    required this.user,
    required this.onView,
    required this.onSuspend,
  });

  final ManageUserListItem user;
  final VoidCallback onView;
  final VoidCallback onSuspend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final AppThemeExtension ext = context.appExtension;
    final bool suspendable = user.status == 'active';
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(ext.radiusXs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _UserCell(user: user),
          const SizedBox(height: HivorrSpacing.sm),
          Wrap(
            spacing: HivorrSpacing.sm,
            runSpacing: HivorrSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              HivorrCapabilityBadge(capability: user.capability),
              _UserStatusBadge(user: user),
              Text(
                _joinedLabel(user.createdAt),
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          // Touch layout: full 48dp buttons (tables use compact actions).
          Row(
            children: <Widget>[
              Expanded(
                child: HivorrButton(
                  label: 'View',
                  variant: HivorrButtonVariant.outline,
                  size: HivorrButtonSize.small,
                  onPressed: onView,
                ),
              ),
              if (suspendable) ...<Widget>[
                const SizedBox(width: HivorrSpacing.sm),
                Expanded(
                  child: HivorrButton(
                    label: 'Suspend',
                    variant: HivorrButtonVariant.outline,
                    size: HivorrButtonSize.small,
                    onPressed: onSuspend,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UserCell extends StatelessWidget {
  const _UserCell({required this.user});

  final ManageUserListItem user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = context.colorScheme;
    final String name = _displayNameOf(user);
    final _AvatarTint tint = _tintFor(context, name);
    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tint.background,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initialsOf(name),
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: tint.foreground,
              ),
            ),
          ),
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
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              Text(
                _subtitleOf(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Jobs column: no per-user jobs aggregate RPC exists yet, so the honest
/// unavailable mark is shown instead of fabricated counts.
class _JobsCell extends StatelessWidget {
  const _JobsCell();

  @override
  Widget build(BuildContext context) {
    return Text(
      '—',
      style: context.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurface,
      ),
    );
  }
}

/// Lifecycle status as a shared [HivorrBadge] (VISUAL-IDENTITY.md §21b).
/// `Pending` (amber) derives from live directory data: an `active` entity
/// that has not completed onboarding yet. The underlying lifecycle value is
/// unchanged — full status management stays on the user-detail screen.
class _UserStatusBadge extends StatelessWidget {
  const _UserStatusBadge({required this.user});

  final ManageUserListItem user;

  @override
  Widget build(BuildContext context) {
    return HivorrBadge(
      label: _statusLabelOf(user.status, user.onboardingCompleted),
      variant: _statusVariantOf(user.status, user.onboardingCompleted),
    );
  }
}

String _statusLabelOf(String status, bool onboardingCompleted) {
  if (status == 'active' && !onboardingCompleted) return 'Pending';
  return switch (status) {
    'active' => 'Active',
    'suspended' => 'Suspended',
    'deactivated' => 'Deactivated',
    'deleted' => 'Deleted',
    _ => status,
  };
}

HivorrBadgeVariant _statusVariantOf(String status, bool onboardingCompleted) {
  if (status == 'active' && !onboardingCompleted) {
    return HivorrBadgeVariant.warning;
  }
  return switch (status) {
    'active' => HivorrBadgeVariant.success,
    'suspended' => HivorrBadgeVariant.error,
    _ => HivorrBadgeVariant.neutral,
  };
}

class _JoinedCell extends StatelessWidget {
  const _JoinedCell({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Text(
      _joinedLabel(createdAt),
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _joinedLabel(DateTime createdAt) {
  try {
    return DateFormat('MMM yyyy', 'en').format(createdAt);
  } catch (_) {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
  }
}

String _displayNameOf(ManageUserListItem user) {
  final String name = user.displayName.isNotEmpty
      ? user.displayName
      : (user.legalName ?? '');
  return name.isNotEmpty ? name : 'Unnamed user';
}

/// Secondary identity line from real directory data only: legal name when
/// it differs from the display name, else roles, else capability.
String _subtitleOf(ManageUserListItem user) {
  final String display = user.displayName;
  final String? legal = user.legalName;
  if (legal != null && legal.isNotEmpty && legal != display) {
    return legal;
  }
  if (user.roles.isNotEmpty) return user.roles.join(', ');
  final String? role = _roleLabelOf(user.capability);
  if (role != null) return role;
  return user.id.length > 8 ? '${user.id.substring(0, 8)}…' : user.id;
}

/// Screenshot vocabulary for capabilities: `hire` clients are Employers.
String? _roleLabelOf(String? capability) => switch (capability) {
  'hire' => 'Employer',
  'client' => 'Employer',
  'offer' => 'Professional',
  'professional' => 'Professional',
  'both' => 'Both',
  null => null,
  '' => null,
  _ => capability,
};

String _initialsOf(String name) {
  final List<String> words = name
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final String word = words.first.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (word.isEmpty) return words.first[0].toUpperCase();
    return word.length == 1
        ? word.toUpperCase()
        : word.substring(0, 2).toUpperCase();
  }
  return '${words[0][0].toUpperCase()}${words[1][0].toUpperCase()}';
}

class _AvatarTint {
  const _AvatarTint({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

/// Avatar tints bound to theme tokens (dark-mode safe) instead of raw hex.
_AvatarTint _tintFor(BuildContext context, String name) {
  final RoleThemeExtension roles = context.roleTheme;
  final AppThemeExtension ext = context.appExtension;
  final ColorScheme colors = context.colorScheme;
  final List<_AvatarTint> tints = <_AvatarTint>[
    _AvatarTint(
      background: roles.bothContainer,
      foreground: roles.bothPrimary,
    ),
    _AvatarTint(
      background: ext.successContainer,
      foreground: ext.success,
    ),
    _AvatarTint(
      background: ext.warningContainer,
      foreground: ext.warning,
    ),
    _AvatarTint(
      background: roles.clientContainer,
      foreground: roles.clientPrimary,
    ),
    _AvatarTint(
      background: colors.errorContainer,
      foreground: colors.error,
    ),
    _AvatarTint(background: ext.infoContainer, foreground: ext.info),
  ];
  int hash = 0;
  for (final int code in name.codeUnits) {
    hash = (hash * 31 + code) % 1000003;
  }
  return tints[hash % tints.length];
}
