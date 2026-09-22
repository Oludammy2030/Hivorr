import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hivorr/app/router/route_names.dart';
import 'package:hivorr/config/permissions/admin_gate.dart';
import 'package:hivorr/data/providers/admin_review_provider.dart';
import 'package:hivorr/data/providers/manage_user_provider.dart';
import 'package:hivorr/data/repositories/manage_user_repository.dart';
import 'package:hivorr/shared/extensions/build_context_extensions.dart';
import 'package:hivorr/shared/helpers/hivorr_spacing.dart';
import 'package:hivorr/shared/widgets/hivorr_button.dart';
import 'package:hivorr/shared/widgets/hivorr_card.dart';
import 'package:hivorr/shared/widgets/hivorr_empty_state.dart';
import 'package:hivorr/shared/widgets/hivorr_loading_state.dart';
import 'package:provider/provider.dart';

/// Manage User directory screen (EP-02-11 admin console).
///
/// Displays a paginated, searchable user directory with status filtering.
/// Tapping a row navigates to the detail screen. Admin gating is shared with
/// the review console: [AdminGate.isAdmin] over the [AdminReviewProvider]
/// (fail-closed), while directory data flows through the [ManageUserProvider].
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

  String? get _capability => widget.capability;

  String get _title => switch (_capability) {
        'professional' => 'Professionals',
        'client' => 'Clients',
        _ => 'All Users',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: context.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => unawaited(
              provider.loadUsers(
                search: provider.search,
                status: provider.statusFilter,
                capability: _capability,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: !AdminGate.isAdmin(admin)
            ? HivorrEmptyState(
                icon: Icon(
                  Icons.admin_panel_settings_outlined,
                  color: context.colorScheme.primary,
                ),
                title: 'Admin access required',
                subtitle: 'You do not have platform admin privileges.',
              )
            : Column(
                children: <Widget>[
                  _filters(provider),
                  Expanded(child: _body(provider)),
                ],
              ),
      ),
    );
  }

  Widget _filters(ManageUserProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HivorrSpacing.lg,
        HivorrSpacing.xs,
        HivorrSpacing.lg,
        HivorrSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (String value) => unawaited(
                provider.loadUsers(
                  search: value.trim().isEmpty ? null : value.trim(),
                  status: _selectedStatus,
                  capability: _capability,
                ),
              ),
            ),
          ),
          const SizedBox(width: HivorrSpacing.sm),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: (String? status) {
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
        ],
      ),
    );
  }

  Widget _body(ManageUserProvider provider) {
    if (provider.isLoading && provider.users.isEmpty) {
      return const HivorrLoadingState();
    }
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
        subtitle: _emptySubtitle,
      );
    }
    return RefreshIndicator(
      onRefresh: () => provider.loadUsers(
        search: provider.search,
        status: provider.statusFilter,
        capability: _capability,
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(HivorrSpacing.lg),
        itemCount: provider.users.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index == provider.users.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: HivorrSpacing.md),
              child: Center(
                child: provider.isLoading
                    ? const CircularProgressIndicator()
                    : HivorrButton(
                        label: 'Load more',
                        onPressed: () => unawaited(provider.loadMore()),
                      ),
              ),
            );
          }
          final ManageUserListItem user = provider.users[index];
          return _UserCard(
            key: ValueKey<String>(user.id),
            user: user,
            onTap: () => context.pushNamed(
              RouteNames.adminManageUserDetail,
              pathParameters: <String, String>{'userId': user.id},
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({super.key, required this.user, required this.onTap});

  final ManageUserListItem user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = _displayName(user);
    return Padding(
      padding: const EdgeInsets.only(bottom: HivorrSpacing.md),
      child: HivorrCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(HivorrSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(name, style: context.textTheme.titleMedium),
                    ),
                    _StatusChip(status: user.status),
                  ],
                ),
                if (user.roles.isNotEmpty) ...<Widget>[
                  const SizedBox(height: HivorrSpacing.xs),
                  Text(
                    user.roles.join(', '),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: HivorrSpacing.xs),
                Wrap(
                  spacing: HivorrSpacing.sm,
                  children: <Widget>[
                    if (user.isAdmin)
                      Text(
                        'Admin',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (user.capability != null && user.capability!.isNotEmpty)
                      Text(
                        _capabilityLabel(user.capability!),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (user.kycTier != null && user.kycTier!.isNotEmpty)
                      Text(
                        'KYC: ${user.kycTier}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      user.onboardingCompleted
                          ? 'Onboarding complete'
                          : 'Onboarding pending',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _displayName(ManageUserListItem user) {
    final String name = user.displayName.isNotEmpty
        ? user.displayName
        : (user.legalName ?? '');
    return name.isNotEmpty ? name : 'Unnamed user';
  }

  static String _capabilityLabel(String cap) => switch (cap) {
        'hire' => 'Client',
        'offer' => 'Professional',
        'both' => 'Both',
        _ => cap,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'active' => context.colorScheme.primary,
      'suspended' => context.colorScheme.error,
      'deactivated' => context.colorScheme.onSurfaceVariant,
      _ => context.colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HivorrSpacing.sm,
        vertical: HivorrSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
