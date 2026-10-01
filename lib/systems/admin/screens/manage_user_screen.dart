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
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Manage User directory screen (EP-02-11 admin console).
///
/// Visual source of truth: Admin Dashboard Users reference screenshot —
/// `User Management` title + total-users subtitle + `Export CSV`, a white
/// rounded card holding the search field and the
/// User | Role | Jobs | Status | Joined | Actions table.
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
        unawaited(manage.loadUsers(
          capability: _capability,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          status: _selectedStatus,
        ));
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
        final bool wide = constraints.maxWidth >= 720;
        return RefreshIndicator(
          onRefresh: () => provider.loadUsers(
            search: provider.search,
            status: provider.statusFilter,
            capability: _capability,
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(HivorrSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  totalLabel: provider.isListHydrated
                      ? '${_formatCount(provider.totalCount)} $_populationLabel'
                      : (provider.isLoading
                          ? 'Loading users…'
                          : 'User directory'),
                  exporting: _exporting,
                  canExport: provider.users.isNotEmpty && !_exporting,
                  onExport: () => _exportCsv(context, provider),
                ),
                const SizedBox(height: HivorrSpacing.lg),
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
                const SizedBox(height: HivorrSpacing.lg),
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
      message: 'Suspend $name? The account is temporarily disabled. '
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
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
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
      final Uint8List bytes =
          Uint8List.fromList(utf8.encode(csv));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _buildCsv(List<ManageUserListItem> users) {
    final StringBuffer out = StringBuffer();
    out.writeln(
        'id,display_name,legal_name,capability,status,kyc_tier,roles,is_admin,onboarding_completed,created_at');
    for (final ManageUserListItem user in users) {
      out.writeln(<String>[
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
      ].join(','));
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

/// Title + subtitle + Export CSV, as in the reference.
class _Header extends StatelessWidget {
  const _Header({
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
    final ColorScheme colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'User Management',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalLabel,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: canExport ? onExport : null,
          icon: exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.filter_list_outlined, size: 18),
          label: const Text('Export CSV'),
          style: TextButton.styleFrom(
            foregroundColor: context.roleTheme.clientPrimary,
            textStyle: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
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
    final ColorScheme colors = context.colorScheme;
    return Container(
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
          Divider(height: 1, color: colors.outlineVariant),
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
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSearch,
      decoration: InputDecoration(
        hintText: 'Search users...',
        hintStyle: context.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
        suffixIcon: PopupMenuButton<String?>(
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
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<String?>>[
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
        filled: true,
        fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
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
          borderSide: BorderSide(color: colors.outline),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
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
        padding: EdgeInsets.all(HivorrSpacing.xl),
        child: HivorrLoadingState(),
      );
    }
    if (provider.lastError != null && provider.users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(HivorrSpacing.xl),
        child: HivorrEmptyState(
          icon: Icon(Icons.error_outline, color: context.colorScheme.error),
          title: 'Failed to load users',
          subtitle: provider.lastError!.message,
        ),
      );
    }
    if (provider.users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(HivorrSpacing.xl),
        child: HivorrEmptyState(
          icon: Icon(Icons.group_outlined,
              color: context.colorScheme.primary),
          title: 'No users found',
          subtitle: emptySubtitle,
        ),
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
    final ColorScheme colors = context.colorScheme;
    final List<ManageUserListItem> users = provider.users;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 22,
                child: _HeaderLabel('User'),
              ),
              Expanded(flex: 11, child: _HeaderLabel('Role')),
              Expanded(flex: 6, child: _HeaderLabel('Jobs')),
              Expanded(flex: 9, child: _HeaderLabel('Status')),
              Expanded(flex: 9, child: _HeaderLabel('Joined')),
              Expanded(
                flex: 14,
                child: _HeaderLabel('Actions'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        for (int i = 0; i < users.length; i++) ...<Widget>[
          _UserRow(
            user: users[i],
            onView: () => onView(users[i]),
            onSuspend: () => onSuspend(users[i]),
          ),
          if (i < users.length - 1)
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
        ],
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
            child: provider.isLoading
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: onLoadMore,
                    child: const Text('Load more'),
                  ),
          )
        else
          const SizedBox(height: HivorrSpacing.md),
      ],
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(flex: 22, child: _UserCell(user: user)),
          Expanded(flex: 11, child: _RolePill(capability: user.capability)),
          const Expanded(flex: 6, child: _JobsCell()),
          Expanded(
            flex: 9,
            child: _StatusDot(
              status: user.status,
              onboardingCompleted: user.onboardingCompleted,
            ),
          ),
          Expanded(flex: 9, child: _JoinedCell(createdAt: user.createdAt)),
          Expanded(
            flex: 14,
            child: Row(
              children: <Widget>[
                _ActionPill(
                  label: 'View',
                  foreground: const Color(0xFF2D3FE7),
                  background: const Color(0xFFEEF0FD),
                  onTap: onView,
                ),
                if (suspendable) ...<Widget>[
                  const SizedBox(width: HivorrSpacing.sm),
                  _ActionPill(
                    label: 'Suspend',
                    foreground: const Color(0xFFEF4444),
                    background: const Color(0xFFFEF2F2),
                    onTap: onSuspend,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _NarrowCard(
              user: users[i],
              onView: () => onView(users[i]),
              onSuspend: () => onSuspend(users[i]),
            ),
          ),
          if (i == users.length - 1) const SizedBox(height: 16),
        ],
        if (provider.hasMore)
          Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: provider.isLoading
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: onLoadMore,
                    child: const Text('Load more'),
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
    final bool suspendable = user.status == 'active';
    return Container(
      padding: const EdgeInsets.all(HivorrSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
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
              _RolePill(capability: user.capability),
              _StatusDot(
                status: user.status,
                onboardingCompleted: user.onboardingCompleted,
              ),
              Text(
                _joinedLabel(user.createdAt),
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: HivorrSpacing.sm),
          Row(
            children: <Widget>[
              _ActionPill(
                label: 'View',
                foreground: const Color(0xFF2D3FE7),
                background: const Color(0xFFEEF0FD),
                onTap: onView,
              ),
              if (suspendable) ...<Widget>[
                const SizedBox(width: HivorrSpacing.sm),
                _ActionPill(
                  label: 'Suspend',
                  foreground: const Color(0xFFEF4444),
                  background: const Color(0xFFFEF2F2),
                  onTap: onSuspend,
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
    final _AvatarTint tint = _tintFor(name);
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint.background,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initialsOf(name),
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
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

/// Role pill from the reference: `Professional` green, `Employer` blue.
/// Falls back to the raw capability (or `—`) so real data is never hidden.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.capability});

  final String? capability;

  @override
  Widget build(BuildContext context) {
    final String? label = _roleLabelOf(capability);
    if (label == null) {
      return Text(
        '—',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final bool professional = label == 'Professional';
    final bool employer = label == 'Employer';
    final Color fg = professional
        ? const Color(0xFF16A34A)
        : (employer
            ? const Color(0xFF2D3FE7)
            : context.roleTheme.adminPrimary);
    final Color bg = professional
        ? const Color(0xFFDCFCE7)
        : (employer
            ? const Color(0xFFEEF0FD)
            : context.colorScheme.secondaryContainer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
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

/// Status dot + label from the reference. `Pending` (amber) derives from
/// live directory data: an `active` entity that has not completed
/// onboarding yet. The underlying lifecycle value is unchanged — full
/// status management stays on the user-detail screen.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status, required this.onboardingCompleted});

  final String status;
  final bool onboardingCompleted;

  @override
  Widget build(BuildContext context) {
    final _StatusLook look =
        _lookFor(status, context, onboardingCompleted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: look.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          look.label,
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: look.color,
          ),
        ),
      ],
    );
  }
}

class _StatusLook {
  const _StatusLook({required this.label, required this.color});

  final String label;
  final Color color;
}

_StatusLook _lookFor(
    String status, BuildContext context, bool onboardingCompleted) {
  if (status == 'active' && !onboardingCompleted) {
    return const _StatusLook(
        label: 'Pending', color: Color(0xFFF97316));
  }
  return switch (status) {
    'active' => const _StatusLook(
        label: 'Active', color: Color(0xFF16A34A)),
    'suspended' => const _StatusLook(
        label: 'Suspended', color: Color(0xFFEF4444)),
    'deactivated' => _StatusLook(
        label: 'Deactivated',
        color: context.colorScheme.onSurfaceVariant),
    'deleted' => _StatusLook(
        label: 'Deleted', color: context.colorScheme.onSurfaceVariant),
    _ => _StatusLook(
        label: status,
        color: context.colorScheme.onSurfaceVariant),
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

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
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
  if (legal != null &&
      legal.isNotEmpty &&
      legal != display) {
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

_AvatarTint _tintFor(String name) {
  const List<_AvatarTint> tints = <_AvatarTint>[
    _AvatarTint(
        background: Color(0xFFF3F0FF), foreground: Color(0xFF8B5CF6)),
    _AvatarTint(
        background: Color(0xFFDCFCE7), foreground: Color(0xFF16A34A)),
    _AvatarTint(
        background: Color(0xFFFFF7ED), foreground: Color(0xFFF97316)),
    _AvatarTint(
        background: Color(0xFFEEF0FD), foreground: Color(0xFF2D3FE7)),
    _AvatarTint(
        background: Color(0xFFFEF2F2), foreground: Color(0xFFEF4444)),
    _AvatarTint(
        background: Color(0xFFE0F2FE), foreground: Color(0xFF0891B2)),
  ];
  int hash = 0;
  for (final int code in name.codeUnits) {
    hash = (hash * 31 + code) % 1000003;
  }
  return tints[hash % tints.length];
}
